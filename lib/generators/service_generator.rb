require "rails/generators"
require "rails/generators/active_record"

module ExternalServices
  module Generators
    # Installs ExternalServices in a rails app.
    class ServiceGenerator < ::Rails::Generators::NamedBase

      source_root File.expand_path("../templates/services", __FILE__)

      desc "Generates specified model and API classes."

      def add_model
        dir = File.expand_path("app/models/external_services")
        template 'model.rb', File.join(dir, "#{file_name}.rb")
      end

      def add_api_action
        dir = File.expand_path("app/models/external_services/api_actions")
        template 'api_action.rb', File.join(dir, "#{file_name}.rb")
      end

      def add_api
        dir = File.expand_path("lib/external_services/api")
        template 'api.rb', File.join(dir, "#{file_name}.rb")
      end

      def add_api_job
        dir = File.expand_path("app/jobs/external_services")
        template 'api_job.rb', File.join(dir, "#{file_name}_api_job.rb")
      end

      protected
    end
  end
end
