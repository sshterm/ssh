// io.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import Foundation

public class io {
    /// 将输入流的数据复制到输出流中，返回复制的字节数。
    /// - Parameters:
    ///   - w: 目标输出流
    ///   - r: 源输入流
    ///   - bufferSize: 缓冲区大小，默认为16384字节
    /// - Returns: 复制的字节数
    public static func Copy(_ w: OutputStream, _ r: InputStream, _ bufferSize: Int = 0x4000) -> Int {
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
    public static func Copy(_ w: OutputStream, _ r: InputStream, _ bufferSize: Int = 0x4000, _ progress: @escaping (_ send: Int) -> Bool) -> Int {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        var total = 0
        var nread, rc: Int
        while r.hasBytesAvailable {
            nread = r.read(buffer, maxLength: bufferSize)
            guard nread > 0 else {
                break
            }
            repeat {
                rc = w.write(buffer, maxLength: nread)
                if rc < 0 {
                    return rc
                }
                total += rc
                nread -= rc
                if !progress(total) {
                    return total
                }
            } while nread > 0
        }
        return total
    }

    // 冗余方法
    public static func Copy(_ r: InputStream, _ w: OutputStream, _ bufferSize: Int = 0x4000) -> Int {
        io.Copy(w, r, bufferSize)
    }

    // 冗余方法
    public static func Copy(_ r: InputStream, _ w: OutputStream, _ bufferSize: Int = 0x4000, _ progress: @escaping (_ send: Int) -> Bool) -> Int {
        io.Copy(w, r, bufferSize, progress)
    }
}
