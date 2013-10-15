
1. About
-------------------------

This pluggable monitor is designed for use with up.time monitoring stations with Windows, Linux, AIX and Solaris version 5+ agents. It scans for particular log files on the agent system and searches the files for a specified string (regex compatible). It will scan new lines in files only and not alert you for older issues. It keeps track of this using a bookmark (in a temp file) so the next time it runs it will simply go to that position in the file and keep scanning. It is made to scan large (multi-GB) files in under one second.

Below is a description of each of the Log Monitor settings that are used:

 Script Name   - the location of the script on the monitoring station that
                 contains the logic for contacting the agent and returning
                 the output in a useful format to the monitoring station
 Port          - port that the up.time agent is listening on (default 9998)
 Password      - password that the up.time agent has setup
                 (on some/older agents)
 Log Directory - the full path location of the log files on the agent system
                 that is to be monitored
 Log Files to Search - Filenames of logs to search through (fully regex
                 compatible)
 Search String - the search text/phrase to search for in the file
                 (fully regex compatible)
 Ignore String - a text/phrase to ignore the entire line. If this is found,
                 then the entire line is ignored (fully regex compatible)
                 (optional)
 Occurrences   - total number of lines the search string was found
 Response Time - total amount of time the monitor took to run (in milliseconds)

IMPORTANT NOTE: The primary recommendation when adding/creating the service monitor in up.time is to set the "Max Rechecks" to be zero (0) or else you may not receive alerts for this monitor.


2. Agent Installation
-------------------------

POSIX:
a. Place the log_monitor.pl file in the directory /opt/uptime-agent/scripts/
   (create the directory if needed)
b. Create/edit the following password file:
   /opt/uptime-agent/bin/.uptmpasswd
   and add the following line to it:
   <password>   /opt/uptime-agent/scripts/log_monitor.pl

WINDOWS:
a. Place the log_monitor.pl file in the uptime agent directory in a subdirectory called "scripts" (C:\program files\uptime software\up.time agent\scripts)
   (create the scripts directory if needed)
b. Open the uptime Agent Console (Start > up.time agent) and click on Advanced > Custom Scripts
c. Enter the following:
Command Name: logmonitor
Path to Script: cmd.exe /c "C:\perl\bin\perl.exe "C:\Program Files\uptime software\up.time agent\scripts\log_monitor.pl""


3. Examples
-------------------------

Here are some example settings for the Log File Monitor:

Search the directory "/usr/local/uptime/logs" in files named "uptime.log.*" for "error" or "exception":
Port                - 9998
Password            - *********
Log Directory       - /usr/local/uptime/logs/
Log Files to Search - uptime\.log.*
Search String       - (error)|(exception)
Ignore String       - 
Occurrences         - Critical: is greater than 0
Max Rechecks        - 0


Search the file "/usr/local/uptime/logs/uptime.log" for "up.time software" (spaces must be changed to '\s') and ignore lines that don't have "2008" in them:
Port                - 9998
Password            - *********
Log Directory       - /usr/local/uptime/logs/
Log Files to Search - uptime.log
Search String       - up.time\ssoftware
Ignore String       - [^(2008)]
Occurrences         - Critical: is greater than 0
Max Rechecks        - 0
