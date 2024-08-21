# ssh
libssh2 + OpenSSL + wolfSSL 的swift实现

SSH Term APP [ssh2.app](https://ssh2.app/) 的 SSH2连接核心

# 使用 OpenSSL 版

```
pod 'SSH', :subspecs => ['OpenSSL'] , :git => 'https://github.com/sshterm/ssh.git'
```

# 使用 wolfSSL 版

```
pod 'SSH', :subspecs => ['wolfSSL'] ,:git => 'https://github.com/sshterm/ssh.git'
```

# 关于libssh2

官方的 libssh2-1.11.0 克隆版本，未做任何修改