package CGI::PathInfo;

#######################################################################
#
# The most current release can always be found at
# <URL:http://www.nihongo.org/snowhare/utilities/>
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE.
#
# Use of this software in any way or in any form, source or binary,
# is not allowed in any country which prohibits disclaimers of any
# implied warranties of merchantability or fitness for a particular
# purpose or any disclaimers of a similar nature.
#
# IN NO EVENT SHALL I BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
# SPECIAL, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
# USE OF THIS SOFTWARE AND ITS DOCUMENTATION (INCLUDING, BUT NOT
# LIMITED TO, LOST PROFITS) EVEN IF I HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE
#
# This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# Copyright 2000 Benjamin Franz and FreeRun Technologies. All Rights Reserved.
#

use strict;
use HTML::Entities ();
use Carp;

use vars qw ($VERSION);
$VERSION = "1.00";

# check for mod_perl and include the 'Apache' module if needed
if (exists $ENV{'MOD_PERL'}) {
    $| = 1;
    require Apache;
}

=head1 NAME

CGI::PathInfo - A lightweight CGI processing package for using PATH_INFO like GET method form parameters

=head1 SYNOPSIS

 use CGI::PathInfo;

 my $path_info = CGI::PathInfo->new;
 my ($form_field_value) = $path_info->param('some_field_name');

=head1 DESCRIPTION

Provides a micro-weight equivalent to the CPAN CGI.pm module
that permits the use of the Apache CGI environment
variable 'PATH_INFO' as a functional equivalent to
the GET method 'QUERY_STRING'.

Rather than attempt to address every possible need of a CGI
programmer, it provides the _minimum_ functions needed for CGI such
as parameter decoding, URL encoding and decoding. 

The parameters decoding interface is somewhat compatible with the
CGI.pm module. No provision is made for generating HTTP or HTML
on your behalf - you are expected to be conversant with how
to put together any HTML or HTTP you need.

=head1 CHANGES

 1.00 21 July 2000  - Initial public release.

=cut

=head1 METHODS

=cut

######################################################################

=over 4

=item new;

Creates a new instance of the CGI::PathInfo object and decodes
any 'PATH_INFO' parameters.

Example:

 use CGI::PathInfo;

 my $path_info = CGI::PathInfo->new;

The defaults are for the parameters to be seperated by '/' characters
with name/value pairs linked by '-' and with leading or trailing
'/' characters ignored.

  Ex:

   $ENV{'PATH_INFO'} = '/yesterday-monday/tomorrow-wednesday';

   decodes to

    'yesterday' -> 'monday'

     'tomorrow' -> 'wednesday'

Values are read using the 'param' method.

Any of the defaults may be overridden by specifying them in the 
invokation of 'new'.

Example:

  my $path_info = CGI::PathInfo->new({  Eq => '=',
                                      SplitOn => '&',
                });

It is probably a Bad Idea (tm) to set the Eq or SplitOn
values to a letter or a number (A-Za-z0-9) unless you
are a wizard at encodings.

The defaults were chosen to maximize the likelyhood that CGI
backed URLs will be crawled by search engines and that
MSIE won't try something stupid because of a '.tla' on a URL.

=back

=cut

sub new {
    my $proto   = shift;
    my $package = __PACKAGE__;
    my $class   = ref ($proto) || $proto || $package;
    my $self    = bless {},$class;

    $self->{$package}->{'field_names'} = [];
    $self->{$package}->{'field'}       = {};
    $self->{$package}->{'settings'} = {
                                       'eq' => '-',
                                  'spliton' => '/',
                        'stripleadingslash' => 1,
                       'striptrailingslash' => 1,
                            };

    my $parms = {};
    if ($#_ == 0) {
        $parms = shift;
    } elsif ($#_ > 0) {
        local $^W = 1;
        %$parms = @_;
    }
    if (ref($parms) ne 'HASH') {
        croak('[' . localtime(time) . "] [error] $package" . '::new() - Passed parameters do not appear to be valid');
    }
    my @parm_keys = keys %$parms;
    foreach my $parm_name (@parm_keys) {
        my $lc_parm_name = lc ($parm_name);
        if (not exists $self->{$package}->{'settings'}->{$lc_parm_name}) {
            croak('[' . localtime(time) . "] [error] $package" . "::new() - Passed parameter name '$parm_name' is not valid here");
        }
        $self->{$package}->{'settings'}->{$lc_parm_name} = $parms->{$parm_name};
    }
    $self->_decode_path_info;

    return $self;
}

