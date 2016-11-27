import stomp, gzip, StringIO, xml

class MyListener(object):
        def on_error(self, headers, message):
                print('received an error %s' % message)
        def on_message(self, headers, message):
                fp = gzip.GzipFile(fileobj = StringIO.StringIO(message))
                text = fp.readlines()
                fp.close()
                print('%s\n' % text)

        #       self._conn.ack(id=headers['message-id'], subscription=headers['subscription'])

conn = stomp.Connection([('datafeeds.nationalrail.co.uk', 61616)])

conn.set_listener('', MyListener())
conn.start()
conn.connect(username = 'd3user', passcode = 'd3password', wait=False)

conn.subscribe(destination='/queue/D31bec463b-b5e7-4dd6-8103-17478cd4b318', id=1, ack='auto')

#conn.send(body=' '.join(sys.argv[1:]), destination='')

mydata = raw_input('Prompt :')

# 61618

conn.disconnect()
