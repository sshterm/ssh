// io.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import Darwin
import Foundation

public class io {
    /// 将输入流的数据复制到输出流中，返回复制的字节数。
    /// - Parameters:
    ///   - w: 目标输出流
    ///   - r: 源输入流
    ///   - bufferSize: 缓冲区大小，默认为16384字节
    /// - Returns: 复制的字节数
    public static func Copy(_ w: OutputStream, _ r: InputStream, _ bufferSize: Int = 0x4000) -> Int64 {
        io.Copy(w, r, bufferSize) { _ in
            true
        }
    }

    /// 将输入流的数据复制到输出流中，返回复制的字节数，并允许通过进度回调函数控制复制过程。
    /// - Parameters:
    ///   - w: 目标输出流
    ///   - r: 源输入流
    ///   - bufferSize: 缓冲区大小，默认为16384字节
    ///   - progress: 进度回调函数，接收已复制的字节数作为参数，返回布尔值决定是否继续复制
    /// - Returns: 复制的字节数
    public static func Copy(_ w: OutputStream, _ r: InputStream, _ bufferSize: Int = 0x4000, _ progress: @escaping (_ send: Int64) -> Bool) -> Int64 {
        w.open()
        r.open()
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer {
            w.close()
            r.close()
            buffer.deallocate()
        }
        var total: Int64 = 0
        var nread, rc: Int
        repeat {
            nread = r.read(buffer, maxLength: bufferSize)
            // 修复错误
            // QQ 往事不再 反馈
            guard nread >= 0 else {
                return Int64(nread)
            }
            repeat {
                rc = w.write(buffer, maxLength: nread)
                if rc < 0 {
                    return Int64(rc)
                }
                total += Int64(rc)
                nread -= rc
                if !progress(total) {
                    return total
                }
            } while nread > 0 && w.hasSpaceAvailable
        } while r.hasBytesAvailable
        return total
    }

    // 冗余方法
    /// 将输入流的内容复制到输出流中，使用默认的缓冲区大小。
    /// - Parameters:
    ///   - r: 输入流
    ///   - w: 输出流
    ///   - bufferSize: 缓冲区大小，默认为0x4000
    /// - Returns: 复制的字节数
    public static func Copy(_ r: InputStream, _ w: OutputStream, _ bufferSize: Int = 0x4000) -> Int64 {
        io.Copy(w, r, bufferSize)
    }

    // 冗余方法
    /// 将输入流的内容复制到输出流中，使用默认的缓冲区大小，并提供进度回调。
    /// - Parameters:
    ///   - r: 输入流
    ///   - w: 输出流
    ///   - bufferSize: 缓冲区大小，默认为0x4000
    ///   - progress: 进度回调函数，接收已发送的字节数，返回一个布尔值表示是否继续复制
    /// - Returns: 复制的字节数
    public static func Copy(_ r: InputStream, _ w: OutputStream, _ bufferSize: Int = 0x4000, _ progress: @escaping (_ send: Int64) -> Bool) -> Int64 {
        io.Copy(w, r, bufferSize, progress)
    }

    /// 从文件描述符 `fd` 读取数据到缓冲区 `buffer`。
    /// - Parameters:
    ///   - fd: 文件描述符，标识要读取的文件。
    ///   - buffer: 指向用于存储读取数据的缓冲区的指针。
    ///   - len: 要读取的字节数。
    ///   - 返回值: 实际读取的字节数，如果发生错误则返回 -1。
    public static func read(_ fd: sockFD, _ buffer: UnsafeMutablePointer<UInt8>, _ len: Int) -> Int {
        Darwin.read(fd, buffer, len)
    }

    /// 将缓冲区 `buffer` 中的数据写入文件描述符 `fd`。
    /// - Parameters:
    ///   - fd: 文件描述符，标识要写入的文件。
    ///   - buffer: 指向包含要写入数据的缓冲区的指针。
    ///   - len: 要写入的字节数。
    ///   - 返回值: 实际写入的字节数，如果发生错误则返回 -1。
    public static func write(_ fd: sockFD, _ buffer: UnsafePointer<UInt8>, _ len: Int) -> Int {
        Darwin.write(fd, buffer, len)
    }
}
