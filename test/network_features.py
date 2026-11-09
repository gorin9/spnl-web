"""Local-only SMTP and TLS integration for the standard-library wrappers."""
import os
import socket
import ssl
import subprocess
import tempfile
import threading
from pathlib import Path
root=Path(__file__).resolve().parent.parent
compiler=os.environ.get('SPINEL','spinel')
with tempfile.TemporaryDirectory() as temp:
    temp=Path(temp)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1',0));listener.listen();listener.settimeout(30)
        port=listener.getsockname()[1];received=[];errors=[]
        def smtp():
            try:
                conn,_=listener.accept()
                with conn,conn.makefile('rwb',buffering=0) as stream:
                    stream.write(b'220 localhost ESMTP\r\n')
                    data=False
                    while True:
                        line=stream.readline()
                        if not line:break
                        if data:
                            if line==b'.\r\n':data=False;stream.write(b'250 queued locally\r\n')
                            else:received.append(line)
                        elif line.startswith(b'EHLO'):stream.write(b'250-localhost\r\n250 SIZE 100000\r\n')
                        elif line.startswith((b'MAIL FROM:',b'RCPT TO:')):stream.write(b'250 ok\r\n')
                        elif line==b'DATA\r\n':data=True;stream.write(b'354 send data\r\n')
                        elif line==b'QUIT\r\n':stream.write(b'221 bye\r\n');break
                        else:raise AssertionError(line)
            except BaseException as e:errors.append(e)
        source=temp/'smtp.rb'
        source.write_text(f"require_relative {str(root/'web/smtp').__repr__()}\nraise 'SMTP failed' unless smtp_send('127.0.0.1',ARGV[0],'from@example.invalid','to@example.invalid',\"Subject: smoke\\r\\n\\r\\nlocal only\\r\\n\")\n")
        subprocess.run([compiler,str(source),'-o',str(temp/'smtp')],check=True)
        worker=threading.Thread(target=smtp,daemon=True);worker.start()
        subprocess.run([str(temp/'smtp'),str(port)],check=True,timeout=20)
        worker.join(20)
        assert not worker.is_alive() and not errors and b'local only' in b''.join(received)
    cert=temp/'cert.pem';key=temp/'key.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-subj','/CN=localhost','-days','1'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    source=temp/'tls.rb'
    source.write_text(f"require 'socket'\nrequire_relative {str(root/'web/tls').__repr__()}\nlistener=TCPServer.new('127.0.0.1',0)\ncontext=tls_init(ARGV[0],ARGV[1])\nputs listener.addr[1]\nSTDOUT.flush\nclient=listener.accept\nssl=OpenSSL::SSL::SSLSocket.new(client,context)\nssl.accept\nssl.write('local TLS')\nssl.close\nclient.close\nlistener.close\n")
    subprocess.run([compiler,str(source),'-o',str(temp/'tls')],check=True)
    proc=subprocess.Popen([str(temp/'tls'),str(cert),str(key)],stdout=subprocess.PIPE,text=True)
    try:
        port=int(proc.stdout.readline().strip())
        context=ssl._create_unverified_context() # ephemeral local test certificate only
        with socket.create_connection(('127.0.0.1',port),timeout=10) as client:
            with context.wrap_socket(client,server_hostname='localhost') as secure:
                assert secure.recv(100)==b'local TLS'
        assert proc.wait(timeout=10)==0
    finally:
        if proc.poll() is None:proc.kill();proc.wait()
print('local-only compiled SMTP and TLS integration passed')
