################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Data;

=pod

=head1 NAME

Slimrat::Server::Data - Slimrat data role

=head1 DESCRIPTION

The C<Slimrat::Server::Data> package provides a basic role for data objects to
implement.

=head1 SYNPOSIS

=cut

# Packages
use Moose::Role;

# Write nicely
use strict;
use warnings;

# Propagation values
use constant {
	PROP_OFF	=> 0,
	PROP_ADD	=> 1,
	PROP_UPDATE	=> 2
};

################################################################################
# Design
#

=pod

=head1 DESIGN

This section describes the data-design aspect of slimrat, which is important 
when making a backend plugin. All the essential principles explained below 
should be present in each backend-implementation.

Slimrat's data model essentially consists of three data objects:
=over
=item Downloads (L<Slimrat::Server::Data::Download>)
=item Groups (L<Slimrat::Server::Data::Group>)
=item Restrictiction (L<Slimrat::Server::Data::Restriction>)
=back
As detailled in the C<Slimrat::Server::Plugin::Backend> package, each of those
data objects can get fetched, added, and modified in the backend using the
respective C<get_>, C<add_> and C<update_> methods. The C<get> method requires
a single argument: a filter which narrows down the subset of items. The C<add_>
method requires a single arugment as well: a dataset, which contains the data
for the new object. Finally, the C<update_> method accepts two arguments, 
beging a filter to select the item to be modified, and the dataset with the
data itself.

How the data objects are related is documented in the respective packages, what
remains to be discussed is the format of filters and datasets. Both are
hashes, but not all keys are accepted.
For filters, there are two types of keys: unique-keys and regular keys. Unique
keys cannot be combined with regular ones, only return a single object, and
there can be only one of them in each filter (think of them as primary keys).
If the filter contains no unique-keys, multiple regular keys can occur.
A dataset doesn't have specific limitations, the key just have to be valid.

About the validity: each of the data packages contains three global arrays
which contain the allowed keys. Those arrays will be used to validate the 
given filters and/or datasets.
=over
=item KEYS_FILTER_UNIQUE
=item KEYS_FILTER_REGULAR
=item KEYS_DATASET
=back

When writing a backend plugin, you can use the information above to optimize
internal datastorage. Example: the C<Download> object mentions a single
unique filter: C<uri>. This can thus be used as a primary key within the
downloads-table. Also, the part of your backend which handles querying the
database for a C<get_> method will only have to implement searches for keys
in the C<KEYS_FILTER_*> arrays. Respectively, the C<add_> and C<update_>
methods will only have to care about changing keys mentioned in the
C<KEYS_DATASET> array.

Conclusivly, a remark about arrays: some objects have n:n relationships (a
download can have multiple restrictions, but a restrictions can be related to
multiple downlodas). The backend interface B<does not> handle such,
and allows a user to query the backend like
  my $download = $backend->get_downloads(uri = 'foo://bar');
  my @restrictions = $download->restrictions;
This relies on the backend plugin to fill the C<restrictionids> field of the
Download object when executing C<get_downloads>.
However, there is some ambiguity with those relationships using the C<update_>
and C<get_> functions. This is the convention:
=over
=item filters: a filter containing a key with n:n-relationships should match all the items B<containing> the value
=item dataset: a dataset containing a key with n:n-relationships B<overwrites> all existing relations
=back
A filter example: calling C<get_downloads(restrictionids => 5)> should match all
downloads with restriction 5, which includes a download with restrictions 5 and 6.
A dataset example: calling C<update_downloads({...}, {restrictionids =< 5)>
overwrites all existing IDs!

=cut


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<propagate>

This attribute controls if and how data initialisations and changes get
propagated towards the backend. Possible values are:
=over
=item PROP_OFF: no propagation
=item PROP_ADD: new objects get added to the backend
=item PROP_UPDATE: updates get pushed as well
=back

# TODO TODO TODO
Main todo: wat na een PROP_ADD in build? doorstromen naar PROP_UPDATE?
En wie is er verantwoordelijk voor het instellen? Wie moet propagation bits
zetten? Zie TODO's in DBI.pm

=cut

has 'propagation' => (
	is		=> 'rw',
	isa		=> 'Int',
	default		=> PROP_OFF
);

=pod

=head2 C<deep_lookup>

This attribute controls whether certain accessors will look through other
datastructures in order to find some data. Have a look at the accessor
documentation to find out which ones honour a C<deep_lookup>.

Its default value is 0, which means no deep lookups.

=cut

has 'deep_lookup' => (
	is		=> 'rw',
	isa		=> 'Bool',
	default		=> 0
);

=pod

=head2 C<backend>

This required attribute is a reference to the active backend, used to query
for extra data or propagate certain settings.

The given backend should consume the C<Slimrat::Server::Plugin::Backend> role,
or the application will throw a fatal error.

=cut

has 'backend' => (
	is		=> 'ro',
	required	=> 1
);

=pod

=head2 C<logger>

This required attribute is a reference to the active logger, used to output
data to the user. It isn't a separate section of the active logger, but rather
a copy of the backend its logger as all data-related messages are closely
related to the backend subsystem.

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

# TODO: before
sub BUILD {
	my ($self) = @_;
	
	# Verify attribute roles
	die('Invalid logger specified')
		unless ($self->logger->does('Slimrat::Server::Plugin::Logger'));
	$self->logger->fatal('invalid backend specified')
		unless ($self->backend->does('Slimrat::Server::Plugin::Backend'));
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
