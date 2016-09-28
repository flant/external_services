module ExternalServices
  module Action
    extend ActiveSupport::Concern

    included do
      scope :unprocessed, -> { where(processed_at: nil) }

      after_commit :kick_active_job
    end

    def processed?
      processed_at.present?
    end

    def set_processed!
      update_attributes! processed_at: Time.now
    end

    def execute!
      raise NotImplementedError
    end

    def kick_active_job
      return if api_disabled?

      job_class.set(queue: queue).perform_later(id)
    end

    module ClassMethods
      def perform_unprocessed
        Rails.logger.info "Running unprocessed #{self.class.name.demodulize} api actions..."

        unprocessed.each(&:kick_active_job)
      end
    end
  end
end
