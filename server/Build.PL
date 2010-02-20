#!/usr/bin/env perl

use Module::Build;

my $build = Module::Build->new (
    module_name         => 'Slimrat::Server',
    dist_name           => 'Slimrat::Server',
    dist_version        => '1.99',
    dist_author         => 'The slimrat team <slimrat@googlegroups.com>',
    dist_abstract       => 'The slimrat server',
    license             => 'artistic_2',
    requires            => {
        'perl'                  => 5,
        'Moose'		        => '0.26',
        'WWW::Mechanize'	=> 0,
        'LWP::UserAgent'	=> 0,
        'XML::RPC'		=> 0,
        'IO::Socket'	        => 0,
        'Carp'                  => 0
    },
    recommends => {
        'DBI'		        => 0,
        'Sys::Syslog'           => 0,
        'Term::ANSIColor'       => 0
    }
);
$build->create_build_script;
