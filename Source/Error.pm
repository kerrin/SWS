#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Error
#-----------------------------------------------------------------------------
# Description:
# 					Used to report an error to the log, and error
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/02 10:25:03 $
# $Revision: 1.16 $
#-----------------------------------------------------------------------------
package SWS::Source::Error;
use strict;

BEGIN
{
	my $project_path;
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		confess('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";

	use vars qw(@ISA @EXPORT);
	@ISA = qw(Exporter);
	@EXPORT = qw(
			   ERROR_SEVERITY_WARNING ERROR_SEVERITY_ERROR ERROR_SEVERITY_FATAL

			  ERROR_NONE

			  ERROR_UNINITIALISED ERROR_INVALID_FUNCTION_CALL
			  ERROR_INVALID_PARAMETER ERROR_MISSING_PARAMETER
			  ERROR_INVALID_TEMPLATE ERROR_INVALID_USER
			  ERROR_MISSING_ACTION ERROR_INVALID_ACTION ERROR_SYSTEM_ERROR
           ERROR_RUNTIME_ERROR ERROR_UNCAUGHT_ERROR ERROR_DOUBLE_OUTPUT
           ERROR_NO_OUTPUT ERROR_TAMPER ERROR_MD5
           ERROR_MISSING_KEY ERROR_CHECK_FAIL ERROR_DUPLICATE_VALUE

			  ERROR_DB_CONNECT ERROR_DB_INVALID_QUERY
			  ERROR_DB_EXECUTE ERROR_DB_SYSTEM ERROR_DB_RESULTS
			  
			  ERROR_IO_FILE_OPEN ERROR_IO_FILE_EXIST ERROR_IO_PARSE
		);
}

use constant ERROR_SEVERITY_WARNING	=> 1;
use constant ERROR_SEVERITY_ERROR	=> 2;
use constant ERROR_SEVERITY_FATAL	=> 3;

use constant ERROR_NONE	=> 0;

# To be renumbered later, so don't rely on the actual values!
use constant ERROR_UNINITIALISED				=> 1;
use constant ERROR_INVALID_FUNCTION_CALL	=> 2;
use constant ERROR_INVALID_PARAMETER		=> 3;
use constant ERROR_MISSING_PARAMETER		=> 4;
use constant ERROR_INVALID_TEMPLATE			=> 5;
use constant ERROR_INVALID_USER				=> 6;
use constant ERROR_MISSING_ACTION			=> 7;
use constant ERROR_INVALID_ACTION			=> 8;
use constant ERROR_SYSTEM_ERROR				=> 9;
use constant ERROR_RUNTIME_ERROR          => 10;
use constant ERROR_UNCAUGHT_ERROR         => 11;
use constant ERROR_DOUBLE_OUTPUT          => 12;
use constant ERROR_NO_OUTPUT              => 13;
use constant ERROR_TAMPER                 => 14;
use constant ERROR_MD5                    => 15;
use constant ERROR_MISSING_KEY            => 16;
use constant ERROR_CHECK_FAIL             => 17;
use constant ERROR_DUPLICATE_VALUE        => 18;

use constant ERROR_DB_CONNECT 				=> 100;
use constant ERROR_DB_INVALID_QUERY			=> 101;
use constant ERROR_DB_EXECUTE					=> 102;
use constant ERROR_DB_SYSTEM 					=> 103;
use constant ERROR_DB_RESULTS					=> 104;

use constant ERROR_IO_FILE_OPEN				=> 200;
use constant ERROR_IO_FILE_EXIST				=> 201;
use constant ERROR_IO_PARSE					=> 202;

sub TEMPLATE() { 'error.html' };

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
#sub new
#{
#	my $prototype 	= shift;
#	my $args 		= $_[0];
#
#	my $filename = $args->{'error_log_filename'};
#	
#	# Get back the correct object name
#	my $class = ref($prototype) || $prototype;
#	
#	# Call the base class to initialise basic elements
#	my $self = $class->SUPER::new(@_);
#	
#	# And return the database enabled base object
#	return $self;
#}

1;
