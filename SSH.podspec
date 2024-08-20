
Pod::Spec.new do |s|
  s.name             = 'SSH'
  s.version          = '0.1.0'
  s.summary          = 'A short description of SSH.'
  s.description      = "A short description of SSH."
  s.homepage         = 'https://github.com/sshterm/ssh'
  s.license          = 'MIT'
  s.author           = { 'sshterm' => 'admin@ssh2.app' }
  s.source           = { :git => 'https://github.com/sshterm/ssh.git', :tag => s.version.to_s }
  s.ios.deployment_target = '16.0'
  s.osx.deployment_target = '13.0'
  s.source_files = 'src/**/*.{swift}'
  s.subspec 'CSSH' do |cs|
      cs.source_files = 'CSSH/src/**/*.{c,h}'
      cs.vendored_frameworks = ["CSSH/xcframework/*.xcframework"]
      cs.libraries = 'z'
      cs.public_header_files = ['CSSH/src/include/**/*.h']
      cs.compiler_flags = '-DHAVE_LIBSSL=1','-DHAVE_LIBZ=1','-DLIBSSH2_HAVE_ZLIB=1','-DLIBSSH2_WOLFSSL=1','-DSTDC_HEADERS=1','-DHAVE_ALLOCA=1','-DHAVE_ALLOCA_H=1','-DHAVE_ARPA_INET_H=1','-DHAVE_GETTIMEOFDAY=1','-DHAVE_INTTYPES_H=1','-DHAVE_MEMSET_S=1','-DHAVE_NETINET_IN_H=1','-DHAVE_O_NONBLOCK=1','-DHAVE_SELECT=1','-DHAVE_SNPRINTF=1','-DHAVE_STDIO_H=1','-DHAVE_STRTOLL=1','-DHAVE_SYS_IOCTL_H=1','-DHAVE_SYS_PARAM_H=1','-DHAVE_SYS_SELECT_H=1','-DHAVE_SYS_SOCKET_H=1','-DHAVE_SYS_TIME_H=1','-DHAVE_SYS_UIO_H=1','-DHAVE_SYS_UN_H=1','-DHAVE_UNISTD_H=1','-DLIBSSH2DEBUG=1'
  end
  s.dependency 'BlueSocket'
end
