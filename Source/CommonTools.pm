#!/usr/bin/perl -w
#-----------------------------------------------------------------------------
# Module: 		CommonTools
#-----------------------------------------------------------------------------
# Description:
# 					Multiple inherited, and supplies functionality used more than 
# 					once
#-----------------------------------------------------------------------------
# CVS Details
# -----------
# $Author: kerrin $
# $Date: 2003/09/27 15:14:50 $
# $Revision: 1.14 $
#-----------------------------------------------------------------------------
package SWS::Source::CommonTools;
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
	@ISA = qw(Exporter);
	@EXPORT = qw(
      OVERWRITE_IGNORE OVERWRITE_DELETE_ONLY 
      OVERWRITE_ERROR OVERWRITE_MOVE_ANYWAY
   );
}

use SWS::Source::Error;
use SWS::Source::Log;
use SWS::Source::Constants;

use constant OVERWRITE_IGNORE          => 1;
use constant OVERWRITE_DELETE_ONLY     => 2;
use constant OVERWRITE_ERROR           => 3;
use constant OVERWRITE_MOVE_ANYWAY     => 4;

#-----------------------------------------------------------------------------
# Function: 	authenticate_member
#-----------------------------------------------------------------------------
# Description:
# 					Authenticate a member log on, with the database
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# User ID					OUT:0	The member identifier number of the member logged on
# Username					IN:0	Usernames are e-mail addresses
# Password					IN:1	Password to log on with
#-----------------------------------------------------------------------------
sub authenticate_member
{
	my $self 		=	shift;
	my $username	= $_[0];
	my $password	= $_[1];

   $self->debug(8, "CommonTools->authenticate_member($username,password)");
	my ($error_code, $results) = $self->db_select('check_member',
											{'member' => $self->config('member_table')},
											$username,$password);
	return $error_code if($error_code);
	unless(defined($results) && @{$results} == 1)
	{
		return ERROR_INVALID_USER;
	}
   $self->{'cgi_vars'}->{'member_ID'} = $self->{'state'}->{'member_ID'} = 
      $results->[0]->{'ID'};

   my $update =
      {
         '#last_logon'  => 'NOW()'
      };
   $error_code = $self->db_update($self->config('member_table'), $update, 
      {'ID' => $self->{'cgi_vars'}->{'member_ID'}});

	return ($error_code, $self->{'cgi_vars'}->{'member_ID'});
}

#-----------------------------------------------------------------------------
# Function: 	log_off
#-----------------------------------------------------------------------------
# Description:
# 					Logs the member off
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return                OUT:0 User ID if logged on, 0 otherwise
#-----------------------------------------------------------------------------
sub log_off
{
	my $self 		=	shift;

	delete $self->{'state'}->{'member_ID'};
	delete $self->{'cgi_vars'}->{'member_ID'};
}

#-----------------------------------------------------------------------------
# Function: 	logged_on
#-----------------------------------------------------------------------------
# Description:
# 					Returns member ID if a member is logged on
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return                OUT:0 User ID if logged on, 0 otherwise
#-----------------------------------------------------------------------------
sub logged_on
{
	my $self 		=	shift;

   $self->debug(8, 'Logged on:' . ($self->{'state'}->{'member_ID'}||0));
   $self->debug(8, 'Logged on:' . ($self->{'cgi_vars'}->{'member_ID'}||0));
   my $logged_on = $self->{'state'}->{'member_ID'} ||
                   $self->{'cgi_vars'}->{'member_ID'} || 0;
	return $logged_on;
}

#-----------------------------------------------------------------------------
# Function: 	member_details
#-----------------------------------------------------------------------------
# Description:
# 					Returns the current members details
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return                OUT:0 User details hash
# Member ID             IN:0  [Optional] The member to get details for
#                             If not passed in, uses current member
#-----------------------------------------------------------------------------
sub member_details
{
	my $self 		=	shift;
	my $member_ID    =	$_[0] || $self->logged_on() || 
      $self->throw_error(ERROR_INVALID_PARAMETER,
         'No member logged on in member_details');

	my ($error_code, $results) = $self->db_select('get_member_details',
											{'member' => $self->config('member_table')},
											$member_ID);
	if($error_code)
   {
	   $self->throw_error($error_code,'Select Error in member_details');
   }
	unless(defined($results) && @{$results} == 1)
	{
		return ERROR_INVALID_USER;
	}
	return $results->[0];
}

