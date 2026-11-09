require 'securerandom'
require_relative 'security'
module SpnlWeb
  module Password
    if RUBY_ENGINE == 'spinel'
      ffi_lib 'crypt'
      ffi_lib 'crypto'
      ffi_func :spnl_bcrypt_hash, [:str, :int], :str, blocking: true
      ffi_func :spnl_bcrypt_verify, [:str, :str], :int, blocking: true
      def self.hash(value, cost)
        raise ArgumentError, 'invalid bcrypt input' if cost < 4 || cost > 16 || value.bytesize > 72 || value.include?("\0")
        result = SpnlWeb::Password.spnl_bcrypt_hash(value, cost)
        raise 'bcrypt unavailable on this platform' if result.empty?
        result
      end
      def self.verify(value, stored)
        return false if value.include?("\0") || stored.include?("\0")
        SpnlWeb::Password.spnl_bcrypt_verify(value, stored) == 1
      end
    else
      def self.hash(value, cost)
        raise ArgumentError, 'invalid bcrypt input' if cost < 4 || cost > 16 || value.bytesize > 72 || value.include?("\0")
        salt = '$2b$' + format('%02d', cost) + '$' + SecureRandom.base64(16).tr('+', '.')[0,21] + '.'
        result = value.crypt(salt)
        raise 'bcrypt unavailable on this platform' unless result.start_with?('$2')
        result
      end
      def self.verify(value, stored)
        return false unless stored.match?(/\A\$2[aby]\$\d\d\$[.\/A-Za-z0-9]{53}\z/)
        return false if stored[4,2].to_i > 16 || value.bytesize > 72 || value.include?("\0")
        Security.equal?(value.crypt(stored), stored)
      end
    end
  end
end
def bc_hash(value,cost);SpnlWeb::Password.hash(value,cost);end
def bc_verify(value,stored);SpnlWeb::Password.verify(value,stored);end
