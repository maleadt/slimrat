################################################################################
# Configuration
#
## NAME		= backend
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= backend base plugin
## LICENSE	= Perl Artistic 2.0
## TYPE		= abstract

# Package definition
package Slimrat::Server::Plugin::Backend;

=pod

=head1 NAME

Slimrat::Server::Plugin::Backend - Slimrat backend base plugin

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Backend> package contains base functionality for
all backend plugins. It provides some ready-to-use routines, as well as some

=head1 SYNPOSIS

=cut

# Packages
use Moose::Role;
use Slimrat::Server::Plugin;
use Slimrat::Server::Data;
use Slimrat::Server::Data::Download;
use Slimrat::Server::Data::Group;
use Slimrat::Server::Data::Restriction;

# Roles
with 'Slimrat::Server::Plugin';

# Write nicely
use strict;
use warnings;

# Constants
use constant {
	STAT_GOOD 	=> 1,
	STAT_MISSING 	=> 2,
	STAT_CORRUPT	=> 3,
	
	CONTEXT_ARRAY => 1,
	CONTEXT_SCALAR => 2,
	CONTEXT_DONTCARE => 3
};

################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<logger>

A required attribute, which provides functionality specified in the
C<Slimrat::Server::Plugin::Logger> role. It is used to send informal messages
to the outer world.

=cut

