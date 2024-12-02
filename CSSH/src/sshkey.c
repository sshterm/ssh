// sshkey.c
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/26.

#include "sshkey.h"

/*
 * base64_encode - 将二进制数据编码为Base64字符串
 * @data: 指向要编码的数据的指针
 * @len: 数据的长度
 *
 * 返回值: 编码后的Base64字符串，需要使用free()释放
 */
char *base64_encode(const unsigned char *data, int len)
{
    BIO *bio, *b64;
    BUF_MEM *bufferPtr;

    b64 = BIO_new(BIO_f_base64());
    bio = BIO_new(BIO_s_mem());
    bio = BIO_push(b64, bio);

    BIO_set_flags(bio, BIO_FLAGS_BASE64_NO_NL);

    BIO_write(bio, data, len);
    BIO_flush(bio);
    BIO_get_mem_ptr(bio, &bufferPtr);

    char *b64text = (char *)malloc(bufferPtr->length + 1);
    memcpy(b64text, bufferPtr->data, bufferPtr->length);
    b64text[bufferPtr->length] = '\0';

    BIO_free_all(bio);

    return b64text;
}

// write_ssh_string 函数用于将字符串写入到BIO对象中
// bio: 目标BIO对象
// str: 要写入的字符串
void write_ssh_string(BIO *bio, const char *str)
{
    uint32_t len = htonl(strlen(str));
    BIO_write(bio, &len, 4);
    BIO_write(bio, str, (int)strlen(str));
}

// write_ssh_mpint 函数用于将大整数写入到BIO对象中
// bio: 目标BIO对象
// bn: 要写入的大整数
void write_ssh_mpint(BIO *bio, const BIGNUM *bn)
{
    int bytes_len = BN_num_bytes(bn);
    unsigned char *bytes = (unsigned char *)malloc(bytes_len);
    BN_bn2bin(bn, bytes);

    if (bytes[0] & 0x80)
    {
        uint32_t len = htonl(bytes_len + 1);
        BIO_write(bio, &len, 4);
        unsigned char zero = 0x00;
        BIO_write(bio, &zero, 1);
    }
    else
    {
        uint32_t len = htonl(bytes_len);
        BIO_write(bio, &len, 4);
    }

    BIO_write(bio, bytes, bytes_len);
    free(bytes);
}

// sshkey_pub 函数根据提供的密钥类型生成相应的 SSH 公钥字符串。
// 参数:
//   pkey: EVP_PKEY 结构体指针，包含私钥信息。
//   key_type: 字符串，指定要生成的公钥类型，可以是 "ssh-rsa" 或 "ssh-ed25519"。
// 返回值:
//   如果成功，返回一个指向生成的公钥字符串的指针。
//   如果失败或 key_type 不支持，返回 NULL。
char *sshkey_pub(EVP_PKEY *pkey, const char *key_type)
{
    if (strcmp(key_type, "ssh-rsa") == 0)
    {
        return sshkey_rsa_pub(pkey);
    }
    else if (strcmp(key_type, "ssh-ed25519") == 0)
    {
        return sshkey_ed25519_pub(pkey);
    }
    else
    {
        return NULL;
    }
}

/*
 * 函数功能：将公钥二进制数据编码为SSH公钥格式
 * 参数：
 *   pubkey_bin: 公钥的二进制数据指针
 *   pubkey_len: 公钥二进制数据的长度
 *   key_type: 公钥类型，如"ssh-ed25519"
 * 返回值：
 *   成功返回编码后的SSH公钥字符串，失败返回NULL
 */
char *sshkey_encode(unsigned char *pubkey_bin, size_t pubkey_len, const char *key_type)
{
    unsigned char *ssh_format = NULL;
    char *encoded_pubkey = NULL;
    char *ssh_public_key = NULL;
    size_t ssh_format_len;
    uint32_t key_type_len = htonl(strlen(key_type));
    uint32_t pubkey_len_net = htonl(pubkey_len);
    ssh_format_len = 4 + strlen(key_type) + 4 + pubkey_len;

    ssh_format = malloc(ssh_format_len);
    if (!ssh_format)
    {
        return NULL;
    }

    memcpy(ssh_format, &key_type_len, 4);
    memcpy(ssh_format + 4, key_type, strlen(key_type));
    memcpy(ssh_format + 4 + strlen(key_type), &pubkey_len_net, 4);
    memcpy(ssh_format + 8 + strlen(key_type), pubkey_bin, pubkey_len);

    encoded_pubkey = base64_encode(ssh_format, (int)ssh_format_len);
    free(ssh_format);

    if (!encoded_pubkey)
    {
        return NULL;
    }

    ssh_public_key = (char *)malloc(strlen(key_type) + strlen(encoded_pubkey) + 2);
    if (ssh_public_key)
    {
        sprintf(ssh_public_key, "%s %s\n", key_type, encoded_pubkey);
    }

    free(encoded_pubkey);

    return ssh_public_key;
}

// sshkey_ed25519_pub 生成 ed25519 公钥的 SSH 格式字符串
// pkey: EVP_PKEY 结构体指针，包含公钥信息
char *sshkey_ed25519_pub(EVP_PKEY *pkey)
{
    unsigned char *pubkey_bin = NULL;
    char *ssh_public_key = NULL;
    size_t pubkey_len;
    char *key_type = "ssh-ed25519";

    if (EVP_PKEY_get_raw_public_key(pkey, NULL, &pubkey_len) <= 0)
    {
        return NULL;
    }

    pubkey_bin = (unsigned char *)OPENSSL_malloc(pubkey_len);
    if (pubkey_bin == NULL)
    {
        return NULL;
    }

    if (EVP_PKEY_get_raw_public_key(pkey, pubkey_bin, &pubkey_len) <= 0)
    {
        OPENSSL_free(pubkey_bin);
        return NULL;
    }

    ssh_public_key = sshkey_encode(pubkey_bin, pubkey_len, key_type);
    if (ssh_public_key == NULL)
    {
        OPENSSL_free(pubkey_bin);
    }

    return ssh_public_key;
}

// sshkey_rsa_pub 生成 rsa 公钥的 SSH 格式字符串
// pkey: EVP_PKEY 结构体指针，包含公钥信息
char *sshkey_rsa_pub(EVP_PKEY *pkey)
{
    BIGNUM *n = NULL, *e = NULL;
    char *ssh_public_key = NULL;
    char *key_type = "ssh-rsa";
    EVP_PKEY_get_bn_param(pkey, "n", &n);
    EVP_PKEY_get_bn_param(pkey, "e", &e);
    BIO *bio = BIO_new(BIO_s_mem());
    if (!bio)
    {
        return NULL;
    }
    write_ssh_string(bio, key_type);
    write_ssh_mpint(bio, e);
    write_ssh_mpint(bio, n);

    BUF_MEM *bufferPtr;
    BIO_get_mem_ptr(bio, &bufferPtr);
    char *b64_pub_key = base64_encode((unsigned char *)bufferPtr->data, (int)bufferPtr->length);
    if (!b64_pub_key)
    {
        goto cleanup;
    }
    size_t ssh_public_key_len = strlen(key_type) + strlen(b64_pub_key) + 2;
    ssh_public_key = (char *)malloc(ssh_public_key_len);
    if (!ssh_public_key)
    {
        goto cleanup;
    }

    snprintf(ssh_public_key, ssh_public_key_len, "%s %s\n", key_type, b64_pub_key);

cleanup:
    BIO_free(bio);
    free(b64_pub_key);

    return ssh_public_key;
}
