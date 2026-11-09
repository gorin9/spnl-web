require_relative 'web/date'
require_relative 'web/uuid'
require_relative 'web/logger'
require_relative 'web/session'
require_relative 'web/csrf'
require_relative 'web/bcrypt'
require_relative 'web/mime'
require_relative 'web/multipart'
require_relative 'web/websocket'
require_relative 'web/scheduler'
# SMTP and TLS are opt-in subfeatures: require "spnl_web/smtp" or /tls.
module SpnlWeb
  VERSION = '0.2.0'
end
