// Types.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/15.

import Foundation

public enum PtyType: String, CaseIterable {
    case vanilla, vt100, vt102, vt220, ansi, xterm

    // 计算并返回枚举值对应的字符串的UTF-8字符长度，作为UInt32类型
    var lengthUInt32: UInt32 {
        rawValue.countUInt32
    }

    // 计算并返回枚举值对应的字符串的UTF-8字符长度，作为Int类型
    var length: Int {
        rawValue.count
    }
}

public enum FingerprintHashType: String {
    // 枚举值包括md5, sha1, sha256
    case md5, sha1, sha256

    // 返回对应哈希算法的摘要长度
    var digestInt32: Int32 {
        Int32(digest)
    }

    // 根据不同的哈希类型返回对应的摘要长度，使用Int32类型
    var digest: Int {
        switch self {
        case .md5:
            Algorithm.md5.digest
        case .sha1:
            Algorithm.sha1.digest
        case .sha256:
            Algorithm.sha256.digest
        }
    }

    // 根据不同的哈希类型返回对应的LIBSSH2常量值
    var hashType: Int32 {
        switch self {
        case .md5:
            LIBSSH2_HOSTKEY_HASH_MD5
        case .sha1:
            LIBSSH2_HOSTKEY_HASH_SHA1
        case .sha256:
            LIBSSH2_HOSTKEY_HASH_SHA256
        }
    }
}

public enum DebugType: String, CaseIterable {
    // 定义调试类型枚举，包括传输、密钥交换、认证、连接、SCP、SFTP、错误、公钥、套接字、全部和无
    case trans, kex, auth, conn, scp, sftp, error, publickey, socket, all, none

    // 根据不同的调试类型返回对应的跟踪级别
    var trace: Int32 {
        switch self {
        case .trans:
            LIBSSH2_TRACE_TRANS // 传输跟踪级别
        case .kex:
            LIBSSH2_TRACE_KEX // 密钥交换跟踪级别
        case .auth:
            LIBSSH2_TRACE_AUTH // 认证跟踪级别
        case .conn:
            LIBSSH2_TRACE_CONN // 连接跟踪级别
        case .scp:
            LIBSSH2_TRACE_SCP // SCP跟踪级别
        case .sftp:
            LIBSSH2_TRACE_SFTP // SFTP跟踪级别
        case .error:
            LIBSSH2_TRACE_ERROR // 错误跟踪级别
        case .publickey:
            LIBSSH2_TRACE_PUBLICKEY // 公钥跟踪级别
        case .socket:
            LIBSSH2_TRACE_SOCKET // 套接字跟踪级别
        case .all:
            ~0 // 所有跟踪级别
        case .none:
            0 // 无跟踪级别
        }
    }
}

extension [DebugType] {
    var trace: Int32 {
        var traces: Int32 = 0
        for t in self {
            traces |= t.trace
        }
        return traces
    }
}
