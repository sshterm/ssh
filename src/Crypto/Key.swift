// Key.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/27.

//
//  PEM.swift
//  SSH
//
//  Created by 费三量 on 2024/8/27.
//
#if OPEN_SSL
    import Foundation
    import OpenSSL

    public extension Crypto {
        /// 生成指定位数的RSA密钥对
        /// - Parameter bits: 密钥位数，默认为2048位
        /// - Returns: 生成的密钥对的OpaquePointer，如果失败则返回nil
        func keygenRSA(_ bits: Int = 2048) -> OpaquePointer? {
            keygen(bits, id: .rsa)
        }

        /// 生成ED25519密钥对
        /// - Returns: 生成的密钥对的OpaquePointer，如果失败则返回nil
        func generateED25519() -> OpaquePointer? {
            keygen(id: .ed25519)
        }

        /// 根据指定的算法和位数生成密钥对
        /// - Parameters:
        ///   - bits: 密钥位数，对于RSA算法有效，默认为2048位
        ///   - id: 密钥算法类型，默认为RSA
        /// - Returns: 生成的密钥对的OpaquePointer，如果失败则返回nil
        private func keygen(_ bits: Int = 2048, id: keyAlgorithm = .rsa) -> OpaquePointer? {
            let genctx = EVP_PKEY_CTX_new_id(id.id, nil)
            defer {
                EVP_PKEY_CTX_free(genctx)
            }
            EVP_PKEY_keygen_init(genctx)

            switch id {
            case .rsa:
                EVP_PKEY_CTX_set_rsa_keygen_bits(genctx, Int32(bits))
                EVP_PKEY_CTX_set_rsa_keygen_primes(genctx, 2)
            case .ed25519:
                break
            }

            var pkey = EVP_PKEY_new()
            EVP_PKEY_keygen(genctx, &pkey)
            return pkey
        }

        /// 释放密钥对的内存
        /// - Parameter pkey: 需要释放的密钥对的OpaquePointer
        func freeKey(_ pkey: OpaquePointer?) {
            EVP_PKEY_free(pkey)
        }

        /// 将BIO对象的内容转换为String
        /// - Parameter bio: BIO对象的OpaquePointer
        /// - Returns: BIO对象内容的String表示
        func bioToString(bio: OpaquePointer) -> String {
            let len = BIO_ctrl(bio, BIO_CTRL_PENDING, 0, nil)
            var buffer = [CChar](repeating: 0, count: len + 1)
            BIO_read(bio, &buffer, Int32(len))

            buffer[len] = 0
            let ret = String(cString: buffer)
            return ret
        }

        /// 将公钥转换为PEM格式的字符串
        /// - Parameter privKey: 公钥的OpaquePointer
        /// - Returns: PEM格式的公钥字符串
        func pubKeyToPEM(privKey: OpaquePointer) -> String {
            let out = BIO_new(BIO_s_mem())!
            defer { BIO_free(out) }

            PEM_write_bio_PUBKEY(out, privKey)
            let str = bioToString(bio: out)

            return str
        }

        /// 将私钥转换为PEM格式的字符串
        /// - Parameters:
        ///   - privKey: 私钥的OpaquePointer
        ///   - password: 可选的密码，用于加密私钥，默认为空
        /// - Returns: PEM格式的私钥字符串
        func privKeyToPEM(privKey: OpaquePointer, password: String = "") -> String {
            let out = BIO_new(BIO_s_mem())!
            defer { BIO_free(out) }
            if password.isEmpty {
                PEM_write_bio_PrivateKey(out, privKey, nil, nil, 0, nil, nil)
            } else {
                PEM_write_bio_PrivateKey(out, privKey, EVP_aes_256_cbc(), password, password.countInt32, nil, nil)
            }
            let str = bioToString(bio: out)

            return str
        }
    }

#endif