#######################################################################

=over 4

=item param([$fieldname]);

Called as C<$path_info-E<gt>param();> it returns the list of all defined
parameter fields in the same order they appear in the data in 
PATH_INFO.

Called as C<$path_info-E<gt>param($fieldname);> it returns the value (or
array of values for multiple occurances of the same field name) assigned
to that $fieldname. If there is more than one value, the values are
returned in the same order they appeared in the data from user agent.
If called in a scalar context when several values are present for
specified parameter, the *first* value will be returned.

Examples:

  my (@form_fields) = $path_info->param;

  my (@multi_pick_field) = $path_info->param('pick_field_name');

  my ($form_field_value) = $path_info->param('some_field_name');

You can also use the param method to set param values to new values.
These values will be returned by this CGI::PathInfo object
as if they had been found in the originally processed PATH_INFO data. This
will not affect a seperately created instance of CGI::PathInfo.

Examples:

    $path_info->param( 'name' => 'Joe Shmoe' );

    $path_info->param({ 'name' => 'Joe Shmoe', 'birth_date' => '06/25/1966' });

    $path_info->param({ 'pick_list' => ['01','05','07'] });

=back

=cut

sub param {
    my $self = shift;
    my $package = __PACKAGE__;

    if (1 < @_) {
        my $n_parms = @_;
        if (($n_parms % 2) == 1) {
            croak('[' . localtime(time) . "] [error] $package" . "::param() - Odd number of parameters  passed");
        }
        my $parms = { @_ };
        $self->_set($parms);
        return;
    }
    if ((@_ == 1) and (ref ($_[0]) eq 'HASH')) {
        my $parms = shift;
        $self->_set($parms);
        return;
    }

    my @result = ();
    if ($#_ == -1) {
        @result = @{$self->{$package}->{'field_names'}};
    } elsif ($#_ == 0) {
        my ($fieldname)=@_;
        if (defined($self->{$package}->{'field'}->{$fieldname})) {
            @result = @{$self->{$package}->{'field'}->{$fieldname}->{'value'}};
        }
    }
    if (wantarray) {
        return @result;
    } elsif ($#result > -1) {
        return $result[0];
    } else {
        return;
    }
}

#######################################################################

=over 4

=item calling_parms_table;

Returns a formatted HTML table containing all the PATH_INFO parameters 
for debugging purposes

Example:

  print $path_info->calling_parms_table;

=back

=cut

sub calling_parms_table {
    my $self = shift;
    my $package = __PACKAGE__;

    my $outputstring = "<table border=\"1\ cellspacing=\0\> <tr> <th colspan=\"2\">PATH_INFO Fields</th> </tr> <tr> <th>Field</th> <th>Value</th> </tr>\n";
    my @field_list = $self->param;
    foreach my $fieldname (sort @field_list) {
        my @values = $self->param($fieldname);
        my $sub_field_counter= $#values;
        for (my $fieldn=0; $fieldn <= $sub_field_counter; $fieldn++) {
            my $e_fieldname = HTML::Entities::encode_entities($fieldname);
            my $fieldvalue  = HTML::Entities::encode_entities($values[$fieldn]);
            $outputstring .= "<tr> <td>$e_fieldname (#$fieldn)</td> <td> $fieldvalue </td> </tr>\n";
        }
    }

    $outputstring .= "</table>\n";

    return $outputstring;
}

#######################################################################

=over 4

=item url_encode($string);

Returns a URL encoding of the input string.
Anything except 0-9a-zA-Z is escaped to %xx form.

The idea is to reserve all other characters for potential use
as parameter or key/value seperators.

Example:

 my $url_encoded_string = $path_info->url_encode($string);

=back

=cut

sub url_encode {
    my $self   = shift;
    my ($line) = @_;

    return '' if (! defined ($line));
    $line =~ s/([^a-zA-Z0-9])/"\%".unpack("H",$1).unpack("h",$1)/egs;
    return $line;
}

#######################################################################

=over 4

=item url_decode($string);

Returns URL *decoding* of input string (%xx substitutions
are decoded to their actual values).

