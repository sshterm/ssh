// SCP.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/21.

import CSSH
import Darwin
import Foundation

public extension SSH {
    // 下载指定路径的文件，可以选择是否使用SFTP协议，并且可以提供一个进度回调函数。
    // - Parameters:
    //   - remotePath: 远程文件的路径。
    //   - sftp: 一个布尔值，指示是否使用SFTP协议，默认为false。
    //   - progress: 一个闭包，用于报告下载进度，接收两个Int64参数，分别代表已发送的字节数和文件总大小，返回一个布尔值决定是否继续下载。
    // - Returns: 如果下载成功，返回Data对象；否则返回nil。
    func download(remotePath: String, sftp: Bool = false, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Data? {
        let stream = OutputStream.toMemory()
        guard await download(remotePath: remotePath, local: stream, sftp: sftp, progress: progress) else {
            return nil
        }
        return stream.data
    }

    // 下载文件的函数，支持进度回调
    // - Parameters:
    //   - remotePath: 远程文件路径
    //   - localPath: 本地文件路径
    //   - sftp: 是否使用sftp,默认 false
    //   - progress: 进度回调闭包，接收两个Int64参数，分别代表已发送的字节数和文件总大小，返回一个Bool值表示是否继续下载
    // - Returns: 下载成功与否的布尔值
    func download(remotePath: String, localPath: String, sftp: Bool = false, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        guard let stream = OutputStream(toFileAtPath: localPath, append: false) else {
            return false
        }
        return await download(remotePath: remotePath, local: stream, sftp: sftp, progress: progress)
    }

    // 下载文件的函数，从远程路径下载到本地输出流，并提供下载进度回调。
    // - Parameters:
    //   - remotePath: 远程文件的路径。
    //   - local: 本地输出流，用于写入下载的文件数据。
    //   - sftp: 是否使用sftp,默认 false
    //   - progress: 一个闭包，用于报告下载进度，参数为已发送的字节数和总字节数，返回值表示是否继续下载。
    // - Returns: 一个布尔值，表示下载是否成功。
    func download(remotePath: String, local: OutputStream, sftp: Bool = false, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            let remote = FileInputStream(rawSession: rawSession, remotePath: remotePath, sftp: sftp)
            guard io.Copy(remote, local, self.bufferSize, { send in
                progress(send, remote.size)
            }) == remote.size else {
                return false
            }
            return true
        }
    }

    // 下载文件的异步函数，不带进度回调
    /// - Parameters:
    ///   - remotePath: 远程文件路径
    ///   - localPath: 本地文件路径
    ///   - sftp: 是否使用sftp,默认 false
    /// - Returns: 下载是否成功的布尔值
    func download(remotePath: String, localPath: String, sftp: Bool = false) async -> Bool {
        await download(remotePath: remotePath, localPath: localPath, sftp: sftp) { _, _ in
            true
        }
    }

    // 上传文件的函数，支持异步操作和进度回调
    /// 使用默认权限上传本地文件到远程路径
    /// - Parameters:
    ///   - localPath: 本地文件路径
    ///   - remotePath: 远程文件路径
    ///   - sftp: 是否使用sftp,默认 false
    ///   - Returns: 上传成功与否的布尔值
    func upload(localPath: String, remotePath: String, permissions: FilePermissions = .default, sftp: Bool = false) async -> Bool {
        await upload(localPath: localPath, remotePath: remotePath, permissions: permissions, sftp: sftp) { _, _ in
            true
        }
    }

    // 上传文件的函数，支持异步操作，并提供上传进度回调
    // - Parameters:
    //   - localPath: 本地文件路径
    //   - remotePath: 远程文件路径
    //   - permissions: 文件权限，默认为默认权限
    //   - sftp: 是否使用sftp,默认 false
    //   - progress: 上传进度回调，参数为已发送的字节数和文件总大小
    // - Returns: 上传成功与否的布尔值
    func upload(localPath: String, remotePath: String, permissions: FilePermissions = .default, sftp: Bool = false, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        guard let stream = InputStream(fileAtPath: localPath) else {
            return false
        }
        guard let fileSize = getFileSize(filePath: localPath) else {
            return false
        }
        return await upload(local: stream, fileSize: fileSize, remotePath: remotePath, permissions: permissions, sftp: sftp, progress: progress)
    }

    // 上传数据到远程路径
    // - Parameters:
    //   - data: 要上传的数据
    //   - remotePath: 远程文件路径
    //   - permissions: 文件权限，默认为默认权限
    //   - sftp: 是否使用SFTP协议，默认为false
    //   - progress: 上传进度回调，返回已发送字节数和总字节数，返回值决定是否继续上传
    // - Returns: 上传是否成功
    func upload(data: Data, remotePath: String, permissions: FilePermissions = .default, sftp: Bool = false, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        return await upload(local: InputStream(data: data), fileSize: data.countInt64, remotePath: remotePath, permissions: permissions, sftp: sftp, progress: progress)
    }

    // 上传文件的函数，异步执行
    // - Parameters:
    //   - local: 本地文件输入流
    //   - fileSize: 文件大小，以字节为单位
    //   - remotePath: 远程存储路径
    //   - permissions: 文件权限，默认为默认权限
    //   - sftp: 是否使用sftp,默认 false
    //   - progress: 一个闭包，用于报告上传进度，参数为已发送的字节数和总字节数，返回值为布尔类型，表示是否继续上传
    // - Returns: 上传成功与否的布尔值
    func upload(local: InputStream, fileSize: Int64, remotePath: String, permissions: FilePermissions = .default, sftp: Bool = false, progress: @escaping (_ send: Int64, _ size: Int64) -> Bool) async -> Bool {
        await call {
            guard let rawSession = self.rawSession else {
                return false
            }
            let remote = FileOutputStream(rawSession: rawSession, remotePath: remotePath, size: fileSize, permissions: permissions, sftp: sftp)
            guard io.Copy(local, remote, self.bufferSize, { send in
                progress(send, fileSize)
            }) == fileSize else {
                return false
            }
            return true
        }
    }
}
