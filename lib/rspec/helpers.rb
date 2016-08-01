require 'rspec/disabler'

module ExternalServices
  module RSpec
    module Helpers
      extend ActiveSupport::Concern

      module ClassMethods
        def disable_external_services(except = [])
          before :all do
            ExternalServices::RSpec::Disabler.disable_external_services except: except
          end

          after :all do
            ExternalServices::RSpec::Disabler.enable_external_services
          end
        end

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

        def describe_external_service_api(object:, api_name:, **kwargs, &blk)
          action_class = kwargs[:action_class] || "ExternalServices::ApiActions::#{api_name.to_s.camelize}".constantize
          methods = [:create, :update, :destroy]
          methods -= [kwargs[:except]].flatten if kwargs[:except]
          methods &= [kwargs[:only]].flatten if kwargs[:only]

          describe action_class.to_s do
            before :all do
              Disabler.enable_external_services
              Disabler.disable_external_services except: [api_name]
            end

            after :all do
              Disabler.enable_external_services
            end

            before do
              @api_object = case object
                            when Symbol
                              send(object)
                            else
                              instance_exec(&object)
                            end
              @action_class = action_class
              @id_key = kwargs[:id_key].try(:to_s) || "#{api_name.to_s.underscore}_id"
              @methods = kwargs[:methods] || { create: :post, update: :put, destroy: :delete }

              perform_unprocessed_actions
            end

            if :create.in? methods
              it 'creates action on create' do
                expect_api_action_on_create
              end
            end

            if :update.in? methods
              it 'creates action on update' do
                @api_object.send("#{@id_key}=", SecureRandom.hex)
                @api_object.save

                expect_api_action_on_update(@api_object)
              end
            end

            if :destroy.in? methods
              it 'creates action on delete' do
                if @api_object.respond_to?(:descendants)
                  @api_object.reload.descendants.each(&:delete)
                end
                @api_object.destroy
                expect_api_action_on_destroy(@api_object)
              end
            end

            if kwargs[:descendants_identifier_check]
              it 'create actions for all descendants on identifier change' do
                @api_object.update_attributes! identifier: "#{@api_object.identifier}1"

                @api_object.descendants.each do |c|
                  expect_api_action_on_update(c)
                end
              end
            end

            instance_exec(&blk) if block_given?
          end

          # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        end
      end

      def remove_api_actions(api_name)
        "ExternalServices::ApiActions::#{api_name.to_s.camelize}".constantize.delete_all
      end

      def expect_api_action_on_create(obj = nil)
        expect_api_action(initiator: obj, method: @methods[:create])
      end

      def expect_api_action_on_update(obj = nil)
        expect_api_action(initiator: obj, method: @methods[:update])
      end

      def expect_api_action_on_destroy(obj = nil)
        expect_api_action(initiator: obj, method: @methods[:destroy])
      end

      def expect_api_action(params)
        params[:initiator] ||= @api_object
        expectation = params.delete(:expectation)
        expectation = true if expectation.nil?
        count = params.delete(:count)
        data = params.delete(:data) || {}

        actions = @action_class.where(params).select do |a|
          data.select { |k, v| a.data[k.to_s] != v }.empty?
        end

        if count
          expect(actions.count).send expectation ? 'to' : 'not_to', eq(count)
        else
          expect(actions.any?).to eq(expectation)
        end
      end

      def unexpect_api_action(params)
        expect_api_action(params.merge(expectation: false))
      end

      def perform_unprocessed_actions
        @action_class.unprocessed.each(&:execute!)
        @api_object.reload
      end
    end
  end
end

RSpec.configure do |config|
  config.include ExternalServices::RSpec::Helpers
end
