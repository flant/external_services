module ExternalServices
  module Api
    class Error < StandardError
      def initialize(response)
        @response = response
      end

      def message
        @response.inspect
      end
    end

    def auth_header
      'Authorization'
    end

    def connection
      return if api_url.blank?

      @connection ||= Faraday.new(url: api_url) do |f|
        f.request  :json
        f.response :json

        f.adapter  :net_http

        f.headers['Content-Type'] = 'application/json'
        f.headers['Accept']       = 'application/json'
        f.headers[auth_header]    = api_key
      end
    end

    # rubocop:disable Lint/UnusedMethodArgument
    def get(path, params: {}, **kwargs)
      request(:get, path, params)
    end

    def post(path, body:, params: {}, **kwargs)
      request(:post, path, params, body)
    end

    def put(path, body:, params: {}, **kwargs)
      request(:put, path, params, body)
    end

    def delete(path, params: {}, **kwargs)
      request(:delete, path, params)
    end
    # rubocop:enable Lint/UnusedMethodArgument

    def fake?
      !connection
    end
  end
end
