// Stream.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import CSSH
import Foundation

class ChannelInputStream: InputStream {
    let handle: OpaquePointer // SSH通道的句柄
    var size: Int // 数据流的总大小
    var got: Int = 0 // 已读取的字节数
    var nread: Int = 0 // 最近一次读取的字节数

    // 初始化方法，接收SSH通道句柄和数据流大小
    init(handle: OpaquePointer, size: Int64) {
        self.handle = handle
        self.size = Int(size)
        super.init()
    }

    // 重写read方法，从SSH通道读取数据到缓冲区
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        var amount = len
        if (size - got) < amount {
            amount = size - got
        }
        nread = libssh2_channel_read_ex(handle, 0, buffer, amount)
        got += nread
        return nread
    }

    // 打开通道，设置为阻塞模式
    override func open() {
        libssh2_channel_set_blocking(handle, 1)
    }

    // 关闭通道，发送EOF并释放资源
    override func close() {
        libssh2_channel_send_eof(handle)
        libssh2_channel_free(handle)
    }

    // 判断是否还有可读的字节
    override var hasBytesAvailable: Bool {
        got < size && nread >= 0
    }
}

class ChannelOutputStream: OutputStream {
    let handle: OpaquePointer // SSH通道的句柄
    var nwrite: Int = 0 // 最近一次写入的字节数

    // 初始化方法，接收SSH通道句柄
    init(handle: OpaquePointer) {
        self.handle = handle
        super.init()
    }

    // 重写write方法，将数据写入SSH通道
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        nwrite = libssh2_channel_write_ex(handle, 0, buffer, len)
        return nwrite
    }

    // 打开通道，设置为阻塞模式
    override func open() {
        libssh2_channel_set_blocking(handle, 1)
    }

    // 关闭通道，发送EOF并释放资源
    override func close() {
        libssh2_channel_send_eof(handle)
        libssh2_channel_free(handle)
    }

    // 判断是否还有可写的空间
    override var hasSpaceAvailable: Bool {
        nwrite >= 0
    }
}

class SFTPInputStream: InputStream {
    let handle: OpaquePointer // SFTP会话的句柄
    var size: Int // 数据流的总大小
    var got: Int = 0 // 已读取的字节数
    var nread: Int = 0 // 最近一次读取的字节数

    // 初始化方法，接收SFTP会话句柄和数据流大小
    init(handle: OpaquePointer, size: Int64) {
        self.handle = handle
        self.size = Int(size)
        super.init()
    }

    // 重写read方法，从SFTP会话读取数据到缓冲区
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        nread = libssh2_sftp_read(handle, buffer, len)
        got += nread
        return nread
    }

    // 打开SFTP会话
    override func open() {}

    // 关闭SFTP会话
    override func close() {
        libssh2_sftp_close_handle(handle)
    }

    // 判断是否还有可读的字节
    override var hasBytesAvailable: Bool {
        got < size && nread >= 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
    }
}

class SFTPOutputStream: OutputStream {
    let handle: OpaquePointer // SFTP会话的句柄
    var nwrite: Int = 0 // 最近一次写入的字节数

    // 初始化方法，接收SFTP会话句柄
    init(handle: OpaquePointer) {
        self.handle = handle
        super.init()
    }

    // 重写write方法，将数据写入SFTP会话
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        nwrite = libssh2_sftp_write(handle, buffer, len)
        return nwrite
    }

    // 打开SFTP会话
    override func open() {}

    // 关闭SFTP会话
    override func close() {
        libssh2_sftp_close_handle(handle)
    }

    // 判断是否还有可写的空间
    override var hasSpaceAvailable: Bool {
        nwrite >= 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
    }
}
