#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Test
#-----------------------------------------------------------------------------
# Description:
# 					This module is a test server, used to demostrate a simple
# 					server
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/10/26 13:34:47 $
# $Revision: 1.1 $
#-----------------------------------------------------------------------------
package SWS::Servers::Test;
use strict;

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
	@ISA = qw(SWS::Source::ServerBase SWS::Source::CommonTools);
	@EXPORT = qw();
}

use SWS::Source::ServerBase;
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

	# And return the database enabled base object
	return $self;
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

   $self->debug(8, 'This is debug from the test server prepolling');

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

   $self->debug(8, 'This is debug from the test server');

   return ERROR_NONE;
}

1;
