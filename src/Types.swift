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

public enum HostkeyType: String, CaseIterable {
    // 定义了主机密钥的类型，包括未知、RSA、DSS、ECDSA_256、ECDSA_384、ECDSA_521和ed25519
    case unknown, rsa, dss, ecdsa_256, ecdsa_384, ecdsa_521, ed25519

    /**
     根据整型原始值初始化HostkeyType枚举实例
     - Parameter rawValue: 整型原始值，对应不同的主机密钥类型
     - Returns: 返回对应的HostkeyType枚举实例，如果原始值不匹配则返回nil
     */
    public init(rawValue: Int32) {
        switch rawValue {
        case LIBSSH2_HOSTKEY_TYPE_UNKNOWN:
            self = .unknown
        case LIBSSH2_HOSTKEY_TYPE_RSA:
            self = .rsa
        case LIBSSH2_HOSTKEY_TYPE_DSS:
            self = .dss
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_256:
            self = .ecdsa_256
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_384:
            self = .ecdsa_384
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_521:
            self = .ecdsa_521
        case LIBSSH2_HOSTKEY_TYPE_ED25519:
            self = .ed25519
        default:
            self = .unknown
        }
    }
}

public enum FileType {
    case link // 链接
    case regularFile // 普通文件
    case directory // 目录
    case characterSpecialFile // 字符特殊文件
    case blockSpecialFile // 块特殊文件
    case fifo // 先进先出队列
    case socket // 套接字
    case unknown // 无法识别的文件类型

    /**
     根据整数值初始化文件类型枚举
     - Parameter rawValue: 文件类型的整数值表示
     - Returns: 对应的FileType枚举值，如果无法识别则返回nil
     */
    public init(rawValue: Int32) {
        switch rawValue & LIBSSH2_SFTP_S_IFMT {
        case LIBSSH2_SFTP_S_IFLNK:
            self = .link
        case LIBSSH2_SFTP_S_IFREG:
            self = .regularFile
        case LIBSSH2_SFTP_S_IFDIR:
            self = .directory
        case LIBSSH2_SFTP_S_IFCHR:
            self = .characterSpecialFile
        case LIBSSH2_SFTP_S_IFBLK:
            self = .blockSpecialFile
        case LIBSSH2_SFTP_S_IFIFO:
            self = .fifo
        case LIBSSH2_SFTP_S_IFSOCK:
            self = .socket
        default:
            self = .unknown
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
