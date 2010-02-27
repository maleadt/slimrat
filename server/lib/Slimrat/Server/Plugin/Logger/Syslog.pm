################################################################################
# Configuration
#
## NAME		= syslog
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= syslog plugin
## LICENSE	= Perl Artistic 2.0

# Package definition
package Slimrat::Server::Plugin::Logger::Syslog;

=pod

=head1 NAME

Slimrat::Server::Plugin::Logger::Syslog - Slimrat syslog plugin

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Logger::Syslog> package implements a logger
which rerouts all messages to a syslog interface.

=head1 SYNPOSIS

=cut

# Packages
require 5.004_02;
use Moose;
use Sys::Syslog 0.25 qw(:DEFAULT setlogsock);
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
	my $self = shift;
	
	# Setup configuration
	$self->config->set_default('type', undef);
	$self->config->set_default('location', undef);
	
	# Connect using a custom socket
	if (defined($self->config->get('type'))) {
		if (defined($self->config->get('location'))) {
			setlogsock(	$self->config->get('type'),
					$self->config->get('location'));
		} else {
			setlogsock(	$self->config->get('type'));
		}
	} elsif (defined($self->config->get('location'))) {
		croak('Custom location requires "type" to be defined as well');
	}
	
	# Connect to the syslog server
	openlog(
		'slimrat',
		'',
		Sys::Syslog::LOG_USER		
	);
}

sub DEMOLISH {
	my $self = shift;
	
	closelog unless $self->has_section;
}

=pod


=head2 C<output(%data)>

Internally-used method to display data. It accepts a data hash, which can
contain the following keys:
=over
=item level: the message severity in C<Sys::Syslog>-typed severity levels
=item messages: an array reference containing messages
=back

=cut

sub output {
	my ($self, %data) = @_;
	my @messages = @{delete $data{messages}};
	die("Output called with insufficient data") unless (defined $data{level});
	
	for my $message (@messages) {
		syslog(
			$data{level},
			$message
		);
	}
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
		level		=> Sys::Syslog::LOG_DEBUG,
		messages	=> \@_
	);
}

sub verbose {
	my $self = shift;
	$self->output(
		level		=> Sys::Syslog::LOG_INFO,
		messages	=> \@_
	);
}

sub info {
	my $self = shift;
	$self->output(
		level		=> Sys::Syslog::LOG_INFO,
		messages	=> \@_
	);
}

sub warning {
	my $self = shift;
	$self->output(
		level		=> Sys::Syslog::LOG_WARNING,
		messages	=> \@_
	);
}

sub error {
	my $self = shift;
	$self->output(
		level		=> Sys::Syslog::LOG_ERR,
		messages	=> \@_
	);
}

sub fatal {
	my $self = shift;
	$self->output(
		level		=> Sys::Syslog::LOG_EMERG,
		messages	=> \@_
	);
}

1;

__END__

=pod

=head1 CONFIGURATION

=head2 C<type>

Optional value, instructs C<Sys::Syslog->setlogsock> to connect over another
socket type. Popular types are C<tcp> and C<udp> (or combined C<inet>).
Must be set if C<location> is set as well.

B<Default>: undef.

=head2 C<location>

Optional value, makes C<Sys::Syslog> connect to a different server.
If set, C<type> must be set as well.

B<Default>: undef.

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
