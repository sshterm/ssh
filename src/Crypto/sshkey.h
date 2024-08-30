// sshkey.h
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/26.

#ifndef sshkey_h
#define sshkey_h

#include <openssl.h>

// 函数：sshkey_ed25519_pub
// 功能：从给定的EVP_PKEY结构体中提取Ed25519公钥，并将其转换为字符串格式返回。
// 参数：
//   pkey - 指向EVP_PKEY结构体的指针，该结构体包含Ed25519密钥对。
// 返回值：
//   成功时返回表示Ed25519公钥的字符串指针；失败时返回NULL。

char *sshkey_ed25519_pub(EVP_PKEY *pkey);

// 函数：sshkey_rsa_pub
// 功能：从给定的EVP_PKEY结构体中提取RSA公钥，并将其转换为字符串格式返回。
// 参数：
//   pkey - 指向EVP_PKEY结构体的指针，该结构体包含RSA密钥对。
// 返回值：
//   成功时返回表示RSA公钥的字符串指针；失败时返回NULL。
char *sshkey_rsa_pub(EVP_PKEY *pkey);

// sshkey_pub 函数用于导出给定 EVP_PKEY 对象的 SSH 公钥。
// 参数:
//   pkey: 指向 EVP_PKEY 对象的指针，该对象包含要导出的私钥。
//   key_type: 指定要导出的公钥类型，例如 "ssh-ed25519" 或 "ssh-rsa"。
// 返回值:
//   成功时返回一个指向导出的公钥字符串的指针，失败时返回 NULL。
char *sshkey_pub(EVP_PKEY *pkey, const char *key_type);

#endif /* sshkey_h */
