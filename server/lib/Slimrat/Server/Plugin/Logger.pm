################################################################################
# Configuration
#
## NAME		= logger
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= logger base plugin
## LICENSE	= Perl Artistic 2.0
## TYPE		= abstract

# Package definition
package Slimrat::Server::Plugin::Logger;

=pod

=head1 NAME

Slimrat::Server::Plugin::Logger - Slimrat logger base plugin

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Logger> package contains base functionality for
all logger plugins. It provides some ready-to-use routines, as well as some

=head1 SYNPOSIS

=cut

# Packages
use Moose::Role;
use Slimrat::Server::Plugin;

# Roles
with 'Slimrat::Server::Plugin';

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=cut

has 'section' => (
	is		=> 'rw',
	isa		=> 'Str',
	predicate	=> 'has_section'
);


################################################################################
# Methods
#

# todo: trap sigdie and sigwarn in build and reroute to self

=pod

=head1 METHODS

=cut

before 'BUILD' => sub {
	my ($self) = @_;
	
	# Default configuration
	$self->config->set_default('verbosity', 3);
};

=pod

# TODO: wrap all in single method? qw/debug info/ verbosity <= indexof?

=head2 C<$logger->debug(@messages)>

A debug message. This is a message which is of no use to an end-user, but
provides useful information for developers to debug problems.

Requires verbosity to be 5 or higher.

# TODO: duplicate this piece of doc, in the single wrapper method
Passed messages logically belong together, but should each get outputted on a 
separate line (as far as that applies to the implementation)

=cut

requires 'debug';

around 'debug' => sub {
	my ($sub, $self, @params) = @_;
	
	$self->$sub(@params) if $self->config->get('verbosity') >= 5;
};

=pod

=head2 C<$logger->verbose(@messages)>

An verbose message. These messages give end-users extra insight in what
slimrat is doing right now, but aren't required.

Requires verbosity to be 4 or higher.

=cut

requires 'verbose';

around 'verbose' => sub {
	my ($sub, $self, @params) = @_;
	
	$self->$sub(@params) if $self->config->get('verbosity') >= 4;
};

=pod

=head2 C<$logger->info(@messages)>

An informative message. These messages are usefull to a regular end user, and
is thus the default verbosity level.

Requires verbosity to be 3 or higher.

=cut

requires 'info';

around 'info' => sub {
	my ($sub, $self, @params) = @_;
	
	$self->$sub(@params) if $self->config->get('verbosity') >= 3;
};

=pod

=head2 C<$logger->warning(@messages)>

A warning message. This is to be used when something unexpected happened, but
the execution of the task was not interrupted.

Requires verbosity to be 2 or higher.

=cut

requires 'warning';

around 'warning' => sub {
	my ($sub, $self, @params) = @_;
	
	$self->$sub(@params) if $self->config->get('verbosity') >= 2;
};

=pod

=head2 C<$logger->error(@messages)>

An error message indicating a subsystem failure. If this error is to be expected,
one should trap the error and continue executing. If unexpected, the untrapped
die kills the server.

Requires verbosity to be 1 or higher.

=cut

requires 'error';

around 'error' => sub {
	my ($sub, $self, @params) = @_;
	
	$self->$sub(@params) if $self->config->get('verbosity') >= 1;
	die("looger-reported error, see above for details\n");
};

=pod

=head2 C<$logger->fatal(@messages)>

A fatal error. This instantly halts the application, and cannot be trapped.

Requires verbosity to be 0 or higher.

=cut

requires 'fatal';

around 'fatal' => sub {
	my ($sub, $self, @params) = @_;
	
	$self->$sub(@params) if $self->config->get('verbosity') >= 0;
	
	CORE::exit(1);	# TODO: seems to get trapped, maybe provide some exit handler
	# to be provided to the logger
};

=pod

=head2 C<$logger->get_section($section)>

Split of a logger specialized for a certain subsection. This creates a shallow 
copy of the logger object, and sets the C<section> attribute. How this affects
the behaviour of the logger is not specified. Plugins might also check in their
DEMOLISH functionality whether the logger is a subsection, as certain code
(eg. the destruction of a handle) should only be executed once.

=cut

sub get_section {
	my ($self, @params) = @_;
	my $section = shift @params;
	
	# Create shallow copy
	my $logger = { %$self };
	bless $logger, ref $self;
	$logger->section($section);
	return $logger;
}



################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=head2 C<timestamp>

Generate a ISO 8601 compliant timestamp, date and time combined in a single
string without whitespace (YYYY-MM-DDThh:mmZ, with T and Z being characters).
This timestamp is based on the UTC time provided by Perl's C<gmtime> function.

=cut

sub timestamp {
	my ($sec, $min, $hour, $day, $mon, $year) = gmtime;
	sprintf "%04d-%02d-%02dT%02d:%02dZ", $year+1900, $mon+1, $day, $hour, $min, $sec;
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

