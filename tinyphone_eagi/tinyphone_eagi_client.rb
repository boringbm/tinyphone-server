#!/usr/local/rvm/rubies/ruby-2.0.0-p576/bin/ruby

require 'ruby-agi'
require 'socket'
require 'uri'
require_relative 'eagi_reader.rb'

agi = AGI.new
@uniqueid = agi.uniqueid
@hangup_sent
host = 'localhost'
port = 12001
@sock = TCPSocket.open(host, port)

#method to send hangup event
def send_hangup(val)
	if !@hangup_sent
		@hangup_sent = true
		@sock.puts "id:#{@uniqueid},event:hangup,value:#{val}"
	end
end

#make sure hangup is sent on exit
Signal.trap(0, proc { send_hangup(1) })

#send new caller message
callerid = agi.calleridnumber
if !callerid
    callerid = agi.callerid
end
#get rid of plus, if it's there
if callerid[0] == '+'[0]
    callerid.slice!(0)
end
argsValue = ""
#don't allow reserved characters through.
reserved_chars=/[{,|:}]/
#add args to value, if there's any
ARGV.each do |arg|
    argsValue << "|" + URI.escape(arg.gsub(reserved_chars,""))
end
@sock.puts "id:#{@uniqueid},event:new_call,value:#{callerid}|#{agi.dnid}#{argsValue}"
#start eagi audio parsing in new thread if EAGI is activated
if (agi.enhanced == '1.0')
	Thread.new {
		EAGI_Reader.new(@sock, @uniqueid)
	}
end
# start agi keypress loop
#agi.stream_file("vm-extension")
looping = true
while looping
    result = agi.wait_for_digit(-1) # wait forever
	if result.digit
        @sock.puts "id:#{@uniqueid},event:keypress,value:#{result.digit}"
	else #hangup broke the pending AGI request
        looping = false 
    end
end
send_hangup(0)
