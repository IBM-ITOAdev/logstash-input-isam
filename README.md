# Logstash Plugin for IBM Security Access Manager log files

# Dependencies

This plugin uses curl to make HTTP queries. Test has only been done on Redhat Linux.  

# isam_web.rb

This plugin reads log files on ISAM for Web via its REST interface.  Here are the links to the online documentation:

1. To list all the log files under certain instance: 
  http://www-01.ibm.com/support/knowledgecenter/api/content/nl/en-us/SSPREK_8.0.1.3/com.ibm.isamw.doc/develop/api_web/Retrieving%20the%20names%20of%20all%20instance-specific%20log%20files%20and%20file%20sizes.xml
2. To retrieve a specific file:
  http://www-01.ibm.com/support/knowledgecenter/api/content/nl/en-us/SSPREK_8.0.1.3/com.ibm.isamw.doc/develop/api_web/Retrieving%20a%20snippet%20of%20an%20instance-specific%20log%20file.xml

## Input

| Parameter          | Description                                                                                                                                                                                 |Optional?
|--------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------
| appliance_hostname | name or IP address of the ISAM appliance we are going to connect                                                                                                                            |No
| username           | the username used for REST API call                                                                                                                                                         |No
| password           | the password of the REST username                                                                                                                                                           |No
| instance_id        | ID of the relevant instance                                                                                                                                                                 |No
| file_id            | the log file name.  If the log file is rotated, this will be the *main* log file name.  For example, if request.log is rotated to request.1510202111.log then request.log is the main file. |No
| interval           | REST API polling interval, default is 20 seconds.                                                                                                                                           |Yes
| work_dir           | the script stores its current polling state (line number) in a file under work_dir. Default is /tmp                                                                                         |Yes

### Sample input config
```
  isam_web {
    interval => 30
    appliance_hostname => "abc.xyz"
    username => "logview"
    password => "logview"
    instance_id => "proda"
    file_id => "msg__webseald-proda.log"
  }
```
## How it works
Upon first start, the plugin will read the log file (eg. request.log) from line 1 and when it reaches the end of the file it will wait for a while (defined by @interval) and poll again for any new lines.  If the next polling finds out that the size of the file is smaller than last time then it will try to find out what is the file name that has been rotated, such as request.log.2015-09-14-11-07-44 and starts reading from the file with the line number it stored from the previous poll.  Once it reaches the end of this file it will continue to read the new file (request.log).

# isam_mobile.rb

This plugin reads log files on ISAM for Mobile via its REST interface.  Here is the link to the online documentation:

  http://www-01.ibm.com/support/knowledgecenter/api/content/nl/en-us/SSPREK_8.0.1.3/com.ibm.isamw.doc/develop/api_web/Retrieving%20the%20contents%20of%20a%20directory%20from%20the%20application%20log%20files%20area.xml

However, this REST API does not provide the option to specify from which line of the log that we want to start the retrieval. This means we can only download the whole file during each poll and this will cause problems:

1. if the file is so big it will create extra load on the server side
2. the index engine that logstash feeds into will possibly create multiple entries for one single line.

So please use this plugin (ISAM for Mobile) with caution.
