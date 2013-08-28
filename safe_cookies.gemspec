# -*- encoding: utf-8 -*-
require File.expand_path('../lib/safe_cookies/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Dominik Schöler"]
  gem.email         = ["dominik.schoeler@makandra.de"]
  gem.description   = %q{Make all cookies `secure` and `HttpOnly`.}
  gem.summary       = %q{Make all cookies `secure` and `HttpOnly`.}
  gem.homepage      = "http://www.makandra.de"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "safe_cookies"
  gem.require_paths = ["lib"]
  gem.version       = SafeCookies::VERSION
  
  gem.add_dependency('rack')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('timecop')
end
