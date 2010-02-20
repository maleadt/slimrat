#!/usr/bin/env perl


#
# Configuration
#

# Define a new class, implementing a Backend
package File;
#with 'Core';

# Write nicely
use strict;
use warnings;


#
# Methods
#
print "MAKING FILE YAAH\n";
sub connect {
	print "File connection\n";
}
sub new {
	print "BOOYAH\n";
	use Data::Dumper;
	print Dumper(\@_);
}
