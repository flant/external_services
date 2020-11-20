
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'external_services/version'

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

  spec.post_install_message = <<-MSG
    WARNING: since v0.4 active_job queues are prefixed, so you should check sidekiq config.
    And there is a sidekiq queue clean function, you should use it on Sidekiq start  instead of cleaning all Redis db.
  MSG

  spec.add_dependency 'faraday', '>= 0.9'
  spec.add_dependency 'faraday_middleware', '>= 0.10'
  spec.add_dependency 'rails', ['>= 4.2.5', '< 6.1']
end
