module ExternalServices
  module RSpec
    module Disabler
      mattr_accessor :external_services

      module_function

      def add_external_service(name)
        self.external_services ||= []
        self.external_services << name.to_sym unless self.external_services.include? name.to_sym
      end

      def disable_external_services(except: [])
        except = [except] unless except.is_a?(Array)
        except = except.map(&:to_sym)

        external_services.each do |name|
          next if name.in? except

          ::ActiveRecord::Base.descendants.each do |klass|
            set_external_service_disabled_value klass, name, true
          end
        end
      end

      def enable_external_services
        external_services.each do |name|
          ::ActiveRecord::Base.descendants.each do |klass|
            set_external_service_disabled_value klass, name, false
          end
        end
      end

      def set_external_service_disabled_value(klass, service, value)
        klass.send("#{service}_api_disabled=", value) if klass.respond_to?("#{service}_api_disabled")
      end
    end
  end
end
