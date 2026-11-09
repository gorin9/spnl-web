require 'openssl'
module SpnlWeb
  module Security
    if RUBY_ENGINE == 'spinel'
      ffi_lib 'crypto'
      ffi_func :spnl_secure_equal, [:str, :size_t, :str, :size_t], :int
      def self.equal?(a, b); SpnlWeb::Security.spnl_secure_equal(a, a.bytesize, b, b.bytesize) == 1; end
    else
      def self.equal?(a, b)
        a.bytesize == b.bytesize && OpenSSL.fixed_length_secure_compare(a, b)
      end
    end
  end
end
