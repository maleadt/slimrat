################################################################################
# Configuration
#
## NAME		= dbi
## AUTHOR	= slimrat development team
## VERSION	= 1.99
## DESCRIPTION	= dbi-based backend plugin
## LICENSE	= Perl Artistic 2.0

# Package definition
package Slimrat::Server::Plugin::Backend::DBI;

=pod

=head1 NAME

Slimrat::Server::Plugin::Backend::DBI - Slimrat DBI backend implementation

=head1 DESCRIPTION

The C<Slimrat::Server::Plugin::Backend::DBI> package implements a backend
saving all data in a DBI-supported database.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use DBI;
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

has 'handle' => (
	is		=> 'ro',
	isa		=> 'DBI',
	lazy		=> 1,
	builder		=> '_build_handle'
);

sub _build_handle {
	my ($self) = @_;
	
	# Create database connection
	my $handle = DBI->connect(
		$self->config->get('source'),
		defined($self->config->get('username')) ? $self->config->get('username') : undef,
		defined($self->config->get('password')) ? $self->config->get('password') : undef,
		{
			PrintError	=> 0,
			AutoCommit	=> 0,
			RaiseError	=> 1
		}
	) or $self->logger->fatal("failed to connect ($DBI::errstr)");
	
	return $handle;
}

################################################################################
# Methods
#

sub BUILD {
	my ($self) = @_;
	
	# Setup and verify configuration
	$self->config->set_default('source', undef);
	$self->config->set_default('username', undef);
	$self->config->set_default('password', undef);
	$self->logger->fatal("missing database source")
		unless defined($self->config->get('source'));
	
	# Build attributes depending on the configuration object
	$self->handle();
}

sub DEMOLISH {
	my ($self) = @_;
	
	# Disconnect
	$self->handle->disconnect();
}