Example:

 my $url_decoded_string = $path_info->url_decode($string);

=back

=cut

sub url_decode {
    my $self   = shift;
    my ($line) = @_;

    return '' if (! defined ($line));
    $line =~ s/\+/ /gos;
    $line =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/egs;
    return $line;
}


########################################################################
# Performs PATH_INFO decoding

sub _decode_path_info {
    my $self = shift;
    my $package = __PACKAGE__;

    my $buffer;
    if (exists $ENV{'MOD_PERL'}) {
              $buffer = Apache->request->path_info;
    } else {
              $buffer = $ENV{'PATH_INFO'} if (defined $ENV{'PATH_INFO'});
    }
    $buffer = '' if (not defined $buffer);
    $self->_burst_URL_encoded_buffer($buffer);

    return;
}

##########################################################################
# Bursts normal URL encoded buffers
# Takes: $buffer   - the actual data to be burst
#
# parameters are presumed to be seperated by ';' characters
#

sub _burst_URL_encoded_buffer {
    my $self = shift;
    my $package = __PACKAGE__;

    my ($buffer) = @_;
    my $settings = $self->{$package}->{'settings'};
    if ($settings->{'strip_leading_slash'})  { $buffer =~ s#^/+##s; }
    if ($settings->{'strip_trailing_slash'}) { $buffer =~ s#/+$##s; }

    my $spliton  = $settings->{'spliton'};
    my $eq_mark  = $settings->{'eq'};

    # Split the name-value pairs on the selected split char
    my @pairs = ();
    if ($buffer) {
        @pairs = split(/$spliton/, $buffer);
    }

    # Initialize the field hash and the field_names array
    $self->{$package}->{'field'}       = {};
    $self->{$package}->{'field_names'} = [];

    foreach my $pair (@pairs) {
        my ($name, $data) = split(/$eq_mark/,$pair,2);

        # Anything that didn't split is omitted from the output
        next if (not defined $data);

        # De-URL encode %-encoding
        $name = $self->url_decode($name);
        $data = $self->url_decode($data);

        if (! defined ($self->{$package}->{'field'}->{$name}->{'count'})) {
            push (@{$self->{$package}->{'field_names'}},$name);
            $self->{$package}->{'field'}->{$name}->{'count'} = 0;
        }
        my $record      = $self->{$package}->{'field'}->{$name};
        my $field_count = $record->{'count'};
        $record->{'count'}++;
        $record->{'value'}->[$field_count]     = $data;
    }
    return;
}

##################################################################
#
# Sets values into the object directly
# Pass an anon hash for name/value pairs. Values may be
# anon lists or simple strings
#
##################################################################

sub _set {
    my $self = shift;
    my $package = __PACKAGE__;

    my $parms = {};
    if (1 < @_) {
        $parms = { @_ };
    } elsif ((1 == @_) and (ref($_[0]) eq 'HASH')) {
        ($parms) = @_;
    } else {
        croak ('[' . localtime(time). "] [error] $package"  . '::_set() - Invalid or no parameters passed');
    }
    foreach my $name (keys %$parms) {
        my $value = $parms->{$name};
        my $data  = [];
        my $data_type = ref $value;
        if (not $data_type) {
            $data = [ $value ];
        } elsif ($data_type eq 'ARRAY') {
            # Shallow copy the anon array to prevent action at a distance
            @$data = map {$_} @$value;
        } else {
            croak ('[' . localtime(time) . "] [error] $package"  . "::_set() - Parameter '$name' has illegal data type of '$data_type'");
        }

        if (! defined ($self->{$package}->{'field'}->{$name}->{'count'})) {
            push (@{$self->{$package}->{'field_names'}},$name);
        }
        my $record = {};
        $self->{$package}->{'field'}->{$name} = $record;
        $record->{'count'} = @$data;
        $record->{'value'} = $data;
    }
    return;
}

##########################################################################

=head1 BUGS

None known.

=head1 TODO

Who knows?

=head1 AUTHORS

Benjamin Franz <snowhare@nihongo.org>

=head1 VERSION

Version 1.00 22 July 2000

=head1 COPYRIGHT

Copyright (c) Benjamin Franz and FreeRun Technologies July 2000. All rights reserved.

 This program is free software; you can redistribute it
 and/or modify it under the same terms as Perl itself.

=cut

1;
