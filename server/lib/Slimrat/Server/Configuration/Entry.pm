################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Configuration::Entry;

=pod

=head1 NAME

Slimrat::Server::Config::Entry - Slimrat configuration entry.

=head1 DESCRIPTION

The C<Slimrat::Server::Config::Entry> package is nothing more then a simple
container for a configuration entry.

=head1 SYNPOSIS

=cut

# Packages
use Moose;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<default>

The default value of a configuration.

=cut

has 'default' => (
	is		=> 'rw',
	isa		=> 'Str',
	predicate	=> 'has_default'
);

=pod

=head2 C<value>

The actual value.

=cut

has 'value' => (
	is		=> 'rw',
	isa		=> 'Str',
	predicate	=> 'has_value'
);
=pod

=head2 C<mutable>

A boolean configuring whether the key/value pair is writable.

=cut

has 'mutable' => (
	is		=> 'ro',
	isa		=> 'Bool'
);

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

