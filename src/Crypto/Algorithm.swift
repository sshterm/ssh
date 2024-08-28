// Algorithm.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/19.

import Foundation
#if OPEN_SSL
    import OpenSSL
#else
    import wolfSSL
#endif
public enum ShaAlgorithm: String, CaseIterable {
    #if OPEN_SSL
        case md4, md5, md5_sha1, sha1, sha224, sha256, sha384, sha512, sha512_224, sha512_256, sha3_224, sha3_256, sha3_384, sha3_512
    #else
        case md4, md5, sha1, sha224, sha256, sha384, sha512, sha512_224, sha512_256, sha3_224, sha3_256, sha3_384, sha3_512
    #endif
    #if OPEN_SSL
        public var EVP: OpaquePointer? {
            switch self {
            case .md4:
                EVP_md4()
            case .md5:
                EVP_md5()
            case .md5_sha1:
                EVP_md5_sha1()
            case .sha1:
                EVP_sha1()
            case .sha224:
                EVP_sha224()
            case .sha256:
                EVP_sha256()
            case .sha384:
                EVP_sha384()
            case .sha512:
                EVP_sha512()
            case .sha512_224:
                EVP_sha512_224()
            case .sha512_256:
                EVP_sha512_256()
            case .sha3_224:
                EVP_sha3_224()
            case .sha3_256:
                EVP_sha3_256()
            case .sha3_384:
                EVP_sha3_384()
            case .sha3_512:
                EVP_sha3_512()
            }
        }
    #else
        public var EVP: UnsafePointer<WOLFSSL_EVP_MD>? {
            switch self {
            case .md4:
                wolfSSL_EVP_md4()
            case .md5:
                wolfSSL_EVP_md5()
            case .sha1:
                wolfSSL_EVP_sha1()
            case .sha224:
                wolfSSL_EVP_sha224()
            case .sha256:
                wolfSSL_EVP_sha256()
            case .sha384:
                wolfSSL_EVP_sha384()
            case .sha512:
                wolfSSL_EVP_sha512()
            case .sha512_224:
                wolfSSL_EVP_sha512_224()
            case .sha512_256:
                wolfSSL_EVP_sha512_256()
            case .sha3_224:
                wolfSSL_EVP_sha3_224()
            case .sha3_256:
                wolfSSL_EVP_sha3_256()
            case .sha3_384:
                wolfSSL_EVP_sha3_384()
            case .sha3_512:
                wolfSSL_EVP_sha3_512()
            }
        }
    #endif
    // 返回算法的摘要长度
    public var digest: Int {
        #if OPEN_SSL
            Int(EVP_MD_get_size(EVP))
        #else
            Int(wolfSSL_EVP_MD_size(EVP))
        #endif
    }
}

#if OPEN_SSL
    public enum keyAlgorithm: String, CaseIterable {
        case rsa, ed25519

        var id: Int32 {
            switch self {
            case .rsa:
                EVP_PKEY_RSA
            case .ed25519:
                EVP_PKEY_ED25519
            }
        }
    }
#endif
