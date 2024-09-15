// HMAC.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/18.

#if OPEN_SSL
    import OpenSSL
#else
    import wolfSSL
#endif
import Foundation

// 提供HMAC加密功能
public extension Crypto {
    /// 使用指定的算法和密钥计算给定消息的HMAC（基于哈希的消息认证码）
    ///
    /// - Parameters:
    ///   - message: 需要计算HMAC的消息字符串
    ///   - key: 用于计算HMAC的密钥字符串
    ///   - algorithm: 指定的哈希算法
    /// - Returns: 计算得到的HMAC数据
    func hmac(_ message: String, key: String, algorithm: ShaAlgorithm) -> Data {
        hmac(message.pointerCChar, message_len: message.count, key: key.pointerCChar, key_len: key.countInt32, algorithm: algorithm)
    }

    /// 使用指定的算法和密钥对消息进行HMAC（基于哈希的消息认证码）加密。
    ///
    /// - Parameters:
    ///   - message: 需要进行HMAC加密的消息数据。
    ///   - key: 用于HMAC加密的密钥数据。
    ///   - algorithm: 加密算法，例如SHA256。
    /// - Returns: 返回加密后的HMAC数据。
    func hmac(_ message: Data, key: Data, algorithm: ShaAlgorithm) -> Data {
        hmac(message.pointerCChar, message_len: message.count, key: key.pointerCChar, key_len: key.countInt32, algorithm: algorithm)
    }

    /// 使用指定的算法和密钥计算给定消息的HMAC（Hash-based Message Authentication Code）。
    /// - Parameters:
    ///   - message: 指向要计算HMAC的消息的原始指针。
    ///   - message_len: 消息的长度（以字节为单位）。
    ///   - key: 指向用于计算HMAC的密钥的原始指针。
    ///   - key_len: 密钥的长度（以字节为单位）。
    ///   - algorithm: 要使用的哈希算法。
    /// - Returns: 包含计算出的HMAC值的Data对象。
    func hmac(_ message: UnsafeRawPointer, message_len: Int, key: UnsafeRawPointer, key_len: Int32, algorithm: ShaAlgorithm) -> Data {
        #if OPEN_SSL
            let evp = algorithm.EVP
            let digest = EVP_MD_get_size(evp)
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(digest))
            let len = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
            defer {
                buffer.deallocate()
                len.deallocate()
            }
            HMAC(evp, key, key_len, message, message_len, buffer, len)
            return Data(bytes: buffer, count: Int(len.pointee))
        #else
            let evp = algorithm.EVP
            let digest = wolfSSL_EVP_MD_size(evp)
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: Int(digest))
            let len = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
            defer {
                buffer.deallocate()
                len.deallocate()
            }
            wolfSSL_HMAC(evp, key, key_len, message, message_len, buffer, len)
            return Data(bytes: buffer, count: Int(len.pointee))
        #endif
    }
}
