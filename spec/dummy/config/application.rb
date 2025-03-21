require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)
require 'external_services'

module Dummy
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    #
    config.load_defaults 7.1
  end
end
