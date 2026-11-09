require 'socket'
# Standard Thread owns scheduling and socket readiness. No global Fiber registry.
module SpnlWeb
  class Server
    def initialize(host, port, max_connections = 128)
      @listener = TCPServer.new(host, port)
      @slots = SizedQueue.new(max_connections)
      @connections = []
      @mutex = Mutex.new
      @stopping = false
    end
    def port; @listener.addr[1]; end
    def run(&handler)
      until @stopping
        @slots.push(true)
        socket = nil
        begin
          socket = @listener.accept
        rescue IOError, SystemCallError
          @slots.pop
          raise unless @stopping
          break
        end
        @mutex.synchronize { @connections.push(socket) }
        Thread.new(socket) do |client|
          begin
            handler.call(client)
          rescue IOError, SystemCallError, ArgumentError, EOFError => e
            log_warn(e.message)
          ensure
            client.close unless client.closed?
            @mutex.synchronize { @connections.delete(client) }
            @slots.pop
          end
        end
      end
    end
    def stop
      @stopping = true
      @listener.close unless @listener.closed?
    end
    def drain(timeout = 5.0)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      while @mutex.synchronize { !@connections.empty? } && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        sleep 0.01
      end
      @mutex.synchronize { @connections.each { |socket| socket.close unless socket.closed? } }
    end
  end
end
