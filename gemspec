require 'rubygems'

SPEC = Gem::Specification.new do |s|
  s.name      = 'Dynamime'
  s.version   = '0.9.0'
  s.author    = 'Willem van Kerkhof'
  s.email     = 'willem.van-kerkhof@innoq.com'
  s.homepage  = ''
  s.platform  = Gem::Platform::RUBY
  s.summary   = 'Rails plugin that implements sophisticated user agent dependend template rendering'
  s.files     = Dir['./*'] + Dir['*/**']
  s.test_file = 'test/dynamime_test.rb'
  s.has_rdoc  = true
  s.require_path = 'lib'
end
