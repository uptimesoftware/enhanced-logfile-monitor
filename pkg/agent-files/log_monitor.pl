#!/usr/bin/perl
use strict;
# use the File::Find libraries for searching through the directory for files that match a regex
use File::Find;

################################
# site to obfuscate Perl code: #
# http://liraz.org/obfus.html  #
################################

##############################################################
# the following variables may need to be set manually, so let's put them first
# so they are easier to get at after obfuscating the code
my $is_unix = 0;		# define if the script will run on a Windows or Unix platform; default Windows
if (-e "/etc/hosts") {	# determine if it's on Unix
	$is_unix = 1;
}

##############################################################
# get the one variable from the command line and parse it into the main 4 variables
my $cmdlinevar = $ARGV[1];
if (length($cmdlinevar) == 0) {
	# try the first argument instead (Linux agents send arguments as the second arg; the others send it as second)
	$cmdlinevar = $ARGV[0];
}
# confirm that we received the necessary arguments by now
if (length($cmdlinevar) == 0) {
	print "Error: Arguments were not received on the agent script; quitting.";
	exit(1);
}

$cmdlinevar =~ s/(UPDOTTIME)/ /g;			# "UPDOTTIME" separates each variable
my @splitline = split(/ /, $cmdlinevar);	# split the command line variables

# get all the variables from the command line variable
my $dir          = get_rid_of_quotes($splitline[0]);
my $files_regex  = get_rid_of_quotes($splitline[1]);
my $search_regex = get_rid_of_quotes($splitline[2]);
my $ignore_regex = get_rid_of_quotes($splitline[3]);
my $debug_mode   = get_rid_of_quotes($splitline[4]);

# set debug_mode variable properly (1 or 0)
if (lc($debug_mode) eq 'on') {
	$debug_mode = 1;
}
else {
	$debug_mode = 0;
}

# insert spaces where they were ("UPSPCTIME")
$dir          =~ s/(UPSPCTIME)/ /g;
$files_regex  =~ s/(UPSPCTIME)/ /g;
$search_regex =~ s/(UPSPCTIME)/ /g;
$ignore_regex =~ s/(UPSPCTIME)/ /g;
$search_regex =~ s/(UPORTIME)/\|/g;
$ignore_regex =~ s/(UPORTIME)/\|/g;

##############################################################
# variables used in this script
my @filenames;			# array containing all the valid filenames found
my @endlinenums;		# array containing all the end line numbers (for bookmarking)
my $total_count = 0;	# count the number of occurrences

##############################################################
# generated filename of the file that contains the bookmarks/positions to read from
# it is generated by converting the following characters:
# - '\' or '/' to '.'
# - ' ' to '_'
my $bookmarkfile = gen_bookmark_filename($dir);

sub gen_bookmark_filename {
	my $pre_dir = '';
	if ($is_unix) {
		$pre_dir = '/opt/uptime-agent/tmp/';
	}
	else {
		$pre_dir = 'UPLOGM-';
	}
	my $dir = $_[0];
	chomp($dir);
	$dir =~ s/\://g;	# get rid of ':'
	$dir =~ s/\?//g;	# get rid of '?'
	$dir =~ s/ //g;		# get rid of ' '
	$dir =~ s/\\/\./g;	# convert '\' to '.'
	$dir =~ s/\//\./g;	# convert '/' to '.'
	$dir =~ s/\|/\./g;	# convert '|' to '.'
	return $pre_dir . $dir . ".bmf";
}

# function that returns the list of files in the directory that match the file regex entered
sub get_list_of_files
{
	eval {
		### try block

		# skip directories
		if (! -d) {
			# search for the file regex
			if ($_ =~ /^$files_regex$/i) {
				push(@filenames, $File::Find::name);
			}
		}
	};
	if ($@) {
		### catch block
		print ("Error: Could not check for valid filename; please check regular expression.\n");
		exit(1);
	}
}

# get rid of any quotes/double-quotes from the beginning and/or end of a filename
sub get_rid_of_quotes
{
	my $fn = $_[0];
	chomp($fn);
	$fn =~ s/^\'//;
	$fn =~ s/\'$//;
	$fn =~ s/^\"//;
	$fn =~ s/\"$//;
	return $fn;
}


# get the list of files in the directory that match the file regex entered
find (\&get_list_of_files, $dir);
# if in debug mode...
if ($debug_mode) {
	print "Bookmark File: '$bookmarkfile'\n";
	print "Checking_Dir: $dir\n";
	print "File_Regex: $files_regex\n";
	print "Checking_Files: @filenames\n";
	print "Search_String: $search_regex\n";
	print "Ignore_String: $ignore_regex\n";
}

