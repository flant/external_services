require 'rails'
module ExternalServices
  class Engine < ::Rails::Engine
    isolate_namespace ExternalServices

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: 'spec/factories'
    end
  end
end
