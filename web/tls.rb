require 'openssl'
module SpnlWeb
  module TLS
    def self.context(cert_path, key_path)
      context = OpenSSL::SSL::SSLContext.new
      context.cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
      context.key = OpenSSL::PKey.read(File.read(key_path))
      context
    end
    def self.server(listener, cert_path, key_path)
      OpenSSL::SSL::SSLServer.new(listener, context(cert_path, key_path))
    end
  end
end
def tls_init(cert_path, key_path); SpnlWeb::TLS.context(cert_path, key_path); end
