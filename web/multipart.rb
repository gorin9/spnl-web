module SpnlWeb
  class Part
    attr_reader :name, :filename, :content_type, :data
    def initialize(name,filename,content_type,data)
      @name=name;@filename=filename;@content_type=content_type;@data=data
    end
  end
  module Multipart
    MAX_BYTES = 1_048_576
    def self.parse(body, boundary)
      raise ArgumentError, 'invalid multipart boundary' unless boundary.match?(/\A[0-9A-Za-z'()+_,.\/:=? -]{1,70}\z/) && !boundary.end_with?(' ')
      raise ArgumentError, 'multipart too large' if body.bytesize > MAX_BYTES
      marker = '--' + boundary
      raise ArgumentError, 'incomplete multipart' unless body.start_with?(marker+"\r\n") && body.end_with?("\r\n"+marker+"--\r\n")
      chunks = body.split("\r\n"+marker)
      chunks[0] = chunks[0][marker.bytesize+2, chunks[0].bytesize]
      chunks.pop
      chunks.map do |chunk|
        chunk = chunk[2,chunk.bytesize] if chunk.start_with?("\r\n")
        pair = chunk.split("\r\n\r\n",2)
        raise ArgumentError, 'invalid multipart part' unless pair.length == 2
        disposition = pair[0].split("\r\n").find { |h| h.downcase.start_with?('content-disposition:') }
        raise ArgumentError, 'missing disposition' if disposition.nil?
        name = disposition[/\bname="([^"\r\n]*)"/,1]
        filename = disposition[/\bfilename="([^"\r\n]*)"/,1]
        raise ArgumentError, 'missing part name' if name.nil?
        content_type = pair[0].split("\r\n").find { |h| h.downcase.start_with?('content-type:') }
        Part.new(name,filename.nil? ? '' : filename,content_type.nil? ? '' : content_type.split(':',2)[1].strip,pair[1])
      end
    end
  end
end
def get_boundary(raw)
  content_type = raw.split("\r\n").find { |h| h.downcase.start_with?('content-type:') }
  return '' if content_type.nil?
  match = content_type.match(/boundary=(?:"([^"]+)"|([^;\s]+))/)
  return '' if match.nil?
  match[1].nil? ? match[2] : match[1]
end
def parse_multipart_first(raw,boundary)
  body = raw.split("\r\n\r\n",2)[1]
  return '' if body.nil?
  parts = SpnlWeb::Multipart.parse(body,boundary)
  parts.empty? ? '' : parts[0].data
end
