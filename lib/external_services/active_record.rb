module ExternalServices
  module ActiveRecord
    module HasExternalService
      extend ActiveSupport::Concern

      module ClassMethods
        def has_external_service(name, options = {})
          class_attribute :external_services unless respond_to?(:external_services)
          self.external_services ||= []
          self.external_services << name.to_sym

          service_class = get_service_class(name, options)
          service_assoc = :"#{name}_service"
          has_one service_assoc, class_name: service_class, as: :subject, dependent: :destroy, autosave: true

          define_external_service_getset         name, options
          define_external_service_callbacks      name, options
          define_external_service_sync_methods   name, options
          define_external_service_helper_methods name, options

          extend  service_class::SubjectClassMethods if defined? service_class::SubjectClassMethods
          include service_class::SubjectMethods if defined? service_class::SubjectMethods

          # rubocop:disable Lint/HandleExceptions
          begin
            service_module = const_get(name.to_s.camelize)
            include service_module
          rescue NameError
          end
          # rubocop:enable Lint/HandleExceptions
        end

        def includes_external_services
          includes(self.external_services.map { |name| :"#{name}_service" })
        end

        def external_services_disabled
          Thread.current[:external_services_disabled]
        end

        def external_services_disabled=(val)
          Thread.current[:external_services_disabled] = val
        end

        def without_external_services
          old = external_services_disabled
          self.external_services_disabled = true

          yield
        ensure
          self.external_services_disabled = old
        end

        private

        def get_service_class(name, options = {})
          (options[:class] || "ExternalServices::#{name.to_s.camelize}").constantize
        end

        def define_external_service_getset(name, _options = {})
          service_assoc = :"#{name}_service"

          define_method :"#{name}_id" do
            public_send(service_assoc).try(:public_send, :external_id)
          end

          define_method :"#{name}_id=" do |val|
            public_send(service_assoc).try(:public_send, :external_id=, val)
          end

          define_method :"#{name}_extra_data" do
            public_send(service_assoc).try(:public_send, :extra_data)
          end

          define_method :"#{name}_extra_data=" do |val|
            public_send(service_assoc).try(:public_send, :extra_data=, val)
          end

          define_singleton_method :"find_by_#{name}_id" do |id|
            all.joins(service_assoc).find_by(external_services: { external_id: id })
          end

          define_method service_assoc do
            super() || public_send(:"build_#{service_assoc}")
          end
        end

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def define_external_service_callbacks(name, _options = {})
          service_assoc = :"#{name}_service"

          callbacks_module = Module.new do
            extend ActiveSupport::Concern

            included do
              before_save do
                public_send(:"build_#{service_assoc}") if public_send(service_assoc).blank?
              end

              after_save    :"#{name}_on_create", if: :id_changed?

              after_save    :"#{name}_on_update", if: proc {
                !id_changed?
              }

              after_destroy :"#{name}_on_destroy"
            end

            define_method :"#{name}_on_create" do
              public_send(service_assoc).on_subject_create(self)
            end
            protected :"#{name}_on_create"

            define_method :"#{name}_on_update" do
              public_send(service_assoc).on_subject_update(self)
            end

            define_method :"#{name}_on_destroy" do
              public_send(service_assoc).on_subject_destroy(self)
            end
            protected :"#{name}_on_destroy"

            define_method :"#{name}_on_revive" do
              public_send(service_assoc).on_subject_revive(self)
            end
            protected :"#{name}_on_revive"
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          include callbacks_module
        end

        def define_external_service_sync_methods(name, _options = {})
          service_assoc = :"#{name}_service"
          synced_method = :"#{name}_service_synced?"
          disabled_method = :"#{name}_api_disabled"

          syncs_module = Module.new do
            extend ActiveSupport::Concern

            define_method synced_method do
              public_send(service_assoc).external_id?
            end

            define_method :external_services_synced? do
              result = (!defined?(super) || super())
              result &&= public_send(synced_method) unless public_send(disabled_method)
              result
            end
          end

          include syncs_module
        end

        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
        def define_external_service_helper_methods(name, _options = {})
          ## subject class methods
          helpers_class_module = Module.new do
            define_method :"with_#{name}_api_for" do |synced: [], for_syncing: [], &b|
              return if ([synced] + [for_syncing]).flatten.select(&:"#{name}_api_disabled").any?

              unsynced = [synced].flatten.select { |o| o.send("#{name}_id").nil? }
              if unsynced.any?
                objects = unsynced.map { |o| "#{o.class.name} (id=#{o.id})" }.join(', ')
                raise "[#{name}] Trying to work with an unsynced objects: #{objects}"
              end

              b.call
            end

            define_method :"#{name}_api_name" do
              to_s.demodulize.underscore
            end

            define_method :"#{name}_api_path" do
              send(:"#{name}_api_name").pluralize
            end

            define_method :"#{name}_api_disabled" do
              ENV["#{name}_api_disabled".upcase] == 'true' || Thread.current[:"#{name}_api_disabled"] || external_services_disabled
            end

            define_method :"#{name}_api_disabled=" do |val|
              Thread.current[:"#{name}_api_disabled"] = val
            end

            define_method :"without_#{name}_api" do |&blk|
              begin
                old = send :"#{name}_api_disabled"
                send :"#{name}_api_disabled=", true

                blk.call
              ensure
                send :"#{name}_api_disabled=", old
              end
            end
          end

          ## subject methods
          helpers_module = Module.new do
            define_method :"#{name}_api_disabled" do
              self.class.send :"#{name}_api_disabled"
            end

            define_method :"#{name}_api_path" do
              if send(:"#{name}_id").present?
                "#{self.class.send(:"#{name}_api_path")}/#{send(:"#{name}_id")}"
              else
                self.class.send(:"#{name}_api_path")
              end
            end

            define_method :"#{name}_api_data" do
              send(:"to_#{name}_api")
            end

            define_method :"#{name}_api_action" do |method, **args|
              return if self.class.send(:"#{name}_api_disabled")
              return if !args[:force] && send(:"#{name}_api_disabled")

              path    = args[:path]    || send(:"#{name}_api_path")
              data    = args[:data]    || send(:"#{name}_api_data")
              options = args[:options] || {}

              options[:change_external_id] = true if options[:change_external_id].nil?

              "ExternalServices::ApiActions::#{name.to_s.camelize}".constantize.create!(
                initiator: self,
                name:      args[:name] || self.class.send(:"#{name}_api_name"),
                method:    method,
                path:      path,
                data:      data,
                queue:     args[:queue],
                options:   options
              )
            end
          end

          extend  helpers_class_module
          include helpers_module
        end
        # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
      end
    end
  end
end

ActiveSupport.on_load :active_record do
  ActiveRecord::Base.send :include, ExternalServices::ActiveRecord::HasExternalService
end
