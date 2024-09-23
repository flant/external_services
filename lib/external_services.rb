# frozen_string_literal: true

require_relative 'external_services/engine'
require_relative 'external_services/version'

require_relative 'external_services/active_record'
require_relative 'external_services/api'
require_relative 'generators/install_generator'
require_relative 'generators/service_generator'

if defined?(::RSpec::Core)
  require_relative 'rspec/configuration'
  require_relative 'rspec/helpers'
end

Dir[File.join(File.expand_path('lib/external_services'), 'api', '*.rb')].sort.each do |api|
  require_relative api
end

module ExternalServices
end
