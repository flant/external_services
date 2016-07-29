module ExternalServices
  module ApiActions
    class Test < ApiAction
      def execute!
        set_processed!
      end
    end
  end
end
