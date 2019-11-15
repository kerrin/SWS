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

use SWS::Source::Config;

print "Testing SWS::Source::Config\n";

my $args = {'site' => 'Test','config_filename' => 'test.cfg'};
my $config = new SWS::Source::Config($args);

print "Basic=" . $config->config('Basic') . "\n";
print "Numeric=" . $config->config('Numeric') . "\n";
print "Complex=" . $config->config('Complex') . "\n";
print "ContainsEqual=" . $config->config('ContainsEqual') . "\n";
print "ContainVariableReplacement=" . $config->config('ContainVariableReplacement') . "\n";
print "Empty=>" . $config->config('Empty') . "<\n";
eval
{
	print "NotExist=" . $config->config('NotExist') . "\n";
};
unless($@)
{
	die('Expected error on getting config item NotExist, but did not');
}

print "Test Done\n";
