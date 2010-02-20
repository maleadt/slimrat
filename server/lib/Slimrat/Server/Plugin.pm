################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Plugin;

=pod

=head1 NAME

Slimrat::Server::Plugin - Slimrat base plugin

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin> package contains base functionality for all
plugins.

=head1 SYNPOSIS

=cut

# Packages
use Moose::Role;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<infohash>

The plugin-specific infohash, containing the info keys defined in the plugin
file. This infohash is constructed in C<Slimrat::Server::PluginManager::parse>,
so look there for more information.

=cut

has 'infohash' => (
	is		=> 'ro',
	isa		=> 'HashRef',
	required	=> 1
);

=pod

=head2 C<config>

A required attributed, to be passed by constructor, containing all static
configuration data relevant to the plugin. This must be an instance
of C<Slimrat::Server::Configuration>.

=cut

has 'config' => (
	is		=> 'ro',
	isa		=> 'Slimrat::Server::Configuration',
	required	=> 1
);

################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=cut

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

