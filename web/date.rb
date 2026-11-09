require 'time'
def iso_now; Time.now.utc.iso8601; end
def rfc2822_now; Time.now.utc.rfc2822; end
def http_date_now; Time.now.utc.httpdate; end
