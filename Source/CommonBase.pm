#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		CommonBase
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
# $Date: 2004/07/04 14:53:46 $
# $Revision: 1.26 $
#-----------------------------------------------------------------------------
package SWS::Source::CommonBase;
use strict;

use CGI;
use CGI::Cookie;
use HTML::Template;

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
	@ISA = qw(SWS::Source::Base SWS::Source::CommonTools);
	@EXPORT = qw();
}

use SWS::Source::Base;
use SWS::Source::CommonTools;
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
	
	my $cgi;
	if(exists($args->{'cgi'}))
	{
		$cgi = $args->{'cgi'};
	} else {
		$cgi = new CGI();
	}
	if(exists($args->{'cgi_vars'}))
	{
		$self->{'cgi_vars'} = $args->{'cgi_vars'};
	}
   my $state = {};
	if(exists($args->{'state'}))
	{
		$state = $args->{'state'};
	}
   $args->{'site'} ||= $cgi->{'site'};
	if(exists($args->{'site'}) && defined($args->{'site'}))
	{
		$self->{'invoking_site'} = $args->{'site'};
	} else {
		die('No site invoked us!');
	}

	$self->{'config'} = $config;
   my $debug_level;
	if($self->{'config'}->config('debug') > 0)
	{
      $debug_level = $self->{'config'}->config('debug_level');
   } else {
      $debug_level = 0;
   }
	$self->{'debug_log'} = new SWS::Source::Log({
	  					'log_type' 		=> LOG_TYPE_DEBUG,
						'log_filename' => $self->{'config'}->config('debug_filename'),
						'log_level'    => $debug_level
					});
	$self->{'error_log'} = new SWS::Source::Log({
			  					'log_type' 		=> LOG_TYPE_ERROR,
								'log_filename' => $self->{'config'}->config('error_filename')
							});
	$self->{'event_log'} = new SWS::Source::Log({
			  					'log_type' 		=> LOG_TYPE_EVENT,
								'log_filename' => $self->{'config'}->config('event_filename')
							});
   $self->debug(9, 'Config Items');
   $self->debug_dumper(9, $config->{'config_items'});
   
   $self->{'database'} = new SWS::Source::Database($config,$args);

   my $error_code = $self->{'database'}->connect(	
		  					$config->config('database_host'),
							$config->config('database_port'),
							$config->config('database_name'),
							$config->config('database_username'),
							$config->config('database_password'),
							$config->config('database_driver')
				 		);
	$self->initialise_state($cgi, $state);

	# And return the database enabled base object
	return $self;
}

#-----------------------------------------------------------------------------
# Function: 	debug
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Level						IN:0    The debug level
# Text						IN:1    The text to output if debug level allows
#-----------------------------------------------------------------------------
sub debug
{
	my $self 	=	shift;

	return $self->{'debug_log'}->debug(@_);
}

#-----------------------------------------------------------------------------
# Function: 	debug_dumper
#-----------------------------------------------------------------------------
# Description:
#              Output to debug log a dump of the structure
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code   OUT:0 0 successful, or an error code
# Level						IN:0    The debug level
# Structure					IN:1    The structure to dump to log
#-----------------------------------------------------------------------------
sub debug_dumper
{
	my $self 	=	shift;

	return $self->{'debug_log'}->debug_dumper(@_);
}

#-----------------------------------------------------------------------------
# Function: 	event
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Text						IN:0	The event text to log
#-----------------------------------------------------------------------------
sub event
{
	my $self 	=	shift;

   if($self->config('send_events_to_debug') == 1)
   {
      $self->debug(1, "EVENT:$_[0]");
   }

	return $self->{'event_log'}->event(@_);
}

#-----------------------------------------------------------------------------
# Function: 	error
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Severity					IN:0	The error severity (Warning, Error, Fatal)
# Error Code				IN:1	The error code
# Text						IN:2	The error text to log
#-----------------------------------------------------------------------------
sub error
{
	my $self 	=	shift;

   if($self->config('send_errors_to_debug') == 1)
   {
      my $severity = $_[0];
      my $severity_text = 'UNKNOWN';
      if($severity == ERROR_SEVERITY_WARNING)
      {
         $severity_text = 'WARN';
      } elsif($severity == ERROR_SEVERITY_ERROR) {
         $severity_text = 'ERROR';
      } elsif($severity == ERROR_SEVERITY_FATAL) {
         $severity_text = 'FATAL';
      }
      $self->debug(1, "ERROR:$severity_text:$_[1]:$_[2]");
   }

	return $self->{'error_log'}->error(@_);
}

