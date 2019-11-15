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

use SWS::Source::Database;

print "Testing SWS::Source::Database\n";

my $args = {'site' => 'Test','config_filename' => 'main.cfg'};
my $config = new SWS::Source::Config($args);
print "Config " . $config->config('debug_filename') . "\n";

print "About to create Database object\n";
$args = {'site' => 'Test'};
my $database = new SWS::Source::Database($config,$args);

print "About to connect Database object\n";
my $error_code = $database->connect(	
		  					$config->config('database_host'),
							$config->config('database_port'),
							$config->config('database_name'),
							$config->config('database_username'),
							$config->config('database_password'),
							$config->config('database_driver')
				 		);
print "ERROR CODE: $error_code\n" if ($error_code);
print "Connected\n";
						
print "Select\n";
my $results;
($error_code, $results) = $database->db_select('check_user',
											{'member' => $config->config('member_table')},
											'guest','Gu35t');
print "ERROR CODE: $error_code\n" if ($error_code);
print "Selected\n";
if($results)
{
	foreach my $row (@{$results})
	{
		print 'Row: ' . $row->{'ID'} . "\n";
	}
} else {
	print "ERROR: No results\n";
}

print "INSERT\n";
my $new_ID;
my $details =
	{
		'test_number'	=> 123,
		'test_string'	=> 'This is a string',
		'#test_date'	=> 'NOW()'
	};
($error_code, $new_ID) = $database->db_insert('TEST', $details);
print "ERROR CODE: $error_code\n" if ($error_code);
print "INSERT Done, got ID ($new_ID)\n";

print "Select\n";
($error_code, $results) = $database->db_select('check_test',
											{'test' => $config->config('test_table')},
											$new_ID);
print "ERROR CODE: $error_code\n" if ($error_code);
print "Selected\n";
if($results)
{
	if(@{$results} == 1)
	{
		print 'ID: ' . $results->[0]->{'ID'} . "\n";
		print 'test_number: ' . $results->[0]->{'test_number'} . "\n";
		print 'test_string: ' . $results->[0]->{'test_string'} . "\n";
		print 'test_date: ' . $results->[0]->{'test_date'} . "\n";
		unless($results->[0]->{'ID'} == $new_ID)
		{
			print "Error ID mismatch, expected $new_ID, got " . $results->[0]->{'ID'} . "\n";
		}
		unless($results->[0]->{'test_number'} == 123)
		{
			print "Error test_number mismatch, expected 123, got " . $results->[0]->{'test_number'} . "\n";
		}
		unless($results->[0]->{'test_string'} eq 'This is a string')
		{
			print "Error  mismatch, expected 'This is a string', got " . $results->[0]->{'test_string'} . "\n";
		}
	} else {
		print "ERROR: Wrong number of results " . @{$results} . "\n";
	}
} else {
	print "ERROR: No results\n";
}

print "UPDATE\n";
$details =
	{
		'test_number'	=> 321,
		'test_string'	=> 'This is a modified string',
		'#test_date'	=> 'NOW()'
	};
my $condition = 
	{
		'ID'	=>	$new_ID
	};
$error_code = $database->db_update('TEST', $details, $condition);
print "ERROR CODE: $error_code\n" if ($error_code);
print "update Done\n";

print "Select\n";
($error_code, $results) = $database->db_select('check_test',
											{'test' => $config->config('test_table')},
											$new_ID);
print "ERROR CODE: $error_code\n" if ($error_code);
print "Selected\n";
if($results)
{
	if(@{$results} == 1)
	{
		print 'ID: ' . $results->[0]->{'ID'} . "\n";
		print 'test_number: ' . $results->[0]->{'test_number'} . "\n";
		print 'test_string: ' . $results->[0]->{'test_string'} . "\n";
		print 'test_date: ' . $results->[0]->{'test_date'} . "\n";
		unless($results->[0]->{'ID'} == $new_ID)
		{
			print "Error ID mismatch, expected $new_ID, got " . $results->[0]->{'ID'} . "\n";
		}
		unless($results->[0]->{'test_number'} == 321)
		{
			print "Error test_number mismatch, expected 321, got " . $results->[0]->{'test_number'} . "\n";
		}
		unless($results->[0]->{'test_string'} eq 'This is a modified string')
		{
			print "Error  mismatch, expected 'This is a modified string', got " . $results->[0]->{'test_string'} . "\n";
		}
	} else {
		print "ERROR: Wrong number of results " . @{$results} . "\n";
	}
} else {
	print "ERROR: No results\n";
}

print "DELETE\n";
$condition = 
	{
		'ID'	=>	$new_ID
	};
$error_code = $database->db_delete('TEST', $condition);
print "ERROR CODE: $error_code\n" if ($error_code);
print "Delete Done\n";

print "Select\n";
($error_code, $results) = $database->db_select('check_test',
											{'test' => $config->config('test_table')},
											$new_ID);
print "ERROR CODE: $error_code\n" if ($error_code);
print "Selected\n";
if($results)
{
	print "ERROR: Wrong number of results " . @{$results} . "\n";
} else {
	print "No results is correct\n";
}

print "About to disconnect\n";
$error_code = $database->disconnect();
print "ERROR CODE: $error_code\n" if ($error_code);
print "Disconnected\n";

print "Test Done\n";
