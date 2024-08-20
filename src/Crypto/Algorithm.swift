// Algorithm.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/19.

import Foundation
import wolfSSL

public enum Algorithm: String, CaseIterable {
    case md5, sha1, sha224, sha256, sha384, sha512

    // 返回对应算法的OpaquePointer，用于后续的加密操作
    public var EVP: UnsafePointer<WOLFSSL_EVP_MD>? {
        switch self {
        case .md5:
            return wolfSSL_EVP_md5()
        case .sha1:
            return wolfSSL_EVP_sha1()
        case .sha224:
            return wolfSSL_EVP_sha224()
        case .sha256:
            return wolfSSL_EVP_sha256()
        case .sha384:
            return wolfSSL_EVP_sha384()
        case .sha512:
            return wolfSSL_EVP_sha512()
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
            return 16
        case .sha1:
            return 20
        case .sha224:
            return 28
        case .sha256:
            return 32
        case .sha384:
            return 48
        case .sha512:
            return 64
        }
    }
}
