// SSH.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import Foundation

/// SSH 类，‌用于处理 SSH 连接和相关操作。‌
public class SSH {
    /// 获取当前LIBSSH2库的版本号。
    /// LIBSSH2_VERSION_MAJOR, LIBSSH2_VERSION_MINOR 和 LIBSSH2_VERSION_PATCH 是预定义的常量，
    /// 分别代表LIBSSH2库的主版本号、次版本号和补丁版本号。
    /// 通过字符串插值将这三个版本号拼接成一个完整的版本号字符串。
    public static let version = "\(LIBSSH2_VERSION_MAJOR).\(LIBSSH2_VERSION_MINOR).\(LIBSSH2_VERSION_PATCH)"

    /// SSH 服务器的地址。‌
    public let host: String

    /// SSH 服务器的端口。‌
    public let port: Int32

    /// SSH 登录用户名。‌
    public var user: String

    /// 连接超时时间（‌秒）‌。‌
    public let timeout: Int

    /// 是否启用压缩。‌
    public let compress: Bool

    /// SSH 协议横幅
    public let banner: String

    // 用于存储和管理 SSH 方法及其描述。
    public let methods: [SSHMethod: String]

    /// 是否为阻塞模式
    public let blocking: Bool

    /// 是否为保持心跳
    public let keepalive: Bool

    /// 用于控制 SSH 类的调试信息的输出
    public let debug: [DebugType]

    // sockfd 是一个表示套接字文件描述符的变量，初始值为 -1。
    public var sockfd: sockFD = LIBSSH2_INVALID_SOCKET

    /// 忽略的文件列表，目前包含当前目录(".")和上级目录("..")
    public var ignoredFiles = [".", ".."]

    /// 用于存储 libssh2 会话的原生指针。‌
    public var rawSession, rawChannel, rawSFTP: OpaquePointer?

    /// 缓冲区大小。‌
    public var bufferSize = 0x4000

    // keepaliveInterval 属性用于设置SSH连接的保持活动间隔时间（秒），
    // 默认值为5秒。保持活动信号用于在无数据交换时维持连接活跃，
    // 防止因长时间无活动而被网络设备断开连接。
    public var keepaliveInterval = 5

    // 创建一个OperationQueue实例，用于管理并发操作
    let job = OperationQueue()

    /// 用于同步访问的锁。‌
    let lock = NSLock()
    let lockRow = NSLock()

    /// 并发队列，‌用于处理 SSH 相关任务。‌
    let queue: DispatchQueue = .init(label: "SSH Queue", attributes: .concurrent)

    /// DispatchSourceRead 对象，‌用于读取 Socket 数据。‌
    var socketSource: DispatchSourceRead?

    /// DispatchSourceTimer 对象，‌用于处理超时。‌
    var keepAliveSource: DispatchSourceTimer?

    /// 会话代理，‌用于处理会话相关事件。‌
    public var sessionDelegate: SessionDelegate?

    /// 通道代理，‌用于处理通道相关事件。‌
    public var channelDelegate: ChannelDelegate?

    /// 初始化SSH连接参数并启动libssh2库
    /// 该初始化方法用于设置SSH连接的各项参数，并启动libssh2库以准备进行SSH连接。
    /// 参数包括远程主机地址、端口、用户名、连接超时时间、是否启用压缩、阻塞模式以及调试类型。
    /// - Parameters:
    ///   - host: 远程主机地址，必填。
    ///   - port: 远程主机端口，默认为22。
    ///   - user: 连接用户名，默认为root。
    ///   - timeout: 连接超时时间，默认为15秒。
    ///   - compress: 是否启用压缩，默认为true。
    ///   - methods: SSH方法及其对应的字符串参数，使用字典表示，默认为空字典。
    ///   - blocking: 是否阻塞模式，默认为true。
    ///   - debug: 调试类型，默认为无。
    ///   - keepalive: 是否保持心跳，默认为false。
    public init(host: String, port: Int32 = 22, user: String = "root", timeout: Int = 15, compress: Bool = true, blocking: Bool = true, banner: String = "", methods: [SSHMethod: String] = [:], debug: [DebugType] = [.none], keepalive: Bool = false) {
        self.host = host
        self.port = port
        self.user = user
        self.timeout = timeout
        self.compress = compress
        self.banner = banner
        self.methods = methods
        self.debug = debug
        self.blocking = blocking
        self.keepalive = keepalive
    }

    /// 关闭 SSH 会话和 Socket 连接。
    /// - Parameter type: 关闭类型，可选值为全部、SFTP、通道、Socket 或会话。
    public func close(_ type: CloseType = .session) {
        #if DEBUG
            print("关闭", type.rawValue)
        #endif
        switch type {
        case .sftp:
            if let rawSFTP {
                libssh2_sftp_shutdown(rawSFTP)
                self.rawSFTP = nil
            }
        case .channel:
            if let rawChannel {
                libssh2_channel_set_blocking(rawChannel, 0)
                lock.lock()
                defer {
                    lock.unlock()
                }
                libssh2_channel_free(rawChannel)
                addOperation {
                    self.channelDelegate?.disconnect(ssh: self)
                }
                self.rawChannel = nil
            }
        case .socket:
            if sockfd != LIBSSH2_INVALID_SOCKET {
                shutdown()
            }
            sockfd = LIBSSH2_INVALID_SOCKET
        case .session:
            if let rawSession {
                shutdown(.r)
                job.cancelAllOperations()
                lockRow.lock()
                defer {
                    lockRow.unlock()
                }
                cancelKeepalive()
                cancelSources()
                close(.channel)
                close(.sftp)
                _ = callSSH2 {
                    libssh2_session_disconnect_ex(rawSession, SSH_DISCONNECT_BY_APPLICATION, "SSH Term: Disconnect", "")
                }
                libssh2_session_free(rawSession)
                libssh2_exit()
                shutdown(.w)
                close(.socket)
                self.rawSession = nil
            }
        }
    }

    deinit {}
}
