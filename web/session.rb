require_relative 'security'
require 'time'
module SpnlWeb
  class Session
    def initialize(secret, previous_secrets = [])
      raise ArgumentError, 'session secret must have at least 32 bytes' if secret.bytesize < 32
      @secret = secret
      @previous_secrets = previous_secrets
    end
    def sign(value, expires_at = 0)
      raise ArgumentError, 'invalid session payload' if value.include?("\0") || expires_at < 0
      payload = 'v1:' + expires_at.to_s + ':' + value
      payload + '.' + OpenSSL::HMAC.hexdigest('SHA256', @secret, payload)
    end
    def verify(signed)
      return '' if signed.include?("\0")
      dot = signed.rindex('.')
      return '' if dot.nil?
      payload = signed[0, dot]
      signature = signed[dot+1, signed.length]
      return '' unless signature.match?(/\A[0-9a-f]{64}\z/)
      valid = Security.equal?(signature, OpenSSL::HMAC.hexdigest('SHA256', @secret, payload))
      @previous_secrets.each { |key| valid = true if Security.equal?(signature, OpenSSL::HMAC.hexdigest('SHA256', key, payload)) }
      return '' unless valid
      parts = payload.split(':', 3)
      return '' unless parts.length == 3 && parts[0] == 'v1' && parts[1].match?(/\A[0-9]+\z/)
      expires = parts[1].to_i
      return '' if expires > 0 && expires <= Time.now.to_i
      parts[2]
    end
  end
  def self.cookie_value(raw, name)
    header = raw.split("\r\n").find { |line| line.downcase.start_with?('cookie:') }
    return '' if header.nil?
    header.split(':', 2)[1].split(';').each do |pair|
      item = pair.strip.split('=', 2)
      return item.length == 2 ? item[1] : '' if item[0] == name
    end
    ''
  end
  def self.session
    secret = ENV['SPNL_SESSION_SECRET']
    raise ArgumentError, 'SPNL_SESSION_SECRET is required' if secret.nil?
    Session.new(secret)
  end
end
def session_sign(value); SpnlWeb.session.sign(value); end
def session_verify(value); SpnlWeb.session.verify(value); end
def get_session_cookie(raw); SpnlWeb.cookie_value(raw, 'session'); end
