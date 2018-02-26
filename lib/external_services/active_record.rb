module ExternalServices
  module ActiveRecord
    module HasExternalService
      extend ActiveSupport::Concern

      module ClassMethods
        def has_external_service(name, options = {})
          class_attribute :external_services unless respond_to?(:external_services)
          self.external_services ||= {}
          self.external_services[name.to_sym] = options

          unless options[:only_api_actions] == true
            service_class = get_service_class(name, options)
            service_assoc = :"#{name}_service"
            has_one service_assoc, class_name: service_class, as: :subject, dependent: :destroy, autosave: true

            define_external_service_getset         name, options
            define_external_service_sync_methods   name, options
          end

          define_external_service_callbacks      name, options
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
          includes(self.external_services.keys.map { |name| :"#{name}_service" })
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

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        def define_external_service_callbacks(name, options = {})
          service_assoc = :"#{name}_service"
          only_api_actions = (options[:only_api_actions] == true)

          callbacks_module = Module.new do
            extend ActiveSupport::Concern

            included do
              unless only_api_actions
                before_save do
                  public_send(:"build_#{service_assoc}") if public_send(service_assoc).blank?
                end

                before_update  :halt_on_external_services_syncing
                before_destroy :halt_on_external_services_syncing
              end

              after_save    :"#{name}_on_create", if: :id_changed?

              after_save    :"#{name}_on_update", if: proc {
                !id_changed?
              }

              after_destroy :"#{name}_on_destroy"
            end

            define_method :"#{name}_on_create" do
              public_send(service_assoc).on_subject_create(self) unless only_api_actions
            end
            protected :"#{name}_on_create"

            define_method :"#{name}_on_update" do
              public_send(service_assoc).on_subject_update(self) unless only_api_actions
            end

            define_method :"#{name}_on_destroy" do
              public_send(service_assoc).on_subject_destroy(self) unless only_api_actions
            end
            protected :"#{name}_on_destroy"

            protected def halt_on_external_services_syncing
              if external_services_syncing?
                errors.add :base, :external_services_sync_in_process
                if ::ActiveRecord::VERSION::MAJOR < 5
                  return false
                else
                  throw :abort
                end
              end
            end
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          include callbacks_module
        end

        def define_external_service_sync_methods(name, _options = {})
          service_assoc = :"#{name}_service"
          synced_method = :"#{name}_service_synced?"
          syncing_method = :"#{name}_service_syncing?"
          disabled_method = :"#{name}_api_disabled"

          syncs_module = Module.new do
            extend ActiveSupport::Concern

            define_method synced_method do
              public_send(service_assoc).external_id?
            end

            define_method syncing_method do
              action_class = "ExternalServices::ApiActions::#{name.to_s.camelize}".constantize
              action_class.to_create(self).unprocessed.exists?
            end

            define_method :external_services_synced? do
              result = (!defined?(super) || super())
              result &&= public_send(synced_method) unless public_send(disabled_method)
              result
            end

            define_method :external_services_syncing? do
              result = (defined?(super) && super())
              result ||= public_send(syncing_method) unless public_send(disabled_method)
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
              (synced + for_syncing).map(&:class).uniq.each do |k|
                return true if k.send("#{name}_api_disabled")
              end

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

            define_method :"find_all_by_#{name}_ids" do |ids|
              conditions = { external_services: { type: get_service_class(name).name, external_id: ids } }
              includes(:"#{name}_service").where(conditions)
            end

            define_method :"#{name}_synced" do
              includes(:"#{name}_service").where.not(external_services: { external_id: [nil, ''] })
            end

            define_method :"not_#{name}_synced" do
              includes(:"#{name}_service").where(external_services: { external_id: [nil, ''] })
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
              async   = args[:async].nil? ? true : args[:async]

              options[:change_external_id] = true if options[:change_external_id].nil?

              action = "ExternalServices::ApiActions::#{name.to_s.camelize}".constantize.new(
                initiator: self,
                name:      args[:name] || self.class.send(:"#{name}_api_name"),
                method:    method,
                path:      path,
                data:      data,
                queue:     args[:queue],
                options:   options,
                async:     async
              )

              if async
                action.save!
              else
                action.execute!
              end
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
