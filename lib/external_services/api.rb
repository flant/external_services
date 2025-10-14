# frozen_string_literal: true

require 'faraday'

module ExternalServices
  module Api
    class Error < StandardError
      attr_reader :response, :status, :url, :method, :body

      def initialize(response = nil)
        @response = response

        if response.respond_to?(:env)
          @status = response.status
          @url = response.env.url.to_s
          @method = response.env.method.to_s.upcase
          @body = response.body
        end

        super(build_message)
      end

      private

      def build_message
        return 'API Error: No response provided' if response.nil?

        message = <<~MSG
          API Error:
            Method: #{method}
            URL: #{url}
            Status: HTTP #{status}
        MSG

        message += "  Body: #{body.inspect}\n" if body

        message.strip
      end
    end

    def api_url
      ENV["#{to_s.demodulize.upcase}_API_URL"]
    end

    def api_key
      ENV["#{to_s.demodulize.upcase}_API_KEY"]
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

    def patch(path, body:, params: {}, **_kwargs)
      request(:patch, path, params, body)
    end

    def fake?
      !connection
    end

    def fake_response_body(method, _path, _params = {})
      (method == :post ? { 'id' => SecureRandom.hex } : {})
    end

    def request(method, path, params = {}, body = nil)
      resp = if fake?
               Struct.new(:success?, :body, :headers).new(true, fake_response_body(method, path, params), {})
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
