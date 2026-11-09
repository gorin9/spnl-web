require 'net/smtp'
def smtp_send(host, port, from, to, body)
  raise ArgumentError, 'invalid mail address' if (from + to).match?(/[\r\n]/)
  smtp = Net::SMTP.new(host, port.to_i)
  begin
    smtp.start
    smtp.send_message(body, from, to)
  ensure
    smtp.finish if smtp.started?
  end
  true
end
