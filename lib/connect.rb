# encoding: utf-8

require 'socket'
require './main'

class ConnectIrc < Main

  private
  def initialize(server, port, oauth, bot)
    @bot = bot
    @oauth = oauth
    @socket = TCPSocket.open(server, port)
    say "PASS #{@oauth}"
    say "NICK #{@bot}"
    say "JOIN ##{@bot}"
  end
  
end

bot = ConnectIrc.new(
  "irc.twitch.tv", #ip
  6667, #port
  'oauth:x', #generator: http://twitchapps.com/tmi/
  'nick' #bot user name (is also main channel)
)

bot.run
