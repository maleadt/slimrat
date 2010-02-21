################################################################################
# Configuration
#
## NAME		= memory
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= in-memory backend plugin
## LICENSE	= Perl Artistic 2.0

# Package definition
package Slimrat::Server::Plugin::Backend::Memory;

=pod

=head1 NAME

Slimrat::Server::Plugin::Backend::Memory - Slimrat in-memory backend
implementation

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Backend::Memory> package implements a backend
saving all data in the memory. This is a volatile backend, meaning upon
exit all data will be lost.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use Storable qw//;
use Slimrat::Server::Plugin::Backend;
use Slimrat::Server::Data::Download;
use Slimrat::Server::Data::Group;
use Slimrat::Server::Data::Restriction;

# Consume roles
with 'Slimrat::Server::Plugin::Backend';

# Write nicely
use strict;
use warnings;

################################################################################
# Attributes
#

has 'downloads' => (
	is	=> 'rw',
	isa	=> 'HashRef[HashRef]'
);

has 'groups' => (
	is	=> 'rw',
	isa	=> 'HashRef[HashRef]'
);

has 'restrictions' => (
	is	=> 'rw',
	isa	=> 'HashRef[HashRef]'
);



################################################################################
# Methods
#

sub BUILD {
	my ($self) = @_;
}

sub reset {
	my ($self) = @_;
	
	# Reset all
	delete $self->{qw/downloads groups restrictions/};
}

sub initialize {
	my ($self) = @_;
	
	# Initialize all with empty hashes
	$self->downloads( {} );
	$self->groups( {} );
	$self->restrictions( {} );
}

sub consistency {
	my ($self) = @_;
	
	# Check all ID's
	# TODO
}

sub store {
	my ($self, $filename) = @_;
	
	my %to_store = (
		downloads	=> $self->downloads,
		groups		=> $self->groups,
		restrictions	=> $self->restrictions
	);
	Storable::store \%to_store, $filename;
}

sub restore {
	my ($self, $filename) = @_;
	
	my %to_use = %{Storable::retrieve($filename)};
	$self->downloads($to_use{downloads});
	$self->groups($to_use{groups});
	$self->restrictions($to_use{restrictions});
}

sub get_downloads_raw {
	my ($self, %filter) = @_;
	
	# Process all downloads
	my %downloads = ();
	DOWNLOADS: foreach my $id (keys %{$self->downloads}) {
		my $download = $self->downloads->{$id};
		
		# Check filter requirments
		foreach my $key (keys %filter) {
			my $value = $filter{$key};
			
			# Regular compare keys
			if (grep{$key} qw{uri status directory groupid}) {
				last DOWNLOADS
					unless $download->{$key} eq $value;
			}
			
			# Complex keys
			elsif ($key eq 'restrictionids') {
				last DOWNLOADS
					unless grep{$value} $download->{restrictionids};
			}
		}
		
		# Save
		$downloads{$id} = $download;
	}
	
	return %downloads;
}

sub get_downloads {
	my ($self, %filter);
	
	# Fetch references and build objects
	my %refs = $self->get_downloads_raw(%filter);
	my @downloads = ();
	foreach my $id (keys %refs) {
		my $ref = $refs{$id};
		push(@downloads, new Download(uri => $id, %$ref));
	}
	
	return @downloads;
}

sub add_download {
	my ($self, %dataset) = @_;
	
	my $uri = delete $dataset{uri};
	return $self->logger->error("attempt to overwrite existing downloads")
		if (defined $self->downloads->{$uri});
	$self->downloads->{$uri} = \%dataset;	# TODO: maybe copy the hash
}

sub update_downloads {
	my ($self, $filterref, $datasetref) = @_;
	my %filter = %$filterref;
	my %dataset = %$datasetref;
	
	my $modified = 0;
	
	# Fetch dopwnloads
	my %refs = $self->get_downloads_raf(%filter);
	foreach my $id (keys %refs) {
		my $ref = $refs{$id};
		
		# Adjust them
		foreach my $key (keys %dataset) {
			my $value = $dataset{$key};
			$ref->{$key} = $value;
		}
		
		# TODO: not neccesary?
		$self->downloads->{$id} = $ref;
		$modified++;
	}
	
	return $modified;
}

sub get_groups {
	my ($self, %filter) = @_;
}

sub add_group {
	my ($self, %dataset) = @_;
}

sub update_groups {
	my ($self, $filterref, $datasetref) = @_;
	my %filter = %$filterref;
	my %dataset = %$datasetref;	
}

sub get_restrictions {
	my ($self, %filter) = @_;
}

sub add_restriction {
	my ($self, %dataset) = @_;
}

sub update_restrictions {
	my ($self, $filterref, $datasetref) = @_;
	my %filter = %$filterref;
	my %dataset = %$datasetref;	
}

1;

__END__

=pod

=head1 CONFIGURATION

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
