#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Config
#-----------------------------------------------------------------------------
# Description:
# 					This module is used to read a configuration file in, that 
# 					stores values that may change, unlike constants, which probably 
# 					won't change.
# Notes:
# 				Configuration files are of the form: itemkey=itemvalue
# 				Comments are only allowed on seperate lines currently and start #
# 				Previous configuration items can be use in later values by using
# 					the following format in the value:  key=stuff #earlier_item stuff
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/27 14:33:27 $
# $Revision: 1.12 $
#-----------------------------------------------------------------------------
package SWS::Source::Config;
use strict;

use IO::Socket;
use Carp;

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

my $config_items;

#-----------------------------------------------------------------------------
# Function: 	new
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Object						OUT:0	The config object
# Args					 	IN:0	The remaining arguments
#-----------------------------------------------------------------------------
sub new
{
	my $prototype 	= shift;
	my $args 		= $_[0];

	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new(@_);
	
	# Read the SWS config
	my $filename	= $project_path . '/SWS/Config/main.cfg';
	$self->read_config($filename);

	# Now read the site config
	$filename	= $project_path . '/' . $args->{'site'} . '/Config/main.cfg';
	$self->read_config($filename);

   $self->{'config_items'} = $config_items;
	
	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	config
#-----------------------------------------------------------------------------
# Description:
# 					Used to retrieve a configuration item value.
# 					Note: This function is an exception to returning an error code, 
# 					to make ease of use better.
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Value						OUT:0	The value of the item requested
# Item Name					IN:0	The item to retrieve
#-----------------------------------------------------------------------------
sub config
{
	my $self = shift;
	my $item_name 	= $_[0];

	# If the item exists, return the value
	if(exists($config_items->{$item_name}))
	{
		return $config_items->{$item_name};
	}

	# Error
	die('Error getting config item ' .  $item_name . ', does not exist');
}

#-----------------------------------------------------------------------------
# Function: 	read_config
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Filename					IN:0	The filename and path of the config file
#-----------------------------------------------------------------------------
sub read_config
{
	my $self = shift;
	my $filename = $_[0];

	my $file;
	unless(open($file, $filename))
	{
		die("Could not open configuration file $filename for reading");
	}
	
	my $line_num = 0;
	while(<$file>)
	{
		$line_num++;
		my $line = $_;
		$line =~ s/\s*=\s*/=/g;
		if($line =~ /^#/ || $line =~ /^$/)
		{ 
			# This line is either a comment, or blank line, so ignore
			next;
		}
		if ($line =~ /^([\w_]+?)=(.*)$/)
		{
			# This line is a key and value line, so extract the data
			my $key = $1;
			if(exists($config_items->{$key}))
			{
				# This key exists already, so it must be a duplicate
				die("Redefined key $key");
			}
			my $value = $2;
			# Check the value for variables to replace
			while($value =~ /#([\w_]+)/)
			{
				# Found a variable, so replace it
				my $replace = $1;
				$replace =~ s/#//;
				if(exists($config_items->{$1}))
				{
					# We have the variable defined as a key already, so replace the
					# variable with its value
					my $replace_with = $config_items->{$1};
					$value =~ s/#$replace/$replace_with/;
				} else {
					die("Variable replace failed on key $replace");
				}
			}

			# Store the value
			$config_items->{$key} = $value;
		} else {
			# Unrecognised line format
			die("Invalid config line, line $line_num");
		}
	}
	
	close($file);
	
	return 0;
}

1;
