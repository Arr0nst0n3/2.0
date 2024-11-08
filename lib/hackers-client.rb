module Trickster
  module Hackers
    require "net/http"
    require "digest"
    require "base64"
    require 'net/http'
    require 'uri'
    require 'zlib'
    require 'stringio'

    ##
    # An exception raises when the request fails
    class RequestError < StandardError
      attr_reader :type, :description
      
      ##
      # Creates new exception:
      #   type        = Type
      #   description = Description
      def initialize(type = nil, description = nil)
        @type = type&.strip
        @description = description&.strip
      end

      ##
      # Returns the description of the exception as a string
      def to_s
        msg = @type.nil? ? "Unknown" : @type
        msg += ": #{@description}" unless @description.nil?
        return msg
      end
    end

    ##
    # Client to communicate with HTTP server
    class Client
      ##
      # Creates new client:
      #   host    = Host
      #   port    = Port
      #   ssl     = Use TLS/SSL
      #   uri     = URI
      #   salt    = Hash URI salt
      #   amount  = Amount of concurrent clients
      def initialize(host, port, ssl, uri, salt, amount = 5)
        @uri = uri
        @salt = salt
        @clients = Hash.new
        amount.times do
          client = Net::HTTP.new(host, port.to_s)
          client.use_ssl = ssl
          @clients[client] = Mutex.new
        end
      end

      ##
      # Encodes URI:
      #   data = Hash of parameters
      #
      # Returns encoded string
      def encodeURI(data)
        params = Array.new
        data.each do |k, v|
          params.push(
            [
              k,
              URI.encode_www_form_component(v).gsub("+", "%20"),
            ].join("=")
          )
        end
        return params.join("&")
      end

      ##
      # Makes URI:
      #   uri       = URI
      #   sid       = Session ID
      #   cmd       = Append cmd_id parameter to URI?
      #   session   = Append session_id parameter to URI?
      #
      # Returns combined URI
      def makeURI(uri, sid, cmd = true, session = true)
        request = @uri + "?" + uri
        request += "&session_id=" + sid if session
        request += "&cmd_id=" + hashURI(request) if cmd
        puts "this perfect urlgen : " + request
        return request
      end

      ##
      # Does request:
      #   params    = Parameters
      #   sid       = Session ID
      #   cmd       = Append cmd_id parameter to URI?
      #   session   = Append session_id parameter to URI?
      #   data      = POST data
      #
      # Returns response
      def request(params, sid, cmd = true, session = true, data = {})
        header = {
          "Content-Type"    => "application/x-www-form-urlencoded",
          "Accept-Charset"  => "utf-8",
          "Accept-Encoding" => "gzip, identity",
          "User-Agent"      => "BestHTTP/2 v2.2.0",
        }
        
        # Ensure the URI is properly constructed
        uri = URI.encode_www_form(params)
        puts "this perfect uri : " + uri
      
        response = nil
        client, mutex = @clients.detect { |k, v| !v.locked? }
        
        if client.nil?
          client, mutex = @clients.to_a.first
        end
      
        mutex.synchronize do
          # Perform GET or POST request based on data
          if data.empty?
            response = client.get(makeURI(uri, sid, cmd, session), header)
          else
            response = client.post(makeURI(uri, sid, cmd, session), URI.encode_www_form(data), header)
          end
        rescue => e
          raise RequestError.new(e.class.to_s, e.message)
        end
      
        # Check if response is successful (HTTP 200 OK)
        if response.class != Net::HTTPOK
          fields = Serializer.parseData(response.body)
          raise RequestError.new(
            Serializer.normalizeData(fields.dig(0, 0, 0)),
            Serializer.normalizeData(fields.dig(0, 0, 1))
          )
        end
      
        # Handling potential gzip encoding in the response
        body = response.body
        if response['Content-Encoding'] == 'gzip'
          gzipped = StringIO.new(body)
          gz = Zlib::GzipReader.new(gzipped)
          body = gz.read
        end
      
        # Ensure the response body is in utf-8 encoding
        body.force_encoding('utf-8')
      
        return body
      rescue StandardError => e
        # Handle any other exceptions and errors
        raise "Request failed: #{e.message}"
      end


      ##
      # Private methods
      private

      ##
      # Calculates the hash of the URI:
      #   uri = URI
      #
      # Returns the hash of the URI
      def hashURI(uri)
        data = uri.clone
        offset = data.length < 10 ? data.length : 10
        data.insert(offset, @salt)
        hash = Digest::MD5.digest(data)
        hash = Base64.strict_encode64(hash[2..7])
        hash.gsub!(
          /[=+\/]/,
          {"=" => ".", "+" => "-", "/" => "_"},
        )
        return hash
      end
    end
  end
end

