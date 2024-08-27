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
        func keygen(_ bits: Int = 2048, id: keyAlgorithm = .rsa) -> OpaquePointer? {
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

        func keygen(id: keyAlgorithm = .ed25519) -> OpaquePointer? {
            return keygen(0, id: id)
        }

        func freeKey(_ pkey: OpaquePointer?) {
            EVP_PKEY_free(pkey)
        }

        func bioToString(bio: OpaquePointer) -> String {
            let len = BIO_ctrl(bio, BIO_CTRL_PENDING, 0, nil)
            var buffer = [CChar](repeating: 0, count: len + 1)
            BIO_read(bio, &buffer, Int32(len))

            buffer[len] = 0
            let ret = String(cString: buffer)
            return ret
        }

        func pubKeyToPEM(privKey: OpaquePointer) -> String {
            let out = BIO_new(BIO_s_mem())!
            defer { BIO_free(out) }

            PEM_write_bio_PUBKEY(out, privKey)
            let str = bioToString(bio: out)

            return str
        }

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
