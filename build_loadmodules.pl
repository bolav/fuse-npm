#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin";
use CreateModule;


my $cm = new CreateModule;

open my $fh, ">", "LoadModules.uno";
foreach my $module (@ARGV) {
	warn "Including $module";
	print $fh $cm->create_loadmodule($module);
}
close $fh;