has 'logger' => (
	is		=> 'ro',
	required	=> 1
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

before 'BUILD' => sub {
	my ($self) = @_;
	
	# Verify attribute roles
	die('Invalid logger specified') unless ($self->logger->does('Slimrat::Server::Plugin::Logger'));	
};

=pod

=head2 C<$backend->consistency()>

This method checks the consistency of the backend-stored data. The return value
depends on the state:
=over
=item STAT_GOOD: data is consistent and ready to use
=item STAT_MISSING: data is absent or has not been initialized
=item STAT_CORRUPT: data is corrupt beyond repair
=back

=cut

requires 'consistency';

=pod

=head2 C<$backend->reset()>

This method resets the backend's data, clearing its persistend state. This
is required when corrupt data is found.

=cut

requires 'reset';

=pod

=head2 C<$backend->initialize()>

This method is sets up the backend for first use, after which it is ready to
be used.

=cut

requires 'initialize';

=pod

=head2 C<$backend->store($filename)>

This method provides the functionality to do a raw dump to a file. This does
B<not> requires the data to be in a consistent state, on the contrary: it will
get called to dump an inconsistent database after which the backend will get
re-initialized.

=cut

requires 'store';

=pod

=head2 C<$backend->restore($filename)>

This method is used to restore the database from a dump made with the L<dump>
method above. It requires the database to in a pristine state, meaning that
it is initialized but does not contain any data.

=cut

requires 'restore';

=pod

=head2 C<$backend->get_downloads(%filter)>
=head2 C<$backend->add_download(%dataset)>
=head2 C<$backend->update_downloads(\%filter, \%dataset)>

These methods provide a way to fetch, add or update downloads from the backend.

For the restrictions on filters and datasets, see L<Slimrat::Server::Data>.
For explanation of the different keys, see L<Slimrat::Server::Data::Download>.

B<Note>: the restrictionids attribute implements a n:n-relationship, which
results in some difficulties in implementation and usage. See the L<DESIGN>
section in L<Slimrat::Server::Data>!

=cut

requires 'get_downloads';

around 'get_downloads' => sub {
	my ($sub, $self, %filter) = @_;
	
	check_filter(
		logger => $self->logger,
		filter => \%filter,
		uniques => Slimrat::Server::Data::Download::KEYS_FILTER_UNIQUE,
		regulars => Slimrat::Server::Data::Download::KEYS_FILTER_REGULAR,
		context => wantarray ? CONTEXT_ARRAY : CONTEXT_SCALAR,	
	) or return;
	
	return $self->$sub(%filter);
};

requires 'add_download';

around 'add_download' => sub {
	my ($sub, $self, %data) = @_;
	
	check_data(
		logger => $self->logger,
		data => \%data, 
		keys => Slimrat::Server::Data::Download::KEYS_DATASET,
	) or return;
	
	return $self->$sub(%data);
};

requires 'update_downloads';

around 'update_downloads' => sub {
	my ($sub, $self, $filterref, $dataref) = @_;
	
	check_filter(
		logger => $self->logger,
		filter => $filterref,
		uniques => Slimrat::Server::Data::Download::KEYS_FILTER_UNIQUE,
		regulars => Slimrat::Server::Data::Download::KEYS_FILTER_REGULAR,
		context => CONTEXT_DONTCARE
	) or return;
	
	check_data(
		logger => $self->logger,
		data => $dataref,
		keys => [qw{uri groupid restrictionids}]
	) or return;
	
	return $self->$sub($filterref, $dataref);
};

=pod

=head2 C<$backend->get_groups(%filter)>
=head2 C<$backend->add_group(%dataset)>
=head2 C<$backend->update_groups(\%filter, \%dataset)>

These methods provide a way to fetch, add or update groups from the backend.

For the restrictions on filters and datasets, see L<Slimrat::Server::Data>.
For explanation of the different keys, see L<Slimrat::Server::Data::Group>.

B<Note>: the restrictionids attribute implements a n:n-relationship, which
results in some difficulties in implementation and usage. See the L<DESIGN>
section in L<Slimrat::Server::Data>!

=cut

requires 'get_groups';

around 'get_groups' => sub {
	my ($sub, $self, %filter) = @_;
	
	check_filter(
		logger => $self->logger,
		filter => \%filter,
		uniques => Slimrat::Server::Data::Group::KEYS_FILTER_UNIQUE,
		regulars => Slimrat::Server::Data::Group::KEYS_FILTER_REGULAR,
		context => wantarray ? CONTEXT_ARRAY : CONTEXT_SCALAR,	
	) or return;
	
	return $self->$sub(%filter);
};

requires 'add_group';

around 'add_group' => sub {
	my ($sub, $self, %data) = @_;
	
	check_data(
		logger => $self->logger,
		data => \%data, 
		keys => Slimrat::Server::Data::Group::KEYS_DATASET,
	) or return;
	
	return $self->$sub(%data);
};

requires 'update_groups';

around 'update_groups' => sub {
	my ($sub, $self, $filterref, $dataref) = @_;
	
	check_filter(
		logger => $self->logger,
		filter => $filterref,
		uniques => Slimrat::Server::Data::Group::KEYS_FILTER_UNIQUE,
		regulars => Slimrat::Server::Data::Group::KEYS_FILTER_REGULAR,
		context => CONTEXT_DONTCARE
	) or return;
	
	check_data(
		logger => $self->logger,
		data => $dataref,
		keys => [qw{uri groupid restrictionids}]
	) or return;
	
	return $self->$sub($filterref, $dataref);
};

=pod

=head2 C<$backend->get_restrictions(%filter)>
=head2 C<$backend->add_restriction(%dataset)>
=head2 C<$backend->update_restrictions(\%filter, \%dataset)>

These methods provide a way to fetch, add or update restrictions from the backend.

For the restrictions on filters and datasets, see L<Slimrat::Server::Data>.
For explanation of the different keys, see L<Slimrat::Server::Data::Restriction>.

=cut

requires 'get_restrictions';

around 'get_restrictions' => sub {
	my ($sub, $self, %filter) = @_;
	
	check_filter(
		logger => $self->logger,
		filter => \%filter,
		uniques => Slimrat::Server::Data::Restriction::KEYS_FILTER_UNIQUE,
		regulars => Slimrat::Server::Data::Restriction::KEYS_FILTER_REGULAR,
		context => wantarray ? CONTEXT_ARRAY : CONTEXT_SCALAR,	
	) or return;
	
	return $self->$sub(%filter);
};

requires 'add_restriction';

around 'add_restriction' => sub {
	my ($sub, $self, %data) = @_;
	
	check_data(
		logger => $self->logger,
		data => \%data, 
		keys => Slimrat::Server::Data::Restriction::KEYS_DATASET,
	) or return;
	
	return $self->$sub(%data);
};

requires 'update_restrictions';

around 'update_restrictions' => sub {
	my ($sub, $self, $filterref, $dataref) = @_;
	
	check_filter(
		logger => $self->logger,
		filter => $filterref,
		uniques => Slimrat::Server::Data::Restriction::KEYS_FILTER_UNIQUE,
		regulars => Slimrat::Server::Data::Restriction::KEYS_FILTER_REGULAR,
		context => CONTEXT_DONTCARE
	) or return;
	
	check_data(
		logger => $self->logger,
		data => $dataref,
		keys => [qw{uri restrictionid restrictionids}]
	) or return;
	
	return $self->$sub($filterref, $dataref);
};


################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=head2 C<check_data(%parameters)

Checks the validity of passed data, and prints errors or warnigns when appropriate.
The parameters should contain following keys:
=over
=item data: a HashRef to the dataset to be checked
=item logger: a logger to print errors or warnings to
=item keys: the keys which may occur in the dataset
=back

=cut

sub check_data {
	my %parameters = @_;
	my %data = %{$parameters{data}};
	my $logger = $parameters{logger};
	
	# Extract valid keys
	my %keys = ();
	foreach my $key (keys %data) {
		my $value = delete $data{$key};
		if (defined $value) {
			$keys{$key} = $value;
		}
	}
	if (keys %keys) {
		return $logger->error('dataset contains invalid keys')
			if (keys %data);
		return 1;
	}
	
	# Empty dataset
	return $logger->error('dataset doesn\'t contain any keys');
}

=pod

=head2 C<check_filter(%parameters)>

Checks the validity of a filter, and prints errors or warnings when appropriate.
The parameters should contain following keys:
=over
=item filter: a HashRef to the filter to be checked
=item logger: a logger to print errors or warnings to
=item uniques: an ArrayRef containing the possible unique keys
=item regulars: an ArrayRef containing the possible regular keys
=item context: an integer describing the context (see the C<CONTEXT_> constants)
=back

=cut

sub check_filter {
	my %parameters = shift;
	my %filter = %{$parameters{filter}};
	my $logger = $parameters{logger};
	
	# Extract unique keys
	my %uniques = ();
	foreach my $key (keys %{$parameters{uniques}}) {
		my $value = delete $filter{$key};
		if (defined $value) {
			$uniques{$key} = $value;
		}
	}
	if (keys %uniques) {
		return $logger->error('a filter cannot combine unique-keys wich regular ones')
			if (keys %filter);
		return $logger->error('a filter cannot contain multiple unique-keys')
			if (keys %uniques > 1);
		$logger->warning('using a unique-key in array context')
			if ($parameters{context} == CONTEXT_ARRAY);
		return 1;
	}
	
	# Extract regular keys
	my %regulars = ();
	foreach my $key (keys %{$parameters{regulars}}) {
		my $value = delete $filter{$key};
		if (defined $value) {
			$regulars{$key} = $value;
		}
	}
	if (keys %regulars) {
		return $logger->error('filter contains unknown keys')
			if (keys %filter);
		$logger->warning('using a regular-key filter in scalar context')
			if ($parameters{context} == CONTEXT_SCALAR);
		return 1;	
	}
	
	# Empty filter
	return 1;	
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
