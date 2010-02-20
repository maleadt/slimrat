################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Data::Download;

=pod

=head1 NAME

Slimrat::Server::Data::Download - Slimrat download data object

=head1 DESCRIPTION

The C<Slimrat::Server::Data::Download> package provides a tiny data object which
contains a download and all its obliged attributes. It also includes a
dynamic way to request related objects through lazy attributes and a reference
to the active backend.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use Slimrat::Server::Data;

# Consume roles
with 'Slimrat::Server::Data';

# Write nicely
use strict;
use warnings;

# Constants
use constant {
	STAT_STOPPED	=> 1,
	STAT_PAUSED	=> 2,
	STAT_RUNNING	=> 3,
	STAT_COMPLETED	=> 4
};
use constant KEYS_FILTER_UNIQUE => [qw{uri}];
use constant KEYS_FILTER_REGULAR => [qw{status groupid restrictionids}];
use constant KEYS_DATASET => [qw{uri status directory groupid restrictionids}];


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<uri>

This attribute uniquely identifies a download. It is used to distinguish
differend downloads, as well as create links to other data structures.

It is a read-only attribute, which means a download cannot change its URI
after creation.

=cut

has 'uri' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

=pod

=head2 C<status>

This flag controls the download status. It can be used to select a specific
subset of downloads (e.g. to create a historic view). Different values are
possible:
=over
=item STAT_STOPPED (1): downloads which have been stopped, albeit by user interaction or failure
=item STAT_PAUSED (2): paused downloads
=item STAT_RUNNING (3): downloads currently active
=item STAT_COMPLETED (4): completed downloads
=item =back

This is a writable value, which'll trigger a backend update if the C<propagate>
flag is set.

=cut

has 'status' => (
	is		=> 'rw',
	isa		=> 'Int',
	default		=> STAT_STOPPED,
	trigger		=> \&_trigger_status,
	required	=> 1
);

sub _trigger_status {
	my ($self, $value) = @_;
	return unless ($self->propagation == Slimrat::Server::Data::PROP_UPDATE);
	
	$self->backend->update_download(
		{ uri => $self->uri },
		{ status => $value }
	);
}

=pod

=head2 C<directory>

This is the target directory to which the file will be downloaded. It has a
predicate C<has_directory>, because if the directory is not set one should
look at the group a download is part of to get the target directory.

This is a writable value, which'll trigger a backend update if the C<propagate>
flag is set. The attribute also supports a C<deep_lookup>, which'll query the
download group as well when no directory is found.

=cut

# Definition
has 'directory' => (
	is		=> 'rw',
	isa		=> 'Str',
	predicate	=> 'has_directory',
	trigger		=> \&_trigger_directory
);

# Propagation-handling
sub _trigger_directory {
	my ($self, $value) = @_;
	return unless ($self->propagation == Slimrat::Server::Data::PROP_UPDATE);
	
	$self->backend->update_download(
		{ uri => $self->uri },
		{ directory => $value }
	);
}

# Deep-lookup handling
around 'directory' => sub {
	my ($sub, $self, @params) = @_;
	
	# Write accessor
	if (@params) {
		return $self->directory(@params);
	}
	
	# Read accessor
	else {
		my $directory = $self->directory();
		if (not defined $directory && $self->deep_lookup) {
			my $group = $self->group;
			$directory = $group->directory;
		}
		return $directory;
	}
};

=pod

=head2 C<groupid>

This attribute links the download to a certain group by saving its ID. It is a
read-write accessor, which upon write will force an update to the backend if
the propagate bit is set.

=cut

# Definition
has 'groupid' => (
	is		=> 'rw',
	isa		=> 'Slimrat::Server::Data::Group',
	trigger		=> \&_trigger_groupid,
	predicate	=> 'has_groupid'
);

# Propagation-handling of a group ID
sub _trigger_groupid {
	my ($self, $value) = @_;
	delete $self->{group};
	return unless ($self->propagation == Slimrat::Server::Data::PROP_UPDATE);
	
	$self->backend->update_download(
		{ uri => $self->uri },
		{ groupid => $value }
	);
}

=pod

=head2 C<group>

This attribute provides some sugar to prevent working with raw group ID's.
It provides an accessor to a Group object, which upon read will do some extra
fetches from the backend to provide such an object, which contains more data
then only the group ID.

When writing to this accessor, the ID will get extracted and the write accessor
of the C<groupid> attribute will beset to (eventually) trigger a write to
the backend.

=cut

# Definition
has 'group' => (
	is		=> 'rw',
	isa		=> 'Slimrat::Server::Data::Group',
	trigger		=>  \&_trigger_group,
	lazy		=> 1,
	builder		=> '_build_group'
);

# Lazy-value
sub _build_group {
	my ($self) = @_;
	return unless ($self->has_groupid);
	
	my $group = $self->backend->get_groups(
		name => $self->groupid
	);
	return $group;
}

# Propagation-handling of Group objects
sub _trigger_group {
	my ($self, $value) = @_;
	$self->groupid($value->name);
}

=pod

=head2 C<restrictionids>

This attribute links the download to a set of restrictions by their ID. It is a
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
	return unless ($self->propagation == Slimrat::Server::Data::PROP_UPDATE);
	
	$self->backend->update_download(
		{ uri => $self->uri },
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
the backend. The read accessor also supports a C<deep_lookup>, which'll look
up the Group restrictions as well if set.

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

# Deep-lookup handling
around 'restrictions' => sub {
	my ($sub, $self, @params) = @_;
	
	# Write accessor
	if (@params) {
		return $self->restrictions(@params);
	}
	
	# Read accessor
	else {
		my @restrictions = @{$self->directory()};
		if ($self->deep_lookup) {
			my $group = $self->group;
			push(@restrictions, @{$group->restrictions});
		}
		return \@restrictions;
	}
};


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;
	
	# Object creation
	if ($self->propagation == Slimrat::Server::Data::PROP_ADD) {
		my %dataset = ();
		foreach my $key (@{KEYS_DATASET()}) {
			my $value = $self->{$key};
			if (defined $value) {
				$dataset{$key} = $value;
			}
		}
		$self->backend->add_download(%dataset);
		$self->propagation(Slimrat::Server::Data::PROP_OFF);	# TODO?
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
