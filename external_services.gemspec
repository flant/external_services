# frozen_string_literal: true

require_relative 'lib/external_services/version'

Gem::Specification.new do |spec|
  spec.name          = 'external_services'
  spec.version       = ExternalServices::VERSION
  spec.authors       = ['Sergey Gnuskov']
  spec.email         = ['sergey.gnuskov@flant.com']

  spec.summary       = 'Gem helps syncronizing objects to different external services like Gitlab, Redmine and any other.'
  spec.homepage      = 'https://github.com/flant/external_services'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.7'

  spec.add_dependency 'faraday', '>= 2.0', '< 3'
  spec.add_dependency 'rails', '>= 5.0.7', '< 8'
end
