################################################################################
# Configuration
#
## NAME		= downloader
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= downloader base plugin
## LICENSE	= Perl Artistic 2.0
## TYPE		= abstract

# Package definition
package Slimrat::Server::Plugin::Downloader;

=pod

=head1 NAME

Slimrat::Server::Plugin::Downloader - Slimrat downloader base plugin

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Downloader> package contains base functionality for
all downloader plugins. It provides some ready-to-use routines, as well as some

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

=head1 CONFIGURATION

=head1 ATTRIBUTES

=cut


################################################################################
# Methods
#


################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=cut

__END__

=pod

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

