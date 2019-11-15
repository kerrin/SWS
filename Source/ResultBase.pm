#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		ResultBase
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
# $Date: 2003/09/23 21:55:13 $
# $Revision: 1.5 $
#-----------------------------------------------------------------------------
package SWS::Source::ResultBase;
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
	@ISA = qw(SWS::Source::CommonBase SWS::Source::CommonTools 
             SWS::Source::FormBase);
	@EXPORT = qw(
         FIELD_TYPE_USERNAME FIELD_TYPE_PASSWORD FIELD_TYPE_STRING
         FIELD_TYPE_NUMBER FIELD_TYPE_FLOAT FIELD_TYPE_EMAIL

         OVERWRITE_IGNORE OVERWRITE_DELETE_ONLY OVERWRITE_ERROR
         OVERWRITE_MOVE_ANYWAY
      );
}

use SWS::Source::CommonBase;
use SWS::Source::CommonTools;
use SWS::Source::FormBase;
use SWS::Source::Log;
use SWS::Source::Config;
use SWS::Source::Error;
use SWS::Source::Database;
use SWS::Source::Constants;

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
   $self->debug(8, 'ResultBase::run');

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
   
   my ($error_code, $search_handle, $variables, @params);
   if(exists($self->{'cgi_vars'}->{'search_string'}))
   {
      ($error_code, $search_handle, $variables, @params) = 
         $self->unpack_search($self->{'cgi_vars'}->{'search_string'});
   } else {
      ($error_code, $search_handle, $variables, @params) = 
         $self->generate_search();
   }
   if($error_code)
   {
      $self->throw_error($error_code, 
         'Failed to get search details in ResultBase');
   }

   my $results;
	($error_code, $results) = 
      $self->db_select($search_handle, $variables, @params);
   if($error_code)
   {
      $self->throw_error($error_code, 'Failed to search in ResultBase');
   }
	unless(defined($results))
	{
      # This time we want an empty array
      $results = [];
      $self->{'tmpl_vars'}->{'message'} = $self->empty_results();
	}

   $self->{'tmpl_vars'}->{'results_loop'} = $results;
   
   if($self->can('setup_tmpl_vars'))
   {
      $self->setup_tmpl_vars();
   }
   if($self->can('all_screens_common'))
   {
      $self->all_screens_common();
   }
   
   my $template;
	($error_code, $template) = 
		$self->load_template($self->TEMPLATE(), $self->{'tmpl_vars'});

	$self->output_to_browser($template);

	return; 
}

#-----------------------------------------------------------------------------
# Function:    unpack_search
#-----------------------------------------------------------------------------
# Description:
#              Used to convert the search string in to the variables required
#              Search string is of the format:
#              handle::variable_name=>value;;variable_name=>value;;search_params=>where_clause::replacement_value::replacement_value
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Response Code         OUT:0 0 successful, or an error code
# Handle                OUT:1 The search query handle
# Variables             OUT:2 The replacement variables hash
# Parameters            OUT:3 The queries parameters
#-----------------------------------------------------------------------------
sub unpack_search
{
   my $self = shift;
   $self->debug(8, 'ResultBase::unpack_search');

   my ($handle,$variables,@params);
   $self->debug(8, 'Unpacking ' . $self->{'cgi_vars'}->{'search_string'});
   my $variables_string;
   ($handle,$variables_string,@params) = 
      split(/::/,$self->{'cgi_vars'}->{'search_string'});
   delete $self->{'cgi_vars'}->{'search_string'};

   # Unescape characters
   $handle =~ s/\:/:/g;
   $handle =~ s/\;/;/g;
   $handle =~ s/\\\\/\\/g;
   $self->debug(8, "Handle: $handle");
   
   my @key_value_pairs = split(/;;/,$variables_string);
   foreach my $key_value (@key_value_pairs)
   {
      my ($key, $value) = split(/=>/,$key_value,2);
      # Unescape characters
      $key =~ s/\=/=/g;
      $key =~ s/\>/>/g;
      $key =~ s/\:/:/g;
      $key =~ s/\;/;/g;
      $key =~ s/\\\\/\\/g;
      $value =~ s/\=/=/g;
      $value =~ s/\>/>/g;
      $value =~ s/\:/:/g;
      $value =~ s/\;/;/g;
      $value =~ s/\\\\/\\/g;
      
      $variables->{$key} = $value;
      $self->debug(8, "Variable: $key => $value");
   }
   foreach (@params)
   {
      # Unescape characters
      $_ =~ s/\:/:/g;
      $_ =~ s/\\\\/\\/g;
      $self->debug(8, "Param $_");
   }

   return (ERROR_NONE, $handle,$variables,@params);
}

#-----------------------------------------------------------------------------
# Function:    generate_search
#-----------------------------------------------------------------------------
# Description:
#              Used to generate the search variables
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Response Code         OUT:0 0 successful, or an error code
# Handle                OUT:1 The search query handle
# Variables             OUT:2 The replacement variables hash
# Parameters            OUT:3 The queries parameters
#-----------------------------------------------------------------------------
#sub generate_search
#{
#   my $self = shift;
#   $self->debug(8, 'ResultBase::generate_search');
#
#}

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
#   my $self = shift;
#   $self->debug(8, 'ResultBase::setup_tmpl_vars');
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
#   my $self = shift;
#   $self->debug(8, 'ResultBase::all_screens_common');
#
#}

#-----------------------------------------------------------------------------
# Function:    empty_results
#-----------------------------------------------------------------------------
# Description:
#              Used to return the message to display if no results are found
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Message               OUT:0 The message to set if no results found
#-----------------------------------------------------------------------------
sub empty_results
{
   my $self = shift;
   $self->debug(8, 'ResultBase::empty_results');

   return 'None Found';
}

1;
