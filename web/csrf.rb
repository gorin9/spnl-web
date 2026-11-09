require 'securerandom'
require 'cgi'
require_relative 'session'
def csrf_token; SecureRandom.hex(32); end
def csrf_valid?(submitted, expected)
  !submitted.empty? && !expected.empty? && SpnlWeb::Security.equal?(submitted, expected)
end
def get_csrf_cookie(raw); SpnlWeb.cookie_value(raw, 'csrf_token'); end
def get_query_token(path)
  parts = path.split('?', 2)
  return '' if parts.length < 2
  parts[1].split('&').each do |field|
    pair = field.split('=', 2)
    return pair.length == 2 ? CGI.unescape(pair[1]) : '' if CGI.unescape(pair[0]) == 'token'
  end
  ''
end
