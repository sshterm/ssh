// io.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/9/3.

import Foundation

public class io {
    public static func Copy(_ w: OutputStream, _ r: InputStream, _ bufferSize: Int = 0x4000) -> Int64 {
        io.Copy(w, r, bufferSize) { _ in
            true
        }
    }

    public static func Copy(_ w: OutputStream, _ r: InputStream, _ bufferSize: Int = 0x4000, _ progress: @escaping (_ send: Int64) -> Bool) -> Int64 {
        w.open()
        r.open()
        defer {
            w.close()
            r.close()
        }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer {
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
                    return -1
                }
                total += Int64(rc)
                nread -= rc
                if !progress(total) {
                    return -1
                }
            } while nread > 0
        }
        return total
    }
}
