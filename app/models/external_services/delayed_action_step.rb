module ExternalServices
  module DelayedActionSteps
    class Base
      attr_accessor :executable

      def initialize(proc)
        @executable = proc
      end
    end

    class Proc < Base
      def unwrap
        [executable]
      end
    end

    class DelaydAction < Base
      def unwrap
        executable.call.steps
      end
    end
  end
end
