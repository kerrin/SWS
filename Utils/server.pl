#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		server.pl
#-----------------------------------------------------------------------------
# Description:
# 					The script that starts up servers
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/03/13 14:48:24 $
# $Revision: 1.2 $
#-----------------------------------------------------------------------------
use strict;

my $project_path;
my $site;
BEGIN
{
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		die('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	unless($site = $ENV{'SITE'})
	{
		die('Set enviroment variable SITE to the SITE NAME');
	}
}

use SWS::Source::Log;
use SWS::Source::Config;
use SWS::Source::Error;
use SWS::Source::CommonBase;
use SWS::Source::Database;

unless(@ARGV)
{
   print "Usage: server.pl <Server Name> [shutdown]\n";
   print "If shutdown is supplied the server will be asked to shut down\n";
   print "Otherwise a new server will be started\n";
   print "For each start up, a new server will be started\n";
   print "For each shut down a single server will be stopped if any are running\n";
   exit(0);
}
my $server;
unless($server = $ARGV[0])
{
   die('No server to start');
}

my $args = {'site' => $site};
my $config = new SWS::Source::Config($args);

my $debug_log;
my $debug_level;
if($config->config('debug') > 0)
{
   $debug_level = $config->config('debug_level');
} else {
   $debug_level = 0;
}
$debug_log = new SWS::Source::Log({
			        	'log_type'     => LOG_TYPE_DEBUG,
						'log_filename' => $config->config('debug_filename'),
						'log_level'    => $debug_level
					});
my $error_log = new SWS::Source::Log({
		            'log_type'     => LOG_TYPE_ERROR,
						'log_filename' => $config->config('error_filename')
					});

run();

#-----------------------------------------------------------------------------
# Function: 	run
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
#
#-----------------------------------------------------------------------------
sub run
{
   my $object;
   $args->{'site'} = $site;
   $args->{'server'} = $server;
   $debug_log->debug(8, "Site: $site");
   undef $object if(defined($object));
   my $filename = "$project_path/$site/Servers/$server" . '.pm';
   my $server_name = $site . '::Servers::' . $server;
   if(-f $filename)
   {
      # Read in the server config as well
      my $server_config_filename = 
         $project_path . '/' . $site . '/Config/' . $server . '.cfg';
      $config->read_config($server_config_filename);
   } else {
      # Read in the server config as well
      my $server_config_filename = $project_path . '/SWS/Config/' .
         $server . '.cfg';
      $config->read_config($server_config_filename);
      $filename = "$project_path/SWS/Servers/$server" . '.pm'; 
      $server_name = 'SWS::Servers::' . $server;
      unless(-f $filename)
      {
         $object = SWS::Source::CommonBase->new($config, $args);
         $object->error(ERROR_SEVERITY_FATAL, ERROR_INVALID_ACTION,
            "Server $server invalid");
         die(ERROR_INVALID_ACTION . ":Server $server invalid");
      }
   }
   eval "use $server_name";
   if ($@)
   {
      $error_log->error(ERROR_SEVERITY_FATAL,ERROR_SYSTEM_ERROR,
         "Could not use server $server_name");
      die("Could not use server $server_name");
   }
   # Clear the boot and shutdown files, if they exist
   my $booted_file = $project_path . '/' . $site . '/Servers/.' . 
      $server . '_booted';
   unlink($booted_file);
   my $shutdown_file = $project_path . '/' . $site . '/Servers/.' . 
      $server . '_shutdown';
   unlink($shutdown_file);
   
   $object = $server_name->new($config, $args);
   if(@ARGV > 1 && $ARGV[1] eq 'shutdown')
   {
      $object->shutdown_server();
   } else {
      # Boot the server

      # Split our process
      my $pid = fork();
      if (!defined($pid))
      {
         die('Could not fork process');
      }
      if($pid)
      {
         # Parent
         # Check our server was booted
         unless($object->successful_boot($pid))
         {
            kill('KILL', $pid);
            die("Our server failed to boot");
         }
         $object->event("Server $server started successfully");
         return;
      } else {
         # Child
         $object->debug(6, "Started server $server_name");
         $object->{'no_browser_output'} = 1;
         my $error_code = $object->run();
         $object->debug(7, "Ended server $server_name");
      }
   }
}


