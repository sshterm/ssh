// Algorithm.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/19.

import Foundation
import wolfSSL

public enum Algorithm: String, CaseIterable {
    case md5, sha1, sha224, sha256, sha384, sha512, sha512_224, sha512_256, sha3_224, sha3_256, sha3_384, sha3_512, ripemd160

    // 返回对应算法的OpaquePointer，用于后续的加密操作
    public var EVP: UnsafePointer<WOLFSSL_EVP_MD>? {
        switch self {
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
        case .ripemd160:
            wolfSSL_EVP_ripemd160()
        }
    }

    // 返回算法的摘要长度，以Int类型表示
    public var digestInt32: Int32 {
        Int32(digest)
    }

    // 返回算法的摘要长度，以Int32类型表示
    public var digest: Int {
        switch self {
        case .md5:
            16
        case .sha1:
            20
        case .sha224:
            28
        case .sha256:
            32
        case .sha384:
            48
        case .sha512:
            64
        case .sha512_224:
            28
        case .sha512_256:
            32
        case .sha3_224:
            28
        case .sha3_256:
            32
        case .sha3_384:
            48
        case .sha3_512:
            64
        case .ripemd160:
            20
        }
    }
}
