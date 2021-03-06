require 'protobuf/rpc/server'
require 'protobuf/rpc/servers/zmq/util'
module Protobuf
  module Rpc
    module Zmq

      class Worker
        include ::Protobuf::Rpc::Server
        include ::Protobuf::Rpc::Zmq::Util

        ##
        # Constructor
        #
        def initialize(options = {})
          host = options[:host]
          port = options[:port]

          @zmq_context = ::ZMQ::Context.new
          @socket = @zmq_context.socket(::ZMQ::REP)
          zmq_error_check(@socket.connect("tcp://#{resolve_ip(host)}:#{port}"))

          @poller = ::ZMQ::Poller.new
          @poller.register(@socket, ::ZMQ::POLLIN)
        end

        ##
        # Instance Methods
        #
        def handle_request(socket)
          @request_data = ''
          zmq_error_check(socket.recv_string(@request_data))
          log_debug { sign_message("handling request") } unless @request_data.nil?
        end

        def run
          while ::Protobuf::Rpc::Zmq::Server.running? do
            # poll for 1_000 milliseconds then continue looping
            # This lets us see whether we need to die
            @poller.poll(1_000)
            @poller.readables.each do |socket|
              initialize_request!
              handle_request(socket)
              handle_client unless @request_data.nil?
            end
          end
        ensure
          @socket.close
          @zmq_context.terminate
        end

        def send_data
          response_data = @response.to_s # to_s is aliases as serialize_to_string in Message
          @stats.response_size = response_data.size
          zmq_error_check(@socket.send_string(response_data))
        end
      end

    end
  end
end
