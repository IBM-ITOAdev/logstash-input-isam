# encoding: utf-8                                                               
############################################
#
# 
# Logstash mediation input for iSAM
#
############################################
require "logstash/inputs/base"
require "logstash/namespace"
require "pathname"
require "stud/interval"
require "json"
require "pp"

class LogStash::Inputs::ISAM_MOBILE < LogStash::Inputs::Base
  config_name "isam_mobile"
  milestone 1

  default :codec, "plain"

  config :appliance_hostname, :validate => :string, :required => true
  config :username, :validate => :string, :required => true
  config :password, :validate => :string, :required => true
  config :file_id, :validate => :string, :required => true
  config :interval, :validate => :number, :default => 20
  config :work_dir, :validate => :string, :default => '/tmp'


  public
  def register 
    @cmd_file = "curl -k -H 'Accept:application/json' --user #@username:#@password -X GET https://#@appliance_hostname/application_logs/mga/runtime/#@file_id"
  end

  public
  def read_file(file, queue)
    puts @cmd_file
    resp = `#@cmd_file`
    j = JSON.parse(resp)
    if j["message"] != nil
      puts "Error message received - " + j["message"]
      return
    end
    lines = j["contents"].split(/\n/)
    lines.each { |line|
      # AEDT is not supported by Java SimleDateFormat
      line = line.sub!(/AEDT/, '+1100') if line =~ /AEDT/
      event = LogStash::Event.new("message" => line)
      event["type"] = "isam_mobile-rest"
      event["file"] = @file_id
      decorate(event)
      queue << event
    }
  end

  public
  def run(queue)
    loop do
      read_file(@file_id, queue)
      sleep @interval
    end
  end
  
  public
  def teardown
  end
  
end # class LogStash::Inputs::ISAM_MOBILE
