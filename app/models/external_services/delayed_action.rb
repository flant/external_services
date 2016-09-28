module ExternalServices
  class DelayedAction < ::ActiveRecord::Base
    include ExternalServices::Action

    self.table_name = :external_services_delayed_actions

    after_initialize :init_sync_key

    serialize :arguments, Array
    class_attribute :dynamic_steps

    scope :processed, -> { where.not(processed_at: nil) }
    scope :not_processed, -> { where(processed_at: nil) }

    class << self
      def create_with_args!(*args)
        create arguments: serialize_args
      end

      def virtual_delayed_action(action_name, arguments:)
        klass = "ExternalServices::DelayedActions::#{api_name.to_s.camelize}::#{action_name.to_s.camelize}"
        klass = klass.constantize

        klass.new arguments: klass.serialize_args(*arguments)
      end

      def serialize_args(*args)
        args.map { |o| o.send("serialize_for_#{api_name}_api") }
      end

      def api_name
        api_name_regexp = /ExternalServices::DelayedActions::(?<api_name>\w+)::/
        name.match(api_name_regexp)[:api_name].underscore
      end

      def define_step(type: :proc)
        @steps ||= []

        klass = "ExternalServices::DelayedActionSteps::#{type.to_s.camelize}".constantize

        @steps << klass.new(Proc.new { yield })
      end

      def steps
        @steps || []
      end

      def define_dynamic_step
        @dynamic_step = Proc.new { |obj| yield(obj) }
      end

      def dynamic_step
        @dynamic_step
      end

      def dynamic_steps?
        dynamic_steps || false
      end

      def has_dynamic_steps
        self.dynamic_steps = true
      end
    end

    def virtual_delayed_action(action_name, arguments:)
      self.class.virtual_delayed_action action_name, arguments
    end

    def steps
      if self.class.dynamic_steps? && self.class.dynamic_step
        @steps ||= arguments.map { |arg| Proc.new { self.class.dynamic_step.call(arg) } }
      else
        @steps ||= self.class.steps.map(&:unwrap).flatten
      end
    end

    def execute!
      return if processed? || ExternalServices::DelayedAction.not_processed.where(sync_key: sync_key).exists?

      steps.each_with_index do |step, index|
        next if last_processed_step && index <= last_processed_step

        begin
          step.call
          self.last_processed_step = index
        rescue
          break
        end
      end

      self.processed_at = Time.zone.now if last_step?
      save!
    end

    def job_class
      "ExternalServices::#{self.class.api_name.camelize}DelayedActionJob".constantize
    end

    def api_disabled?
      return true if arguments.find do |arg|
        arg[:type] && arg[:type].constantize.send("#{self.class.api_name}_api_disabled")
      end

      false
    end

    def queue
      :create # TODO: only create?
    end

    def sync_prefix
      self.class.name.underscore
    end

    protected

    def last_step?
      last_processed_step && (last_processed_step + 1) == steps.count
    end

    def init_sync_key
      self.sync_key ||= [sync_prefix, arguments.map { |a| a[:id] }].flatten.join('_')
    end
  end
end