#-----------------------------------------------------------------------------
# Function:    gender
#-----------------------------------------------------------------------------
# Description:
#              Returns a string name for the gender ID
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Gender Name           OUT:0 The gender name
# gender ID             IN:0  The gender to identify
#-----------------------------------------------------------------------------
sub gender
{
   my $self       =  shift;
   my $gender_ID  = $_[0];
   
   my $gender_name = 'ERROR';
   if($gender_ID == GENDER_MALE)
   {
      $gender_name = 'Male';
   } elsif($gender_ID == GENDER_FEMALE) {
      $gender_name = 'Female';
   } elsif($gender_ID == GENDER_NONE) {
      $gender_name = 'None';
   }
   return $gender_name;
}

#-----------------------------------------------------------------------------
# Function:    age
#-----------------------------------------------------------------------------
# Description:
#              Returns the age today, given a data of birth
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Age                   OUT:0 The age of the person
# Date Of Birth         IN:0  The date of birth of the person
#-----------------------------------------------------------------------------
sub age
{
   my $self    =  shift;
   my $dob     = $_[0];
   
   unless($dob =~ /^(\d{4})-(\d{2})-(\d{2})$/)
   {
      $self->throw_error(ERROR_INVALID_PARAMETER, 
         'Date of birth not recognised:' . $dob);
   }
   my ($dob_year,$dob_month,$dob_day) = ($1,$2,$3);
   my @time = localtime(time);
   my $age = $time[3] + 1900 - $dob_year;

   # If they haven't had a birthday yet, we just aged them one year, so ...
   $time[4]++;
   if($dob_month == $time[4])
   {
      # There birthday is this month, so if the day is later this month
      # they are actually 1 year younger
      $age-- if($dob_day < $time[5]);
   } elsif($dob_month > $time[4]) {
      # There birthday is later this year, so they are actually 1 year younger
      $age-- if($dob_day < $time[5]);
   }
   
   return $age;
}

#-----------------------------------------------------------------------------
# Function: 	add_member
#-----------------------------------------------------------------------------
# Description:
# 					Adds a basic member to the database, any additional data 
# 					associated with the member should be added with a separate 
# 					function
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# User ID               OUT:1 The member identifier number of the member added
# User Details          IN:0  A hash containing the member details to add
#-----------------------------------------------------------------------------
sub add_member
{
	my $self 	=	shift;
	my $details = $_[0];

   $self->debug(8, 'CommonTools->add_member');
   unless(  exists($details->{'username'}) &&
            exists($details->{'password'}) &&
            exists($details->{'screen_name'}) &&
            exists($details->{'firstname'}) &&
            exists($details->{'surname'}) &&
            exists($details->{'dob'}) &&
            exists($details->{'gender_ID'}) &&
            exists($details->{'state_ID'})
         )
   {
      $self->error(ERROR_SEVERITY_ERROR, ERROR_MISSING_PARAMETER, 
         'Required parameter missing for add member');
      return ERROR_MISSING_PARAMETER;
   }

   # Remeber to encrypt the password
   $details->{'#password'} = "ENCRYPT('" . $details->{'password'} . "','SW')";
   delete $details->{'password'};

   $details->{'#registered'} = 'NOW()';
   return $self->db_insert($self->config('member_table'), $details);
}

#-----------------------------------------------------------------------------
# Function: 	update_member
#-----------------------------------------------------------------------------
# Description:
# 					Modify a members basic details
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Error Response Code	OUT:0	0 successful, or an error code
# User ID               IN:0	The member identifier number of the member added
# Username              IN:1  Usernames are e-mail addresses
# Password              IN:2  Password to log on with
# Status                IN:3  The member state (pending,enabled,disabled,banned)
#-----------------------------------------------------------------------------
sub update_member
{
	my $self 		=	shift;
	my $member_ID	= $_[0];
	my $details    = $_[1];
   $self->debug(8, 'CommonTools->update_member');

   return $self->db_update($self->config('member_table'), 
         {'ID' => $member_ID},
         $details);
}

