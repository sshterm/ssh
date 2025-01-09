// Stream.swift
// Copyright (c) 2025 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import CSSH
import Darwin
import Foundation

class FileInputStream: InputStream {
    var size: Int64 = 0
    var handle, raw: OpaquePointer?
    var rawSession: OpaquePointer
    let remotePath: String
    let sftp: Bool
    var got: Int = 0
    var nread: Int = 0

    init(rawSession: OpaquePointer, remotePath: String, sftp: Bool = true) {
        self.rawSession = rawSession
        self.remotePath = remotePath
        self.sftp = sftp
        super.init()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard let handle else {
            return -1
        }
        if sftp {
            nread = libssh2_sftp_read(handle, buffer, len)
            got += nread
            return nread
        } else {
            var amount = len
            if (size - Int64(got)) < amount {
                amount = Int(size - Int64(got))
            }
            nread = libssh2_channel_read_ex(handle, 0, buffer, amount)
            got += nread
            return nread
        }
    }

    override func open() {
        libssh2_session_set_blocking(rawSession, 1)
        if sftp {
            guard let rawSFTP = libssh2_sftp_init(rawSession) else {
                return
            }
            var fileinfo = LIBSSH2_SFTP_ATTRIBUTES()

            guard libssh2_sftp_stat_ex(rawSFTP, remotePath, remotePath.countUInt32, LIBSSH2_SFTP_STAT, &fileinfo) == LIBSSH2_ERROR_NONE else {
                libssh2_sftp_shutdown(rawSFTP)
                return
            }
            guard let handle = libssh2_sftp_open_ex(rawSFTP, remotePath, remotePath.countUInt32, UInt(LIBSSH2_FXF_READ), 0, LIBSSH2_SFTP_OPENFILE) else {
                libssh2_sftp_shutdown(rawSFTP)
                return
            }
            size = Int64(fileinfo.filesize)
            self.handle = handle
            raw = rawSFTP
        } else {
            var fileinfo = libssh2_struct_stat()
            guard let handle = libssh2_scp_recv2(rawSession, remotePath, &fileinfo) else {
                return
            }
            size = fileinfo.st_size
            self.handle = handle
        }
    }

    override func close() {
        if sftp {
            if let handle {
                libssh2_sftp_close_handle(handle)
            }
            if let raw {
                libssh2_sftp_shutdown(raw)
            }
        } else {
            if let handle {
                libssh2_channel_send_eof(handle)
                libssh2_channel_free(handle)
            }
        }
    }

    override var hasBytesAvailable: Bool {
        if sftp {
            handle != nil && got < size && nread > 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
        } else {
            handle != nil && got < size && nread > 0
        }
    }
}

class FileOutputStream: OutputStream {
    let size: Int64
    let sftp: Bool
    let remotePath: String
    var handle, raw: OpaquePointer?
    var rawSession: OpaquePointer
    var nwrite: Int = 0
    let permissions: FilePermissions
    init(rawSession: OpaquePointer, remotePath: String, size: Int64, permissions: FilePermissions = .default, sftp: Bool = true) {
        self.rawSession = rawSession
        self.remotePath = remotePath
        self.size = size
        self.sftp = sftp
        self.permissions = permissions
        super.init()
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        guard let handle else {
            return -1
        }
        nwrite = sftp ? libssh2_sftp_write(handle, buffer, len) : libssh2_channel_write_ex(handle, 0, buffer, len)
        return nwrite
    }

    override func open() {
        libssh2_session_set_blocking(rawSession, 1)
        if sftp {
            guard let rawSFTP = libssh2_sftp_init(rawSession) else {
                return
            }
            guard let handle = libssh2_sftp_open_ex(rawSFTP, remotePath, remotePath.countUInt32, UInt(LIBSSH2_FXF_WRITE | LIBSSH2_FXF_CREAT | LIBSSH2_FXF_TRUNC), permissions.rawInt, LIBSSH2_SFTP_OPENFILE) else {
                return
            }
            self.handle = handle
            raw = rawSFTP
        } else {
            guard let handle = libssh2_scp_send64(rawSession, remotePath, permissions.rawValue, size, 0, 0) else {
                return
            }
            self.handle = handle
        }
    }

    override func close() {
        if sftp {
            if let handle {
                libssh2_sftp_close_handle(handle)
            }
            if let raw {
                libssh2_sftp_shutdown(raw)
            }
        } else {
            if let handle {
                libssh2_channel_send_eof(handle)
                libssh2_channel_free(handle)
            }
        }
    }

    override var hasSpaceAvailable: Bool {
        if sftp {
            handle != nil && nwrite > 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
        } else {
            handle != nil && nwrite > 0
        }
    }
}

class ChannelInputStream: InputStream {
    let handle: OpaquePointer
    let err: Bool
    var nread: Int = 0

    init(handle: OpaquePointer, err: Bool = false) {
        self.handle = handle
        self.err = err
        super.init()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        nread = libssh2_channel_read_ex(handle, err ? SSH_EXTENDED_DATA_STDERR : 0, buffer, len)
        return nread
    }

    override func open() {}

    override func close() {}

    override var hasBytesAvailable: Bool {
        nread > 0
    }
}

class ChannelOutputStream: OutputStream {
    let handle: OpaquePointer
    let err: Bool
    var nwrite: Int = 0
    init(handle: OpaquePointer, err: Bool = false) {
        self.handle = handle
        self.err = err
        super.init()
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        nwrite = libssh2_channel_write_ex(handle, err ? SSH_EXTENDED_DATA_STDERR : 0, buffer, len)
        return nwrite
    }

    override func open() {}

    override func close() {}

    override var hasSpaceAvailable: Bool {
        nwrite > 0
    }
}

class PipeOutputStream: OutputStream {
    let callback: (Data) -> Bool
    var ok: Bool = true
    init(callback: @escaping (Data) -> Bool) {
        self.callback = callback
        super.init()
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        ok = callback(Data(bytes: buffer, count: len))
        return len
    }

    override func open() {}

    override func close() {}

    override var hasSpaceAvailable: Bool {
        ok
    }
}

class SocketOutput: OutputStream {
    let fd: sockFD
    var nwrite: Int = 0
    init(_ fd: sockFD) {
        self.fd = fd
        super.init()
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        nwrite = io.write(fd, buffer, len)
        return nwrite
    }

    override func open() {}

    override func close() {}

    override var hasSpaceAvailable: Bool {
        nwrite > 0
    }
}

class SocketInput: InputStream {
    let fd: sockFD
    var nread: Int = 0
    init(_ fd: sockFD) {
        self.fd = fd
        super.init()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        nread = io.read(fd, buffer, len)
        return nread
    }

    override func open() {}

    override func close() {}

    override var hasBytesAvailable: Bool {
        nread > 0
    }
}

extension OutputStream {
    var data: Data? {
        guard let data = property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as? Data else {
            return nil
        }
        return data
    }
}
