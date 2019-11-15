#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		Base
#-----------------------------------------------------------------------------
# Description:
# 					Supplies functionality used more than once.
# 					All the low level modules will inherit this.
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/27 14:33:27 $
# $Revision: 1.4 $
#-----------------------------------------------------------------------------
package SWS::Source::Base;
use strict;
use Digest::MD5;

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
	@ISA = qw(Exporter);
	@EXPORT = qw();
}

use SWS::Source::Constants;
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
# Arguments					IN:0  This is aguments required to set up all modules
#-----------------------------------------------------------------------------
sub new
{
	my $prototype 	= shift;

	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = {};
	bless($self, $class);
	
	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	generate_md5
#-----------------------------------------------------------------------------
# Description:
#              Generates a MD5 encryption of a value
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# return                OUT:0 Return Code
# return                OUT:1 The md5 encryption of the value
# Value                 IN:0  This is the value to encrypt
# Key                   IN:1  [Optional] The key to use to encrypt with
#-----------------------------------------------------------------------------
sub generate_md5
{
   my $self    = shift;
   my $value   = $_[0];
   my $md5_key = $_[1] || $self->config('default_md5_key');
   $self->debug(8, "SWS::Base->generate_md5");

   my $md5 = new Digest::MD5();
   $md5->add($md5_key);
   $md5->add($value) if ($value);
   my $checksum = $md5->hexdigest();
   if (!$checksum || length($checksum) != 32)
   {
      $checksum ||= '<EMPTY>';
      $self->error(ERROR_SEVERITY_FATAL,ERROR_INVALID_PARAMETER, 
         "Generating Checksum failed [$checksum]");

      # Pretend it worked, so as not to give away anything to the hacking scum
      $checksum = "h4s78s37d8t9f2b3y8k9l2i3l897f8w6";
      return (ERROR_INVALID_PARAMETER,$checksum);
   }
   $self->debug(8, "Hex digest of [$value] is [$checksum]");
   return (ERROR_NONE,$checksum);
}

1;
