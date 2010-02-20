# Browser.pm - Abstraction of WWW::Mechanize to support content-
#              encodings
#
# Copyright (c) 2009 Tim Besard
#
# This file is part of slimrat, an open-source Perl scripted
# command line and GUI utility for downloading files from
# several download providers.
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# Authors:
#    Tim Besard <tim-dot-besard-at-gmail-dot-com>
#

#################
# CONFIGURATION #
#################

# Package name
package WWW::Mechanize::GZip;

# Extend WWW::Mechanize
use base qw(WWW::Mechanize);

# Packages
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError);

# Find root for custom packages
use FindBin qw($RealBin);
use lib $RealBin;

# Custom packages
use Log;
use Configuration;

# Write nicely
use strict;
use warnings;

# Base configuration
my $config = new Configuration;
$config->set_default("compression", 1);
$config->set_default("timeout", 900);
$config->set_default("useragent", "slimrat/trunk");     # TODO: get Common::$VERSION in here


#
# Static functionality
#

# Configure the plugin producer
sub configure($) {
	my $complement = shift;
	$config->merge($complement);
	$config->merge($config->section("plugin"));
}


#
# Object-oriented functionality
#

# Constructor
sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
        
	$self->default_header('Accept-Language' => "en");
	$self->agent($config->get("useragent"));
	$self->timeout($config->get("timeout"));
	
        return $self;
} 

# Prepare a new request, with encoding-headers appended
sub prepare_request {
    my ($self, $request) = @_;

    # call baseclass-method to prepare request...
    $request = $self->SUPER::prepare_request($request);

    # set HTTP-header to request gzip-transfer-encoding at the webserver
    $request->header('Accept-Encoding' => ["identity", "gzip", "x-gzip", "x-bzip2", "deflate"]);

    return ($request);
}

# Send a request and return the (decoded) response
sub send_request {
    my ($self, $request, $arg, $size) = @_;

    # call baseclass-method to make the actual request
    my $response = $self->SUPER::send_request($request, $arg, $size);

    # check if response is declared as gzipped and decode it
    if ($response && defined($response->headers->header('content-encoding')) && $response->headers->header('content-encoding') eq 'gzip') {
        # store original content-length in separate response-header
        $response->headers->header('x-content-length', length($response->{_content}));
        
        # decompress ...
        $response->{_content} = Compress::Zlib::memGunzip(\($response->{_content}));
        
        # store new content-length in response-header
        $response->{_headers}->{'content-length'} = length($response->{_content});
    }
    return $response;
}

# Decode an already downloaded file
sub decode_file($$) {
    my ($filepath, $encoding) = @_;
    if ($encoding) {
            for my $ce (reverse split(/\s*,\s*/, lc($encoding))) {
                    next unless $ce;
                    next if $ce eq "identity";
                    if ($ce =~ m/^(gzip|x-gzip|bzip2|deflate)/) {
                            debug("uncompressing standard encodings");
                            anyuncompress $filepath => "$filepath.temp", AutoClose => 1, BinModeOut => 1
                                    or return 0; # TODO: do something with $AnyUncompressError
                            rename("$filepath.temp", $filepath);
                    } else {
                        return 0; # TODO: error
                    }
            }
    }
    return 1;
}

1;