#-----------------------------------------------------------------------------
# Function: 	throw_error
#-----------------------------------------------------------------------------
# Description:
# 					Stop execution of module, and start execution of error module
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Code				IN:1	The error to report
# Message					IN:2	The message for the error to log
#-----------------------------------------------------------------------------
sub throw_error
{
   my $self       = shift;
	my $error_code	= $_[0];
	my $message 	= $_[1];
   
   unless($self->{'no_browser_output'})
   {
      if($self->{'thrown_error'})
      {
         print "Thrown error after thrown error: $error_code : $message\n";
         exit(-1);
      }
      $self->{'thrown_error'} = 1;
      if($self->{'output_to_browser'})
      {
         print "Thrown error after output to browser: $error_code : $message\n";
         exit(-1);
      }
      $self->error(ERROR_SEVERITY_FATAL,$error_code,"Thrown:$message");
      my ($sub_error_code, $template) = 
            $self->load_template('error.html',
                                 {
                                    'error_message'   => $message,
                                    'error_code'      => $error_code
                                 }
                              );

      $self->output_to_browser($template);
   }

	die("$error_code:$message");
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
	my $self 	=	shift;
   my $item    = $_[0];

   my $value;
   eval 
   {
		local $SIG{__DIE__};
   	$value = $self->{'config'}->config($item);
   };
	if ($@)
	{
		$self->throw_error(ERROR_INVALID_PARAMETER, 
			"Error on getting config item: $item : $@");
	}
   return $value;
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
	
	return $self->{'database'}->db_select(@_);
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

	return $self->{'database'}->db_insert(@_);
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

	return $self->{'database'}->db_update(@_);
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
# Values						IN:1	The values to pass in to the query
#-----------------------------------------------------------------------------
sub run_query
{
	my $self 		= shift;

   return $self->{'database'}->run_query(@_);
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

	return $self->{'database'}->db_delete(@_);
}

#-----------------------------------------------------------------------------
# Function: 	site
#-----------------------------------------------------------------------------
# Description:
# 					returns the site Identifier that invoked us
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
#-----------------------------------------------------------------------------
sub site
{
	my $self 	=	shift;

	return $self->{'invoking_site'};
}

#-----------------------------------------------------------------------------
# Function: 	initialise_state
#-----------------------------------------------------------------------------
# Description:
# 					Called when entering the first screen, reads in all the 
# 					information from cookies, and any CGI variables, and puts them 
# 					in the state.
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# CGI							IN:0	The CGI object containing variables
#-----------------------------------------------------------------------------
sub initialise_state
{
	my $self 	=	shift;
	my $cgi		= $_[0] ||  $self->throw_error(ERROR_MISSING_PARAMETER,'cgi missing in Common Base initialise_state');
   my $state   = $_[1] || {};

   $self->debug(8, "SWS::CommonBase->initialise_state");
	$self->{'cgi'} = $cgi;

	my $cgi_vars = $self->{'cgi'}->Vars();
   if(exists($self->{'cgi_vars'}))
   {
      # Copy the real CGI vars in to the cgi vars we have already
      # The real CGI variables will take precidence
      foreach my $key (keys %{$cgi_vars})
      {
         $self->{'cgi_vars'}->{$key} = $cgi_vars->{$key};
      }
   } else {
      $self->{'cgi_vars'} = $cgi_vars;
   }

   $self->load_cookies();

   $self->{'output_to_browser'} = 0;

   $self->debug(8, 'STATE:'.($self->{'cgi_vars'}->{'state'}||'NONE'));
   my @keys = split(/;/,($self->{'cgi_vars'}->{'state'}||''));
   delete $self->{'cgi_vars'}->{'state'};
   $self->debug(7, "State is:");
   $self->debug_dumper(7, $state);
   $self->{'state'} = $state;
   foreach my $value_string (@keys)
   {
      $self->debug(8, "Found $value_string in STATE");
      my ($key,$value,$checksum,$undef) = split(/::/,$value_string);
      if(defined($undef))
      {
         $self->throw_error(ERROR_TAMPER,'State not correct' . $value_string);
      }
      $key =~ s/\\:/:/g;
      $value =~ s/\\:/:/g;
      $checksum =~ s/\\:/:/g;
      $key =~ s/\\;/;/g;
      $value =~ s/\\;/;/g;
      $checksum =~ s/\\;/;/g;
      $key =~ s/\\\\/\\/g;
      $value =~ s/\\\\/\\/g;
      $checksum =~ s/\\\\/\\/g;
      my ($return_code,$check_checksum) = $self->generate_md5($value);
      if($check_checksum ne $checksum)
      {
         $self->throw_error(ERROR_MD5,'MD5 check failed');
      }
      $self->debug(8, "Adding value from state:$key=>$value");
      
      # Put in cgi_vars and state
      unless(exists($self->{'cgi_vars'}->{$key}))
      {
         # Only if it didn't exist already, we don't want to override anything
         # comming from the cgi
         $self->{'cgi_vars'}->{$key} = $value;
      }
      if(exists($self->{'state'}->{$key}))
      {
         $self->error(ERROR_SEVERITY_WARNING, ERROR_DUPLICATE_VALUE,
            'State contains a duplicate key ' . $key);
      } else {
         $self->{'state'}->{$key} = $value;
      }
   }
   
   if($self->logged_on())
   {
      $self->{'tmpl_vars'}->{'logged_on'} = 1;
   }
	return ERROR_NONE;
}

#-----------------------------------------------------------------------------
# Function: 	clean_cgi_vars
#-----------------------------------------------------------------------------
# Description:
# 					Removes keys from the cgi variable that we no longer want
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# NONE
#-----------------------------------------------------------------------------
sub clean_cgi_vars
{
	my $self 	   =	shift;

   $self->debug(8, 'CommonBase->clean_cgi_vars');
   my @clean_list = ('action','no_check','message','error_message');
   foreach my $value (@clean_list)
   {
      delete $self->{'cgi_vars'}->{$value};
   }
}

#-----------------------------------------------------------------------------
# Function: 	generate_state_string
#-----------------------------------------------------------------------------
# Description:
# 					Saves the state to a string for use in the template
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# State String          OUT:0 State string generated
# Variables             IN:0  The variables to store in state
#-----------------------------------------------------------------------------
sub generate_state_string
{
	my $self 	   =	shift;
	my $variables 	=	$_[0] || $self->{'cgi_vars'};
   $self->debug(8, 'CommonBase->generate_state_string');

   # Make sure there is no state
   delete $variables->{'state'};
   my $state_string = '';
   my $prepend = '';
   foreach my $key (keys %{$variables})
   {
      my $value = $variables->{$key};
      my ($return_code,$checksum) = $self->generate_md5($value);
      $key =~ s/\\/\\\\/g;
      $key =~ s/:/\\:/g;
      $key =~ s/;/\\;/g;
      $value =~ s/\\/\\\\/g;
      $value =~ s/:/\\:/g;
      $value =~ s/;/\\;/g;
      $checksum =~ s/\\/\\\\/g;
      $checksum =~ s/:/\\:/g;
      $checksum =~ s/;/\\;/g;

      $state_string .= $prepend . $key . '::' . $value . '::' . $checksum;
      $prepend = ';';
   }
   return $state_string;
};

#-----------------------------------------------------------------------------
# Function: 	load_cookies
#-----------------------------------------------------------------------------
# Description:
# 					Saves the cookies currently stored in memory to a real cookie
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Return						OUT:1 The text to put in the HTML header
#-----------------------------------------------------------------------------
sub load_cookies
{
	my $self 	=	shift;
   $self->debug(8, "SWS::CommonBase->load_cookies");

	my $domain = $self->config('domain');
   my %cookies = CGI::Cookie->fetch();
   if (!%cookies)
   {
      # No cookies available
      $self->debug(5, "No cookies to load");
   }
	
	foreach my $this_cookie (keys %cookies)
	{
		my $cookie_name = $cookies{$this_cookie}->name();
		my $cookie_value = $cookies{$this_cookie}->value();
      my ($value, $checksum) = split(/::/,$cookie_value);
      my ($return_code, $check_checksum) = $self->generate_md5($value);
      if($check_checksum ne $checksum)
      {
         $self->error(ERROR_SEVERITY_WARNING,ERROR_MD5,'Cookie MD5 check failed');
         undef $value;
      }
      $cookie_name =~ s/\\\\/\\/g;
      $cookie_name =~ s/\\:/:/g;
      $cookie_name =~ s/\\;/;/g;
      $cookie_value =~ s/\\\\/\\/g;
      $cookie_value =~ s/\\:/:/g;
      $cookie_value =~ s/\\;/;/g;
      $self->{'cookies'}->{$cookie_name} = $value;
      $self->{'cgi_vars'}->{$cookie_name} = $value;
      $self->{'state'}->{$cookie_name} = $value;
	}
}

#-----------------------------------------------------------------------------
# Function: 	save_cookies
#-----------------------------------------------------------------------------
# Description:
# 					Saves the cookies currently stored in memory to a real cookie
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Return						OUT:1 The text to put in the HTML header
#-----------------------------------------------------------------------------
sub save_cookies
{
	my $self 	=	shift;
   $self->debug(8, "SWS::CommonBase->save_cookies");

	my $domain = $self->config('domain');
	my $expiry = $self->config('cookie_expiry');
	my $return = '';
	
   $self->debug(8, "Domain: $domain, Expiry: $expiry");
	foreach my $cookie_key (keys %{$self->{'cookies'}})
	{
      $self->debug(8, "Saving cookie: $cookie_key");
		my $cookie_value = $self->{'cookies'}->{$cookie_key};
      $cookie_value =~ s/\\/\\\\/g;
      $cookie_value =~ s/:/\\:/g;
      $cookie_value =~ s/;/\\;/g;
      my ($return_code,$checksum) = $self->generate_md5($cookie_value);
      $checksum =~ s/\\/\\\\/g;
      $checksum =~ s/:/\\:/g;
      $checksum =~ s/;/\\;/g;
      $cookie_value .= '::' . $checksum;
		my $cookie = CGI::Cookie->new(-name 	=> $cookie_key,
		  	                         	-value 	=> $cookie_value,
												-domain 	=> $domain,
												-expires => $expiry);
		$return .= "Set-Cookie: $cookie\n";
	}
   $self->debug(8, "Cookie output: $return");
	return $return;
}

#-----------------------------------------------------------------------------
# Function: 	load_template
#-----------------------------------------------------------------------------
# Description:
# 					Loads the template for the current screen, and processes it, 
# 					replacing template variables, adding in the state information 
# 					to all forms
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Template (OUT)			OUT:1	The html ready for output
# Template (IN)			IN:0	Filename of the template to load
# Template variables		IN:1	The template variables
#-----------------------------------------------------------------------------
sub load_template
{
	my $self 		= shift;
	my $filename	= $_[0] || $self-throw_error(ERROR_MISSING_PARAMETER,'Template missing in load template');
	my $variables	= $_[1] || $self->{'tmpl_vars'};

   $self->debug(8, 'CommonBase->load_template');
	
	my $site = $self->{'invoking_site'};
	my $core_path = "$project_path/SWS/WWW/Templates/";
	my $site_path = "$project_path/$site/WWW/Templates/";
	my ($error_code, $template_file_and_path) = 
		$self->find_file([$site_path,$core_path], $filename);
	if($error_code)
   {
	   $self->throw_error($error_code,"Can't find template $filename");
   }
   my $template_file;
	($error_code, $template_file) = 
		$self->read_file([$site_path,$core_path], 'index.html');
	if($error_code)
   {
	   $self->throw_error($error_code,"Can't find template main index file");
   }

   $template_file =~ s/#before_screen/\/include_before.html/g;
   $template_file =~ s/#after_screen/\/include_after.html/g;
   $template_file =~ s/#screen/$template_file_and_path/g;
   
   $self->debug(9, "Template:$template_file");
   
 	my $template;
   eval
   {
		local $SIG{__DIE__};
		$template = HTML::Template->new_scalar_ref(\$template_file,
			'die_on_bad_params' 	=> 0, # Ignore params that aren't in template
			'global_vars' 			=> 1, # Loops have access to all variables
 			'path'					=> [$site_path, $core_path]);
	};
	if ($@)
	{
		$self->throw_error(ERROR_INVALID_TEMPLATE, 
			"Error on template `$filename': $@");
	}

   $self->clean_cgi_vars();
   $self->debug(9, 'cgi_vars');
   $self->debug_dumper(9, $self->{'cgi_vars'});
   $variables->{'state'} = $self->generate_state_string();

	# Fill out the parameters in the template
   $self->debug(9, 'tmpl_vars');
   $self->debug_dumper(9, $self->{'tmpl_vars'});
	$template->param($variables);
   $self->debug(9, 'Loaded tmpl_vars');

	# Now return the template text
	return (ERROR_NONE, $template->output());
}

#-----------------------------------------------------------------------------
# Function: 	output_to_browser
#-----------------------------------------------------------------------------
# Description:
# 					Sends the html to the browser, adding the headers.
# 					If we use compression of html (which is supported by the major 
# 					browsers), this is where that would occur.
# 					This module deals with the different requirements of different 
# 					browsers
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# HTML						IN:0	The html text to send
#-----------------------------------------------------------------------------
sub output_to_browser
{
	my $self 	= shift;
	my $html		= $_[0];
   
   $self->debug(8, 'CommonBase->output_to_browser');
   if($self->{'output_to_browser'} == 1)
   {
      $self->throw_error(ERROR_DOUBLE_OUTPUT, 'Tried to output to HTML twice');
   }
	
	print $self->save_cookies();

	# For now we will not gzip
	
	print "Content-Type: text/html\n\n";
	print $html;

   $self->{'output_to_browser'} = 1;
}

#-----------------------------------------------------------------------------
# Function: 	find_file
#-----------------------------------------------------------------------------
# Description:
# 					Reads in a text file, and returns the content in a scalar
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Content					OUT:1 File contents 
# Path List					IN:0	List of paths to attempt to find from
# Filename					IN:1	Filename
#-----------------------------------------------------------------------------
sub find_file
{
	my $self 		= shift;
	my $path_list 	= $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER, 'path list missing in Common Base find file');
	my $filename 	= $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'filename missing in Common Base find file');

   $self->debug(8, 'CommonBase->find_file');
	# Open the file
	my $fh;
	$self->debug(8, "Find file $filename from path(s) [" . 
		join(',',@{$path_list}) . ']');
	my $index = 0;
	my $path = $path_list->[$index] || $self->throw_error(ERROR_MISSING_PARAMETER, 'Path list is empty in Common Base find file');
	while(! -f ($path . $filename) && $index < @{$path_list})
	{
		$index++;
		$path = $path_list->[$index];
	}
	if($index >= @{$path_list})
	{
		$self->error(ERROR_SEVERITY_FATAL,ERROR_IO_FILE_EXIST,
			"Cannot find file $filename in following paths " .
			join(',',@{$path_list}));
		return ERROR_IO_FILE_EXIST;
	}
	$self->debug(8, "Found $path$filename read successfully");
	return (ERROR_NONE, $path . $filename);
}

