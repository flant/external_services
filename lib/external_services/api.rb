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

    def get(path, params: {}, **_kwargs)
      request(:get, path, params)
    end

    def post(path, body:, params: {}, **_kwargs)
      request(:post, path, params, body)
    end

    def put(path, body:, params: {}, **_kwargs)
      request(:put, path, params, body)
    end

    def delete(path, params: {}, **_kwargs)
      request(:delete, path, params)
    end

    def fake?
      !connection
    end
  end
end
