Pod::Spec.new do |s|
  s.name     = 'SimpleTracer'
  s.version  = '0.1.0'
  s.summary  = 'SimpleTracer'
  s.homepage = 'https://github.com/Binlogo/SimpleTracer'
  s.license  = 'MIT'
  s.author   = { 'Binlogo' => 'binboy.top@gmail.com' }
  s.source   = { :git => 'https://github.com/Binlogo/SimpleTracer.git', :branch => 'master' }

  s.requires_arc     = true
  s.static_framework = true

  s.ios.deployment_target = '9.0'
  s.swift_version         = '4.2'

  s.source_files     = 'Sources/**/*.{swift,h,m}'
  s.exclude_files    = 'Sources/**/*.plist'
end

