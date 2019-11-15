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

use SWS::Source::CommonBase;

print "Testing SWS::Source::CommonBase\n";

my $args = {'site' => 'SWS/Test','config_filename' => 'main.cfg'};
my $config = new SWS::Source::Config($args);
print "Config " . $config->config('debug_filename') . "\n";

print "About to create CommonBase object\n";
$args = {'site' => 'SWS/Test'};
my $http = new SWS::Source::CommonBase($config,$args);

print "About to load template\n";
$args = {'test' => 'This is a test varaiable'};
my ($error_code, $template) = $http->load_template('test.html', $args);
print "ERROR CODE: $error_code\n" if ($error_code);
print "Got:$template\n";
						
print "Send to 'browser'\n";
$http->output_to_browser($template);

print "Test Done\n";