#-----------------------------------------------------------------------------
# Function:    move_from_cgi_vars_to_tmpl_vars
#-----------------------------------------------------------------------------
# Description:
#              Used to move fields from cgi_vars to the tmpl_vars
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name                  Type  Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 The return code, 0 for ok
# Fields                IN:0  The field list to move
# Overwrite             IN:1  The overwrite action (Ignore,delete anyway,error)
#-----------------------------------------------------------------------------
sub move_from_cgi_vars_to_tmpl_vars
{
   my $self       = shift;
   my $fields     = $_[0];
   my $overwrite  = $_[1] || OVERWRITE_MOVE_ANYWAY;

   $self->debug(8, 'ResultBase::move_from_cgi_vars_to_tmpl_vars');
   foreach my $field (@{$fields})
   {
      $self->debug(8, "Processing field $field");
      if(exists($self->{'tmpl_vars'}->{$field}))
      {
         $self->debug(8, "Field $field exists already");
         if($overwrite == OVERWRITE_IGNORE)
         {
            $self->debug(8, "Ignoring field $field");
            next;
         } elsif($overwrite == OVERWRITE_DELETE_ONLY) {
            $self->debug(8, "Only deleting field $field");
            delete $self->{'cgi_vars'}->{$fields};
            next;
         } elsif($overwrite == OVERWRITE_ERROR) {
            $self->throw_error(ERROR_INVALID_PARAMETER, 
               "ResultBase->copy_and_delete:$field exists in tmpl_var already");
         }
         $self->debug(8, 'Proceeding as normal');
      }
      $self->{'tmpl_vars'}->{$field} = $self->{'cgi_vars'}->{$field};
      delete $self->{'cgi_vars'}->{$field};
   }
}

#-----------------------------------------------------------------------------
# Function: 	parse_string
#-----------------------------------------------------------------------------
# Description:
# 					Does variable replacement on a string
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# parsed string         OUT:0 The parsed string
# string                IN:0  The string to parse
# variables             IN:1  The variables to put in
#-----------------------------------------------------------------------------
sub parse_string
{
	my $self 	   =	shift;
   my $string     = $_[0];
   my $variables  = $_[1];

   $self->debug(8, 'SWS::CommonTools->parse_string');
   foreach my $key (keys %{$variables})
   {
      $string =~ s/#$key/$variables->{$key}/g;
      $self->debug(8, "the key is $key the value is $variables->{$key}");
   }
   while($string =~ s/#(\w*)//g)
   {
      $self->error(ERROR_SEVERITY_WARNING, ERROR_IO_PARSE, 
         "Unreplaced variable ($1) in SWS::CommonTools->parse_string");
   }
   $self->debug(7, "The string now is $string");
   
   return $string;
}

#-----------------------------------------------------------------------------
# Function: 	send_email
#-----------------------------------------------------------------------------
# Description:
# 					Send an email out
#-----------------------------------------------------------------------------
# Parameters
# ----------
# Name						Type	Usage
# --------------------- ----- ------------------------------------------------
# Return Code           OUT:0 0 on success, error code otherwise
# Email details         IN:0  The details of the email in a hash
#-----------------------------------------------------------------------------
sub send_email
{  
   my $self = shift;
   my $email_details = $_[0]  || return ERROR_MISSING_PARAMETER;
   
   $self->debug(8, "SWS::CommonTools->send_email");
   
   my $from = $email_details->{'from'} || return ERROR_MISSING_PARAMETER;
   my $subject = $email_details->{'subject'} || return ERROR_MISSING_PARAMETER;
   my $content_type =  $email_details->{'content-type'} || '';
   my $to = $email_details->{'to'} || return ERROR_MISSING_PARAMETER;
   my $message = $email_details->{'message'} || '';

   $self->debug(8, "Email to $to");

   # Use sendmail to send the mail to the user
   my $sendmailfh;
   my $sendmail_call = $self->config('sendmail_call');

   open($sendmailfh, "$sendmail_call")
     or return ERROR_IO_FILE_OPEN;

   $self->debug(8, "About to print to SENDMAIL");

   print $sendmailfh <<"EOF";
From: $from
To: $to
Subject: $subject
Content-type: $content_type

$message
EOF

   close($sendmailfh)
     or warn "sendmail didn't close nicely";

   $self->debug(8, "All emails OK. I should return fine");

   return ERROR_NONE;
}

1;
