// Crypto.swift
// Copyright (c) 2024 ssh2.app
// Created by admin@ssh2.app 2024/8/18.

import Foundation
#if OPEN_SSL
    import OpenSSL
#else
    import wolfSSL
#endif
public class Crypto {
    public static let shared: Crypto = .init()

    #if OPEN_SSL
        public let name = "OpenSSL"
    #else
        public let name = "wolfSSL"
    #endif

    #if OPEN_SSL
        public let version = OPENSSL_VERSION_STR
    #else
        public let version = LIBWOLFSSL_VERSION_STRING
    #endif
}
