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

    /// 根据原始值初始化HostKey类型
    /// - Parameter rawValue: 主机密钥的原始整数值
    public init(rawValue: Int32) {
        // 使用switch语句根据不同的原始值设置对应的HostKey类型
        switch rawValue {
        case LIBSSH2_HOSTKEY_TYPE_UNKNOWN:
            // 如果原始值表示未知类型，则设置为unknown
            self = .unknown
        case LIBSSH2_HOSTKEY_TYPE_RSA:
            // 如果原始值表示RSA类型，则设置为rsa
            self = .rsa
        case LIBSSH2_HOSTKEY_TYPE_DSS:
            // 如果原始值表示DSS类型，则设置为dss
            self = .dss
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_256:
            // 如果原始值表示256位ECDSA类型，则设置为ecdsa_256
            self = .ecdsa_256
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_384:
            // 如果原始值表示384位ECDSA类型，则设置为ecdsa_384
            self = .ecdsa_384
        case LIBSSH2_HOSTKEY_TYPE_ECDSA_521:
            // 如果原始值表示521位ECDSA类型，则设置为ecdsa_521
            self = .ecdsa_521
        case LIBSSH2_HOSTKEY_TYPE_ED25519:
            // 如果原始值表示ED25519类型，则设置为ed25519
            self = .ed25519
        default:
            // 对于未知的原始值，默认设置为unknown
            self = .unknown
        }
    }
}

// Hostkey 结构体用于存储主机密钥的信息。
// data 属性存储了密钥的数据。
// type 属性表示密钥的类型。
public struct Hostkey {
    public let data: Data
    public let type: HostkeyType
}

/// SSH方法枚举，表示SSH协议中可以使用的不同方法。
/// 这些方法包括密钥交换、主机密钥验证、加密算法、消息认证码、压缩算法和语言等。
public enum SSHMethod: String, CaseIterable {
    /// 密钥交换方法
    case kex
    /// 主机密钥验证方法
    case hostkey
    /// 客户端到服务器的加密算法
    case crypt_cs
    /// 服务器到客户端的加密算法
    case crypt_sc
    /// 客户端到服务器的消息认证码
    case mac_cs
    /// 服务器到客户端的消息认证码
    case mac_sc
    /// 客户端到服务器的压缩算法
    case comp_cs
    /// 服务器到客户端的压缩算法
    case comp_sc
    /// 客户端到服务器的语言选项
    case lang_cs
    /// 服务器到客户端的语言选项
    case lang_sc
    /// 签名算法0
    case sign_algo0

    /// 根据当前枚举值返回对应的LIBSSH2方法常量。
    /// - Returns: 对应的LIBSSH2方法常量。
    var int32: Int32 {
        switch self {
        case .kex:
            /// 返回LIBSSH2密钥交换方法的常量。
            LIBSSH2_METHOD_KEX
        case .hostkey:
            /// 返回LIBSSH2主机密钥方法的常量。
            LIBSSH2_METHOD_HOSTKEY
        case .crypt_cs:
            /// 返回LIBSSH2客户端加密方法的常量。
            LIBSSH2_METHOD_CRYPT_CS
        case .crypt_sc:
            /// 返回LIBSSH2服务器加密方法的常量。
            LIBSSH2_METHOD_CRYPT_SC
        case .mac_cs:
            /// 返回LIBSSH2客户端MAC方法的常量。
            LIBSSH2_METHOD_MAC_CS
        case .mac_sc:
            /// 返回LIBSSH2服务器MAC方法的常量。
            LIBSSH2_METHOD_MAC_SC
        case .comp_cs:
            /// 返回LIBSSH2客户端压缩方法的常量。
            LIBSSH2_METHOD_COMP_CS
        case .comp_sc:
            /// 返回LIBSSH2服务器压缩方法的常量。
            LIBSSH2_METHOD_COMP_SC
        case .lang_cs:
            /// 返回LIBSSH2客户端语言方法的常量。
            LIBSSH2_METHOD_LANG_CS
        case .lang_sc:
            /// 返回LIBSSH2服务器语言方法的常量。
            LIBSSH2_METHOD_LANG_SC
        case .sign_algo0:
            /// 返回LIBSSH2签名算法方法的常量。
            LIBSSH2_METHOD_SIGN_ALGO
        }
    }
}

public enum FileType: String, CaseIterable {
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

// 扩展了[DebugType]数组类型，添加了一个计算属性trace
extension [DebugType] {
    // trace属性用于计算并返回数组中所有元素的trace值的按位或结果
    /// 计算并返回数组中所有元素的trace值的按位或结果
    var trace: Int32 {
        // 初始化traces变量，用于累加trace值
        var traces: Int32 = 0
        // 遍历数组中的每个元素
        for t in self {
            // 将当前元素的trace值与traces进行按位或操作，并赋值回traces
            traces |= t.trace
        }
        // 返回最终的traces值
        return traces
    }
}

/// 枚举 `CloseType` 定义了不同类型的关闭操作。
/// 这些类型包括全部关闭、SFTP关闭、通道关闭、cocket关闭和会话关闭。
public enum CloseType: String {
    /// 表示关闭所有相关资源。
    case all

    /// 表示仅关闭SFTP连接。
    case sftp

    /// 表示仅关闭通道。
    case channel

    /// 表示仅关闭cocket连接。
    case cocket

    /// 表示仅关闭会话。
    case session
}
