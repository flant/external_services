module ExternalServices
  class ApiJob < ActiveJob::Base
    queue_as :default

    retry_on Api::Error, wait: ->(executions) { Math.gamma(executions) * 60 } # (n-1)! * 60

    def action_class
      "ExternalServices::ApiActions::#{self.class.to_s.demodulize.gsub(/ApiJob/, '')}".constantize
    end

    def perform(action_id)
      action = action_class.find(action_id)
      return if action.processed?

      action.execute!
    end
  end
end
