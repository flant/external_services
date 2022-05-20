require 'rails/generators'
require 'rails/generators/active_record'

module ExternalServices
  module Generators
    # Installs ExternalServices in a rails app.
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Generates migrations and directories.'

      def migration_version
        return unless Rails::VERSION::MAJOR >= 5

        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
     end

      def create_migration_files
        add_migration('create_external_services')
        add_migration('create_external_services_api_actions')
      end

      def create_directories
        create_directory 'app/models/external_services/api_actions'
        create_directory 'app/jobs/external_services'
        create_directory 'lib/external_services/api'
      end

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      protected

      def create_directory(dir)
        dir = File.expand_path(dir)
        empty_directory dir
        add_file File.join(dir, '.keep')
      end

      def add_migration(template)
        migration_dir = File.expand_path('db/migrate')
        if self.class.migration_exists?(migration_dir, template)
          ::Kernel.warn "Migration already exists: #{template}"
        else
          migration_template "migrations/#{template}.rb", "db/migrate/#{template}.rb", migration_version: migration_version
        end
      end
    end
  end
end
