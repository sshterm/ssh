// Protocol.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/21.

import Foundation

public protocol SessionDelegate {
    /// 当SSH会话断开时调用
    /// - Parameter ssh: 当前的SSH会话实例
    func disconnect(ssh: SSH)

    /// 当SSH会话握手时调用
    /// - Parameters:
    ///   - ssh: 当前的SSH会话实例
    ///   - fingerprint: SSH服务器的指纹
    /// - Returns: 是否接受此次握手，返回布尔值
    func connect(ssh: SSH, fingerprint: String) -> Bool

    /// 当需要键盘交互时调用，返回用户输入的字符串
    /// - Parameters:
    ///   - ssh: 当前的SSH会话实例
    ///   - prompt: 提示信息
    /// - Returns: 用户输入的字符串
    func keyboardInteractive(ssh: SSH, prompt: String) -> String

    /// 发送数据时调用，参数为发送数据的大小
    /// - Parameters:
    ///   - ssh: 当前的SSH会话实例
    ///   - size: 发送数据的大小
    func send(ssh: SSH, size: Int) async

    /// 接收数据时调用，参数为接收数据的大小
    /// - Parameters:
    ///   - ssh: 当前的SSH会话实例
    ///   - size: 接收数据的大小
    func recv(ssh: SSH, size: Int) async

    /// 输出调试信息
    /// - Parameters:
    ///   - ssh: 当前的SSH会话实例
    ///   - message: 调试信息内容
    func debug(ssh: SSH, message: String) async

    /// 追踪SSH会话中的消息
    /// - Parameters:
    ///   - ssh: 当前的SSH会话实例
    ///   - message: 追踪的消息内容
    func trace(ssh: SSH, message: String) async
}

public protocol ChannelDelegate {
    /// 标准输出数据到达时调用
    /// - Parameters:
    ///   - ssh: SSH实例
    ///   - data: 到达的标准输出数据
    func stdout(ssh: SSH, data: Data) async

    /// 标准错误输出数据到达时调用
    /// - Parameters:
    ///   - ssh: SSH实例
    ///   - data: 到达的标准错误输出数据
    func dtderr(ssh: SSH, data: Data) async

    /// 通道断开时调用
    /// - Parameter ssh: SSH实例
    func disconnect(ssh: SSH)

    /// 通道连接时调用
    /// - Parameters:
    ///   - ssh: SSH实例
    ///   - online: 通道是否在线
    func connect(ssh: SSH, online: Bool)
}

// 定义C语言风格的函数类型别名
typealias sendType = @convention(c) (libssh2_socket_t, UnsafeRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
typealias recvType = @convention(c) (libssh2_socket_t, UnsafeMutableRawPointer, size_t, CInt, UnsafeRawPointer) -> ssize_t
typealias disconnectType = @convention(c) (UnsafeRawPointer, CInt, UnsafePointer<CChar>, CInt, UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void
#if DEBUG
    typealias debugType = @convention(c) (UnsafeRawPointer, CInt, UnsafePointer<CChar>, CInt, UnsafePointer<CChar>, CInt, UnsafeRawPointer) -> Void
#endif
typealias cbGenericType = @convention(c) () -> Void
