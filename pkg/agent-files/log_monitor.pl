#!/usr/bin/perl
use strict;
use warnings;

##############################################################################
# This log_monitor.pl script will search for occurrences of a string within 
# a list of files.  The script expects to be called with one large 
# concatenated variable that contains five other variables.  These variables
# represent the log file search criteria and are stored in %criteria.
# The criteria are compared against a bookmark file to ensure the same lines
# in the log files are not searched multiple times.  Once the files are have 
# been searched the bookmark file is updated with the last checked line and
# the occurrences are printed out.
##############################################################################

binmode STDOUT, ":utf8";
use utf8;

use Tie::File;  # for searching through log file and retain a line count
use MIME::Base64;  # for decoding command line argument
use JSON;  # for reading and writing the bookmark file
use Data::Dumper;


##############################################################################
# define if the script is run on a Windows or Unix platform
my $is_unix = 0;  # default Windows
$is_unix = 1 if ( -e "/etc/hosts" );  # determine if it's actually Unix


##############################################################################
# get the CLI variable and parse it into the main 5 variables
my $cmdlinevar = 0;
$cmdlinevar = $ARGV[1];
#if (length($cmdlinevar) == 0) {
if ( !defined $cmdlinevar ) {
	# try the first argument instead
    # Linux agents send arguments as the 2nd arg; others send it as 2nd arg
	$cmdlinevar = $ARGV[0];
}
# confirm that we received the necessary arguments by now
if (length($cmdlinevar) == 0) {
	print "Error: Arguments were not received on the agent script; quitting.";
	exit(1);
}

$cmdlinevar =~ s/(UPDOTTIME)/ /g;         # UPDOTTIME separates each variable
my @splitline = split(/ /, $cmdlinevar);  # split the command line variables

# criteria hash contains the search criteria provided by the service monitor
# {directory}    directory to search in (string)
# {files_regex}  regular expression of files to search within (string)
# {search_regex} regular expression of the string to find (string)
# {ignore_regex} lines will be ignored if they match this regex (string)
# {debug_mode}   whether to produce debug output
# {filename}     array of the files matching files_regex (array of strings)
# {position}     array of bookmark positions (array of integers)
# {bookmarkpos}  corresponding bookmark array entry
# the array indexes for {bookmarkpos} and {filename} match up
my %criteria;

# populate criteria hash with variables from the command line variable
$criteria{directory}    = decode_base64($splitline[0]);
$criteria{files_regex}  = decode_base64($splitline[1]);
$criteria{search_regex} = decode_base64($splitline[2]);
$criteria{ignore_regex} = decode_base64($splitline[3]);
$criteria{debug_mode}   = $splitline[4];

$criteria{directory} =~ s/\\/\//g;  # reorientate slashes for consistency
$criteria{directory} =~ s/\/$//g;  # strip off trailing slash

# set debug_mode variable properly (1 or 0)
if ( lc( $criteria{debug_mode} ) eq 'on' ) { $criteria{debug_mode} = 1; }
else { $criteria{debug_mode} = 0; }

# get list of files matching files_regex
opendir(DIR, $criteria{directory}) || die "$!";
#@{$criteria{filename}} = grep(/${criteria{files_regex}}/, readdir(DIR));
push @{$criteria{filename}}, reverse map "$criteria{directory}/$_", 
  grep /${criteria{files_regex}}/, readdir( DIR );
closedir(DIR);

if ( $criteria{debug_mode} ) {
	#print Dumper(\%criteria);
}


##############################################################################
# generated filename of the file which contains the bookmark positions
my $bookmarkfile = gen_bookmark_filename($criteria{directory});


##############################################################################
# store the bookmark file into the array @bookmark
my @bookmark;
my $json;
my $bookmarks;
my $i;
my $line;
if ( -s $bookmarkfile ) {  # if bookmark file is not empty
	open (BOOKMARK, '<' . $bookmarkfile) || 
	  die ("Error: Could not open bookmark file for reading!");
	$json = <BOOKMARK>;
	close (BOOKMARK);
	$bookmarks = decode_json($json);
	
	if ( $criteria{debug_mode} ) {
		#print Dumper($bookmarks);
	}
}


##############################################################################
# if in debug mode...
if ( $criteria{debug_mode} ) {
	print "Bookmark File: $bookmarkfile\n";
	print "Checking_Dir: $criteria{directory}\n";
	print "File_Regex: $criteria{files_regex}\n";
	print "Search_String: $criteria{search_regex}\n";
	print "Ignore_String: $criteria{ignore_regex}\n";
	print "Checking_Files: ";
	print join ( ",  ", @{$criteria{filename}} );
	print "\n";
}


