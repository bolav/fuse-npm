package CreateModule;

use Moose;
use File::Spec;
use JSON;
use Try::Tiny;
use Data::Dump qw/dump/;

has 'seen' => (is => 'rw', isa => 'HashRef', default => sub { {}; });
has 'tree' => (is => 'ro', isa => 'HashRef', default => sub { {}; });
has 'collisions' => (is => 'ro', isa => 'ArrayRef', default => sub { []; });
has 'rerun' => (is => 'rw');
has 'rewrite' => (is => 'rw');
has 'seenset' => (is => 'rw', isa => 'HashRef', default => sub { {}; });
has 'rewrites' => (is => 'rw', isa => 'HashRef', default => sub { {}; });

sub create_loadmodule {
	my ($self, $module) = @_;

	my $ret = 'using Uno;
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

	$self->rerun(1);
	$self->rewrite(0);

	my $mods = '';
	while ($self->rerun) {
		$self->rerun(0);
		try {
			$mods = $self->include_module($module, $module, "node_modules");
		} catch {
			warn "$_";
		};
		if ($self->rerun) {
			$self->seen({});
			$self->rewrite(1);
			$self->rewrites({});
			dump $self->collisions;
			# die "Collisions";
		}
	}
	$ret .= $mods;
	$ret .= '} }',"\n";

}

# https://nodejs.org/api/modules.html
sub include_module {
	my ($self, $module, $file, $dir) = @_;
	if ($self->seenset->{"$module - $file - $dir"}) {
		warn "seen!! $module - $file - $dir";
		return '';
	}
	$self->seenset->{"$module - $file - $dir"}++;
	# warn "Including $file, $module, $dir";

	my $ret = '';
	my $fn = File::Spec->catfile($dir, $file);
	# warn $fn;
	if (-d $fn) {
		if (-e File::Spec->catfile($fn, 'index.js')) {
			$ret .= $self->include_module($module, "index.js", $fn);
		}
		elsif (-e File::Spec->catfile($fn, 'package.json')) {
			$ret .= $self->parse_packagejson($module, $fn);
		}
	}
	elsif (-e $fn) {
		$ret .= $self->parse_module($module, $fn, $dir);
		my $reg = $self->register($module, $fn);
		return $ret unless ($reg);
		$ret .= $reg;
	}
	elsif (-e $fn . '.js') {
		$ret .= $self->parse_module($module, $fn . '.js' , $dir);
		my $reg = $self->register($module, $fn . '.js');
		return $ret unless ($reg);
		$ret .= $reg;
	}
	elsif (-e '/Users/bolav/dev/socket.io/node/lib/' . $module . '.js' ) {
		$fn = '/Users/bolav/dev/socket.io/node/lib/' . $module . '.js';
		$ret .= $self->parse_module($module, $fn, '/Users/bolav/dev/socket.io/node/lib/');
		my $reg = $self->register($module, $fn);
		return $ret unless ($reg);
		$ret .= $reg;
	}
	else {
		warn "Funky town $file, $module, $dir, $fn";
		die "funky town";
	}
	return $ret;
}

sub register {
	my ($self, $module, $fn) = @_;

	if ($self->seen->{$module}) {
		# warn "Already have $module (".$self->seen->{$module}.") $fn";
		if ($fn ne $self->seen->{$module}) {
			$self->rerun(1);
			push @{$self->collisions}, $module;
			# $self->seen({});
			# $self->rerun(0);
			# die "Name collision $module " . $self->seen->{$module} . " $fn" ;
		}
		return;
	}

	$self->seen->{$module} = $fn;

	# warn $fn;
	# mkdir 'fusejs_lib';

	return 'Register("'. $module .'", new FileModule(import BundleFile("'. $fn .'")));'."\n";
}

sub trouble_file {
	my ($self, $module) = @_;
	return 0 unless ($self->rewrite);
	warn "Checking $module";
	foreach my $c (@{$self->collisions}) {
		return 1 if $self->tree->{$c};
	}
	return 0;
}

sub rewrite_module {
	my ($self, $module, $file, $dir) = @_;
	mkdir 'fusejs_lib';

	my $fn_file = $file;
	$fn_file =~ s/[^\w]/_/g;

	my $fn = File::Spec->catfile('fusejs_lib', $fn_file);
	my $ret = '';

	$self->rewrites->{$file} = $fn;

	open my $in, '<', $file || die "$file: $!";
	open my $out, '>', $fn || die "$fn : $!";

	warn "Rewriting $module, $file, $fn";

	while (<$in>) {
		if (/require\s*\(['"]([\w\.\/\-]+)['"]\)/) {
			my $new_module = $1;
			warn "require $new_module ($file)";

			push @{$self->{tree}->{$new_module}}, $file;
			# rewrite???
			if ($new_module =~ /^\.\.?\//) {
				$ret .= $self->include_module($new_module, $new_module, $dir);
			}
			else {
				$ret .= $self->include_module($new_module, $new_module, "node_modules");
			}
		}

		print $out $_;
	}
	close $in;
	close $out;
	return $ret;
}

sub parse_module {
	my ($self, $module, $file, $dir) = @_;

	if ($self->trouble_file($file)) {
		my $lself = shift @_;
		return $lself->rewrite_module(@_);
	}
	my $ret = '';
	# warn "Reading $file, $module, $dir";
	open my $fh, '<', $file || die "$file: $!";
	while (<$fh>) {
		# warn "\t" . $_ if /parser/;
		if (/require\s*\(['"]([\w\.\/\-]+)['"]\)/) {
			my $new_module = $1;
			warn "require $new_module ($file) $module";

			push @{$self->{tree}->{$new_module}}, $file;
			# rewrite???
			if ($new_module =~ /^\.\.?\//) {
				my $new_dir = $dir;
				if (($module =~ './lib/WebSocket') ||
					($module =~ './lib/Sender') ||
					($module =~ './lib/Receiver')
				) {
					$new_dir = File::Spec->catfile($dir, 'lib');
				}
				$ret .= $self->include_module($new_module, $new_module, $new_dir);
			}
			else {
				$ret .= $self->include_module($new_module, $new_module, "node_modules");
			}
		}
	}
	close $fh;
	return $ret;
}

sub parse_packagejson {
	my ($self, $module, $dir) = @_;
	warn "Reading package.json, $module, $dir";
	my $json = '';
	my $fn = File::Spec->catfile($dir, 'package.json');
	open my $fh, '<', $fn || die "$fn: $!";
	while (<$fh>) {
		$json .= $_;
	}
	close $fh;
	my $obj = decode_json $json;
	return $self->include_module($module, $obj->{main}, $dir);
}

1;