# go through the list of filenames
my $numoffiles = @filenames;
my $line;
for (my $i = 0; $i < $numoffiles; $i++) {
	my $bookmarkedlineposition = 0;
	my $logfile = $filenames[$i];
	my $previouslybookmarked = 0; # 0 = false, 1 = true
	
	# get the last bookmark for this filename (if the bookmark file exists and is not zero size)
	if (-s $bookmarkfile) {
		open (BOOKMARK, "<" . $bookmarkfile) || die ("Error: Could not open bookmark temp file for reading!");
		while ($line = <BOOKMARK>) {	# read bookmark file
			my @splitline = split(/\?/, $line);	# split the bookmarked line (FILENAME?POS?SEARCH)
			if (($splitline[0] eq $logfile) && (@splitline == 3)) {
				# now let's verify if it's the same search/ignore string
				my $searchstr = $search_regex . $ignore_regex;
				$searchstr =~ s/\?//g;	# get rid of '?'
				chomp($splitline[2]);	# get rid of the new line at the end
				if ($splitline[2] eq $searchstr) {
					# found the filename and it's the right search string, so let's save the bookmarked position
					chomp ($splitline[1]);
					$bookmarkedlineposition = $splitline[1];
					$previouslybookmarked = 1;
				}
			}
		}
		close (BOOKMARK);
	}
	
	# if the file did NOT have a bookmark (so it is the first time)
	if (! $previouslybookmarked) {
		eval {
			### try block

			# ...skip the line-by-line search and just get the EOF position to start monitoring for next time
			open (LOGFILE, "<$logfile") || print("Warning: Could not open file '$logfile'. Skipping file.");
			seek (LOGFILE, 0, 2);
			# update the @endlinenums array with the new bookmark
			$endlinenums[$i] = tell(LOGFILE);
			close (LOGFILE);
		};
		if ($@) {
			### catch block
			print("Warning: Could not open file '$logfile'. Skipping file.");
			exit(1);
		}
	}
	# else if the file already had a previous bookmark...
	else {
		# if the file exists...
		if (-s $logfile) {
			eval {
				### try block
				# ...open the logfile
				open (LOGFILE, "<$logfile") || print("Warning: Could not open file '$logfile'. Skipping file.");
				
				# get EOF position of file
				seek (LOGFILE, 0, 2);				# seek to the EOF position
				my $logfile_eof = tell(LOGFILE);	# get the EOF position
				seek (LOGFILE, 0, 0);				# seek back to the beginning of the file
				
				# if in debug mode...
				if ($debug_mode) {
					# go back 1MB and start scanning from there (for testing)
					$bookmarkedlineposition -= 1048576;
					if ($bookmarkedlineposition < 0) {
						$bookmarkedlineposition = 0;
					}
				}

				# check if the file rotated or the bookmark is no longer valid
				if ($bookmarkedlineposition > $logfile_eof) {
					# reset the bookmark to the beginning of the file
					$bookmarkedlineposition = 0;
					seek (LOGFILE, 0, 0);
				}
				# else, seek to the last known position
				elsif (seek (LOGFILE, $bookmarkedlineposition, 0) != 1) {
					# if we get here, then there was an error seeking to the position
					# so we'll just assume the file was reset, so we should start from the beginning
					$bookmarkedlineposition = 0;
					seek (LOGFILE, $bookmarkedlineposition, 0)
				}

				# loop through the rest of the file, line by line
				while ($line = <LOGFILE>) {
					eval {
						### try block
						# check if we need to ignore/skip the line
						if ((length($ignore_regex) > 0) && ($line =~ m/$ignore_regex/i)) {
							# skip the line
						}
						else {
							eval {
								### try block
								# check if the line matches the search regex
								if ($line =~ m/$search_regex/i) {
									$total_count++;

									# if in debug mode...
									if ($total_count <= 50) {
										# print the line out to screen (only the first 50 lines though!)
										print "{$logfile}: '$line'\n";
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
				}
				
				# update the @endlinenums array
				$endlinenums[$i] = tell(LOGFILE);
				
				# close the logfile
				close (LOGFILE);
			};
			if ($@) {
				### catch block
				print ("Warning: Could not open file '$logfile'. Skipping file.");
				last;
			}
		}
		else {
			# the file is empty, so let's just update the bookmark position to zero
			$endlinenums[$i] = 0;
		}
	}
}


# create/update the bookmark file
# first, read the values in the bookmark file, then we'll update the values,
# and save everything to the bookmark file.
# this is so that we can use multiple monitors for the same log directory
my @oldfilenames;	# array containing all the filenames in the bookmark file before updating
my @oldpositions;	# array containing all the positions in the bookmark file before updating
my @oldsearchstr;	# array containing all the search/ignore strings in the bookmark file before updating

# if there is a bookmark file already...
if (-s $bookmarkfile) {
	# ...we'll just update the values in there and add any new ones
	my $i = 0;
	# get original bookmark values
	open (BOOKMARK, "<" . $bookmarkfile) || die ("Error: Could not open bookmark temp file for reading!");
	while ($line = <BOOKMARK>) {	# read bookmark file
		chomp ($line);
		my @splitline = split(/\?/, $line);	# split the bookmarked line (FILENAME?POS)
		# Make sure there is the proper number of values in the bookmark file (skip old/invalid lines)
		if (@splitline == 3) {
			push(@oldfilenames, $splitline[0]);
			push(@oldpositions, $splitline[1]);
			push(@oldsearchstr, $splitline[2]);
		}
		$i++;
	}
	close (BOOKMARK);
	
	# now lets update them with the latest positions
	my $numofnewfiles = @filenames;		# number of filenames that we used this time
	my $numofoldfiles = @oldfilenames;	# number of filenames that were in the bookmark originally
	my $updated = 0;
	for (my $i = 0; $i < $numofnewfiles; $i++) {
		$updated = 0;
		for (my $j = 0; ! $updated && $j < $numofoldfiles;$j++) {
			# get the last part (search+ignore strings)
			my $searchstr = $search_regex . $ignore_regex;
			$searchstr =~ s/\?//g;	# get rid of '?'
			if (($filenames[$i] eq $oldfilenames[$j]) && ($oldsearchstr[$j] eq $searchstr)) {
				# found the filename, so let's update the old bookmark with the new position
				$oldfilenames[$j] = $filenames[$i];
				$oldpositions[$j] = $endlinenums[$i];
				$oldsearchstr[$j] = $searchstr;
				
				$updated = 1;
			}
		}
		# if not updated (meaning it's a new file)...
		if ( ! $updated ) {
			# ...add the new file to the list
			push(@oldfilenames, $filenames[$i]);
			push(@oldpositions, $endlinenums[$i]);
			
			# get the last part (search+ignore strings)
			my $searchstr = $search_regex . $ignore_regex;
			$searchstr =~ s/\?//g;	# get rid of '?'
			push(@oldsearchstr, $searchstr);
		}
	}
}
# ...else if there is no bookmark file (new bookmark)
# we'll just create it fresh
else {
	my $numofnewfiles = @filenames;	# number of filenames that we used this time
	for (my $i = 0; $i < $numofnewfiles; $i++) {
		push(@oldfilenames, $filenames[$i]);
		push(@oldpositions, $endlinenums[$i]);
		
		# get the last part (search+ignore strings)
		my $searchstr = $search_regex . $ignore_regex;
		$searchstr =~ s/\?//g;	# get rid of '?'
		push(@oldsearchstr, $searchstr);
	}
}

# now lets save all the updated filenames and positions
#
# format of bookmark file:
# <filename>?<position>?<search+ignore>
my $numoffiles = @oldfilenames;
open (BOOKMARK, ">" . $bookmarkfile) || die("Error: Cannot create bookmark temp file for writing!\nBookmark file: " . $bookmarkfile . "\n");
for (my $i = 0; $i < $numoffiles; $i++) {
	my $logfile   = $oldfilenames[$i];
	my $linenum   = $oldpositions[$i];
	my $searchstr = $oldsearchstr[$i];
	print (BOOKMARK $logfile . '?' . $linenum . '?' . $searchstr . "\n");
}
close (BOOKMARK);


# if the bookmark file was not previously created, let's always create it, even when we're testing
if ((! -e $bookmarkfile) && ($debug_mode)) {
	print "Created bookmark file '$bookmarkfile'. Re-test the monitor to verify it's working now.\n";
}
if (! -e $bookmarkfile) {
	print "Error: Bookmark file does not exist! Please check permissions: Bookmark filename: '$bookmarkfile'";
}


# print out the number of occurrences for the monitor
print("total_count $total_count\n");