##############################################################################
# store previous bookmark position in $criteria{position} array then search
my $j;
my @logfileArray;
my $logfile_eof;
my $linenum;
my $total_count = 0;  # count the number of occurrences
my $numfiles = scalar @{$criteria{filename}};
my $numbookmarks = scalar @bookmark;
for $i ( 0 .. ($numfiles - 1) ) {
	# set criteria{position}[i] to zero to start
	# if doesn't change, then there was no bookmark entry
	$criteria{position}[$i] = 0; 
	for $j ( 0 .. ( $numbookmarks - 1 ) ) {
		if ( $criteria{filename}[$i] eq $bookmark[$j]{filename} and 
		  $criteria{search_regex} eq $bookmark[$j]{search_regex} and 
		  $criteria{ignore_regex} eq $bookmark[$j]{ignore_regex} ) {			
			$criteria{position}[$i] = $bookmark[$j]{position};
			$criteria{bookmarkpos}[$i] = $j;
			last;
		}
	}	
	
	##################################################
	# start search 1000 lines earlier if in debug mode
	if ( $criteria{debug_mode} ) {
		$criteria{position}[$i] -= 1000;
		$criteria{position}[$i] = 0 if ($criteria{position}[$i] < 0);
	}


	##################################################
	# read file into @logfileArray
	tie @logfileArray, 'Tie::File', "$criteria{filename}[$i]" || 
	  print("Warning: Could not open file " . $criteria{filename}[$i] .
	    ". Skipping file.\n");
	$logfile_eof = scalar @logfileArray;	# get the EOF position

	
	##############################################################
	# check if the file rotated or the bookmark is no longer valid
	if ($criteria{position}[$i] > $logfile_eof) {
		# reset the bookmark to the beginning of the file
		$criteria{position}[$i] = 0;		
	}
	
	
	$linenum = $criteria{position}[$i];				
	#while ($line = <LOGFILE>) {
	while ( $linenum < $logfile_eof ){
		eval {
			### try block
			# check if we need to ignore/skip the line
			if ( ( length( $criteria{ignore_regex} ) > 0 ) && 
			  ( $logfileArray[$linenum] =~ m/${criteria{ignore_regex}}/i ) ) {
				# skip the line
			}
			else {
				eval {
					### try block
					# check if the line matches the search regex
					if ( $logfileArray[ $linenum ] =~
					  m/${criteria{search_regex}}/i ) {
						$total_count++;
						# print the first 50 matching lines to screen
						# limit 50, so we don't overload up
						if ($total_count <= 50) {
							print $criteria{filename}[$i] . ", line " . 
							 (($linenum+1)) . " = '$logfileArray[$linenum]'\n";
						}
					}
				};
				if ($@) {
					### catch block
					print ("Error: Invalid regular expression for search string.\n");
					last;
				}
			}
		};
		if ($@) {
			### catch block
			print ("Error: Invalid regular expression for ignore string.\n");
			last;
		}
		$linenum++;
	}

	# save new end of file position to bookmark array
	if ( $criteria{bookmarkpos}[$i] ) {
		$bookmark[$criteria{bookmarkpos}[$i]]{position} = $logfile_eof;
	}
	else { # new bookmark entry
		$bookmark[$numbookmarks]{filename} = $criteria{filename}[$i];
		$bookmark[$numbookmarks]{position} = $logfile_eof;
		$bookmark[$numbookmarks]{search_regex} = $criteria{search_regex};
		$bookmark[$numbookmarks]{ignore_regex} = $criteria{ignore_regex};
		$numbookmarks++;
	}
	
	# untie the log file array
	untie @logfileArray;
}
	
	
##############################################################################
# write bookmark array back to bookmark file
open ( BOOKMARK, '>' . $bookmarkfile ) || 
  die ("Error: Could not open bookmark file, $bookmarkfile, for writing!");
$json = encode_json \@bookmark;
print BOOKMARK $json;
#my $bookmarkline;
#$i = 0;
#foreach ( @bookmark ) {
#	$bookmarkline = $bookmark[$i]{filename} . '?' . $bookmark[$i]{position} .
#	  '?' . $bookmark[$i]{searchignore};
#	print MYFILE "$bookmarkline\n";
#	$i++;
#}
close ( BOOKMARK );
  
##############################################################################
# print out the number of occurrences for the monitor
print("total_count $total_count\n");


##############################################################################
# generate the bookmark file name based on the directory being searched
sub gen_bookmark_filename {
	my $dir = shift;
	my $pre_dir = '';
	if ($is_unix) {
		$pre_dir = '/opt/uptime-agent/tmp/';
	}
	else {
		if ( -d 'C:\Program Files (x86)\uptime software\up.time agent' ) {
			# 64bit Windows OS
			$pre_dir = 'C:\Program Files (x86)\uptime software\up.time agent\UPLOGM-';
		}
		else {
			# 32bit Windows OS
			$pre_dir = 'C:\Program Files\uptime software\up.time agent\UPLOGM-';
		}
	}	
	chomp($dir);
	$dir =~ s/\://g;	# get rid of ':'
	$dir =~ s/\?//g;	# get rid of '?'
	$dir =~ s/ //g;		# get rid of ' '
	$dir =~ s/\\/\./g;	# convert '\' to '.'
	$dir =~ s/\//\./g;	# convert '/' to '.'
	$dir =~ s/\|/\./g;	# convert '|' to '.'
	return "$pre_dir" . $dir . ".bmf";
}