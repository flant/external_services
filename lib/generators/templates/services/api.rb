module ExternalServices
  module Api
    module <%= name %>
      extend ExternalServices::Api
      class Error < ExternalServices::Api::Error; end

      module_function

      def api_url
        ENV['<%= name.upcase %>_API_URL']
      end

      def api_key
        ENV['<%= name.upcase %>_API_KEY']
      end

      # def auth_header
      #   # Redefine if needed
      # end

      def request(method, path, params = {}, body = nil)
        resp = if fake?
                 Struct.new(:success?, :body, :headers).new(true, (method == :post ? { 'id' => SecureRandom.hex } : {}), {})
               else
                 connection.send(method, path, body) do |req|
                   req.params = params
                 end
               end

        raise Error, resp unless resp.blank? || resp.success?

        resp
      end
    end
  end
end
