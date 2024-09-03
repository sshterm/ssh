// Stream.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import CSSH
import Foundation

class ChannelInputStream: InputStream {
    let handle: OpaquePointer
    var size: Int
    var got: Int = 0
    var nread: Int = 0
    init(handle: OpaquePointer, size: Int64) {
        self.handle = handle
        self.size = Int(size)
        super.init()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        var amount = len
        if (size - got) < amount {
            amount = size - got
        }
        nread = libssh2_channel_read_ex(handle, 0, buffer, amount)
        got += nread
        return nread
    }

    override func open() {
        libssh2_channel_set_blocking(handle, 1)
    }

    override func close() {
        libssh2_channel_send_eof(handle)
        libssh2_channel_free(handle)
    }

    override var hasBytesAvailable: Bool {
        got < size && nread >= 0
    }
}

class ChannelOutputStream: OutputStream {
    let handle: OpaquePointer
    var nwrite: Int = 0
    init(handle: OpaquePointer) {
        self.handle = handle
        super.init()
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        nwrite = libssh2_channel_write_ex(handle, 0, buffer, len)
        return nwrite
    }

    override func open() {
        libssh2_channel_set_blocking(handle, 1)
    }

    override func close() {
        libssh2_channel_send_eof(handle)
        libssh2_channel_free(handle)
    }

    override var hasSpaceAvailable: Bool {
        nwrite >= 0
    }
}

class SFTPInputStream: InputStream {
    let handle: OpaquePointer
    var size: Int
    var got: Int = 0
    var nread: Int = 0
    init(handle: OpaquePointer, size: Int64) {
        self.handle = handle
        self.size = Int(size)
        super.init()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        nread = libssh2_sftp_read(handle, buffer, len)
        got += nread
        return nread
    }

    override func open() {}

    override func close() {
        libssh2_sftp_close_handle(handle)
    }

    override var hasBytesAvailable: Bool {
        got < size && nread >= 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
    }
}

class SFTPOutputStream: OutputStream {
    let handle: OpaquePointer
    var nwrite: Int = 0
    init(handle: OpaquePointer) {
        self.handle = handle
        super.init()
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        nwrite = libssh2_sftp_write(handle, buffer, len)
        return nwrite
    }

    override func open() {}

    override func close() {
        libssh2_sftp_close_handle(handle)
    }

    override var hasSpaceAvailable: Bool {
        nwrite >= 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
    }
}
