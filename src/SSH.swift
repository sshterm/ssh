// SSH.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/16.

import CSSH
import Foundation
import Socket

/// SSH 类，‌用于处理 SSH 连接和相关操作。‌
public class SSH {
    /// SSH 服务器的地址。‌
    public let host: String

    /// SSH 服务器的端口。‌
    public let port: Int32

    /// SSH 登录用户名。‌
    public let user: String

    /// 连接超时时间（‌秒）‌。‌
    public let timeout: Int

    /// 是否启用压缩。‌
    public let compress: Bool

    // 用于存储和管理 SSH 方法及其描述。
    public let methods: [SSHMethod: String]

    /// 是否为阻塞模式。‌
    public let blocking: Bool

    /// 用于控制 SSH 类的调试信息的输出
    public let debug: [DebugType]

    /// Socket 对象，‌用于网络通信。‌
    public var socket: Socket?

    /// 忽略的文件列表，目前包含当前目录(".")和上级目录("..")
    public var ignoredFiles = [".", ".."]

    /// 用于存储 libssh2 会话的原生指针。‌
    public var rawSession, rawChannel, rawSFTP: OpaquePointer?

    /// 缓冲区大小。‌
    public var bufferSize = 0x4000

    // 创建一个OperationQueue实例，用于管理并发操作
    let job = OperationQueue()

    /// 用于同步访问的锁。‌
    let lock = NSLock()

    /// 并发队列，‌用于处理 SSH 相关任务。‌
    let queue: DispatchQueue = .init(label: "SSH Queue", attributes: .concurrent)

    /// DispatchSourceRead 对象，‌用于读取 Socket 数据。‌
    var socketSource: DispatchSourceRead?

    /// DispatchSourceTimer 对象，‌用于处理超时。‌
    var timeoutSource: DispatchSourceTimer?

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
    ///   - user: 连接用户名，必填。
    ///   - timeout: 连接超时时间，默认为15秒。
    ///   - compress: 是否启用压缩，默认为true。
    ///   - methods: SSH方法及其对应的字符串参数，使用字典表示，默认为空字典。
    ///   - blocking: 是否阻塞模式，默认为true。
    ///   - debug: 调试类型，默认为无。
    public init(host: String, port: Int32, user: String, timeout: Int = 15, compress: Bool = true, methods: [SSHMethod: String] = [:], blocking: Bool = true, debug: [DebugType] = [.none]) {
        self.host = host
        self.port = port
        self.user = user
        self.timeout = timeout
        self.compress = compress
        self.methods = methods
        self.debug = debug
        self.blocking = blocking
        libssh2_init(0)
    }

    /// 关闭 SSH 会话和 Socket 连接。‌
    public func close() {
        job.cancelAllOperations()
        closeSession()
        closeSocket()
    }

    /// 析构函数，‌用于清理资源。‌
    deinit {
        libssh2_exit()
    }
}
