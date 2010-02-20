################################################################################
# Configuration
#

# Package definition
package Slimrat::Server::Inetd;

=pod

=head1 NAME

Slimrat::Server::Intetd - Slimrat server internet daemon

=head1 DESCRIPTION

The C<Slimrat::Server::Inetd> package functions like a internet super-server,
listening for remote requests and translating them to local procedure calls.

=head1 SYNPOSIS

=cut

# Packages
use Moose;
use IO::Socket;
use XML::RPC;

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

=head2 C<backend>

A required attribute, which serves as backend to set and get all dynamic
data. It should consume the C<Slimrat::Server::Plugin::Backend> role.

=cut

has 'backend' => (
	is		=> 'ro',
	required	=> 1,
);

=pod

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

=head2 C<socket>

The actual socket on which the internet server listens.

=cut

has 'socket' => (
	is		=> 'ro',
	isa		=> 'IO::Socket::INET',
	builder		=> '_build_socket',
	lazy		=> 1
);

sub _build_socket {
	my ($self, @params) = @_;
	
	$self->{'socket'} = IO::Socket::INET->new(
		LocalPort	=> $self->config->get("port"),
		Type		=> SOCK_STREAM,
		Reuse		=> 1,
		Listen		=> $self->config->get("queue")
	) or die "$@\n";
}

=pod

=head2 C<xmlrpc>

The XML-RPC interpreter, which'll decode requests from an external client.

=cut

has 'xmlrpc' => (
	is		=> 'ro',
	isa		=> 'XML::RPC',
	builder		=> '_build_xmlrpc',
	lazy		=> 1
);

sub _build_xmlrpc {
	my ($self, @params) = @_;
	
	$self->{'xmlrpc'} = XML::RPC->new();
}

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
	$self->logger->fatal("invalid backend specified") unless ($self->backend->does('Slimrat::Server::Plugin::Backend'));
	
	# Default configuration values
	$self->config->set_default("port", 6800);
	$self->config->set_default("queue", 10);
	
	# Build attributes which depend on the config object
	$self->socket();
	$self->xmlrpc();	
}

=pod

=head2 C<$inetd->run()>

The main loop, which listens for external connections, decodes the received
data as a HTTP requests, decodes the POST-body as XML-RPC request, and finally
issues a local procedure call.

=cut

sub run {
	my ($self, @params) = @_;
	
	# Listen for connections
	$self->logger->info("Accepting connections");
	my $client;
	while ($client = $self->socket()->accept()) {
		# Handle the connection in a fork
		next if my $pid = fork;
		if (not defined $pid) {
			$self->logger->error("client fork failed ($!)");
			next;
		}
	
		$self->process_connection($client);
	}
	continue {
		close($client);
		kill CHLD => -$$;
	}
}

=pod

=head2 C<$inetd->process_connection($client)

Process a newly connected client. This includes fetching some bytes and
determining the type of request. Possible request types (and associated
handler methods) are:
=over
=item HTTP request: handled by C<process_http>
=back

Before calling the respective protocol handlers, essential protocol-specific
data which was needed to determine the protocol, is passed as well (mostly
request headers).

=cut

sub process_connection {
	my ($self, $client) = @_;
	
	# Extract the request message
	my $message;
	while(<$client>)
	{
		last if /^\r\n$/;
		$message .= $_;
	}
	$self->logger->debug("recieved client request", $message);

	# Split the request message in the request line and a set of headers
	@_ = split(/\n/, $message);
	my $request = shift @_;
	my %headers = map{ m/^(.+?): (.*?)\s*$/ } @_;
	
	# TODO: identify http instead of guessing
	$self->process_http($client, $request, %headers);
	close($client);
	select STDOUT;
	exit(fork);
}

=pod

=head2 C<$inetd->process_http($client, %headers)

This method processes an identified HTTP connection. The passed headers have
already been extracted (as they were needed to determine the protocol), which
only leaves the HTTP body to be decoded (in case of a POST request).

After identifying the application protocol, the correct handler is called:
=over
=item XML-RPC over HTTP: process_http_xmlrpc
=back

=cut

sub process_http {
	my ($self, $client, $request, %headers) = @_;
	
	# Split the request line
	my ($method, $uri, $version) = split(/ /, $request);

	# Check request type
	if ($method eq 'POST') {		
		# Get request body
		my $body;
		while(<$client> )
		{
			$body .= $_;
			last if (length($body) >= $headers{'Content-Length'});
		}
		
		# TODO: identify xmlrpc instead of guessing
		$self->process_http_xmlrpc($client, $body);	
	} else {
		# Send error
		$self->logger->error("refusing unknown request method '$method'");
		select $client;
		$| = 1;		
		print $client "HTTP/1.0 501 NOT IMPLEMENTED\r\n\r\n";
		print $client "<H1>501 Method Not Implemented</H1>";	
	}
}

=pod

=head2 C<$inetd->process_http_xmlrpc($client, $request)

This method handles an application protocol over HTTP, in this case XML-RPC.

=cut

sub process_http_xmlrpc {
	my ($self, $client, $body) = @_;
	
	# Get response
	my $response = $self->xmlrpc()->receive($body, sub {
		my ($rpc_name, @rpc_params) = @_;
	
		# Split in package and method
		my ($package, $method) = split(/\./, $rpc_name);
		unless (defined $method) { $method = $package; $package = undef; }
		
		# Invoke the method
		return $self->invoke($package, $method, @rpc_params);
	});
	$self->logger->debug("sending client response", $response);

	# Send response
	select $client;
	$| = 1;		
	print $client "HTTP/1.0 200 OK\r\n";
	print $client "Content-type: text/xml\r\n\r\n";
	print $client $response;	
}

=pod

=head2 C<$inetd->invoke($package, $method, @params)

This method provides the connection between an RPC-request and an actual
local procedure call. Before making this call, the method verifies the usage,
and possibly returns an XML-RPC fault prematurely.

=cut

sub invoke {
	my ($self, $package, $method, @params) = @_;
	$self->logger->debug("invoking '$method'" . ($package?" in package '$package'":''));
	
	# Prevent critical errors from reaching the user
	$SIG{__DIE__} = sub {
		$self->logger->error('client caused die-signal', @_);
		fault('internal error');
	};
	$SIG{__WARN__} = sub {
		$self->logger->warning('client caused warn signal', @_);
	};
	
	#
	# Classless methods
	#
	
	if (not defined $package) {
		if ($method eq "hello") {
			require Data::Dumper;
			print Dumper(\@params);
		} else {
			fault('unknown method');
		}
	}
	
	
	else {
		fault('unknown package');
	}
	
}

################################################################################
# Auxiliary
#

=pod

=head1 AUXILIARY

=head2 C<signal_child>

Child signal handler (which issues a 'wait' syscall to avoid zombie processes).

=cut

$SIG{CHLD} = \&signal_child;

sub signal_child {
	wait;
}

sub fault {
	my ($message, $code) = @_;
	$code ||= -1;
	
	$XML::RPC::faultCode = $code;
	die($message . "\n");	# The "\n" prevents die() from printing a trace
}

1;

__END__

=pod

=head1 CONFIGURATION

=head2 C<port>

The port on which the internet daemon listens for webrequests.

B<Default value>: 6800

=head2 C<queue>

The size of the socket queue, which directly translates to the C<Listen>
property of C<IO::Socket::INET>.

B<Default value>: 10

=head1 COPYRIGHT

Copyright 2008-2010 The slimrat development team as listed in the AUTHORS file.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
