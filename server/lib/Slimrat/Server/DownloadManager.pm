################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::DownloadManager;

=pod

=head1 NAME

Slimrat::Server::DownloadManager - Slimrat serverside plugin manager

=head1 DESCRIPTION

The C<Slimrat::Server::DownloadManager> package contains functionality to
manage and process downloads. This includes selecting a plugin able to
get the data associated with a given URI.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use Carp;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<pluginmanager>

=cut

has 'pluginmanager' => (
	is		=> 'ro',
	isa		=> 'Slimrat::Server::PluginManager',
	required	=> 1
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=head2 get_plugin($uri)

=cut

# TODO
sub get_downloader {
	my ($self, $uri, @params) = @_;
	
	# Get subset of plugins and match them against the given URI
	my @matches;
	my @infohashes = $self->pluginmanager->get_group('Slimrat::Server::Plugin::Downloader');
	foreach my $infohash (@infohashes) {
		my $regex = $infohash->{regex};
		push(@matches, $infohash) if ($uri =~ $regex);
	}
	
	die("Given URI matched multiple downloaders") if (scalar @matches > 1);
	croak("Given URI didn't match any plugin") unless (scalar @matches);
	
	return $self->pluginmanager->instantiate($matches[0], @params);
}

