require 'stringio'
require_relative '../spnl_web'
def assert(x,m);raise m unless x;end
s=SpnlWeb::Session.new('x'*32)
signed=s.sign('alice',Time.now.to_i+60)
assert(s.verify(signed)=='alice','signed session')
assert(s.verify(signed+'x')=='' && s.verify('unsigned')=='','invalid session')
assert(s.verify(s.sign('alice',Time.now.to_i-1))=='','expired session')
assert(SpnlWeb::Session.new('y'*32,['x'*32]).verify(signed)=='alice','rotation')
assert(get_session_cookie("GET / HTTP/1.1\r\nHost: x\r\n\r\n")=='','missing cookie')
assert(get_session_cookie("Cookie: notsession=bad; session=ok\r\n")=='ok','cookie boundary')
assert(csrf_valid?('abc','abc') && !csrf_valid?('',''),'csrf')
assert(!csrf_valid?("abc\0x","abc\0y"),'binary constant-time comparison')
io=StringIO.new;SpnlWeb::Log.new(io).info("quote\"\nline")
assert(JSON.parse(io.string)['msg']=="quote\"\nline",'JSON log escaping')
assert(iso_now.include?('T') && http_date_now.end_with?('GMT'),'time')
body="--x\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.bin\"\r\n\r\na\x00b\r\n--x\r\nContent-Disposition: form-data; name=\"text\"\r\n\r\nhello\r\n--x--\r\n"
parts=SpnlWeb::Multipart.parse(body,'x');assert(parts.length==2 && parts[0].data.bytesize==3 && parts[1].data=='hello','multipart')
assert(ws_accept_value('dGhlIHNhbXBsZSBub25jZQ==')=='s3pPLMBiTxaQ9kYGzzhZRbK+xOo=','WebSocket RFC vector')
hash=bc_hash('password',4);assert(bc_verify('password',hash) && !bc_verify('wrong',hash),'bcrypt')
uuid=SpnlWeb::UUID.v7_at(0x0123456789ab)
assert(uuid.start_with?('01234567-89ab-7') && uuid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/),'UUIDv7 timestamp/version/variant')
puts 'sessions, expiry, rotation, CSRF, JSON logs, binary multipart, WebSocket and bcrypt passed'
