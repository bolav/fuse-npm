#!/usr/bin/perl

use File::Spec;
use JSON;

our $seen = {};
open my $fh, ">", "LoadModules.uno";

print $fh 'using Uno;
using Uno.Collections;
using Fuse;
using Fuse.Scripting;
public class LoadModules : Behavior
{
	static void Register(string moduleId, IModule module)
	{
		Uno.UX.Resource.SetGlobalKey(module, moduleId);
	}

	public LoadModules () {
		debug_log "Loading my modules";
';


# 
foreach my $module (@ARGV) {
	warn "Including $module";
	print $fh include_module($module, $module, "node_modules");
}



print $fh '} }',"\n";
close $fh;

# https://nodejs.org/api/modules.html
sub include_module {
	my ($module, $file, $dir) = @_;
	warn "Including $file, $module, $dir";

	my $ret = '';
	my $fn = File::Spec->catfile($dir, $file);
	# warn $fn;
	if (-d $fn) {
		if (-e File::Spec->catfile($fn, 'index.js')) {
			$ret .= include_module($module, "index.js", $fn);
		}
		elsif (-e File::Spec->catfile($fn, 'package.json')) {
			$ret .= parse_packagejson($module, $fn);
		}
	}
	elsif (-e $fn) {
		my $reg = register($module, $fn);
		return $ret unless ($reg);
		$ret .= $reg;
		$ret .= parse_module($module, $fn, $dir);
	}
	elsif (-e $fn . '.js') {
		my $reg = register($module, $fn . '.js');
		return $ret unless ($reg);
		$ret .= $reg;
		$ret .= parse_module($module, $fn . '.js' , $dir);
	}
	elsif (-e '/Users/bolav/dev/socket.io/node/lib/' . $module . '.js' ) {
		$fn = '/Users/bolav/dev/socket.io/node/lib/' . $module . '.js';
		my $reg = register($module, $fn);
		return $ret unless ($reg);
		$ret .= $reg;
		$ret .= parse_module($module, $fn, '/Users/bolav/dev/socket.io/node/lib/');
	}
	else {
		warn "Funky town $file, $module, $dir";
		die "funky town";
	}
	return $ret;
}

sub register {
	my ($module, $fn) = @_;

	if ($seen->{$module}) {
		# warn "Already have $module (".$seen->{$module}.") $fn";
		die "Name collision $module " . $seen->{$module} . " $fn" if ($fn ne $seen->{$module});
		return;
	}

	$seen->{$module} = $fn;
	return 'Register("'. $module .'", new FileModule(import BundleFile("'. $fn .'")));'."\n";
}

sub parse_module {
	my ($module, $file, $dir) = @_;
	my $ret = '';
	warn "Reading $file, $module, $dir";
	open my $fh, '<', $file || die "$file: $!";
	while (<$fh>) {
		# warn "\t" . $_ if /parser/;
		if (/require\s*\(['"]([\w\.\/\-]+)['"]\)/) {
			my $new_module = $1;
			warn "require $new_module ($file)";
			# rewrite???
			if ($new_module =~ /^\.\//) {
				$ret .= include_module($new_module, $new_module, $dir);
			}
			else {
				$ret .= include_module($new_module, $new_module, "node_modules");
			}
		}
	}
	close $fh;
	return $ret;
}

sub parse_packagejson {
	my ($module, $dir) = @_;
	warn "Reading package.json, $module, $dir";
	my $json = '';
	my $fn = File::Spec->catfile($dir, 'package.json');
	open my $fh, '<', $fn || die "$file: $!";
	while (<$fh>) {
		$json .= $_;
	}
	close $fh;
	my $obj = decode_json $json;
	return include_module($module, $obj->{main}, $dir);
}
