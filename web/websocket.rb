require 'base64'
require 'digest'
module SpnlWeb
  class WebSocket
    MAGIC = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
    MAX_BYTES = 1_048_576
    attr_reader :last_opcode
    def self.accept_value(key)
      raise ArgumentError, 'invalid WebSocket key' unless Base64.strict_decode64(key).bytesize == 16
      Base64.strict_encode64(Digest::SHA1.digest(key+MAGIC))
    end
    def initialize(io)
      @io=io;@last_opcode=1;@fragment=+'';@fragment_opcode=0
    end
    def read_exact(size)
      out=+''.b
      while out.bytesize < size
        chunk=@io.read(size-out.bytesize)
        raise EOFError if chunk.nil? || chunk.empty?
        out << chunk
      end
      out
    end
    def send_frame(opcode,payload)
      size=payload.bytesize
      raise ArgumentError, 'WebSocket payload too large' if size > MAX_BYTES
      header=(128|opcode).chr.b
      if size < 126
        header << size.chr
      elsif size <= 65535
        header << 126.chr << ((size>>8)&255).chr << (size&255).chr
      else
        header << 127.chr
        7.downto(0) { |i| header << ((size>>(i*8))&255).chr }
      end
      @io.write(header+payload.b)
    end
    def read_message
      loop do
        header=read_exact(2);a=header.getbyte(0);b=header.getbyte(1)
        opcode=a&15;fin=(a&128)!=0
        raise ArgumentError, 'invalid WebSocket frame' if (a&112)!=0 || (b&128)==0 || ![0,1,2,8,9,10].include?(opcode)
        size=b&127
        if size==126
          bytes=read_exact(2);size=(bytes.getbyte(0)<<8)|bytes.getbyte(1)
          raise ArgumentError, 'noncanonical frame length' if size < 126
        elsif size==127
          bytes=read_exact(8);size=0
          8.times { |i| size=(size<<8)|bytes.getbyte(i) }
          raise ArgumentError, 'invalid frame length' if size < 65536 || bytes.getbyte(0)>=128
        end
        raise ArgumentError, 'WebSocket message too large' if size > MAX_BYTES || @fragment.bytesize+size > MAX_BYTES
        raise ArgumentError, 'invalid control frame' if opcode>=8 && (!fin || size>125)
        mask=read_exact(4);input=read_exact(size);payload=+''.b
        size.times { |i| payload << (input.getbyte(i)^mask.getbyte(i%4)).chr }
        if opcode==8
          raise ArgumentError, 'invalid close frame' if size==1
          if size>=2
            code=(payload.getbyte(0)<<8)|payload.getbyte(1)
            raise ArgumentError, 'invalid close code' unless (code>=1000 && code<=1014 && ![1004,1005,1006].include?(code)) || (code>=3000 && code<=4999)
            raise ArgumentError, 'invalid close reason' unless payload.byteslice(2,size-2).dup.force_encoding('UTF-8').valid_encoding?
          end
          send_frame(8,payload);return nil
        elsif opcode==9
          send_frame(10,payload);next
        elsif opcode==10
          next
        elsif opcode==0
          raise ArgumentError, 'unexpected continuation' if @fragment_opcode==0
          @fragment << payload
        else
          raise ArgumentError, 'interleaved fragments' unless @fragment_opcode==0
          @fragment_opcode=opcode;@fragment=payload
        end
        if fin
          result=@fragment;kind=@fragment_opcode;@last_opcode=kind;@fragment=+''.b;@fragment_opcode=0
          raise ArgumentError, 'invalid text encoding' if kind==1 && !result.dup.force_encoding('UTF-8').valid_encoding?
          return result
        end
      end
    end
  end
end
def ws_key(raw)
  line=raw.split("\r\n").find { |h| h.downcase.start_with?('sec-websocket-key:') }
  line.nil? ? '' : line.split(':',2)[1].strip
end
def ws_accept_value(key);SpnlWeb::WebSocket.accept_value(key);end
