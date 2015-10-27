# Logstash Plugin for IBM Security Access Manager log files

# Dependencies

This plugin uses curl to make HTTP queries. Test has only been done on Redhat Linux.  

# isam_web.rb

This input plugin will read log files on ISAM for Web via its REST interface.  Here are the links to the online documentation:

1. To list all the log files under certain instance: 
  http://www-01.ibm.com/support/knowledgecenter/api/content/nl/en-us/SSPREK_8.0.1.3/com.ibm.isamw.doc/develop/api_web/Retrieving%20the%20names%20of%20all%20instance-specific%20log%20files%20and%20file%20sizes.xml
2. To retrieve a specific file:
  http://www-01.ibm.com/support/knowledgecenter/api/content/nl/en-us/SSPREK_8.0.1.3/com.ibm.isamw.doc/develop/api_web/Retrieving%20a%20snippet%20of%20an%20instance-specific%20log%20file.xml

# Sample input config

  isam_web {
    interval => 30
    appliance_hostname => "abc.xyz"
    username => "logview"
    password => "logview"
    instance_id => "proda"
    file_id => "msg__webseald-proda.log"
  }


