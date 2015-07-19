# encoding: utf-8

require 'openwfe/util/scheduler'

require './database.rb'
require './mods/twitch_api.rb'

class Main < Database
  Database.new
  
  include OpenWFE

  $debug = true
  @@time_last = Time.now
  @@time_last_msg = Time.now
  @@joined_channels = [" "] #one empty record just to count bot channel itself
  @@built_in_commands = ["!addcom", "!modcom", "!delcom", "!commands", "!join", "!channels", "!leave", "!game", "!uptime"]
  @@built_in_command = false
  @@k = 0

  #Takes params from user message.
  #Example message: /addcom !command Some command text @count@
  #Params: [/addcom], [!command], [Some command text @count]
  #Saves ' and \ as sign codes in db.
  #Does not save other special chars.
  #Returns true or false if params are good for specific commands.
  #Returns @args_table with params.
  def get_params(content, command) 
  @args_table = []

    content_string = content.split(" ")

    @args_table[1] = @channel

    for i in 2..content_string.length
      @args_table[2] = "#{@args_table[2]} #{content_string[i]}"
    end
    @args_table[2].lstrip!.rstrip!
    
    for i in 1..@args_table.length-1
      @args_table[i].gsub!(/['\\]/, "'" => "%27", "\\" => "%5C")
    end
        
    @args_table[0] = "#{content_string[1]}"
    @args_table[0].gsub!(/[^0-9A-Za-z_]/, "")
    @args_table[0] = "!#{@args_table[0]}" if @args_table[0].byteslice(0,1) != "!"

    if ((command == "addcom" || command == "modcom") && @args_table[2] == "") || (@@built_in_commands.include?(@args_table[0]))
      return false 
    else
      return true
    end
  end  
  
  #Get user name from server message string
  #Example: (":username!username@username.tmi.twitch.tv ACTION #channel")
  #Returns: @nick = username
  def get_name(msg) 
    @nick = ""
    msg.each_char do |char|
      @nick = "#{@nick}#{char}"
      if char == "!"
        break
      end
    end
    if @nick != nil
      return @nick.to_s.byteslice(1,@nick.length-2).capitalize! #@nick = ":nick!" -> @nick = "Nick"
    else
      return " "
    end
  end
  
  #Check if /timeout or /ban command was succesful.
  #Get permission info from jtv message.
  #Example: (":jtv!jtv@jtv.tmi.twitch.tv PRIVMSG channel :You don't have permission to timeout users in this room.")
  #Example 2: :jtv!jtv@jtv.tmi.twitch.tv PRIVMSG channel :You cannot timeout the broadcaster.
  #Sent by "jtv", contains "permission"
  #Returns = false - if can not ban || true - if can ban
  def check_ban(msg) # TODO : get_name should take name from next message, not from cuss message or /timeout message
    @banned = true
    if msg.match(/timeout/) and get_name(msg) == "jtv"
      @banned = false
    end
    return @banned
  end
  
  #Get user name from server message string
  #Example: (":username!username@username.tmi.twitch.tv ACTION #channel")
  #Returns: @channel = channel
  def get_channel(msg)
    @chann = ""
    started = false
    msg.each_char do |char|
      if !started and char == "#"
        started = true
      end
      if started
        @chann = "#{@chann}#{char}"
        if char == ":"
          break
        end
      end
    end
    @chann = @chann.to_s.byteslice(1,@chann.length-3) #@chann = "#channel :" -> @chann = "channel"
  end

  #Triggered every [delay] secconds
  #Joins channel, channel name taken from database join_queue table(oldest record).
  def join_queue
    join_channel = get_join_queues
    if join_channel != '' && join_channel != nil
      say("JOIN ##{join_channel}")
      del_join_queue(join_channel)
      say_to_chan(join_channel, "/me has joined the channel.")
      @@joined_channels[@@joined_channels.length] = join_channel
      join_channel = ''
    end
  end
  
  #Formats command name and params to use
  #Command name taken from commands table in database
  #Also incrases commands counter in db
  def custom_db_command(content, name, channel, command)
    #command name
    command.gsub!(/[^0-9A-Za-z_]/, "")
    command = "!#{command}"
    #command text
    @matches = ["%27", "%5C", "@user@", "@channel@", "@time@", "@count@"]
    @vars = ["'", "\\", name, channel, Time.now.to_s[0...-5], get_command_count(@channel, @command)]
  
    if content.byteslice(0,command.length) == command
      @command_text = get_command_text_by_name(channel, command)
      if @command_text
        for i in 0..@matches.length
          @command_text.gsub!(@matches[i].to_s, @vars[i].to_s)
        end
        say_to_chan(channel, @command_text)
        @command_text = ""
        commands_count_inc(channel, command, name)
      end
    end
  end
  
  #!addcom - add commands to database
  def addcom(content)
    good_params = get_params(content, "addcom") 
    if good_params
      add_command(@args_table[0], @args_table[1], @args_table[2], *@args_table[3]) #command, channel, desc, *arg
      $error_command_exist ? say_to_chan(@channel, "Command #{@args_table[0]} already exist.") : say_to_chan(@channel, "Command #{@args_table[0]} has ben succesfully added.")
      $error_command_exist = false
    end
  end
  
  #!modcom - modify command in database
  def modcom(content)
    good_params = get_params(content, "modcom") 
    if good_params
      mod_command(@args_table[0], @args_table[1], @args_table[2]) #command, channel, newdesc
      if $error_command_not_exist  
        say_to_chan(@channel, "Command #{@args_table[0]} does not exist.")
      else
        say_to_chan(@channel, "Command #{@args_table[0]}  has been succesfully modified.")
      end
      $error_command_not_exist = false
    end
  end
  
  #!delcom - deletes command from database
  def delcom(content)
    good_params = get_params(content, "delcom")
    if good_params
      del_command(@args_table[0], @args_table[1]) #command, channel
      $error_command_not_exist ? say_to_chan(@channel, "Command #{@args_table[0]} does not exist.") : say_to_chan(@channel, "Command #{@args_table[0]} has been succesfully deleted.")
      $error_command_not_exist = false
    end
  end
  
  #Saves unique class id to file in order to indentify which bot on which server has some problems
  def save_id_to_file(id)
    f = File.new(".id","w")
    f.write(id)
    f.close
  end
  
  #Says something on irc main channel
  def say(msg)
    #puts msg
    @socket.puts msg
  end

  #Says something on irc as PRIVMSG, so on specific twitch channel
  def say_to_chan(channel, msg)
    say "PRIVMSG ##{channel} :#{msg}" if $debug == false
  end
  
  def debug_on
    if $debug == true && @first_done == nil
      get_biggest_channels(20)
      @first_done = true
    end
  end
  
  #Main bot method, initialized here
  def run
    extend Twitch_api
    save_id_to_file(self.__id__)
    
    #timers to join channels from db queue
    scheduler = Scheduler.new
    scheduler.start
    scheduler.schedule_every('10s') { join_queue } 
    scheduler.schedule_every('15s') { 
      if $debug == true
        debug_on if @@k == 0
        if @@k < 15
          puts "JOINED(#{@@k}) #{$list[@@k]}"
          say "JOIN ##{$list[@@k]}"
          @@k += 1
        end
      end
    } 
    
    say_to_chan(@bot, "/me has joined the channel.")
    
    #main bot loop
    until @socket.eof? do 
      msg = @socket.gets
      puts msg if !msg.match(/^PING :(.*)$/)
      
      @channel = get_channel(msg).to_s
      @name = get_name(msg).to_s
            
      if msg.match(/^PING :(.*)$/)
        say "PONG #{$~[1]}"
        next
      end

      if msg.match(/PRIVMSG ##{@channel} :(.*)$/)
        content = $~[1]
        content.chop!
        
        chat_lines_count_inc(@channel, @name)

        #debug commands for admins only :)
        if @name.downcase == "beautiful_existence"
          say_to_chan(@bot, "My id: #{self.__id__ }") if content == "!id"
          if content == "!debug"
            $debug = true
            debug_on            
            next
          end
        end
        
        #commands that works only on bot main channel
        if @channel == @bot
          if content == "!channels"
            @@joined_channels.length == 1 ? channels = "channel" : channels ="channels"
            say_to_chan(@channel, "I am currently connected to #{@@joined_channels.length} #{channels}.")
          elsif content == "!join"  # TODO - get channels queue and reply "no" if its too long
            if @@joined_channels.include?(@name.downcase) == false
              @oauth = "test_oauth"
              add_join_queue(@name.downcase)
              add_user_to_db(@name.downcase, @oauth)
              say_to_chan(@channel, "Ok #{@name.downcase}, I will join your channel as soon as its possible :)")
            end
          end
        end
        #commands that works on all channels
        #if whole msg is equal to string
        if (content == "!leave" && @name.downcase == @channel) #and is used by channel on channel
          say_to_chan(@channel, "Cya o/ If you want me to get back here, type !join on my channel :)")
          @@joined_channels.delete(@name) # TODO : fix delete from list
          say("PART ##{@name.downcase}")
        elsif content == "!commands"
          get_command_list(@channel)
          @@built_in_commands.each {|command| @commands_list = "#{@commands_list} #{command}"}
          say_to_chan(@channel, "Default commands: #{@commands_list}") if @commands_list.length != 0
          say_to_chan(@channel, "Commands: #{@list}") if @list.length != 0
          @commands_list.clear
        elsif content == "!game" && $debug == false
          say_to_chan(@channel, "Current game: #{self.get_stream_info(@channel, "game")}")
        elsif content == "!uptime" && $debug == false
          say_to_chan(@channel, "Uptime: #{self.get_stream_info(@channel, "created_at")}")
        elsif content.match(/cuss/)         #blacklisted word is timeouted 
          say_to_chan(@channel, "/timeout #{@name.downcase} 10") #TODO ban counter
=begin          
          if check_ban(msg) # TODO : change check_ban to check_if_im_mod_and_banned_is_mod or msg to nextmsg 
            say_to_chan(@channel, "You can't use words like this here!") 
          else
            say_to_chan(@channel, "#{@channel.capitalize}, I need permission to deal with your chat :)")
          end
=end
        end

        #takes content which starts with !, so it may be a command
        if content.byteslice(0,1) == "!" 
          @command = ""
          content.each_char do |char| #cuts command out of user message on chat
            char != " " ? @command = "#{@command}#{char}" : break
          end
          if @@built_in_commands.include?(@command)
            if @name.downcase == @channel #command only usable by streamer on his chat
              case @command
                when "!addcom"
                addcom(content)
                when "!modcom"
                modcom(content)
                when "!delcom"
                delcom(content)
              end
            end  
          end

          #command casted from database
          custom_db_command(content, @name, @channel, @command)
        end
      end
    end
  end
end
