# encoding: utf-8                                                               

############################################
#
# Logstash mediation input for ISAM for Web
#
############################################

require "logstash/inputs/base"
require "logstash/namespace"
require "pathname"
require "stud/interval"
require "json"
require "pp"
require "yaml/store"

class LogStash::Inputs::ISAM_WEB < LogStash::Inputs::Base
  config_name "isam_web"
  milestone 1

  default :codec, "plain"

  config :appliance_hostname, :validate => :string, :required => true
  config :username, :validate => :string, :required => true
  config :password, :validate => :string, :required => true
  config :instance_id, :validate => :string, :required => true
  config :file_id, :validate => :string, :required => true
  config :interval, :validate => :number, :default => 20
  config :work_dir, :validate => :string, :default => '/tmp'

  public
  def ifRotated (cmd, file_id)
    resp = `#{cmd}`
    j = JSON.parse(resp)
    (0..j.length-1).each { |i|
      if j[i]["id"] == file_id
        if j[i]["file_size"] >= @last_check
          @last_check = j[i]["file_size"]
          return false
        else
          return true
        end
      end
    }
  end

  # The return result will contain the file name of the most recent
  # rotate file for the main file (such as request.log)
  public
  def find_rotated_file (cmd, file_id)
    h = {}
    resp = `#{cmd}`
    j = JSON.parse(resp)
    j.each { |file|
      if file["id"] =~ /^#{file_id}/
        h[file['version']] = file["id"]
      end
    }
    #h.sort.reverse.map { |k, v|
    #  puts "#{k} => #{v}"
    #}
    r = h.sort.reverse[1][1]
    if (r)
      puts "the rotated file is: #{r}"
      return r
    else
      return nil
    end
  end

  public
  def register 
    @cmd_inst = "curl -k -H 'Accept:application/json' --user #@username:#@password -X GET https://#@appliance_hostname/wga/reverseproxy_logging/instance/#@instance_id"
    @cmd_file = "curl -k -H 'Accept:application/json' --user #@username:#@password -X GET https://#@appliance_hostname/wga/reverseproxy_logging/instance/#@instance_id/#@file_id?options=line-numbers" + '\&size=214800000'
    @current_line = 1 # the initial line number when we start.
    @poll_interval = @interval
    @last_check = 1
    @store = YAML::Store.new("#@work_dir/#@instance_id-#@file_id.yaml")
    @store.transaction do
      if @store[:current_line] != nil
        @current_line = @store[:current_line]
      end
    end
  end

  # The return result will indicate whether the file has rotated.
  #   1 : reached the end of the file
  #   2 : the file is rotated
  public
  def read_file(file, 
                line_number,
                # what to do when the end of file is reached
                # 1 : continue the reading loop
                # 2 : exit with status 1
                exit_condition,
                queue
                )
    n = line_number
    loop do
      if ifRotated(@cmd_inst, file)
        @store.transaction do
          # We only record the line number of the main file
          # (request.log for example. This means the ingestion will
          # not recover from disruption during the mid of reading a
          # rotated file (with time stamp).
          @store[:current_line] = @current_line
        end
        puts "the file has rotated, return with status 2 ..."
        return 2
      else
        puts "Not rotated, continue the reading loop ..."
      end
      
      # have to reconstruct this string as the file is not the default one anymore. 
      cmd_file = "curl -k -H 'Accept:application/json' --user #@username:#@password -X GET https://#@appliance_hostname/wga/reverseproxy_logging/instance/#@instance_id/#{file}?options=line-numbers" + '\&size=214800000'

      cmd = cmd_file + '\&' + "start=#{n}"
      puts cmd
      resp = `#{cmd}`
      j = JSON.parse(resp)
      if j["message"] != nil
        # we have reached the end of the file
        if (exit_condition == 1)
          # continue the reading loop
          @poll_interval = @interval
        else
          puts "End of file, return with status 1 according to exit_condition ..."
          return 1
        end
      else
        lines = j["contents"].split(/\n/)
        lines.each { |line|
          if line =~ /^(\d+)\s+(.*)/
            @current_line = $1.to_i + 1
            n = @current_line
            @store.transaction do
              @store[:current_line] = @current_line
              # epoch timestamp will be used to calculate the resume point
              @store[:current_time] = Time.now.to_i
            end
            l = $2
            event = LogStash::Event.new("message" => l)
            event["type"] = "isam_web-rest"
            event["file"] = @file_id
            event["line_number"] = @current_line
            decorate(event)
            queue << event
          end
        }
        @poll_interval = 0
      end
      sleep @poll_interval
    end # loop
  end

  public
  def run(queue)
    # To simplify the code we will always resume from the break point
    # of the main file (such as request.log) when we restart.  This
    # means we will lose the resume point when the program is
    # interrupted during the reading of the rotation file.
 
    # while (read_file(@file_id, @current_line, 2, queue) != 2) # for debugging as I don't have a test env.
    while (read_file(@file_id, @current_line, 1, queue) == 2)
      f = find_rotated_file(@cmd_inst, @file_id)
      if (f) 
        read_file(f, @current_line, 2, queue)
        # reset @current_line before going back to the main file
        @current_line = 1
      else 
        puts "the file has rotated but no rotation file is found.  Going back to the main file."
        next
      end
    end
    
  end

  public
  def teardown
  end

end # class LogStash::Inputs::ISAM_WEB
