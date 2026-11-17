Pod::Spec.new do |s|
  s.name           = 'AppShield'
  s.version        = '1.0.0'
  s.summary        = '番茄帳：計時中把選好的 app 蓋上系統擋板'
  s.description    = '番茄帳：計時中把選好的 app 蓋上系統擋板（螢幕使用時間 API）'
  s.license        = 'MIT'
  s.author         = 'domyweb'
  s.homepage       = 'https://github.com/domyweb666'
  s.platforms      = { :ios => '16.4' }
  s.swift_version  = '5.9'
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.frameworks = 'FamilyControls', 'ManagedSettings'

  s.source_files = "**/*.{h,m,swift}"
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
end
