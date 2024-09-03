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
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        w.open()
        r.open()
        defer {
            w.close()
            r.close()
            buffer.deallocate()
        }
        var total: Int64 = 0
        var nread, rc: Int
        while r.hasBytesAvailable {
            nread = r.read(buffer, maxLength: bufferSize)
            guard nread > 0 else {
                break
            }
            repeat {
                rc = w.write(buffer, maxLength: nread)
                if rc < 0 {
                    return total
                }
                total += Int64(rc)
                nread -= rc
                if !progress(total) {
                    return total
                }
            } while nread > 0
        }
        return total
    }
}
