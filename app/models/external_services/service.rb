module ExternalServices
  class Service < ::ActiveRecord::Base
    self.table_name = :external_services

    belongs_to :subject, polymorphic: true
    serialize :extra_data, JSON

    after_update :on_first_sync, if: proc { # Rails 5.1+ support
      (respond_to?(:saved_change_to_external_id?) ? saved_change_to_external_id? : external_id_changed? ) &&
      (respond_to?(:external_id_before_last_save) ? external_id_before_last_save.nil? : external_id_was)
    }

    def self.to_sym
      to_s.demodulize.underscore.to_sym
    end

    def on_subject_create(subj)
      method = subj.send("#{api_name}_id").present? ? :put : :post
      subj.send("#{api_name}_api_action", method)
    end

    def on_subject_update(subj)
      method = subj.send("#{api_name}_id").present? ? :put : :post
      return true if (subj.respond_to?(:became_archived?) && subj.became_archived?) && method == :post
      subj.send("#{api_name}_api_action", method)
    end

    def on_subject_destroy(subj)
      subj.send("#{api_name}_api_action", :delete)
    end

    def api_name
      self.class.to_sym
    end

    protected

    def on_first_sync
      callback_name = "on_#{api_name}_first_sync"
      subject.send(callback_name) if subject.respond_to?(callback_name)
    end
  end
end