sub initialize {
	my ($self) = @_;
	
	eval {
		# Restrictions table
		$self->handle->do('
			CREATE TABLE restrictions (
				id INTEGER,
				type VARCHAR NOT NULL,
				description TEXT,
				
				PRIMARY KEY(id ASC)
		');
		
		# Groups table
		$self->handle->do('
			CREATE TABLE restrictions (
				name VARCHAR NOT NULL,
				directory VARCHAR,
				
				PRIMARY KEY(name)
		');	
		
		# Downloads table
		$self->handle->do('
			CREATE TABLE downloads (
				uri VARCHAR NOT NULL,
				status INTEGER NOT NULL,
				directory VARCHAR,
				groupid VARCHAR,
				
				PRIMARY KEY(uri),
				FOREIGN KEY(groupid) REFERENCES groups(name),
				CHECK (status IN())
			);
		');
		
		# Junction table for Downloads<->Restrictions
		$self->handle->do('
			CREATE TABLE j_downloads_restrictions (
				download VARCHAR NOT NULL,
				restriction INTEGER NOT NULL,
				
				PRIMARY KEY(download, restriction),
				FOREIGN KEY(download) REFERENCES downloads(uri),
				FOREIGN KEY(restriction) REFERENCES restrictions(id)
			);
		');
		
		# Junction table for Groups<->Restrictions
		$self->handle->do('
			CREATE TABLE j_groups_restrictions (
				group VARCHAR NOT NULL,
				restriction INTEGER NOT NULL,
				
				PRIMARY KEY(group, restriction),
				FOREIGN KEY(group) REFERENCES groups(uri),
				FOREIGN KEY(restriction) REFERENCES restrictions(id)
			);
		');
		
		$self->handle->commit();
	};
	if ($@) {
		$self->logger->error("DBI initialization failed ($@)");
		eval{ $self->handle->rollback() };
		return 0;
	}
	return 1;	
}

sub reset {
	my ($self) = @_;
	
	eval {
		$self->handle->do('
			DROP TABLE j_groups_restrictions;
			DROP TABLE j_downloads_restrictions;
			DROP TABLE downloads;
			DROP TABLE groups;
			DROP TABLE restrictions;
		');
	};
	if ($@) {
		$self->logger->error("DBI reset failed ($@)");
		eval{ $self->handle->rollback() };
		return 0;
	}
	return 1;
}

sub consistency {
	my ($self) = @_;
	
	# Fetch list of tables
	my %tables;
	eval {
		my $sth = $self->handle->prepare("SELECT name FROM sqlite_master WHERE type = 'table'");
		$sth->execute;
		my ($name);
		$sth->bind_columns(\$name);
		while ($sth->fetch) {
			$tables{$name} = 1;
		}
	};
	if ($@) {
		return $self->error("DBI failure when listing tables ($@)");
	}
	
	# Verify tables
	my $missing = 0;
	my @tables_check = qw{downloads groups restrictions j_groups_restrictions j_downloads_restrictions};
	foreach my $table (@tables_check) {
		$missing++ unless defined($tables{$table});
	}
	if ($missing > 0) {
		return Slimrat::Server::Plugin::Backend::STAT_MISSING if ($missing == @tables_check);
		return Slimrat::Server::Plugin::Backend::STAT_CORRUPT;
	}
	
	# Verify data
	# TODO: not necessary if done through constraints
	
	return Slimrat::Server::Plugin::Backend::STAT_GOOD;
}

sub store {
	die("lol");
}

sub restore {
	die("lol");
}

sub filter_downloads {
	my ($filterref, $dbi) = @_;
	my %filter = %$filterref;
	
	# Build SQL statement
	my @joins = ();
	my @conditions = ();	
	foreach my $key (keys %filter) {
		my $value = $filter{$key};
		if (grep{$key} qw{uri status directory groupid}) {
			push(@conditions, (
				sprintf '%s = %s',
				$key,
				$dbi->quote($value)
			));
		}
		elsif ($key eq 'restrictionids') {
			my @restrictionids = @{$filter{$key}};
			foreach my $restrictionid (@restrictionids) {
				push(@joins, (
					sprintf 'INNER JOIN j_downloads_restrictions ON %s = %s',
					$key,
					$dbi->quote($restrictionid))
				);
			}
		}
	}	
	return join(' ', @joins) . ' WHERE ' . join(' AND ', @conditions);
}

sub get_downloads {
	my ($self, %filter) = @_;
	
	# Build SQL statement	
	my $sql_filter = filter_downloads(\%filter, $self->backend);
	my $sql = "SELECT downloads.* FROM downloads $sql_filter";
	
	# Execute SQL statement
	eval {
		my $sth = $self->handle->do($sql);
		my @downloads;
		while (my ($uri, $status, $directory, $groupid)) {
			my $download = new Download(
				uri		=> $uri,
				status		=> $status,
				directory	=> $directory,
				groupid		=> $groupid,
				propagate	=> Slimrat::Server::Data::PROP_UPDATE
			);
			push(@downloads, $download);
		}
		return @downloads;
	};
	if ($@) {
		$self->logger->error("DBI failure at getting downloads ($@)");
		return;
	}	
}

sub add_download {
	my ($self, %dataset) = @_;
	
	# Prepare and execute statement
	eval {
		my $sth = $self->handle->prepare('
			INSERT INTO downloads 
			VALUES (?, ?, ?, ?)
		');
		
		$sth->execute(
			$dataset{uri},
			$dataset{status},
			$dataset{directory},
			$dataset{groupid}
		);
		
		$self->backend->commit();
	};
	if ($@) {
		$self->logger->error("DBI failure at adding download ($@)");
		return;
	}
}

sub update_downloads {
	my ($self, $filterref, $datasetref) = @_;
	my %filter = %$filterref;
	my %dataset = %$datasetref;
	
	# Build SQL
	my $sql_set = join(', ', map {
		"downloads.$_ = " . $self->backend->quote($dataset{$_})
	} keys %dataset);
	my $sql_filter = filter_downloads($filterref, $self->backend);
	
	# Execute SQL
	eval {
		$self->backend->do("UPDATE downloads SET $sql_set FROM downloads $sql_filter")
			or die('update did not affect any rows');
		$self->backend->commit();
	};
	if ($@) {
		$self->logger->error("DBI failure at updating downloads ($@)");
		return ;
	}
}

sub get_groups {
	die("lol");
}

sub add_group {
	die("lol");
}

sub update_groups {
	die("lol");
}

sub get_restrictions {
	die("lol");
}

sub add_restriction {
	die("lol");
}

sub update_restrictions {
	die("lol");
}

1;

__END__

=pod

=head1 CONFIGURATION

=head2 C<source>

This is a required configuration value, neccesary for the DBI module in order
to connect to a certain database. See L<DBI::DBI> and C<DBI->available_drivers>
on how to create a valid URI.

B<Default>: undef (which results in an error).

=head2 C<username>
=head2 C<password>

Credentials required to connect to the database.

B<Default>: undef.

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
