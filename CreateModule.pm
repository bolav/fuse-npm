package CreateModule;

use Moose;
use File::Spec;
use JSON;
use Try::Tiny;
use Data::Dump qw/dump/;

has 'seen' => (is => 'rw', isa => 'HashRef', default => sub { {}; });
has 'file_module' => (is => 'ro', isa => 'HashRef', default => sub { {}; });
has 'tree' => (is => 'ro', isa => 'HashRef', default => sub { {}; });
has 'collisions' => (is => 'ro', isa => 'ArrayRef', default => sub { []; });
has 'rerun' => (is => 'rw');
has 'rewrite' => (is => 'rw');
has 'seenset' => (is => 'rw', isa => 'HashRef', default => sub { {}; });
has 'babel' => (is => 'rw', isa => 'HashRef', default => sub { {}; });
has 'rewrites' => (is => 'rw', isa => 'HashRef', default => sub { {}; });

sub builtin {
	my ($self, $module) = @_;
	my $rew = {
		'tty' => 'tty-browserify',
		'debug' => '_empty.js',
		'fs' => '_empty.js',
		'xmlhttprequest' => '_empty.js',
		'url' => 'browserify_modules/url',
		'buffer' => 'browserify_modules/buffer',
		'ws' => '_empty.js',
		# Just to find it:
		'ieee754' => 'browserify_modules/ieee754',
	};
	return $rew->{$module} || $module;
}

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
			$self->seenset({});
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
	warn $fn;
	if (-d $fn) {
		if (-e File::Spec->catfile($fn, 'index.js')) {
			$ret .= $self->include_module($module, "index.js", $fn);
		}
		elsif (-e File::Spec->catfile($fn, 'package.json')) {
			$ret .= $self->parse_packagejson($module, $fn);
		}
	}
	elsif (-e $fn) {
		my $fn_js;
		my ($new_dir, $fn_js) = ($fn =~ /^(.*\/)([^\/]+)$/);
		$dir = $new_dir if ($new_dir);
		warn "$fn $dir";
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

	$fn = $self->rewrites->{$fn} if ($self->rewrites->{$fn});
	warn 'Register ' . $module . ', ' . $fn;

	if ($self->seen->{$module}) {
		# warn "Already have $module (".$self->seen->{$module}.") $fn";
		if ($fn ne $self->seen->{$module}) {
			if ($self->rewrite) {
				warn "Still seen ";
				warn dump $self->collisions;
				warn "Already have $module (".$self->seen->{$module}.") $fn";

				exit(0);
			}

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
	warn "trouble_file $module";
	foreach my $c (@{$self->collisions}) {
		foreach my $m (@{$self->file_module->{$c}}) {
			return 1 if ($m eq $module);
		}
	}
	return 0;
}

sub rewrite_name {
	my ($self, $module, $dir) = @_;
	foreach my $c (@{$self->collisions}) {
		warn "rewrite_name $module eq $c";
		if ($module eq $c) {
			warn "Trouble with $c ($dir)";
			return $c. '__'. $dir;
		}
	}
	return;
}

sub parse_module {
	my ($self, $module, $file, $dir) = @_;

	my $rewrite = 0;

	if ($self->trouble_file($file)) {
		$rewrite = 1;
	}

	my $open_file = $file; # Filename to open, and process
	my $fn_file = $file;
	$fn_file =~ s/[^\w\.]/_/g;

	my $fn = File::Spec->catfile('fusejs_lib', $fn_file);
	my $ret = '';

	if ($self->babel->{$file}) {
		warn "babel $file";
		if ($rewrite) {
			warn "babel and rewrite";
			exit(0);
		}
		system("babel $file > $fn");
		$self->rewrites->{$file} = $fn;
		$open_file = $fn;
	}

	if ($rewrite) {
		mkdir 'fusejs_lib';
		$self->rewrites->{$file} = $fn;
	}

	open my $in, '<', $open_file || die "$file: $!";
	my $out;

	if ($rewrite) {
		open $out, '>', $fn || die "$fn : $!";
		warn "Rewriting $module, $file, $fn";
	}


	while (my $line = <$in>) {
		if ($line =~ /require\s*\(['"]([\w\.\/\-]+)['"]\)/) {
			my $new_module = $1;
			$new_module = $self->builtin($new_module);
			warn "require $new_module ($file)";

			push @{$self->file_module->{$new_module}}, $file;
			push @{$self->tree->{$new_module}}, $module;
			# rewrite???
			if ($new_module =~ /^\.\.?\//) {
				my $rew_module = $new_module;
				if (my $r = $self->rewrite_name($new_module, $dir)) {
					$rew_module = $r;
					$line =~ s/\Q$new_module\E/$rew_module/;
					warn "Rewriteing require ($new_module): $_";
				}
				my $new_dir = $dir;
				if (($module =~ './lib/WebSocket') ||
					($module =~ './lib/Sender') ||
					($module =~ './lib/Receiver')
				) {
					$new_dir = File::Spec->catfile($dir, 'lib');
				}
				$ret .= $self->include_module($rew_module, $new_module, $new_dir);
			}
			else {
				$ret .= $self->include_module($new_module, $new_module, "node_modules");
			}
		}
		if ($line =~ /\bprocess\b[^\']/) {
			warn 'process API is not available in Fuse ('. $file .')';
			$self->dump_tree($module);
			warn $line;
			exit(0);
		}
		if (($line =~ /^\s*const/)

			){
			$self->babel->{$file}++;
			warn "Reading $file, $module, $dir";
			warn "Illegal definition const, adding babel preprocessing";
		}

		if ($rewrite) {
			print $out $line;
		}
	}
	close $in;
	if ($rewrite) {
		close $out;
	}
	return $ret;
}

sub dump_tree {
	my ($self, $module, $indent) = @_;
	$indent ||= '';
	$indent = '  ' . $indent;
	warn "$indent Module : $module";
	if ($self->tree->{$module}) {
		warn dump $self->tree->{$module};
		$self->dump_tree($self->tree->{$module}->[0], $indent);
	}
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