#-----------------------------------------------------------------------------
# Function: 	read_file
#-----------------------------------------------------------------------------
# Description:
# 					Reads in a text file, and returns the content in a scalar
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# Content					OUT:1 File contents 
# Path List					IN:0	List of paths to attempt to read from
# Filename					IN:1	Filename
#-----------------------------------------------------------------------------
sub read_file
{
	my $self 		= shift;
	my $path_list 	= $_[0] || $self->throw_error(ERROR_MISSING_PARAMETER, 'path list missing in Common Base read file');
	my $filename 	= $_[1] || $self->throw_error(ERROR_MISSING_PARAMETER,'filename missing in Common Base read file');

   $self->debug(8, 'CommonBase->read_file');
	# Open the file
	my $fh;
	$self->debug(8, "Read in $filename from path(s) [" . 
		join(',',@{$path_list}) . ']');
   my ($error_code, $path_filename) = $self->find_file($path_list, $filename);
   return ($error_code, $path_filename) if($error_code);
	if (!open($fh, ($path_filename)))
	{
		$self->error(ERROR_SEVERITY_FATAL,ERROR_IO_FILE_OPEN, 
			"Cannot open `$path_filename'");
		return ERROR_IO_FILE_OPEN;
	}
	my $content = '';
	# Slurp the whole file in at once
	local $/;
	{
		undef $/;
		$content = <$fh>;
	}
	close($fh);
	$self->debug(8, "$path_filename read successfully");
	return (ERROR_NONE, $content);
}

1;
