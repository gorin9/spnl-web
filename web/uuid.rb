require 'securerandom'
module SpnlWeb
  module UUID
    # RFC 9562 UUIDv7, random ordering within a millisecond (no shared counter).
    def self.v7_at(milliseconds)
      raise ArgumentError, 'UUID timestamp outside 48 bits' if milliseconds < 0 || milliseconds > 281474976710655
      bytes = SecureRandom.random_bytes(16)
      6.times { |i| bytes.setbyte(i, (milliseconds >> ((5-i)*8)) & 255) }
      bytes.setbyte(6, (bytes.getbyte(6) & 15) | 112)
      bytes.setbyte(8, (bytes.getbyte(8) & 63) | 128)
      hex = bytes.unpack1('H*')
      hex[0,8]+'-'+hex[8,4]+'-'+hex[12,4]+'-'+hex[16,4]+'-'+hex[20,12]
    end
    def self.v7
      now = Time.now
      v7_at(now.to_i*1000 + now.nsec/1_000_000)
    end
  end
end
