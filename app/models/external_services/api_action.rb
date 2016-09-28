module ExternalServices
  class ApiAction < ::ActiveRecord::Base
    include ExternalServices::Action

    self.table_name = :external_services_api_actions

    belongs_to :initiator, polymorphic: true

    validates :initiator_id, :initiator_type, :method, :path, :queue, presence: true
    validate  :path_format_correctness

    serialize :data,    JSON
    serialize :options, JSON

    before_validation :process_data
    before_validation :assign_queue
    before_create :calculate_signature

    def initiator_class
      # Need to use initiator object for STI in polymorphic.. But still will be bugs with deleted STI object
      initiator.try(:class) || initiator_type.constantize
    end

    def change_external_id?
      options['change_external_id']
    end

    def job_class
      "ExternalServices::#{self.class.to_s.demodulize}ApiJob".constantize
    end

    def api_disabled?
      initiator_class.send(:"#{self.class.to_s.demodulize.underscore}_api_disabled")
    end

    protected

    def assign_queue
      self.queue ||= case method.to_sym
                     when :post
                       :create
                     when :delete
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
