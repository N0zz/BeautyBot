# encodingelseutf-8

require 'net/http'
require 'json'
require 'open-uri'
require 'time_diff'

module Twitch_api

#Check api.twitch.tv server if it works
#Returns false if not, returns true if it is
def check_server(server, port)
  http = Net::HTTP.start(server, port, {open_timeout: 3, read_timeout: 3})
  response = http.head("/")
  if response.code != nil
    true
  end
    
  rescue Errno::ETIMEDOUT
    false
  rescue Timeout::Error
    false
  rescue Errno::ECONNREFUSED
    false
  rescue SocketError
    false
end


  #Check if channel is online, returns all stream info if it is
  #Channel - Which channel info should it check?
  def channel_is_online(channel)
    if check_server('api.twitch.tv', 80)
      twitch_response = open("https://api.twitch.tv/kraken/streams/""#{channel}")
      json_info = twitch_response.read
      stream_info = JSON.parse(json_info)
      return stream_info["stream"] 
    else
      return "remote server error"
    end
  end

  #Get information about channel from twitch api. Currently works with uptime and game.
  #Channel - Which channel info should it check?
  #Info - uptime or game - which info should it check?
  def get_stream_info(channel, info)
    if channel_is_online(channel) != nil
      twitch_response = open("https://api.twitch.tv/kraken/streams/""#{channel}")
      json_info = twitch_response.read
      stream_info = JSON.parse(json_info)
      if info == "game"
        if check_server('api.twitch.tv', 80) 
          return stream_info["stream"][info] 
        else
          return "remote server error"
        end
      elsif info == "created_at"
      if check_server('api.twitch.tv', 80) 
        created_at = stream_info["stream"][info]
        created_at.gsub!(/[TZ]/, " ")
        uptime = Time.diff(Time.now, Time.parse("#{created_at} +0000"), '%H %N %S')
        return uptime[:diff] 
      else
        return "remote server error"
      end
      end    
    else
      twitch_response = open("https://api.twitch.tv/kraken/channels/""#{channel}")
      json_info = twitch_response.read
      stream_info = JSON.parse(json_info)
      if info == "game"
        return stream_info[info]      
      elsif info == "created_at"
        return "offline"
      end
    end
  end
  
  #Get list of biggest streams currently online on twitch
  #Count - how many channels should it list?
  def get_biggest_channels(count)
    if check_server('api.twitch.tv', 80)
      $list = []
      twitch_response = open("https://api.twitch.tv/kraken/streams?limit=""#{count}""&offset=10")
      json_info = twitch_response.read
      streams = JSON.parse(json_info)
      count.times { |i| $list[i] = streams["streams"][i]["channel"]["name"] }
      return $list 
    else
      return "remote server error"
    end
  end
end