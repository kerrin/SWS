#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Constants
#-----------------------------------------------------------------------------
# Description:
# 					This module contains all the core code constants
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/08/24 21:38:09 $
# $Revision: 1.4 $
#-----------------------------------------------------------------------------
package SWS::Source::Constants;
use strict;

BEGIN
{
	my $project_path;
	unless($project_path = $ENV{'PROJECT_PATH'})
	{
		die('Set enviroment variable PROJECT_PATH to the project path');
	}
	eval "use lib '$project_path';";
	
	# And associated package defaults
	use vars qw(@ISA @EXPORT);
	@ISA = qw(Exporter);
	@EXPORT = qw(
         APPLICATION_CONFIG_FILE

         MEMBER_STATE_ADMIN MEMBER_STATE_ENABLED MEMBER_STATE_DISABLED
         MEMBER_STATE_BARRED MEMBER_STATE_REGISTERED

         GENDER_NONE GENDER_MALE GENDER_FEMALE
      );
}

use constant APPLICATION_CONFIG_FILE => 'main.cfg';

use constant MEMBER_STATE_ADMIN        => 1;
use constant MEMBER_STATE_ENABLED      => 2;
use constant MEMBER_STATE_DISABLED     => 3;
use constant MEMBER_STATE_BARRED       => 4;
use constant MEMBER_STATE_REGISTERED   => 5;

use constant GENDER_NONE   => 1;
use constant GENDER_MALE   => 2;
use constant GENDER_FEMALE => 3;

1;
