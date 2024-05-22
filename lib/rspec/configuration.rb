# frozen_string_literal: true

module ExternalServices
  module RSpec
    module Configuration
      extend ActiveSupport::Concern

      def add_external_service(name)
        Disabler.add_external_service name

        mod = Module.new do
          define_method :"describe_#{name}_api" do |object:, **kwargs, &blk|
            describe_external_service_api(object: object, api_name: name, **kwargs, &blk)
          end
        end

        extend mod
      end
    end
  end
end

RSpec::Core::Configuration.include ExternalServices::RSpec::Configuration
