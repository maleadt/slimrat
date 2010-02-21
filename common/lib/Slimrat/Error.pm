################################################################################
# Configuration
#

# Package definition
package Slimrat::Error;

=pod

=head1 NAME

Slimrat::Error - Slimrat protocol error codes

=head1 DESCRIPTION

The C<Slimrat::Error> package provides definitions and auxiliary methods to
process errorcodes received by the server. 

=head1 SYNPOSIS

=cut

# Packages
require 5.002;   # because we use prototypes

# Write nicely
use strict;
use warnings;

# Exporter
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(error_system error_service error_method error_message);


################################################################################
# Constants
#

=pod

=head1 CONSTANTS

The following constant functions can be used as mnemonic error code
names.  None of these are exported by default.  Use the C<:constants>
tag to import them all.
   
   SLIMRAT_VERSION_NOT_SUPPORTED        (0)
   
   SLIMRAT_INTERNAL_FAILURE             (10)
   SLIMRAT_BACKEND_FAILURE              (11)
   
   SLIMRAT_SERVICE_UNAVAILABLE          (20)
   
   SLIMRAT_NOT_FOUND                    (21)

=cut

# Error codes
my %ErrorCode = (
    0	=> 'Version Not Supported',
    
    # System failures
    1	=> 'Internal Failure',
    2	=> 'Backend Failure',
    
    # Service issues
    10	=> 'Service Unavailable',
    
    # Method issues
    20	=> 'Not Found',
    21	=> 'Bad Request'
);

# Mnemonic-generation
my $mnemonicCode = '';
my ($code, $message);
while (($code, $message) = each %ErrorCode) {
    # create mnemonic subroutines
    $message =~ tr/a-z \-/A-Z__/;
    $mnemonicCode .= "sub SLIMRAT_$message () { $code }\n";
    $mnemonicCode .= "push(\@EXPORT_OK, 'SLIMRAT_$message');\n";
}
eval $mnemonicCode; # only one eval for speed
die if $@;

# Export mnemonics
%EXPORT_TAGS = (
	constants	=> [grep /^SLIMRAT_/, @EXPORT_OK],
	error		=> [grep /^error_/, @EXPORT, @EXPORT_OK],
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=head2 C<error_message($code)>

The error_message() function will translate error codes to human
readable strings. The string is the same as found in the constant
names above.  If the $code is unknown, then C<undef> is returned.

=cut

sub error_message {
	return $ErrorCode{$_[0]};
}

=pod

=head2 C<error_system($code)>

Return TRUE if C<$code> represents a I<System Error> error message (0x).

=cut

sub error_system {
	return ($_[0] >= 1  && $_[0] < 10);
}

=pod

=head2 C<error_service($code)>

Return TRUE if C<$code> represents a I<Service Error> error message (1x).

=cut

sub error_service {
	return ($_[0] >= 10 && $_[0] < 20);
}

=pod

=head2 C<error_method($code)>

Return TRUE if C<$code> represents a I<Method Error> error message (2x).

=cut

sub error_method {
	return ($_[0] >= 20 && $_[0] < 30);
}

1;

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
