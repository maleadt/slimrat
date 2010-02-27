################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Inetd::Connector;

=pod

=head1 NAME

Slimrat::Server::Intetd::Connector - Slimrat server function connector

=head1 DESCRIPTION

The C<Slimrat::Server::Inetd::Connector> package provides an object which links
a remote procedure call to a local function call.

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

=head2 C<logger>

A required attribute, which provides functionality specified in the
C<Slimrat::Server::Plugin::Logger> role. It is used to send informal messages
to the outer world.

=cut

has 'logger' => (
	is		=> 'ro',
	required	=> 1
);

=pod

=head2 C<object>

A base object on which the function will be called.

=cut

has 'object' => (
	is		=> 'ro',
	predicate	=> 'has_object',
	required	=> 1
);

=pod

=head2 C<function>

The function name which will be called. This does not need to be an existing
function upon construction, but is checked when invoking the C<check>
function.

=cut

has 'function' => (
	is		=> 'ro',
	isa		=> 'Str',
	required	=> 1
);

=pod

=head2 C<signature>

The function signature.

=cut

has 'signature' => (
	is		=> 'ro',
	isa		=> 'ArrayRef[Str]',
	default		=> sub { [] }
);


################################################################################
# Methods
#

=pod

=head1 METHODS

=cut

sub BUILD {
	my ($self) = @_;
	
	# Verify attribute roles
	die('Invalid logger specified') unless ($self->logger->does('Slimrat::Server::Plugin::Logger'));
}

=pod

=head2 C<$connector->check>

Check if the specified function exists in the object.

=cut

sub check {
	my ($self, @params) = @_;
	
	# Check if function exists
	$self->logger->error("function does not exist")
		unless ($self->object->can($self->function));
	
	# Check function signature
	$self->logger->error("incorrect amount of parameters")
		unless (@_ == @{$self->signature});
	for my $i (0 .. @_) {
		$self->logger->error("incorrect parameter")
			unless (ref(\($_[$i])) eq $self->signature->[$i]);
	}
}

=pod

=head2 C<$connector->invoke>

Invoke the function with specified parameters. It is wise to verify the function
and its parameters using the C<check> function before invoking it.

=cut

sub invoke {
	my ($self, @params) = @_;
	
	my $coderef = $self->object->can($self->function);
	($self->object)->$coderef(@params);
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
