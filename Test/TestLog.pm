#!/usr/bin/perl -w
use strict;

BEGIN
{
	my $project_path;
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		confess('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw();
	@EXPORT = qw();
}

use SWS::Source::Log;

print "Testing SWS::Source::Log\n";

my $debug9 = new SWS::Source::Log({	'log_type' 		=> LOG_TYPE_DEBUG,
												'log_filename' => 'Test/Logs/debug9.log',
												'log_level' 	=> 9
											});
my $debug5 = new SWS::Source::Log({	'log_type' 		=> LOG_TYPE_DEBUG,
												'log_filename' => 'Test/Logs/debug5.log',
												'log_level' 	=> 5 
											});
my $debug0 = new SWS::Source::Log({	'log_type' 		=> LOG_TYPE_DEBUG,
												'log_filename' => 'Test/Logs/debug0.log',
												'log_level' 	=> 0 
											});
my $event = new SWS::Source::Log({	'log_type' 		=> LOG_TYPE_EVENT,
												'log_filename' => 'Test/Logs/event.log'
											});
my $error = new SWS::Source::Log({	'log_type' 		=> LOG_TYPE_ERROR,
												'log_filename' => 'Test/Logs/error.log'
											});

print "Created log file successfully\n";

for(my $level = 9; $level >= 0; $level--)
{
	print "Sending level $level debug\n";
	$debug9->debug($level, "This is debug level $level");
	$debug5->debug($level, "This is debug level $level");
	$debug0->debug($level, "This is debug level $level");
}	
print "Sent debug messages, please check files\n";

$event->event('This event happened');
print "Sent event message, please check files\n";
											
$error->error(ERROR_SEVERITY_WARNING, 1, 'This is a warning');
$error->error(ERROR_SEVERITY_ERROR, 2, 'This is an error');
$error->error(ERROR_SEVERITY_FATAL, 3, 'This is a fatal error');
print "Sent error messages, please check files\n";

unless($debug9->event("This is an event to the debug log"))
{
	die('Expected error on sending event to debug log');
}

unless($debug9->error(ERROR_SEVERITY_WARNING, 4,"This is an error to the debug log"))
{
	die('Expected error on sending error to debug log');
}
print "Successfully failed debug calls to wrong type\n";

unless($event->debug(5, "This is a debug to the event log"))
{
	die('Expected error on sending debug to event log');
}

unless($event->error(ERROR_SEVERITY_ERROR, 5,"This is an error to the event log"))
{
	die('Expected error on sending error to event log');
}
print "Successfully failed event calls to wrong type\n";

unless($error->debug(5, "This is a debug to the error log"))
{
	die('Expected error on sending debug to error log');
}

unless($error->event("This is an event to the error log"))
{
	die('Expected error on sending event to error log');
}
print "Successfully failed error calls to wrong type\n";

print "Test Done\n";
