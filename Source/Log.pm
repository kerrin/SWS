#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Log
#-----------------------------------------------------------------------------
# Description:
# 					Used to write information to file in a standardised way.
# 					Each line starts with a time stamp, and contains other useful
# 					data, followed by the text that was logged.
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/04 21:04:59 $
# $Revision: 1.11 $
#-----------------------------------------------------------------------------
package SWS::Source::Log;

use Exporter;
use FileHandle;
use Fcntl ':flock';
use Data::Dumper;

use strict;
BEGIN
{
	my $project_path;
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		die('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(SWS::Source::Base);
	@EXPORT = qw(
			  		LOG_TYPE_DEBUG LOG_TYPE_EVENT LOG_TYPE_ERROR
		 		);
}

use SWS::Source::Base;
use SWS::Source::Error;

use constant LOG_TYPE_NONE		=> 0;
use constant LOG_TYPE_DEBUG	=> 1;
use constant LOG_TYPE_EVENT	=> 2;
use constant LOG_TYPE_ERROR	=> 3;

#-----------------------------------------------------------------------------
# Function: 	new
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
#
#-----------------------------------------------------------------------------
sub new
{
	my $prototype 	= shift;
	my $args 		= $_[0];

	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new(@_);
	
	# Store the log type and filename for this log instance
	$self->{'class_type'} 		= $args->{'log_type'};
	$self->{'class_filename'}	= $args->{'log_filename'};
	if($args->{'log_type'} == LOG_TYPE_DEBUG)
	{
		# We are a debug log, so we also need to store the debug level
		$self->{'class_level'} 		= $args->{'log_level'};
      my $superclass = ref($self);
      my $eval;
      if($self->{'class_level'} == 0)
      {
         $eval = "*$superclass"."::debug = sub {};";
      } else {
         $eval = "*$superclass"."::debug = sub { shift->actual_debug(\@_); };";
      }
      no warnings;
      eval $eval;
      use warnings;
	}
	
	my $handle = $self->get_file_lock($self->{'class_filename'});
	unless($handle)
	{
		die("Cannot acquire a file lock `$self->{'class_filename'}'");
	}

	my $log;
	unless (open($log, '>>' . $self->{'class_filename'}))
	{
		die("Cannot open `$self->{'class_filename'}': $!");
	}
	close $log;
	
	$self->release_file_lock($handle);

	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function:		get_file_lock
#-----------------------------------------------------------------------------
# Description:
#					Get a lock on a file, so we know we are the only one
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Filename					IN:0	The filename to get a lock on
# Timeout					IN:1	The timeout to get the lock
#-----------------------------------------------------------------------------
sub get_file_lock
{
   my $self = shift;
   my $file = $_[0] || die("get_file_lock() needs file");
   my $timeout = $_[1];
   
	$timeout = 2 unless(defined($timeout));

   my $lock;
   unless(open($lock, ">>$file"))
	{
		return undef;
	}

   if($timeout)
   {
		# We only want to try for the lock for so long
      my $now = time();
      while (!flock($lock, LOCK_EX | LOCK_NB))
      {
         select(undef, undef, undef, 0.01);
         if(time() - $now > $timeout)
         {
            return undef;
         }
      }
   } else
   {
		# Try until we get the lock
      unless(flock($lock, LOCK_EX | LOCK_NB))
      {
         return undef;
      }
   }

   return $lock;
}

#-----------------------------------------------------------------------------
# Function:		release_file_lock
#-----------------------------------------------------------------------------
# Description:
#					Free up the lock we have on the file, as we are done with it
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Handle						IN:0	The handle to the locked file
#-----------------------------------------------------------------------------
sub release_file_lock
{
   my $self = shift;
   my $handle = $_[0] || die("release_file_lock function needs handle");

   die("Cannot release non-handle") if(ref($handle) ne 'GLOB');
   close($handle);
}

#-----------------------------------------------------------------------------
# Function: 	actual_debug
#-----------------------------------------------------------------------------
# Description:
#              Output to debug log
#              This is the function we alias the called debug function to
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Level						IN:0    The debug level
# Text						IN:1    The text to output if debug level allows
#-----------------------------------------------------------------------------
sub actual_debug
{
	my $self 	=	shift;
	my $level	= $_[0];
	my $text		= $_[1];

	# Check for wrong log type
	if(!exists($self->{'class_type'}))
	{
		return ERROR_UNINITIALISED;
	} elsif($self->{'class_type'} != LOG_TYPE_DEBUG) {
		return ERROR_INVALID_FUNCTION_CALL;
	}

	# Check the debug level of this message is low enough to get in the log
	if($level > $self->{'class_level'})
	{
		# Level too high
		return ERROR_NONE;
	}

	my $handle = $self->get_file_lock($self->{'class_filename'});
	unless($handle)
	{
		die("Cannot acquire a file lock `$self->{'class_filename'}'");
	}

	my $log;
	unless (open($log, '>>' . $self->{'class_filename'}))
	{
		$self->release_file_lock($handle);
		die("Cannot open `$self->{'class_filename'}': $!");
	}

	# prepare and output the line to the log
	my $log_line = scalar localtime() . ": " . "[$$]: " . $text. "\n";
	print $log $log_line;
	
	close $log;
	
	$self->release_file_lock($handle);
	return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	debug_dumper
#-----------------------------------------------------------------------------
# Description:
#              Output to debug log a dump of the structure
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Level						IN:0    The debug level
# Structure					IN:1    The structure to dump to log
#-----------------------------------------------------------------------------
sub debug_dumper
{
	my $self 	=	shift;
	my $level	= $_[0];
	my $var		= $_[1];

	# Check for wrong log type
	if(!exists($self->{'class_type'}))
	{
		return ERROR_UNINITIALISED;
	} elsif($self->{'class_type'} != LOG_TYPE_DEBUG) {
		return ERROR_INVALID_FUNCTION_CALL;
	}

	# Check the debug level of this message is low enough to get in the log
	if($level > $self->{'class_level'})
	{
		# Level too high
		return ERROR_NONE;
	}

	my $handle = $self->get_file_lock($self->{'class_filename'});
	unless($handle)
	{
		die("Cannot acquire a file lock `$self->{'class_filename'}'");
	}

	my $log;
	unless (open($log, '>>' . $self->{'class_filename'}))
	{
		$self->release_file_lock($handle);
		die("Cannot open `$self->{'class_filename'}': $!");
	}

   my $text = "DUMPER:";
   $text .= Data::Dumper->Dump([$var]);  
   
	# prepare and output the line to the log
	my $log_line = scalar localtime() . ": " . "[$$]: " . $text. "\n";
	print $log $log_line;
	
	close $log;
	
	$self->release_file_lock($handle);
	return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	event
#-----------------------------------------------------------------------------
# Description:
# 					Log to event log
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Text						IN:0	The event text to log
#-----------------------------------------------------------------------------
sub event
{
	my $self 		=	shift;
	my $text			= $_[0];

	# Check for wrong log type
	if(!exists($self->{'class_type'}))
	{
		return ERROR_UNINITIALISED;
	} elsif($self->{'class_type'} != LOG_TYPE_EVENT) {
		return ERROR_INVALID_FUNCTION_CALL;
	}

	my $handle = $self->get_file_lock($self->{'class_filename'});
	unless($handle)
	{
		die("Cannot acquire a file lock `$self->{'class_filename'}'");
	}

	my $log;
	unless (open($log, '>>' . $self->{'class_filename'}))
	{
		$self->release_file_lock($handle);
		die("Cannot open `$self->{'class_filename'}': $!");
	}
	
	# prepare and output the line to the log
	my $log_line = scalar localtime() . ": " . "[$$]: " . $text. "\n";
	print $log $log_line;
	
	close $log;
	
	$self->release_file_lock($handle);

	return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	error
#-----------------------------------------------------------------------------
# Description:
# 					Log to error log
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Severity					IN:0	The error severity (Warning, Error, Fatal)
# Error Code				IN:1	The error code
# Text						IN:2	The error text to log
#-----------------------------------------------------------------------------
sub error
{
	my $self 		=	shift;
	my $severity	= $_[0];
	my $error_code	= $_[1];
	my $text			= $_[2];

	# Check for wrong log type
	if(!exists($self->{'class_type'}))
	{
		return ERROR_UNINITIALISED;
	} elsif($self->{'class_type'} != LOG_TYPE_ERROR) {
		return ERROR_INVALID_FUNCTION_CALL;
	}

	my $handle = $self->get_file_lock($self->{'class_filename'});
	unless($handle)
	{
		die("Cannot acquire a file lock `$self->{'class_filename'}'");
	}

	my $log;
	unless (open($log, '>>' . $self->{'class_filename'}))
	{
		$self->release_file_lock($handle);
		die("Cannot open `$self->{'class_filename'}': $!");
	}
	my $severity_text;
	if($severity == ERROR_SEVERITY_WARNING)
	{
		$severity_text = 'WARN';
	} elsif($severity == ERROR_SEVERITY_ERROR) {
		$severity_text = 'ERROR';
	} elsif($severity == ERROR_SEVERITY_FATAL) {
		$severity_text = 'FATAL';
	} else {
		# Don't know the error type so free the lock and error
		$self->release_file_lock($handle);
		return ERROR_INVALID_PARAMETER;
	}

	# prepare and output the line to the log
	my $log_line = scalar localtime() . 
		": [$$]: $severity_text,EC$error_code : $text\n";
	print $log $log_line;
	
	close $log;
	
	$self->release_file_lock($handle);

	return ERROR_NONE;
}

1;
