module ExternalServices
  class ApiJob < ActiveJob::Base
    queue_as :default

    def action_class
      "ExternalServices::ApiActions::#{self.class.to_s.demodulize.gsub(%r{ApiJob}, '')}".constantize
    end

    def perform(action_id)
      action = action_class.find(action_id)
      return if action.processed?

      action.execute!
    end
  end
end
