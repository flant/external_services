# frozen_string_literal: true

module ExternalServices
  class ApiAction < ::ActiveRecord::Base
    include ExternalServices::Action

    MAX_ACTION_AGE = ENV.fetch('EXTERNAL_SERVICES_MAX_ACTION_AGE', '90').to_i.days

    attr_writer :async

    self.table_name = :external_services_api_actions

    belongs_to :initiator, polymorphic: true

    validates :initiator_id, :initiator_type, :method, :path, :queue, presence: true
    validate  :path_format_correctness

    serialize :data, coder: JSON
    serialize :options, coder: JSON

    scope :to_create, ->(obj) { where(initiator: obj, method: :post) }

    before_validation :assign_queue
    before_validation :process_data

    before_create :calculate_signature

    def self.delete_old_processed
      processed.where(arel_table[:created_at].lt(MAX_ACTION_AGE.ago)).delete_all
    end

    def initiator_class
      # Need to use initiator object for STI in polymorphic.. But still will be bugs with deleted STI object and
      # non-STI inheritance
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

    def signature
      async ? super : calculate_signature
    end

    def data
      !async && (method.to_sym == :delete) ? nil : super
    end

    def set_processed!
      return true unless async

      super
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

    def calculate_signature; end

    def path_format_correctness
      errors.add(:path, :invalid) if path =~ %r{//}
    end

    def async
      @async.nil? || @async
    end

    private

    def create_or_update(*args)
      return true unless async

      super
    end
  end
end
