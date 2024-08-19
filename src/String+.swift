// String+.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/19.

import Darwin
import Foundation

public extension String {
    /// 返回一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    /// - Returns: 一个指向Data对象字节表示的UnsafeMutablePointer<CChar>
    var pointerCChar: UnsafeMutablePointer<CChar> {
        return withCString { str in
            Darwin.strdup(str)
        }
    }

    var countUInt32: UInt32 {
        UInt32(count)
    }

    var countInt32: Int32 {
        Int32(count)
    }
}
