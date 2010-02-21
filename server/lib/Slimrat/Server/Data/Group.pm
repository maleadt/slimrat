################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Data::Group;

=pod

=head1 NAME

Slimrat::Server::Data::Group - Slimrat download data object

=head1 DESCRIPTION

The C<Slimrat::Server::Data::Group> package provides a tiny data object which
contains a group and all its obliged attributes. It also includes a
dynamic way to request related objects through lazy attributes and a reference
to the active backend.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use Slimrat::Server::Data qw(:propagation);

# Consume roles
with 'Slimrat::Server::Data';

# Write nicely
use strict;
use warnings;

# Constants
use constant KEYS_FILTER_UNIQUE => [qw{name}];
use constant KEYS_FILTER_REGULAR => [qw{restrictionids}];
use constant KEYS_DATASET => [qw{name directory restrictionids}];


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<name>

This attribute uniquely identifies a group. It is used to distinguish
differend groups, as well as create links to other data structures.

It is a read-only attribute, which means a group cannot change its name
after creation.

=cut

has 'name' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

=pod

=head2 C<directory>

This is the target directory to which the files will be downloaded. This
directory is only read from a Download object if that object has not set
a directory itself (and the C<deep_lookup> flag is set).

This is a writable value, which'll trigger a backend update if the C<propagate>
flag is set.

=cut

has 'directory' => (
	is		=> 'rw',
	isa		=> 'Str',
	trigger		=> \&_trigger_directory
);

sub _trigger_directory {
	my ($self, $value) = @_;
	return unless ($self->propagation == PROP_UPDATE);
	
	$self->backend->update_group(
		{ name => $self->name },
		{ directory => $value }
	);
}

=pod

=head2 C<restrictionids>

This attribute links the group to a set of restrictions by their ID. It is a
read-write accessor, which upon write will force an update to the backend if
the propagate bit is set.

=cut

# Definition
has 'restrictionids' => (
	is		=> 'rw',
	isa		=> 'ArrayRef',
	trigger		=> \&_trigger_restrictionids,
	predicate	=> 'has_restrictionids'
);

# Propagation-handling of restriction IDs
sub _trigger_restrictionids {
	my ($self, $value) = @_;
	delete $self->{restrictions};
	return unless ($self->propagation == PROP_UPDATE);
	
	$self->backend->update_group(
		{ name => $self->name },
		{ restrictionids => $value }
	);
}

=pod

=head2 C<restrictions>

This attribute provides some sugar to prevent working with raw restrictin ID's.
It provides an accessor to an array of Restriction objects, which upon read will
do some extra fetches from the backend to provide those object, which contains
more data then only the restriction ID.

When writing to this accessor, the IDs will get extracted and the write accessor
of the C<restrictionids> attribute will bevset to (eventually) trigger a write to
the backend.

=cut

# Definition
has 'restrictions' => (
	is		=> 'rw',
	isa		=> 'ArrayRef[Slimrat::Server::Data::Restriction]',
	trigger		=>  \&_trigger_restrictions,
	lazy		=> 1,
	builder		=> '_build_restrictions'
);

# Lazy-value
sub _build_restrictions {
	my ($self) = @_;
	return unless ($self->has_restrictionids);
	
	my @restrictions;
	foreach my $restrictionid (@{$self->restrictionids}) {
		my $restriction = $self->backend->get_restriction(
			id => $restrictionid
		);
		push(@restrictions, $restriction);
	}
	return \@restrictions;
}

# Propagation handling of Restriction objects
sub _trigger_restrictions {
	my ($self, $value) = @_;
	
	my @restrictionids;
	foreach my $restriction (@{$value}) {
		push(@restrictionids, $restriction->id);
	}
	$self->restrictionids(\@restrictionids);
}


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;
	
	# Object creation
	if ($self->propagation == PROP_ADD) {
		my %dataset = ();
		foreach my $key (@{KEYS_DATASET()}) {
			my $value = $self->{$key};
			if (defined $value) {
				$dataset{$key} = $value;
			}
		}
		$self->backend->add_group(%dataset);
		$self->propagation(PROP_OFF);	# TODO?
	}
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
