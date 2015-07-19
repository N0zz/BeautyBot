# encoding: utf-8

require 'mysql2'

class Database

  private
    def initialize
      @@db = Mysql2::Client.new(
        :host =>        '127.0.0.1',
        :username =>    'user',
        :password =>    'pass',
        :port =>        3306,
        :database =>    'dbname'
       )
    end   
  public
    #Adds user name to array in db
    def add_join_queues(channel)
    @@db.query("
      INSERT IGNORE INTO join_queues (`channel`)
      VALUES ('#{channel}')
    ;")
    end
    
    def  add_user_to_db(channel, oauth)
    @@db.query("
      INSERT IGNORE INTO users (`channel`, `oauth`)
      VALUES ('#{channel}', '#{oauth}')
    ;")
    end
    #Dels user name from db table
    def del_join_queues(channel)
      @@db.query("
        DELETE FROM join_queues
        WHERE `channel` = '#{channel}'
      ;")
    end
    
    #Returns first item of array from db
    def get_join_queues
    channel = ""
    results = @@db.query("
      SELECT `channel`
      FROM join_queues
      ORDER BY `id` ASC
      LIMIT 1
    ;")
    
    results.each do |result|
      channel = result['channel']
    end
      if channel == nil
        return nil
      else
        return channel
      end
    end
    
    #Get count of use of command from database
    #Displayed from @count@ in command text
    def get_command_count(channel, command)
      results = @@db.query("
        SELECT SUM(`count`)
        FROM `count_commands`
        WHERE `command` = '!#{command}'
        AND `channel` = '#{channel}'
      ;")

      results.each do |result|
        @count = result["SUM(`count`)"]
      end
      if @count == nil
        return 1
      else
        return @count+1
      end
    end
    
    #Counts chat lines for every user on every channel
    def chat_lines_count_inc(channel, name)
      @@db.query("
        INSERT INTO count_chat_lines (`channel`, `name`, `count`, `created_at`, `updated_at`)
        VALUES ('#{channel}', '#{name}', 1, '#{Time.now}', '#{Time.now}')
        ON DUPLICATE KEY UPDATE `count` = `count` + 1, `updated_at` = '#{Time.now}'
      ;")
    end  
    
    #Increase count of use of command from database
    #Displayed from @count@ in command text
    def commands_count_inc(channel, command, name)
      @@db.query("
        INSERT INTO count_commands (`channel`, `command`, `name`,  `count`, `updated_at`)
        VALUES ('#{channel}', '#{command}', '#{name}', 1, '#{Time.now}')
        ON DUPLICATE KEY UPDATE `count` = `count` + 1
      ;")
    end  
    
    #Returns list of commands from database for specific channel.
    def get_command_list(channel)
      @list = ""
      results = @@db.query("
        SELECT *
        FROM `commands` 
        WHERE `channel` = '#{channel}';
      ")
      
      results.each do |result|
        @list = "#{@list}#{result["command"]} "
      end
      return @list
    end
    
    #Returns command description to say_to_channel after command was used
    def get_command_text_by_name(channel, command)
      if check_if_command_exist_for_this_channel(channel, command)
          results = @@db.query("
            SELECT *
            FROM `commands`
            WHERE `channel` = '#{channel}'
            AND `command` = '#{command}'
          ")
          
          results.each do |result|
            @desc = result["desc"]
          end
          return @desc
      end
    end

    #does what is said in method name...
    def check_if_command_exist_for_this_channel(channel, command)
      command_split ||= get_command_list(channel)
      @results_array = command_split.split(" ")
      if !@results_array.include?(command)
        return false
      else
        return true
      end
    end

    #does what is said in method name...
    def check_if_command_exist(channel, command)
    @id = ""
      results = @@db.query("
        SELECT *
        FROM `commands`
        WHERE `command` = '#{command}'
        AND `channel` = '#{channel}';
      ")
      
      results.each do |result|
        @id = result
      end
    end

    #Adds command to database (!addcom)
    def add_command(command, channel, desc)
      check_if_command_exist(channel, command)
      if @id == ""
        @@db.query("
          INSERT INTO `commands`(`channel`, `command`,`desc`, `created_at`, `updated_at`)
          VALUES('#{channel}', '#{command}', '#{desc}', '#{Time.now}', '#{Time.now}');
        ")
      else
        $error_command_exist = true
      end
    end

    #Dels command to database (!delcom)
    def del_command(command, channel)
      check_if_command_exist(channel, command)
      if @id != ""
        @@db.query("
          DELETE FROM `commands`
          WHERE `command` = '#{command}'
          AND `channel` = '#{channel}';
        ")
      else
        $error_command_not_exist = true
      end
    end
    
    #Mods command to database (!modcom)
    def mod_command(command, channel, newdesc)
      check_if_command_exist(channel, command)
      if @id != ""
        @@db.query("
          UPDATE `commands`
          SET `desc` ='#{newdesc}',
          `updated_at` = '#{Time.now}'
          WHERE `command` = '#{command}'
          AND `channel` = '#{channel}';
        ")
      else
        $error_command_not_exist = true
      end
    end
    
end

Database.new
