require 'external_services/engine'
require 'external_services/version'

require 'external_services/active_record'
require 'external_services/api'
require 'generators/install_generator'
require 'generators/service_generator'

if defined?(::RSpec)
  require 'rspec/configuration'
  require 'rspec/helpers'
end

Dir[File.join(File.expand_path('lib/external_services'), 'api', '*.rb')].each do |api|
  require api
end

module ExternalServices
end
