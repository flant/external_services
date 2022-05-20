module ExternalServices
  class ApiJob < ActiveJob::Base
    queue_as :default

    retry_on ExternalServices::Api::Error, attempts: 5, wait: ->(executions) { (Math.gamma(executions) * 60).seconds } # (n-1)! * 60

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
