################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::PluginManager;

=pod

=head1 NAME

Slimrat::Server::PluginManager - Slimrat serverside plugin manager

=head1 DESCRIPTION

The C<Slimrat::Server::PluginManager> package contains functionality to
manage the several types of plugins available in slimrat.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use File::Find;
use Carp;

# Write nicely
use strict;
use warnings;


################################################################################
# Attributes
#

=pod

=head1 ATTRIBUTES

=head2 C<config>

A required attributed, to be passed by constructor, containing all static
configuration data relevant to the internet daemon. This must be an instance
of C<Slimrat::Server::Configuration>.

=cut

has 'config' => (
	is		=> 'ro',
	isa		=> 'Slimrat::Server::Configuration',
	required	=> 1
);

=pod

=head2 C<plugins>

Read-only attribute, for internal use only. It contains all the registered
loggers in a key/value hash. The key, a string, represents a regular expression
which ought to match any URI to be processed by the logger. The value is an
info-hash created by the C<parse> function, which imposes certain restrictions
(have a look at the documentation of C<parse>). The plugin hash its key is the
plugin's package, while the value is a reference to the info hash.

The builder method uses the C<discover> method to scan for all plugins under
L<Slimrat::Server::Plugin::logger>, and uses C<parse> to parse the plugin.
This imposes certain restrictions on the info a plugin should contain, which
are documented.

=cut

has 'plugins' => (
	is		=> 'ro',
	isa		=> "HashRef",
	builder		=> '_build_plugins'
);

sub _build_plugins {
	my ($self, @params) = @_;
	
	# Discover all plugins
	my %plugins = discover('Slimrat::Server::Plugin')
		or die("Error discovering logger plugins: $!");
	
	# Process all plugins
	my %plugins_usable;
	for my $package (sort keys %plugins) {
		my $file = $plugins{$package};
		
		# Extract info hash
		my %infohash;
		eval {
			%infohash = parse($file);
			$infohash{package} = $package;
		};
		if ($@) {
			warn("Error loading plugin $package: $@");
			next;
		}
		
		# Check if we got a concrete plugin
		if (defined $infohash{type} && $infohash{type} eq "abstract") {
			next;
		}
		
		# Load the plugin
		my $status = do $file;
		if (!$status) {
			if ($@) {
				warn("Error loading plugin $package: $@");
			}
			elsif ($!) {
				warn("Error loading plugin $package: $!");
			}
			else {
				warn("Error loading plugin $package: unknown failure");
			}
			next;
		}
		$plugins_usable{$package} = \%infohash;
	}
	
	return \%plugins_usable;
}

################################################################################
# Methods
#

=pod

=head1 METHODS

=head2 C<$pluginmanager->get_plugin($base, $name, @params)>

This method serves as main method to instantiate a plugin. It searches all
plugins, selects those which package matches the given base, and returns a
single plugin which matches the given name.

=cut

sub get_plugin {
	my ($self, $base, $name, @params) = @_;
	
	my @infohashes = grep {
		$_->{name} eq $name
	} $self->get_group($base);
	
	croak("Given parameters matched multiple plugins") if (scalar @infohashes > 1);
	croak("Given parameters didn't match any plugin") unless (scalar @infohashes);
	
	return $self->instantiate($infohashes[0], @params);
}

=pod

=head2 C<$pluginmanager->get_group($base)>

This method selects a group of plugins, contrary to the C<get_plugin> method
which only selects a single plugin.
Logically, this method only requires the base package which selects the correct
plugins.

=cut

sub get_group {
	my ($self, $base, @params) = @_;
	
	my @infohashes =
		map { $self->plugins->{$_} }
		grep { $_ =~ m{^$base} } keys %{$self->plugins};
	
	return @infohashes;	
}

=pod

=head2 C<$pluginmanager->instantiate(\%infohash, @params)

This method instantiates a plugin based on its info hash.

=cut

sub instantiate {
	my ($self, $infohash, @params) = @_;
	my $package = $infohash->{package};
	new $package (infohash => $infohash, @params);
}

################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=head2 C<discover>

The static C<discover> method needs a base package-path as parameter, and scans
that base for plugins. To do that, it scans @INC to find the folder containing
the given base package layout, and subsequently scans that folder for
Perl-modules. All modules found (possible plugins) are returned in an hash
linking each file to its package name.

Returns a plugin hash (package => file) upon success, and dies upon failure.
=cut

sub discover {
	my ($base) = @_;
	
	# Find the appropriate root folder
	my $subfolders = $base;
	$subfolders =~ s{::}{/}g;
	my $root;
	foreach my $directory (@INC) {
		my $pluginpath = "$directory/$subfolders";
		if (-d $pluginpath) {
			$root = $pluginpath;
			last;
		}
	}
	die("no inclusion directory matched plugin structure") unless defined $root;
	
	# Scan for Perl-modules
	my %plugins;
	find( sub {
		my $file = $File::Find::name;
		if ($file =~ m{$root/(.*)\.pm$}) {
			my $package = "$base/" . $1;
			$package =~ s{\/+}{::}g;
			$plugins{$package} = $file;
		}
	}, $root);
	
	return %plugins;
}

=pod

=head2 C<parse($file, $inforef)>

Parse a given plugin, and save all keys in a hash. The info-hash is constructed
by reading the plugin file, and extracting all key/values formatted as:
  ## KEY = VALUE

Each plugin should contain certain keys in its info hash, namely:
=over
=item C<regex>: the regular-expression matching all URI's
=item C<author>: who wrote the plugin
=item C<version>: the version of the plugin (perl-style)
=item C<description>: a short description
=item C<license>: the license under which the plugin is released
=back

Returns an info-hash upon success and dies upon failure.

=cut

sub parse {
	my ($file) = @_;
	my %info = (file => $file);
	
	# Open and read the file
	open(my $read, '<', $file) or die("could not open potential plugin '$file' for parsing ($!)");
	while (<$read>) {
		if (m{^##\s*(.+?)\s*(=+)\s*(.*?)$}) {
			my ($key, $value) = (lc($1), $3);
			$info{$key} = $value;
			# TODO? push(@{$info{$key}}, $value);
		}
	}
	close($read);
	
	# Check for missing keys
	check_info(\%info, qw{name author version description license});	
	return %info;
}

=pod

=head2 C<check_info($hashref, @keys)>

Checks a given hash for required keys. Its functionality is the same as
C<map { defined $hash{$_} || die() } qw/foo bar/ }>, but makes it more
readable and provides an easy way to log all missing keys instead of only one.

Returns true upon success and dies upon failure.

=cut

sub check_info {
	my ($hashref, @keys) = @_;
	my %hash = %$hashref;
	
	my @missing = grep {
		not defined $hash{$_};
	} @keys;
	
	die("missing plugin keys " . join(", ", @missing)) if (@missing);
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

