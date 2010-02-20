################################################################################
# Configuration
#
## NAME		= console
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= console logger
## LICENSE	= Perl Artistic 2.0

# Package definition
package Slimrat::Server::Plugin::Logger::Console;

=pod

=head1 NAME

Slimrat::Server::Plugin::Logger::Console - Slimrat console logger plugin

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Logger::Console> package implements a logger
which outputs all data to the console (in an appropriate way).

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use Term::ANSIColor qw(:constants);
use Slimrat::Server::Plugin::Logger;

# Consume roles
with 'Slimrat::Server::Plugin::Logger';

# Write nicely
use strict;
use warnings;

################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;
	
}

=pod

=head2 C<output(%data)>

Internally-used method to display data. It accepts a data hash, which can
contain the following keys:
=over
=item colour: the colour which'll prefix the messages
=item messages: an array reference containing messages
=back

=cut

sub output {
	my ($self, %data) = @_;
	$data{colour} = RESET unless defined $data{colour};
	my @messages = @{delete $data{messages}};
	
	# Messages with endlines should get get prefixed as well
	@messages = map { split(/\n/, $_) } @messages;
	
	# Compose a message prefix
	my $prefix = "";
	$prefix .= '[' . ucfirst ($self->section || "Main") . '] ';
	my $prefix_alt = " " x length($prefix);
	$prefix .= timestamp() . ' ';
	
	# Print it	
	print $data{colour}, $prefix;
	for (my $i = 0; $i <= $#messages; $i++) {
		$_ = ucfirst $messages[$i];
		print $prefix_alt if ($i);
		print $_, "\n";
	}
	print RESET;
}

=pod

=head2 debug(@messages)
=head2 verbose(@messages)
=head2 info(@messages)
=head2 warning(@messages)
=head2 error(@messages)
=head2 fatal(@messages)

See L<Slimrat::Server::Plugin::Logger> for an explanation of these methods.

=cut

sub debug {
	my $self = shift;
	$self->output(
		colour		=> CYAN,
		messages	=> \@_,
	);
}

sub verbose {
	my $self = shift;
	$self->output(
		colour		=> GREEN,
		messages	=> \@_,
	);
}

sub info {
	my $self = shift;
	$self->output(
		messages	=> \@_,
	);
}

sub warning {
	my $self = shift;
	$self->output(
		colour		=> YELLOW,
		messages	=> \@_,
	);
}

sub error {
	my $self = shift;
	$self->output(
		colour		=> RED,
		messages	=> \@_,
	);
}

sub fatal {
	my $self = shift;
	$self->output(
		colour		=> RED,
		messages	=> \@_,
	);
}

1;

__END__

=pod

=head1 CONFIGURATION

This plugin does not require any configuration.

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
