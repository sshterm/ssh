// Rsa.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/26.

#if OPEN_SSL
    import Foundation

    import OpenSSL

    public extension Crypto {
        func keygenRSA(_ bits: Int = 2048) -> OpaquePointer? {
            keygen(bits, id: .rsa)
        }
    }
#endif
