Pod::Spec.new do |s|
  s.name = 'liquid_prism'
  s.version = '0.1.0'
  s.summary = 'System Liquid Glass materials for Liquid Prism.'
  s.description = s.summary
  s.homepage = 'https://github.com/rehmatsg/liquid_prism'
  s.license = { :file => '../LICENSE' }
  s.author = 'Rehmat Singh Gill'
  s.source = { :path => '.' }
  s.source_files = 'liquid_prism/Sources/liquid_prism/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.9'
end
