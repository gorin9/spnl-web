require 'logger'
require 'json'
require 'time'
module SpnlWeb
  class Log
    def initialize(io)
      @logger = Logger.new(io)
      @logger.formatter = proc { |severity, time, progname, message| JSON.generate({'ts'=>time.utc.iso8601, 'lvl'=>severity, 'msg'=>message.to_s}) + "\n" }
    end
    def info(message); @logger.info(message); end
    def warn(message); @logger.warn(message); end
  end
  LOG = Log.new(STDERR)
end
def log_info(message); SpnlWeb::LOG.info(message); end
def log_warn(message); SpnlWeb::LOG.warn(message); end
