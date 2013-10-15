# Enhanced Log File Monitor
## Tags : plugin   logs  

## Category: plugin

##Version Compatibility<br/>Module Name</th><th>up.time Monitoring Station Version</th>


  
    * Enhacned Log File Monitor 2.2 - 7.2, 7.1, 7.0, 6.0, 5.5, 5.4, 5.3, 5.2
  


### Description: This plug-in monitor is designed for use with the up.time monitoring station and Windows, Linux, Solaris or AIX version 5+ agents. It scans for certain log files on the agent system and searches the files for a specified string (regex compatible). It will scan only new lines in files and not generate alerts for older issues. It keeps track of this by using a bookmark (in a temp file) so each time it runs it will simply go to the last position in the file and continue scanning. It is designed to scan large (multi-GB) as well as many files within a second.

### Supported Monitoring Stations: 7.2, 7.1, 7.0, 6.0, 5.5, 5.4, 5.3, 5.2
### Supported Agents: Windows, Solaris, Linux, AIX
### Installation Notes: <p><a href="https://github.com/uptimesoftware/uptime-plugin-manager">Install using the up.time Plugin Manager</a>
Then install the agent-side script.</p>

### Dependencies: <p>n/a</p>

### Input Variables: * Log Directory* Log Files to Search (regex)* Search String (regex)* Ignore String (regex)
### Output Variables: * Occurrences
### Languages Used: * Shell/Batch* PHP

