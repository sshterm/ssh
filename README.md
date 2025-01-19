SSH Term APP 7.0以后版本将采用重构核心

[https://github.com/sshterm/ssh2](https://github.com/sshterm/ssh2)


# ssh
libssh2 + OpenSSL + wolfSSL 的swift实现

SSH Term APP [ssh2.app](https://ssh2.app/) 的 SSH2连接核心

全中文注释

# 使用 OpenSSL 版
协议全，推荐

### 不包括libssl，占用空间小
```
pod 'CSSH/OpenSSL', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/OpenSSL', :git => 'https://github.com/sshterm/ssh.git'
```

### 使用完整的OpenSSL包括libssl
```
pod 'CSSH/OpenSSLFull', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/OpenSSLFull', :git => 'https://github.com/sshterm/ssh.git'
```

# 使用 wolfSSL 版
协议少，不支持ED25519等，适合轻量级应用
```
pod 'CSSH/wolfSSL', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/wolfSSL', :git => 'https://github.com/sshterm/ssh.git'
```

# 关于libssh2

https://github.com/libssh2/libssh2

# 关于OpenSSL

https://github.com/openssl/openssl

# 关于wolfSSL

https://github.com/wolfSSL/wolfssl

# 业务说明
    src/ SSH2业务
    src/DNS/ DNS加密业务
    src/Crypto/ 哈希加密业务，包括证书生存等
    src/Machine/ Linux服务器状态查询业务


# Demo

### 加密DNS
```swift
//启动DNS 会自动加密APP的所有DNS请求
DNS.shared.requireEncrypted(.alidns, type: .doh)
```

### SSH2连接
```swift
//创建SSH
 let ssh = SSH(host:  "10.0.0.1", port: 22, user: "root", timeout: 5)
//设置插座
 ssh.sessionDelegate = delegate
 //连接
 await ssh.connect()
 //握手
 await sh.handshake()
 //认证 更多方式 请参考 Auth.swift 的函数注释
 await ssh.authenticate(password: "<PASSWORD>")
```

具体函数用法请参考 代码注释