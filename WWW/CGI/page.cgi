#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		page.cgi
#-----------------------------------------------------------------------------
# Description:
# 					The script the is run by every page, this passes the requests
# 					on to the required module
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/27 14:34:40 $
# $Revision: 1.13 $
#-----------------------------------------------------------------------------
use strict;

use CGI;

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
	my $cgi = new CGI();

	my $action = $cgi->param('action');
	unless($action)
	{
		$action = $config->config('default_action');
	}

   my $output_to_browser = 0;
   my $object;
   my $cookies = {};
   eval{
      local $SIG{__DIE__};
      while($action)
      {
         $args->{'cgi'} ||= $cgi;
         $args->{'site'} ||= $site;
         $debug_log->debug(8, "Site: $site");
         $debug_log->debug(8, "Action: $action");
         undef $object if(defined($object));
         my $filename = "$project_path/$site/Source/$action" . '.pm';
         my $module_name = $site . '::Source::' . $action;
         unless(-f $filename)
         {
            $filename = "$project_path/SWS/Source/$action" . '.pm'; 
            $module_name = 'SWS::Source::' . $action;
            unless(-f $filename)
            {
               $object = SWS::Source::CommonBase->new($config, $args);
               $object->{'output_to_browser'} ||= $output_to_browser;
               $object->throw_error(ERROR_INVALID_ACTION,
                  "Action $action invalid");
            }
         }
         eval "use $module_name";
         if ($@)
         {
            $error_log->error(ERROR_SEVERITY_FATAL,ERROR_SYSTEM_ERROR,
               "Could not use module $module_name");
            return ERROR_SYSTEM_ERROR;
         }
         $object = $module_name->new($config, $args);
         $args = {};
         $object->{'cookies'} ||= $cookies;
         $object->{'output_to_browser'} ||= $output_to_browser;
         $object->debug(6, "Started module $module_name");
         my $old_action = $action;
         my $cgi_vars;
         ($action, $cgi_vars) = $object->run();
         $object->debug(7,'passed back cgi_vars');
         $object->debug_dumper(7,$cgi_vars);
         $args->{'cgi_vars'} = $cgi_vars if(defined($cgi_vars));
         $args->{'state'} = $object->{'state'};
         $object->debug(7,'object state');
         $object->debug_dumper(7,$object->{'state'});
         $object->debug(7, "Ended module $module_name");
         $cookies ||= $object->{'cookies'};
         $output_to_browser ||= $object->{'output_to_browser'};
         $object->debug(8, "Output to browser") if($output_to_browser);
      }
   };
   if(defined($object))
   {
      $output_to_browser ||= $object->{'output_to_browser'};
   }
   if($@)
   {
      unless($output_to_browser)
      {
         eval
         {
            local $SIG{__DIE__};
            my $error = SWS::Source::CommonBase->new($config, $args);
            $output_to_browser ||= $error->{'output_to_browser'};
            $error->throw_error(ERROR_UNCAUGHT_ERROR, 'Script died');
         };
      }
   }
   unless($output_to_browser)
   {
      my $error = SWS::Source::CommonBase->new($config, $args);
      $error->throw_error(ERROR_NO_OUTPUT, 'No Output');
   }
}


