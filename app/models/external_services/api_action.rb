module ExternalServices
  class ApiAction < ::ActiveRecord::Base
    self.table_name = :external_api_actions

    belongs_to :initiator, polymorphic: true

    validates :initiator_id, :initiator_type, :method, :path, :queue, presence: true
    validate  :path_format_correctness

    serialize :data,    JSON
    serialize :options, JSON

    scope :unprocessed, -> { where(processed_at: nil) }

    before_validation :assign_queue
    before_validation :process_data
    after_commit      :kick_active_job

    before_create :calculate_signature

    def processed?
      processed_at.present?
    end

    def set_processed!
      update_attributes! processed_at: Time.now
    end

    def initiator_class
      # Need to use initiator object for STI in polymorphic.. But still will be bugs with deleted STI object
      initiator.try(:class) || initiator_type.constantize
    end

    def api_disabled?
      initiator_class.send(:"#{self.class.to_s.demodulize.underscore}_api_disabled")
    end

    def change_external_id?
      options['change_external_id']
    end

    def job_class
      "ExternalServices::#{self.class.to_s.demodulize}ApiJob".constantize
    end

    def kick_active_job
      return if api_disabled?

      job_class.set(queue: queue).perform_later(id)
    end

    def self.perform_unprocessed
      Rails.logger.info "Running unprocessed #{self.class.name.demodulize} api actions..."

      unprocessed.each(&:kick_active_job)
    end

    def execute!
      raise NotImplementedError
    end

    protected

    def assign_queue
      self.queue ||= case method.to_sym
                     when :create
                       :create
                     when :destroy
                       :delete
                     else
                       :default
                     end
    end

    def process_data
      self.data = nil if method.to_sym == :delete # DELETE has no body
    end

    def calculate_signature
    end

    def path_format_correctness
      errors.add(:path, :invalid) if path =~ %r{//}
    end
  end
end
