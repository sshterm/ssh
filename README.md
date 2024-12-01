# ssh
libssh2 + OpenSSL + wolfSSL 的swift实现

SSH Term APP [ssh2.app](https://ssh2.app/) 的 SSH2连接核心

全中文注释

# 使用 OpenSSL 版


### 在线版

```
pod 'CSSH/OpenSSLFull', :git => 'https://github.com/sshterm/cssh.git'
pod 'SSH/OpenSSL', :git => 'https://github.com/sshterm/ssh.git'
```

### 克隆版

```
pod 'CSSH/OpenSSL', :path => 'Models/CSSH'
pod 'SSH/OpenSSL',  :path => 'Models/SSH'
```

# 使用 wolfSSL 版

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

# Demo

### 加密DNS
```swift
//启动DNS 会自动加密APPP的所有DNS请求
DNS.shared.requireEncrypted(.alidns, type: .doh)
```

### SSH2连接
```swift
//创建SSH
let ssh = SH(host:  "10.0.0.1", port: 22, user: "root", timeout: 5)
//设置插座
 ssh.sessionDelegate = delegate
 //连接
 await ssh.connect()
 //握手
 await sh.handshake()
 //认证 更多方式 请参考 Auth.swift 的函数注释
 await ssh.authenticate(password: "<PASSWORD>")

```