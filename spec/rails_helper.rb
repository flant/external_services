# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('dummy/config/environment.rb', __dir__)
require 'rspec/rails'
require 'factory_bot_rails'

ActiveRecord::Migrator.migrations_paths = [File.expand_path('../spec/dummy/db/migrate', __dir__)]
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!
  config.infer_base_class_for_anonymous_controllers = false

  config.include FactoryBot::Syntax::Methods
end
