module ExternalServices
  module Api
    module <%= name %>
      extend ExternalServices::Api
      class Error < ExternalServices::Api::Error; end

      # module_function
      #
      # Redefine everything unusual:
      # def api_key
      #   'my hardcoded key'
      # end
    end
  end
end
