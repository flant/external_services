module ExternalServices
  module Action
    extend ActiveSupport::Concern

    QUEUE_PREFIX = 'external_services'

    included do
      scope :processed,   -> { where.not(processed_at: nil) }
      scope :unprocessed, -> { where(processed_at: nil) }

      after_commit :kick_active_job
    end

    def processed?
      processed_at.present?
    end

    def set_processed!
      update! processed_at: Time.now
    end

    def execute!
      raise NotImplementedError
    end

    def kick_active_job
      # return if processed? || api_disabled?

      job_class.set(queue: prefixed_queue).perform_later(id)
    end

    def prefixed_queue
      [QUEUE_PREFIX, queue].join('__')
    end

    module ClassMethods
      def clear_sidekiq_queues
        Sidekiq.redis do |conn|
          conn.keys.select { |k| k.include?(QUEUE_PREFIX) }.each do |k|
            conn.del k
          end
        end
      end

      def perform_unprocessed
        Rails.logger.info "Running unprocessed #{self.class.name.demodulize} api actions..."

        unprocessed.each(&:kick_active_job)
      end
    end
  end
end
