#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		ServerBase
#-----------------------------------------------------------------------------
# Description:
# 					This module is the base class for all servers, it provides 
# 					common functionality required by most servers.
# 					Servers may be listening on ports, others may have tasks to 
# 					perform periodically
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/10/28 23:37:11 $
# $Revision: 1.6 $
#-----------------------------------------------------------------------------
package SWS::Source::ServerBase;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);
use POSIX qw(:sys_wait_h);

my $project_path;
BEGIN
{
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		confess('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(SWS::Source::CommonBase);
	@EXPORT = qw();
}

use SWS::Source::CommonBase;
use SWS::Source::Error;

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
	my $config 		= $_[0];
	my $args 		= $_[1];

   die('No server') unless(exists($args->{'server'}));
	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new(@_);

   $self->{'server'} = $args->{'server'};
	
	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	run
#-----------------------------------------------------------------------------
# Description:
# 					Run the server
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub run
{
	my $self 	=	shift;

   # First off, we need our own database connection, as the one
   # created by our parent will disappear soon
   my $args;
   $args->{'site'} = $self->{'invoking_site'};
   $args->{'server'} = $self->{'server'};

   $self->{'database'} = new SWS::Source::Database($self->{'config'},$args);
   my $error_code = $self->{'database'}->connect(
         $self->config('database_host'),
         $self->config('database_port'),
         $self->config('database_name'),
         $self->config('database_username'),
         $self->config('database_password'),
         $self->config('database_driver')
      );

   
   $error_code = $self->prepolling();
   return $error_code if $error_code;

   # Create the booted file
   my $site = $self->{'invoking_site'} || die('No site');
   my $server = $self->{'server'} || die('No server');

   # While not timed out
   my $booted_file = $project_path . '/' . $site . '/Servers/.' . 
      $server . '_booted';
   my $fh;
   if (!open($fh, ">$booted_file"))
   {
      $self->error(ERROR_SEVERITY_FATAL, ERROR_IO_FILE_OPEN,
         'Could not create booted file');
      die('Could not create booted file');
   }
   print $fh 'success ' . time();
   close($fh);
   
   $error_code = $self->polling_loop();

   return $error_code;
}

#-----------------------------------------------------------------------------
# Function: 	shutdown_server
#-----------------------------------------------------------------------------
# Description:
# 					Stop the server by creating the shut down file
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
sub shutdown_server
{
	my $self 	=	shift;

   # Create the shutdown file
   my $site = $self->{'invoking_site'} || die('No site');
   my $server = $self->{'server'} || die('No server');

   my $booted_file = $project_path . '/' . $site . '/Servers/.' . 
      $server . '_shutdown';
   my $fh;
   if (!open($fh, ">$booted_file"))
   {
      $self->error(ERROR_SEVERITY_FATAL, ERROR_IO_FILE_OPEN,
         'Could not create booted file');
      die('Could not create booted file');
   }
   close($fh);
}

#-----------------------------------------------------------------------------
# Function: 	polling_loop
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub polling_loop
{
	my $self 	=	shift;

   my $shutdown  = 0;
   my $error_code;
   my $sleep_time = $self->config('poll_sleep_time');
   while(!$shutdown)
   {
      $error_code = $self->perform_events();
      if($error_code)
      {
         $self->error(ERROR_SEVERITY_WARNING, $error_code,
            'Perform events returned error');
      }
      # Update the working file
      # This will be implemented later, when a server to manage servers exists
      # ..............

      select(undef, undef, undef, $sleep_time);
      $shutdown = $self->check_for_shutdown();
   }

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	successful_boot
#-----------------------------------------------------------------------------
# Description:
# 					Checks the server we booted writes it's booted file
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Shutdown flag         OUT:0	0 to continue, 1 to shutdown
#-----------------------------------------------------------------------------
sub successful_boot
{
	my $self 	=	shift;
   my $pid     = $_[0] || die('No process ID');

   my $site = $self->{'invoking_site'} || die('No site');
   my $server = $self->{'server'} || die('No server');

   # While not timed out
   my $booted_file = $project_path . '/' . $site . '/Servers/.' . 
      $server . '_booted';
   my $timedout = 0;
   my $success = 0;
   my $timeout = $self->config('boot_timeout');
   my $sleep_time = $self->config('boot_sleep_time');
   my $started = [ gettimeofday() ];
   while(!$timedout && !$success)
   {
      # Try to read the booted file
      if(-f $booted_file)
      {
         $success = 1;
         unlink $booted_file;
      }
      
      if (waitpid($pid, WNOHANG) == $pid)
      {
         $self->error(ERROR_SEVERITY_FATAL, ERROR_RUNTIME_ERROR,
            'Child process died ' . $pid);
         return 0;
      }
      
      # If unsuccessful, wait
      if(!$success)
      {
         $timedout = (tv_interval($started) > $timeout);
         select(undef, undef, undef, $sleep_time) unless($timedout)
      }
   }
   # If timed out report failure
   if($timedout)
   {
      return 0;
   }
   # Else success
   return 1;
}

#-----------------------------------------------------------------------------
# Function: 	check_for_shutdown
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Shutdown flag         OUT:0	0 to continue, 1 to shutdown
#-----------------------------------------------------------------------------
sub check_for_shutdown
{
	my $self 	=	shift;

   my $shutdown_file = $project_path . '/' . $self->{'invoking_site'} . 
      '/Servers/.' . $self->{'server'} . '_shutdown';
   # Try to read the shutdown file
   # If successful remove, and report shutdown
   if(-f $shutdown_file)
   {
      unlink($shutdown_file);
      return 1;
   }

   return 0;
}

#-----------------------------------------------------------------------------
# Function: 	prepolling
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub prepolling
{
	my $self 	=	shift;

   $self->error(ERROR_SEVERITY_FATAL, ERROR_RUNTIME_ERROR,
         'Must override prepolling()');
   die('Must override prepolling()');

   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	perform_events
#-----------------------------------------------------------------------------
# Description:
# 					Performs the event, checks for shutdown, and sleeps
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub perform_events
{
	my $self 	=	shift;

   $self->error(ERROR_SEVERITY_FATAL, ERROR_RUNTIME_ERROR,
         'Must override perform_events()');
   die("Must override perform_events()");

   return ERROR_NONE;
}

1;
