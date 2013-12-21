# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano/puppeteer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["John Ferlito"]
  gem.email         = ["johnf@inodes.org"]
  gem.description   = %q{Some useful capistrano tasks for standalone puppet masterless puppet deployments.}
  gem.summary       = %q{Capistrano tasks for puppet}
  gem.homepage      = "https://github.com/johnf/capistrano-puppeteer"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capistrano-puppeteer"
  gem.require_paths = ["lib"]
  gem.version       = Capistrano::Puppeteer::VERSION

  gem.add_dependency 'capistrano', '~> 2'
  gem.add_dependency 'fog', '>= 1.9.0'

  gem.add_development_dependency 'rake'
end
