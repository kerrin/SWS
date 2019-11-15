#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		FormBase
#-----------------------------------------------------------------------------
# Description:
# 					This module encompasses access to all the other modules. 
# 					All non-core modules will inherit from this.
# 					This provides debug, error, and event logs, with access to 
# 					creating additional logs
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2004/04/04 18:36:06 $
# $Revision: 1.10 $
#-----------------------------------------------------------------------------
package SWS::Source::FormBase;
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
	@ISA = qw(SWS::Source::CommonBase SWS::Source::CommonTools);
	@EXPORT = qw(
         FIELD_TYPE_USERNAME FIELD_TYPE_PASSWORD FIELD_TYPE_STRING
         FIELD_TYPE_NUMBER FIELD_TYPE_FLOAT FIELD_TYPE_EMAIL

         OVERWRITE_IGNORE OVERWRITE_DELETE_ONLY OVERWRITE_ERROR
         OVERWRITE_MOVE_ANYWAY
      );
}

use constant FIELD_TYPE_ANY      => 1;
use constant FIELD_TYPE_USERNAME => 2;
use constant FIELD_TYPE_PASSWORD => 3;
use constant FIELD_TYPE_STRING   => 4;
use constant FIELD_TYPE_NUMBER   => 5;
use constant FIELD_TYPE_FLOAT    => 6;
use constant FIELD_TYPE_EMAIL    => 7;

use SWS::Source::CommonBase;
use SWS::Source::CommonTools;
use SWS::Source::Log;
use SWS::Source::Config;
use SWS::Source::Error;
use SWS::Source::Database;
use SWS::Source::Constants;

sub FIELDS() { {}; };

