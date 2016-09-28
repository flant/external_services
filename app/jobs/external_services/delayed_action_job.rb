module ExternalServices
  class DelayedActionJob < ActiveJob::Base
    queue_as :default

    def action_class
      api_name = self.class.name.demodulize.gsub('ApiDelayedActionJob', '')
      "ExternalServices::DelayedActions::#{api_name}".constantize
    end

    def perform(action_id)
      action = action_class.find(action_id)
      return if action.processed?

      action.execute!
    end
  end
end
