
Pod::Spec.new do |s|
  s.name             = 'SSH'
  s.version          = '0.1.0'
  s.summary          = 'SSH,libssh2'
  s.description      = "libssh2 + wolfSSL swift"
  s.homepage         = 'https://github.com/sshterm/ssh'
  s.license          = 'MIT'
  s.author           = { 'sshterm' => 'admin@ssh2.app' }
  s.source           = { :git => 'https://github.com/sshterm/ssh.git', :tag => s.version.to_s }
  s.ios.deployment_target = '16.0'
  s.osx.deployment_target = '13.0'
  s.default_subspecs = :none
  s.subspec 'OpenSSL' do |cs|
    cs.source_files = 'src/**/*.{swift,c,h}'
    cs.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DOPEN_SSL' }
    cs.vendored_frameworks = ["xcframework/CSSH-OpenSSL.xcframework"]
    cs.libraries = 'z'
  end
  s.subspec 'wolfSSL' do |cs|
    cs.source_files = 'src/**/*.swift'
    cs.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '$(inherited) -DWOLF_SSL' }
    cs.vendored_frameworks = ["xcframework/CSSH-wolfSSL.xcframework"]
    cs.libraries = 'z'
  end
end