#-----------------------------------------------------------------------------
# Function: 	new
#-----------------------------------------------------------------------------
# Description:
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Arguments					IN:0	The arguments for all modules
#-----------------------------------------------------------------------------
sub new
{
	my $prototype 	= shift;
	my $config 		= $_[0];
	my $args 		= $_[1];

	# Get back the correct object name
	my $class = ref($prototype) || $prototype;
	
	# Call the base class to initialise basic elements
	my $self = $class->SUPER::new(@_);
	
	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	run
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Next Action				OUT:0	The module name to run next or undef for none
# Next Actions ArgumentsOUT:1	The arguments to pass to the next modules new
#-----------------------------------------------------------------------------
sub run
{
	my $self 	=	shift;
   $self->debug(8, 'FormBase::run');

   if($self->can('pre_check_module_setup'))
   {
      $self->pre_check_module_setup();
   }
   unless(exists($self->{'cgi_vars'}->{'no_check'}) &&
      $self->{'cgi_vars'}->{'no_check'} == 1)
   {
      my $error_code = $self->check_cgi_vars();
      if($error_code == ERROR_CHECK_FAIL)
      {
         if($self->can('setup_tmpl_vars'))
         {
            $self->setup_tmpl_vars();
         }
         if($self->can('all_screens_common'))
         {
            $self->all_screens_common();
         }
   
	      my ($error_code, $template) = 
		      $self->load_template($self->TEMPLATE(), $self->{'tmpl_vars'});

	      $self->output_to_browser($template);
         return;
      } elsif($error_code) {
         $self->throw_error($error_code, 'Error checking cgi variables');
      }
   }
   if($self->can('post_check_module_setup'))
   {
      $self->post_check_module_setup();
   }
   
   if(exists($self->{'cgi_vars'}->{'event'}) && 
      $self->{'cgi_vars'}->{'event'} ne '')
   {
      $self->debug(8, 'Have Event: ' . $self->{'cgi_vars'}->{'event'});
      my $event_function = 'event_' .  $self->{'cgi_vars'}->{'event'};
      delete $self->{'cgi_vars'}->{'event'};
      delete $self->{'state'}->{'event'}; # Let make sure
      unless($self->can($event_function))
      {
         $self->error(ERROR_SEVERITY_FATAL, ERROR_RUNTIME_ERROR,
            "Event function $event_function cannot be found");
         return;
      }
      
      my ($action, $args) = $self->$event_function();
      if($action)
      {
         return ($action, $args);
      }
   }
   
   if($self->can('setup_tmpl_vars'))
   {
      $self->setup_tmpl_vars();
   }
   if($self->can('all_screens_common'))
   {
      $self->all_screens_common();
   }
   
	my ($error_code, $template) = 
		$self->load_template($self->TEMPLATE(), $self->{'tmpl_vars'});

	$self->output_to_browser($template);

	return; 
}

#-----------------------------------------------------------------------------
# Function:    pre_check_module_setup
#-----------------------------------------------------------------------------
# Description:
#              Used to setup the module before any checks are performed
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
#sub pre_check_module_setup
#{
#  my $self    =  shift;
#
#   $self->debug(8, 'FormBase::pre_check_module_setup');
#
#}

#-----------------------------------------------------------------------------
# Function:    post_check_module_setup
#-----------------------------------------------------------------------------
# Description:
#              Used to setup the module after any checks are performed
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
#sub post_check_module_setup
#{
#  my $self    =  shift;
#
#   $self->debug(8, 'FormBase::post_check_module_setup');
#
#}


#-----------------------------------------------------------------------------
# Function:    check_cgi_vars
#-----------------------------------------------------------------------------
# Description:
#              Used to check the cgi variables are as expected
#              If field fails checking two template variables are set
#                 need_<FIELDNAME>  = Flags the field at fault
#                 error_message     = A text message to display
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 The return code, 0 for ok, ERROR_CHECK_FAIL
#-----------------------------------------------------------------------------
sub check_cgi_vars
{
   my $self    =  shift;

   $self->debug(8, 'FormBase::check_cgi_vars');

   my $fields = $self->FIELDS();
   foreach my $this_field_key (keys %{$fields})
   {
      $self->debug(8, "Checking field $this_field_key");
      my $this_field = $fields->{$this_field_key};
      unless(exists($this_field->{'type'}))
      {
         $self->throw_error(ERROR_MISSING_KEY, 
            "Type field missing in check_cgi_vars for field $this_field_key");
      }
      unless(exists($self->{'cgi_vars'}->{$this_field_key}))
      {
         $self->throw_error(ERROR_INVALID_PARAMETER, 
            "Field missing in check_cgi_vars for field $this_field_key");
      }
      my $field_value = $self->{'cgi_vars'}->{$this_field_key} || '';
      my $display_name = $this_field->{'display_name'} || $this_field_key;
      my $require = 0;
      if(exists($this_field->{'required'}) && $this_field->{'required'} > 0)
      {
         $require = 1;
         unless($field_value)
         {
            $self->{'tmpl_vars'}->{'error_message'} = 
               "$display_name is required";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
      }
      my $type = $this_field->{'type'};
      if($type == FIELD_TYPE_USERNAME)
      {
         unless($field_value =~ /^[\w\d\.\-_]+$/)
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is not a valid username";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
      } elsif($type == FIELD_TYPE_PASSWORD) {
         if($field_value =~ /([^\w\d\.\-_!"£\$%\^&\*\(\)\+=\{\}\[\]\~#'@;:\/\\\?<>,\.\|])/)
         {
            # Found an invalid charater, some how! Probably a space or tab
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name contains an invalid character ($1)";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
      } elsif($type == FIELD_TYPE_STRING) {
         if($field_value =~ /([^\w\d\.\-_\s!"£\$%\^&\*\(\)\+=\{\}\[\]\~#'@;:\/\\\?<>,\.\|])/)
         {
            # Found an invalid charater, some how!
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name contains an invalid character ($1)";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} =
            return ERROR_CHECK_FAIL;
         }
      } elsif($type == FIELD_TYPE_NUMBER) {
         unless($field_value =~ /^\-?[\d]*$/)
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is not a valid whole number";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
         if(exists($this_field->{'minimum'}) && $field_value ne '' &&
            $this_field->{'minimum'} > $field_value && 
            ($require || $field_value != -1))
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is too low";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
         if(exists($this_field->{'maximum'}) && $field_value ne '' &&
            $this_field->{'maximum'} < $field_value &&
            ($require || $field_value != -1))
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is too high";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
      } elsif($type == FIELD_TYPE_FLOAT) {
         unless($field_value =~ /^\-?[\d]*\.?[\d]*$/)
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is not a valid number";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
         if(exists($this_field->{'minimum'}) && $field_value ne '' &&
            $this_field->{'minimum'} > $field_value &&
            ($require || $field_value != -1))
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is too low";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
         if(exists($this_field->{'maximum'}) &&  $field_value ne '' &&
            $this_field->{'maximum'} < $field_value &&
            ($require || $field_value != -1))
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is too high";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
      } elsif($type == FIELD_TYPE_EMAIL) {
         unless($field_value =~ /^[\w\d\.\-_]+@[\w\d\.\-_]+$/)
         {
            $self->{'tmpl_vars'}->{'error_message'} =
               "$display_name is not a valid E-Mail Address";
            $self->{'tmpl_vars'}->{'need_' . $this_field_key} = 1;
            return ERROR_CHECK_FAIL;
         }
      } elsif($type == FIELD_TYPE_ANY) {
         # Nothing to check here, this is only here to be valid
      } else {
         $self->throw_error(ERROR_INVALID_PARAMETER, 
            "Type field invalid in check_cgi_vars for field $this_field_key," .
            "type: $type");
      }
   }
   
   # All ok
   return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function:    create_drop_down_from_select
#-----------------------------------------------------------------------------
# Description:
#              Used to generate a drop down array from an array
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# drop down name        IN:0  The name of the handle to give the drop down
# ID to select          IN:1  The ID to mark as selected in the array
# Handle                IN:2  The database handle to use
# Variables             IN:3  The replacement variables for the query
# Params                IN:4  The parameters to the query
#-----------------------------------------------------------------------------
sub create_drop_down_from_select
{
   my $self       = shift;
   my $name       = shift;
   my $selected   = shift || 0;
   my $handle     = shift;
   my $variables  = shift || {};
   my @params     = @_;

   my ($error_code, $details) = $self->db_select($handle,$variables,@params);
   if($error_code)
   {
      $self->throw_error($error_code, 
         "Select error in create_drop_down_from_select with handle $handle");
   }
   unless(defined($details) && @{$details})
   {
      $details = ['ID' => -1, 'name' => 'NONE'];
   }
   
   my @drop_down;
   my $index = 0;
   foreach my $row (@{$details})
   {
      my $ID = $row->{'ID'} || $index;
      my $name = $row->{'name'} || $index;
      my $element = {'ID' => $ID, 'index' => $index, 'name' => $name};
      if(defined($row->{'mouse_over'}))
      {
         $element->{'mouse_over'} = $row->{'mouse_over'};
      }
      if(defined($selected) && $selected == $ID)
      {
         $element->{'selected'} = 1;
         undef($selected);
      }
      push @drop_down, $element;
      $index++;
   }
   $self->{'tmpl_vars'}->{$name.'_loop'} = \@drop_down;
}

#-----------------------------------------------------------------------------
# Function:    create_drop_down_from_array
#-----------------------------------------------------------------------------
# Description:
#              Used to generate a drop down array from an array
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# drop down name        IN:0  The name of the handle to give the drop down
# ID to select          IN:1  The ID to mark as selected in the array
# Array                 IN:2  The array of hashes to generate it from
#-----------------------------------------------------------------------------
sub create_drop_down_from_array
{
   my $self       = shift;
   my $name       = shift;
   my $selected   = shift || 0;
   my @details    = @_;

   $self->debug(9, "SWS::FormBase::create_drop_down_from_array $name, $selected,[...]");
   my @drop_down;
   my $index = 0;
   foreach my $row (@details)
   {
      my $ID = $row->{'ID'} || $index;
      my $name = $row->{'name'} || $index;
      my $element = {'ID' => $ID, 'index' => $index, 'name' => $name};
      if(defined($row->{'mouse_over'}))
      {
         $element->{'mouse_over'} = $row->{'mouse_over'};
      }
      if(defined($selected) && $selected == $ID)
      {
         $element->{'selected'} = 1;
         undef($selected);
      }
      push @drop_down, $element;
      $index++;
   }
   $self->{'tmpl_vars'}->{$name.'_loop'} = \@drop_down;
}

#-----------------------------------------------------------------------------
# Function:    create_numeric_drop_down
#-----------------------------------------------------------------------------
# Description:
#              Used to generate a drop down array from an array
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# drop down name        IN:0  The name of the handle to give the drop down
# ID to select          IN:1  The ID to mark as selected in the array
# Start                 IN:2  The first entry
# Stop                  IN:3  The last entry
# Step                  IN:4  The spacing between entries
# Append                IN:5  Append two letter postfix (1st, 2nd, 3rd, 4th..)
# Unselected            IN:6  Add an unselected option (text to use)
#-----------------------------------------------------------------------------
sub create_numeric_drop_down
{
   my $self       = shift;
   my $name       = $_[0];
   my $selected   = $_[1] || 0;
   my $start      = $_[2] || 0;
   my $stop       = $_[3];
   my $step       = $_[4] || 1;
   my $append     = $_[5] || 0;
   my $unseleced  = $_[6] || '';
   my $mouse_over = $_[7] || 1;

   $self->debug(9, 'FormBase::create_numeric_drop_down ' .
      join(',',@_));

   my @drop_down;
   if($unseleced ne '')
   {
      my $element = {'ID' => -1, 'index' => -1, 'name' => $unseleced};

      push @drop_down, $element;
   }
   for(my $index = 0; $start <= $stop; $start += $step)
   {
      my $name = $start;
      $name .= $self->get_postix($start) if($append);
      my $element = {'ID' => $start, 'index' => $index, 'name' => $name};
      if($mouse_over)
      {
         $element->{'mouse_over'} = $name;
      }
      if(defined($selected) && $selected == $start)
      {
         $element->{'selected'} = 1;
         undef($selected);
      }
      push @drop_down, $element;
      $index++;
   }
   $self->{'tmpl_vars'}->{$name.'_loop'} = \@drop_down;
}

#-----------------------------------------------------------------------------
# Function:    get_postix
#-----------------------------------------------------------------------------
# Description:
#              returns the two letter postix for the number.
#              e.g. 1 => st, 2 => nd, 3 => rd, 4 to 20 = th
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return                OUT:0 Two letter postfix
# Number                IN:0  Number to get postif of
#-----------------------------------------------------------------------------
sub get_postix
{
   my $self = shift;
   my $number = $_[0];

   # It all loops at 100, and every 100 there on so, modular 100.
   $number %= 100;
   
   my $postfix;
   # The teen numbers are unusual, so get them first
   if($number > 3 && $number < 21)
   {
      $postfix = 'th';
   } else {
      # Everything else is based on the last digit, so modular 10
      $number %= 10;
      if($number > 3)
      {
         $postfix = 'th';
      } elsif($number == 1) {
         $postfix = 'st';
      } elsif($number == 2) {
         $postfix = 'nd';
      } elsif($number == 3) {
         $postfix = 'rd';
      } else {
         # must be 0,30,40,50,60,70,80, or 90
         $postfix = 'th';
      }
   }
   
   return $postfix;
}

#-----------------------------------------------------------------------------
# Function:    setup_tmpl_vars
#-----------------------------------------------------------------------------
# Description:
#              Used to fill out the tmpl_vars
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
#sub setup_tmpl_vars
#{
#
#}

#-----------------------------------------------------------------------------
# Function:    all_screens_common
#-----------------------------------------------------------------------------
# Description:
#              Used to do stuff all screens do
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
#sub all_screens_common
#{
#
#}
1;
