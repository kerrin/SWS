#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Database
#-----------------------------------------------------------------------------
# Description:
# 					The database module will provide an easy to use and abstracted
# 					database connection.
# 					If we wish to change the underlying database at a later date, 
# 					all we would need to do is re-write this module for the new 
# 					database, and all sites would then be able to use the new 
# 					database.
# 					The database commands are NOT audited, as the information 
# 					would not be useful enough for the speed loss that having 
# 					auditing would produce.
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/08/22 14:02:10 $
# $Revision: 1.23 $
#-----------------------------------------------------------------------------
package SWS::Source::Database;
use strict;

use DBI;

my $project_path;
BEGIN
{
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		die('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(SWS::Source::Base);
	@EXPORT = qw();
}

use SWS::Source::Base;
use SWS::Source::Config;
use SWS::Source::Log;
use SWS::Source::Error;

our $queries;
our $db_handle;
our $config;
our $debug_log;
our $error_log;

#-----------------------------------------------------------------------------
# Function: 	new
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Object						OUT:0	The database object
# Config					 	IN:0	The configuration object
# Args					 	IN:1	The remaining arguments
#-----------------------------------------------------------------------------
sub new
{
	my $prototype = shift;
	my $configuration = $_[0] || die('No Config');
	my $args 			= $_[1];

	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new();

	if(exists($args->{'site'}) && defined($args->{'site'}))
	{
		$self->{'invoking_site'} = $args->{'site'};
	} else {
		die('No site invoked us!');
	}
	
	$config = $configuration;
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
	$error_log = new SWS::Source::Log({
			            'log_type'     => LOG_TYPE_ERROR,
							'log_filename' => $config->config('error_filename')
						});

	my $error_code = $self->read_query_files();
	die('Read Query File Error:' . $error_code) if($error_code);
						
	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	read_query_files
#-----------------------------------------------------------------------------
# Description:
# 					Reads in the query file, where each query has a unique handle
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub read_query_files
{
	my $self 			= shift;

	my $site = $self->{'invoking_site'};
	# Make sure we clear any first, incase this isn't the first time
	$queries->{$site} = {};

	# First read the SWS queries
	my $path_and_filename = "$project_path/SWS/Config/queries.list";
	my $fh;
	unless(open($fh, $path_and_filename))
	{
		$error_log->error(ERROR_SEVERITY_FATAL, ERROR_IO_FILE_OPEN, 
			"Failed to open query file $path_and_filename");
		return ERROR_IO_FILE_OPEN;
	}
	my ($error_code, $queries_found) = 
		$self->parse_query_file($fh, $queries->{$site}, $path_and_filename);
	close($fh);
	return $error_code if($error_code);
	$debug_log->debug(6, "SWS Query file read");
	
	# Now read the site queries
	$path_and_filename = "$project_path/$site/Config/queries.list";
	unless(open($fh, $path_and_filename))
	{
		$error_log->error(ERROR_SEVERITY_FATAL, ERROR_IO_FILE_OPEN, 
			"Failed to open query file $path_and_filename");
		return ERROR_IO_FILE_OPEN;
	}
	($error_code, $queries_found) = 
		$self->parse_query_file($fh, $queries->{$site}, $path_and_filename);
	close($fh);
	return $error_code if($error_code);
	
	$debug_log->debug(6, "Site Query file read");
	
	return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	parse_query_file
#-----------------------------------------------------------------------------
# Description:
# 					Parses the query file, as it is read from disk
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Queries Found			OUT:1	The number of queries read in
# file handle				IN:0	The file handle of the query file to read
# Query Hash				IN:1	The hash to store the queries in
# Filename					IN:2	The filename to report in error message
#-----------------------------------------------------------------------------
sub parse_query_file
{
	my $self 		= shift;
	my $fh			= $_[0];
	my $hash			= $_[1];
	my $filename	= $_[2];

	$debug_log->debug(9, "Parsing, $filename");

	my $line_num = 0;
	my $queries_found = 0;
	my $in_query = 0;
	my $query_value = '';
	my $handle = '';
	while (<$fh>)
	{
		my $line = $_;
		$line_num++;
		# Clean up the line
		chomp $line;
		$line =~ s/^ //g; 
		$debug_log->debug(9, "Parsing line '$line'");

		if($line =~ /^#/ || $line =~ /^$/)
		{
			# This line is either a comment, or blank line, so ignore
			next;
		}
		if($in_query)
		{
			# We are in the middle of a query
			if($line =~ /^#/ || $line =~ /^$/)
			{
				# This line is either a comment, or blank line, so ignore
				next;
			}
			if ($line =~ /^\[END\]$/i)
			{
				$in_query = 0;
				if($query_value eq '')
				{
					$error_log->error(ERROR_SEVERITY_FATAL,ERROR_IO_PARSE, 
						"Warning: Handle $handle has empty value on line $line_num");
				}
				$hash->{$handle} = $query_value;
				$debug_log->debug(9, "Adding query [$handle]=>$query_value");

				$queries_found++;
				$query_value = '';
			} else {
				$query_value .= $line;
			}
		} else {
			# We are looking for a handle
			if ($line =~ /^\[([\w_]+?)\]$/)
			{
				# This is a handle line [handle_name]
				$handle = $1;
				if(exists($hash->{$handle}))
				{
					$error_log->error(ERROR_SEVERITY_FATAL, ERROR_IO_PARSE, 
						"Handle $handle, found twice. " .
						"Second occurance on line $line_num");
					return (ERROR_IO_PARSE, $queries_found);
				}
			} else {
				$error_log->error(ERROR_SEVERITY_FATAL, ERROR_IO_PARSE, 
					"Error parsing query file $filename," .
					" on line $line_num, expected handle, none found");
				return (ERROR_IO_PARSE, $queries_found);
			}
			$query_value = '';
			$in_query = 1;
		}
	}
	if($in_query)
	{
		$error_log->error(ERROR_SEVERITY_FATAL, ERROR_IO_PARSE, 
			"Error parsing query file $filename," . 
			" EOF found before end of query");
		return (ERROR_IO_PARSE, $queries_found);
	}
	
	$debug_log->debug(9, "Queries Parsed, $queries_found found");
	return (ERROR_NONE, $queries_found);
}

#-----------------------------------------------------------------------------
# Function: 	connect
#-----------------------------------------------------------------------------
# Description:
# 					Opens a database connection
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Host					 	IN:0	The host name to connect to
# Port						IN:1	The port to connect on
# Database					IN:2	The database name
# Username					IN:3	The username to connect as
# Password					IN:4	The password to connect with
# driver						IN:5	The database driver to use. i.e. MySQL
#-----------------------------------------------------------------------------
sub connect
{
	my $self 			= shift;
	my $host 			= $_[0] || $config->config('database_host');
	my $port 			= $_[1] || $config->config('database_port');
	my $database 		= $_[2] || $config->config('database_name');
	my $username 		= $_[3] || $config->config('database_username');
	my $password 		= $_[4] || $config->config('database_password');
	my $driver			= $_[5] || $config->config('database_driver');

	if(defined($db_handle))
	{
		my $error = $self->disconnect();
		return $error if($error);
	}
	
	my $attributes =
	{
		'RaiseError'   => 0,
		'PrintError'   => 0
	};
	$db_handle = DBI->connect(
			  				"DBI:$driver:database=$database;host=$host;port=$port",
							$username, $password, $attributes);

	unless($db_handle)
	{
		my $error = DBI->errstr();
		$error_log->error(ERROR_SEVERITY_FATAL, ERROR_DB_CONNECT, 
			'Failed to open Database connection:' . $error); 
		return ERROR_DB_CONNECT;
	}

	$debug_log->debug(6, "DB Connection Made to $database\@$host");
	return;
}

#-----------------------------------------------------------------------------
# Function: 	disconnect
#-----------------------------------------------------------------------------
# Description:
# 					Opens a database connection
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub disconnect
{
	my $self 			= shift;

	if(defined($db_handle))
	{
		$db_handle->disconnect();
	}
	undef($db_handle);
	
	$debug_log->debug(6, "DB Connection closed");
	return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	db_select
#-----------------------------------------------------------------------------
# Description:
# 					Retrieve rows from the database.
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# Results					OUT:1	The result rows, as an array reference of hashes.
# Query Handle				IN:0	The query name, used to look up the statement
# Variables					IN:1	The variable replacement value
# Values						IN:2	The values to replace the ? in the query
#-----------------------------------------------------------------------------
sub db_select
{
	my $self 		= shift;
	my $handle		= shift;
	my $variables	= shift;
	my @values		= @_;

	$debug_log->debug(8, "Selecting with handle $handle");
	my $site = $self->{'invoking_site'};
	unless(exists($queries->{$site}->{$handle}))
	{
		$error_log->error(ERROR_SEVERITY_FATAL, ERROR_DB_INVALID_QUERY, 
			"Cannot find query for handle $handle");
		return ERROR_DB_INVALID_QUERY;
	}
	my $query = $queries->{$site}->{$handle};

	while($query =~ /#([\w_]+)/)
	{
		# Found a variable, so replace it
		my $replace = $1;
		$replace =~ s/#//;
		if(exists($variables->{$1}))
		{
			# We have the variable defined as a key already, so replace the
			# variable with its value
			my $replace_with = $variables->{$1};
			$query =~ s/#$replace/$replace_with/;
		} else {
			$error_log->error(ERROR_SEVERITY_FATAL,ERROR_MISSING_PARAMETER,
				"Variable replace failed on key $replace");
			return ERROR_MISSING_PARAMETER;
		}
	}

	$debug_log->debug(8, "Executing query: $query");
	$debug_log->debug(9, 'Parameters: ' . join (',',@values));

	my ($error_code, $query_handle) = $self->run_query($query, $handle, @values);
	return $error_code if($error_code);

	# Return the results as an array of hashes
	my $hash_result = [];
	while(my $row = $query_handle->fetchrow_hashref())
	{
		# Add the hash row to our results
		push @{$hash_result}, $row;
	}
   $debug_log->debug(8, 'Query returned ' . @{$hash_result} . ' rows');
	undef($hash_result) unless(@{$hash_result});
	
	return (ERROR_NONE, $hash_result);
}

#-----------------------------------------------------------------------------
# Function: 	db_insert
#-----------------------------------------------------------------------------
# Description:
# 					Used to insert data into the database. Requires all fields that
# 					are NOT NULL and with out a default to be present, except the 
# 					ID, which is generated from a separate table automatically. 
# 					All tables (except the SEQUENCE table have Ids)
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# ID							OUT:1	The ID of the newly inserted row
# Table Name				IN:0	The name of the table to insert into
# Insert hash				IN:1	A hash detailing the field names, and values
#-----------------------------------------------------------------------------
sub db_insert
{
	my $self 	= shift;
	my $table	= $_[0];
	my $details	= $_[1];

	my ($error_code, $new_ID);
	my $query = "INSERT INTO $table (ID";
	my $query_values .= '?';
	my @values;
	if(exists($details->{'ID'}))
	{
		# The ID was passed in, so use it, and remove it
		# Warning: If the ID is above the current max in the table, it will
		# cause problems later, the programmer is trusted to know what they 
		# are doing if they use this feature.
		# If the ID was used already, it will just error
		$new_ID = $details->{'ID'};
		delete $details->{'ID'};
	} else {
		($error_code, $new_ID) = $self->get_next_ID_for_table($table);
		return $error_code if($error_code);
	}
	push @values, $new_ID;

	foreach my $key (keys %{$details})
	{
		if($key =~ s/^#//)
		{
			# This keys' value is to be evaluated instead of inserted as is
			# e.g. 'NOW()' or 'field + 1'
			if(exists($details->{$key}))
			{
				# The key name without the # exists already
				$error_log->error(ERROR_SEVERITY_FATAL,ERROR_INVALID_PARAMETER, 
					"Evaluated key $key clashes with normal key");
				return ERROR_INVALID_PARAMETER;
			}
			# set the value, without quoting, so my sql evaluates it
			$query_values .= ',' . $details->{'#' . $key};
		} else {
			# Normal key, so just insert a value holder
			push @values, $details->{$key};
			$query_values .= ',?';
		}
		# Add the field name to the query
		$query .= ',' . $key;
	}
	# Finish our query by inserting the value list
	$query .= ') VALUES (' . $query_values . ')';

	$debug_log->debug(8, "Executing query: $query");
	$debug_log->debug(9, 'Parameters: ' . join (',',@values));

	# Ok, let run our query
	($error_code,undef) = $self->run_query($query, 'INSERT', @values);
	
	$debug_log->debug(9, "Error Code: $error_code") if($error_code);
	return ($error_code,$new_ID);
}

#-----------------------------------------------------------------------------
# Function: 	db_update
#-----------------------------------------------------------------------------
# Description:
# 					Updates a row in the database. 
# 					Does not require all fields in table to be present.
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# Table Name				IN:0	The name of the table to insert into
# Update Hash				IN:1	A hash detailing the field names, and values
# Condition Hash			IN:2	The condition fields and values
#-----------------------------------------------------------------------------
sub db_update
{
	my $self 		= shift;
	my $table		= $_[0];
	my $details		= $_[1];
	my $conditions	= $_[2];

	my $query = "UPDATE $table set";

	my $comma = ''; # The first value has no preceeding comma
	foreach my $key (keys %{$details})
	{
		my $quote = "'";
		if($key =~ s/^#//)
		{
			# This keys' value is to be evaluated instead of inserted as is
			# e.g. 'NOW()' or 'field + 1'
			if(exists($details->{$key}))
			{
				# The key name without the # exists already
				$error_log->error(ERROR_SEVERITY_FATAL,ERROR_INVALID_PARAMETER, 
					"Evaluated key $key clashes with normal key");
				return ERROR_INVALID_PARAMETER;
			}
			# store the value in it's correct hash name and stop it
			# from being quoted later by clearing the quote variable
			$details->{$key} = $details->{'#' . $key};
			$quote = '';
      }
		$query .= "$comma $key = $quote" . $details->{$key} . "$quote";
		$comma = ','; # The next value must be preceeded by a comma
	}
	$query .= ' WHERE ';

	my $and = '';
	foreach my $key (keys %{$conditions})
	{
		my $quote = "'";
      my $compare = '=';
		if($key =~ s/^(#{0,1})\^/$1/)
      {
         $compare = '!=';
         $conditions->{$1 . $key} = $conditions->{$1 . '^' . $key};
      }
		if($key =~ s/^(#{0,1})\</$1/)
      {
         $compare = '<';
         $conditions->{$1 . $key} = $conditions->{$1 . '<' . $key};
      }
		if($key =~ s/^(#{0,1})\>/$1/)
      {
         $compare = '>';
         $conditions->{$1 . $key} = $conditions->{$1 . '>' . $key};
      }
		if($key =~ s/^#//)
		{
			# This keys' value is to be evaluated instead of inserted as is
			# e.g. 'NOW()' or 'field + 1'
			if(exists($conditions->{$key}))
			{
				# The key name without the # exists already
				$error_log->error(ERROR_SEVERITY_FATAL,ERROR_INVALID_PARAMETER, 
					"Evaluated key $key clashes with normal key");
				return ERROR_INVALID_PARAMETER;
			}
			# store the value in it's correct hash name and stop it
			# from being quoted later by clearing the quote variable
			$conditions->{$key} = $conditions->{'#' . $key};
			$quote = '';
		}
		$query .= "$and $key $compare $quote" . $conditions->{$key} . "$quote";
		$and = ' AND ';
	}

	$debug_log->debug(8, "Executing query: $query");

	# Send the query, all the values have already been inserted
	my @values = ();
	my ($error_code,undef) = $self->run_query($query, 'UPDATE', @values);
	$debug_log->debug(9, "Error Code: $error_code") if($error_code);
	return $error_code;
}

#-----------------------------------------------------------------------------
# Function: 	db_delete
#-----------------------------------------------------------------------------
# Description:
# 					Deletes row(s) from the database
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# Table Name				IN:0	The name of the table to insert into
# Condition Hash			IN:0	The condition fields and values.
#-----------------------------------------------------------------------------
sub db_delete
{
	my $self 		= shift;
	my $table		= $_[0];
	my $conditions	= $_[1];

	my $query = "DELETE FROM $table WHERE ";

	my $and = '';
	foreach my $key (keys %{$conditions})
	{
		my $quote = "'";
      my $equal = '=';
		if($key =~ s/^(#{0,1})\^/$1/)
      {
         $equal = '!=';
         $conditions->{$1 . $key} = $conditions->{$1 . '^' . $key};
      }
		if($key =~ s/^#//g)
		{
			# This keys' value is to be evaluated instead of inserted as is
			# e.g. 'NOW()' or 'field + 1'
			if(exists($conditions->{$key}))
			{
				# The key name without the # exists already
				$error_log->error(ERROR_SEVERITY_FATAL,ERROR_INVALID_PARAMETER, 
					"Evaluated key $key clashes with normal key");
				return ERROR_INVALID_PARAMETER;
			}
			# store the value in it's correct hash name and stop it
			# from being quoted later by clearing the quote variable
			$conditions->{$key} = $conditions->{'#' . $key};
			$quote = '';
		}
		$query .= "$and $key $equal $quote" . $conditions->{$key} . "$quote";
		$and = ' AND ';
	}

	$debug_log->debug(8, "Executing query: $query");

	# Send the query, all the values have already been inserted
	my @values = ();
	my ($error_code,undef) = $self->run_query($query, 'DELETE', @values);
	$debug_log->debug(9, "Error Code: $error_code") if($error_code);
	return $error_code;
}

#-----------------------------------------------------------------------------
# Function: 	get_next_ID_for_table
#-----------------------------------------------------------------------------
# Description:
#					Get the next ID for the table from the sequence table and
#					update the sequence table so next time we get a different one
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# ID							OUT:1	The ID of the newly inserted row
# Table Name				IN:0	The name of the table to insert into
#-----------------------------------------------------------------------------
sub get_next_ID_for_table
{
	my $self 		= shift;
	my $table_name	= $_[0];

	# Lock the sequence table, so we know we are the only one looking
	my $error_code = $self->lock_tables($config->config('sequence_table'));
	return $error_code if($error_code);

	# Now we get the current value for the table
	my $query = "SELECT count FROM " . $config->config('sequence_table');
	$query .= ' WHERE table_name = ?';
	my @values = ($table_name);
	my $query_handle;
	($error_code, $query_handle) = $self->run_query($query, '(get_next_ID_for_table)', @values);
	if($error_code)
	{
		$self->lock_tables($config->config('sequence_table'),1);
		return $error_code;
	}

	# Next we increment the value
	$error_code = $self->db_update($config->config('sequence_table'),
							# Update details
							{'#count'	=> 'count+1'},
							# Condition details
							{'table_name' =>	$table_name});
	if($error_code)
	{
		$self->lock_tables($config->config('sequence_table'),1);
		return $error_code;
	}
	my $result = $db_handle->selectall_arrayref($query_handle);
	
	# It is now safe to unlock the sequence table
	$error_code = $self->lock_tables($config->config('sequence_table'),1);
	
	if ($#$result < 0)
	{
		# No rows returned; so we return nothing
		$error_log->error(ERROR_SEVERITY_FATAL,ERROR_DB_RESULTS, 
			"New ID not found for table `$table_name'");
		return ERROR_DB_RESULTS;
	}
	
	return ($error_code, $result->[0]->[0]); # Return the new ID got
}

#-----------------------------------------------------------------------------
# Function: 	lock_tables
#-----------------------------------------------------------------------------
# Description:
#					Locks or unlocks tables
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# Table Name List			IN:0	The name of the table to insert into
# Unlock						IN:1 	[OPTIONAL] 0 to lock, 1 to unlock
#-----------------------------------------------------------------------------
sub lock_tables
{
	my $self 	= shift;
	my $tables	= $_[0];
	my $unlock	= $_[1] || 0;

	my $query;
	if($unlock)
	{
		$query = "UNLOCK TABLES";
	} else {
		$query = "LOCK TABLES $tables WRITE";
	}

	my @values = ();
	my ($error_code, undef) = $self->run_query($query, 'LOCK', @values);
	
	return $error_code;
}

#-----------------------------------------------------------------------------
# Function: 	run_query
#-----------------------------------------------------------------------------
# Description:
# 					Runs a query, and returns a handle to it
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------ 
# Error Response Code	OUT:0	0 successful, or an error code
# Query Handle				OUT:1	The handle to the query
# Query String				IN:0	The query as text
# Handle Name           IN:1	The handle name to report on error
# Values						IN:2	The values to pass in to the query
#-----------------------------------------------------------------------------
sub run_query
{
	my $self 		= shift;
	my $query		= shift;
	my $handle_name= shift;
	my @values		= @_;
	
	my $query_handle = $db_handle->prepare($query);
	unless($query_handle)
	{
		my $error = $db_handle->errstr();
		$error_log->error(ERROR_SEVERITY_FATAL,ERROR_DB_SYSTEM, 
			"Prepare failed on query $query, reason: $error");
		return ERROR_DB_SYSTEM;
	}
	eval
	{
		local $SIG{__DIE__};
		unless($query_handle->execute(@values))
		{
			my $error = $db_handle->errstr();
			die('Query Execute Failure: ' . $error);
		}
	};
	if ($@)
	{
		my $error = $db_handle->errstr();
		my $string = $@;
		chomp($string);
		$error_log->error(ERROR_SEVERITY_FATAL, ERROR_DB_EXECUTE, 
			"Error in executing `$query' Params[" . join(',',@values) . 
         "] Handle $handle_name: $error ($string)");
		return ERROR_DB_EXECUTE;
	}

	return (ERROR_NONE,$query_handle);
}
1;
