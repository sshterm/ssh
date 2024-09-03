// Stream.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import CSSH
import Foundation

class SessionInputStream: InputStream {
    var size: Int = 0
    var handle, raw: OpaquePointer?
    var rawSession: OpaquePointer
    let remotePath: String
    let sftp: Bool
    var got: Int = 0 // 已读取的字节数
    var nread: Int = 0 // 最近一次读取的字节数

    init(rawSession: OpaquePointer, remotePath: String, sftp: Bool = true) {
        self.rawSession = rawSession
        self.remotePath = remotePath
        self.sftp = sftp
        super.init()
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        if sftp {
            nread = libssh2_sftp_read(handle, buffer, len)
            got += nread
            return nread
        } else {
            var amount = len
            if (size - got) < amount {
                amount = size - got
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
            size = Int(fileinfo.filesize)
            self.handle = handle
            raw = rawSFTP
        } else {
            var fileinfo = libssh2_struct_stat()
            guard let handle = libssh2_scp_recv2(rawSession, remotePath, &fileinfo) else {
                return
            }
            size = Int(fileinfo.st_size)
            self.handle = handle
        }
    }

    override func close() {
        if sftp {
            libssh2_sftp_close_handle(handle)
            libssh2_sftp_shutdown(raw)
        } else {
            libssh2_channel_send_eof(handle)
            libssh2_channel_free(handle)
        }
    }

    override var hasBytesAvailable: Bool {
        if sftp {
            handle != nil && got < size && nread >= 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
        } else {
            handle != nil && got < size && nread >= 0
        }
    }
}

class SessionOutputStream: OutputStream {
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

    // 重写write方法，将数据写入SSH通道
    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
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
            libssh2_sftp_close_handle(handle)
            libssh2_sftp_shutdown(raw)
        } else {
            libssh2_channel_send_eof(handle)
            libssh2_channel_free(handle)
        }
    }

    override var hasSpaceAvailable: Bool {
        if sftp {
            handle != nil && nwrite >= 0 && libssh2_sftp_last_error(handle) == LIBSSH2_FX_OK
        } else {
            handle != nil && nwrite >= 0
        }
    }
}
