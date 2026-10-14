Pod::Spec.new do |s|
  s.name             = 'liquid_prism'
  s.version          = '0.5.3'
  s.summary          = 'Glass components with native UIKit popup menus.'
  s.description      = 'Liquid Prism includes the Liquid Menu UIKit bridge for real native popup presentation.'
  s.homepage         = 'https://github.com/rehmatsg/liquid_prism'
  s.license          = { :type => 'BSD-3-Clause AND MIT', :files => ['../LICENSE', '../LICENSE-liquid-menu'] }
  s.author           = 'Rehmat Singh Gill'
  s.source           = { :path => '.' }
  s.source_files     = 'liquid_prism/Sources/liquid_prism/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.9'
  s.resource_bundles = { 'liquid_prism_privacy' => ['liquid_prism/Sources/liquid_prism/PrivacyInfo.xcprivacy'] }
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
