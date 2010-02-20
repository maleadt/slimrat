#!/usr/bin/env perl

#
# Configuration
#

# Write nicely
use strict;
use warnings;

# Packages
use Perl::Critic;
use File::Find;
use Term::ANSIColor qw(:constants);
use FindBin qw($RealBin);

# Script locations
my $path = '../';
my @modules = qw{server clients/cli clients/swing/src/swingrat};

# Construct static analyzers
my $critic = Perl::Critic->new();

# Global statistics hash
my %loc = ();


#
# Main
#

# Anaylyze
print "* Validating files\n";
map {
	find({ wanted=>\&scan}, $path . $_);
} @modules;
print "\n";

# Print line-count statistics
my $statistics = $critic->statistics();
print "* Done, line-count statistics:\n";
map {
	print "- ", BOLD, $_, RESET, ": ", $loc{$_}, " lines\n";
} keys %loc;


#
# Routines
#

# Scan for files
sub scan {
	# Skip non-files and backup files
	return if m/~$/;
	return unless (-f $_);
	
	# Get file information
	my $extension = ($_ =~ m/\.([^\.]+)$/)[0] || "";
	my $type = `LANG=C file "$_"`;
	chomp($type);
	$type =~ s/^[^:]+: //;
	my $lines = `wc -l "$_"`;
	($lines) = $lines=~m/^(\d+)/;
	
	# Analyze
	my $category;
	my @violations;
	if ($extension =~ m/(pm|pl)/i || $type =~ "perl script" || $type =~ "Perl5 module") {
		$category = "Perl";
		@violations = validate_perl($_);
	} elsif ($extension =~ m/(java)/) {
		$category = "Java";
		@violations = validate_java($_);
	}
	if ($category) {
		print "- ", $File::Find::dir, "/", BOLD, $_, RESET, " ($type)\n";
		$loc{$category} += $lines;	
	}
	
	# Print violations
	if (@violations) {
		print map{ "  " . RED . join("\n    ", split(/\n/, $_)) . RESET . "\n"}@violations;
	}
}

# Validate perl code
sub validate_perl {
	my $file = shift;
	
	return $critic->critique($_);
}

# Validate java code
sub validate_java {
	my $file = shift;
	
	my $output = `java -jar $RealBin/checkstyle-5.0/checkstyle-all-5.0.jar -c $RealBin/checkstyle-5.0/sun_checks.xml "$file"`;
	chomp $output;
	my @lines = split(/\n/, $output);
	
	# Remove audit headings
	shift @lines;
	pop @lines;
	
	return map {
		s/^[^:]*://;
		s/:(\d+)/ column $1/;
		s/^(\d+)/line $1/;
		$_;
	
	} @lines;
}

