// ED25519.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/27.

#if OPEN_SSL
    import Foundation

    import OpenSSL

    public extension Crypto {
        func generateED25519() -> OpaquePointer? {
            keygen(id: .ed25519)
        }
    }
#endif
