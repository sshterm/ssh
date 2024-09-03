// SCP.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/21.

import CSSH
import Darwin
import Foundation

public extension SSH {
    // 下载文件的函数，支持进度回调
    // - Parameters:
    //   - remotePath: 远程文件路径
    //   - localPath: 本地文件路径
    //   - progress: 进度回调闭包，接收两个Int64参数，分别代表已发送的字节数和文件总大小，返回一个Bool值表示是否继续下载
    // - Returns: 下载成功与否的布尔值
    func download(remotePath: String, localPath: String, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        guard let stream = OutputStream(toFileAtPath: localPath, append: false) else {
            return false
        }
        return await download(remotePath: remotePath, local: stream, progress: progress)
    }

    // 下载文件的函数，从远程路径下载到本地输出流，并提供下载进度回调。
    // - Parameters:
    //   - remotePath: 远程文件的路径。
    //   - local: 本地输出流，用于写入下载的文件数据。
    //   - progress: 一个闭包，用于报告下载进度，参数为已发送的字节数和总字节数，返回值表示是否继续下载。
    // - Returns: 一个布尔值，表示下载是否成功。
    func download(remotePath: String, local: OutputStream, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            local.open()
            defer {
                local.close()
            }
            guard let rawSession = self.rawSession else {
                return false
            }
            var fileinfo = libssh2_struct_stat()
            let handle = self.callSSH2 {
                libssh2_scp_recv2(rawSession, remotePath, &fileinfo)
            }
            guard let handle else {
                return false
            }
            defer {
                _ = self.callSSH2 {
                    libssh2_channel_send_eof(handle)
                }
                libssh2_channel_free(handle)
            }

            var bufferSize = self.bufferSize
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
            defer {
                buffer.deallocate()
            }
            let filesize = Int64(fileinfo.st_size)
            var rc, n: Int
            var total: Int64 = 0
            while total < filesize {
                if (filesize - total) < bufferSize {
                    bufferSize = size_t(filesize - total)
                }
                rc = self.callSSH2 {
                    libssh2_channel_read_ex(handle, 0, buffer, bufferSize)
                }
                guard rc > 0 else {
                    break
                }
                repeat {
                    guard rc > 0 else {
                        break
                    }
                    n = local.write(buffer, maxLength: rc)
                    if n < 0 {
                        return false
                    }
                    total += Int64(n)
                    rc -= n
                    if !progress(total, filesize) {
                        return false
                    }
                } while rc > 0
            }

            return true
        }
    }

    // 下载文件的异步函数，不带进度回调
    /// - Parameters:
    ///   - remotePath: 远程文件路径
    ///   - localPath: 本地文件路径
    /// - Returns: 下载是否成功的布尔值
    func download(remotePath: String, localPath: String) async -> Bool {
        await download(remotePath: remotePath, localPath: localPath) { _, _ in
            true
        }
    }

    // 上传文件的函数，支持异步操作和进度回调
    /// 使用默认权限上传本地文件到远程路径
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    ///   - Returns: 上传成功与否的布尔值
    func upload(localPath: String, remotePath: String, permissions: FilePermissions = .default) async -> Bool {
        await upload(localPath: localPath, remotePath: remotePath, permissions: permissions) { _, _ in
            true
        }
    }

    // 上传文件的函数，支持异步操作，并提供上传进度回调
    // - Parameters:
    //   - localPath: 本地文件路径
    //   - remotePath: 远程文件路径
    //   - permissions: 文件权限，默认为默认权限
    //   - progress: 上传进度回调，参数为已发送的字节数和文件总大小
    // - Returns: 上传成功与否的布尔值
    func upload(localPath: String, remotePath: String, permissions: FilePermissions = .default, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        guard let stream = InputStream(fileAtPath: localPath) else {
            return false
        }
        guard let fileSize = getFileSize(filePath: localPath) else {
            return false
        }
        return await upload(local: stream, fileSize: fileSize, remotePath: remotePath, permissions: permissions, progress: progress)
    }

    // 上传文件的函数，异步执行
    // - Parameters:
    //   - local: 本地文件输入流
    //   - fileSize: 文件大小，以字节为单位
    //   - remotePath: 远程存储路径
    //   - permissions: 文件权限，默认为默认权限
    //   - progress: 一个闭包，用于报告上传进度，参数为已发送的字节数和总字节数，返回值为布尔类型，表示是否继续上传
    // - Returns: 上传成功与否的布尔值
    func upload(local: InputStream, fileSize: Int64, remotePath: String, permissions: FilePermissions = .default, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            local.open()
            defer {
                local.close()
            }
            let handle = self.callSSH2 {
                libssh2_scp_send64(rawSession, remotePath, permissions.rawValue, fileSize, 0, 0)
            }
            guard let handle else {
                return false
            }
            defer {
                _ = self.callSSH2 {
                    libssh2_channel_send_eof(handle)
                }
                libssh2_channel_free(handle)
            }
            libssh2_channel_set_blocking(handle, 1)
            var nread, rc: Int
            var total: Int64 = 0
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: self.bufferSize)
            defer {
                buffer.deallocate()
            }
            while local.hasBytesAvailable {
                nread = local.read(buffer, maxLength: self.bufferSize)
                guard nread > 0 else {
                    break
                }
                repeat {
                    rc = self.callSSH2 {
                        libssh2_channel_write_ex(handle, 0, buffer, nread)
                    }
                    if rc < 0 {
                        return false
                    }
                    total += Int64(rc)
                    nread -= rc
                    if !progress(total, fileSize) {
                        return false
                    }
                } while nread > 0
            }

            return true
        }
    }
}
