package Filer::Tools;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

# require Exporter;
# our @ISA = qw(Exporter);
# our @EXPORT = qw(catpath);

# REAPER  - taken from 'man perlipc'

use POSIX ":sys_wait_h";

sub REAPER {
	my $child;
	my %Kid_Status;

	# If a second child dies while in the signal handler caused by the
	# first death, we won't get another signal. So must loop here else
	# we will leave the unreaped child as a zombie. And the next time
	# two children die we get another zombie. And so on.
	while (($child = waitpid(-1,WNOHANG)) > 0) {
		$Kid_Status{$child} = $?;
	}

	$SIG{CHLD} = \&REAPER;  # still loathe sysV
}

$SIG{CHLD} = \&REAPER;

sub start_program {
	my ($self,$command,@params) = @_;

	my $pid = fork();
	return 0 unless defined $pid;

	if ($pid == 0) { # child
		exec $command, @params;
		exit 0;
	} elsif ($pid > 0) {
		print "forked $command\n";
	}

	return $pid;
}

sub wait_for_pid {
	my $pid = pop;

	while (kill 0, $pid) {
		while (Gtk2->events_pending) {
			Gtk2->main_iteration
		}
	}
}

####

sub catpath {
	my ($self,$dir,@p) = @_;
	return File::Spec->catfile(File::Spec->splitdir($dir), @p);
}

sub _mkdir {
	my ($self,$dir) = @_;
	my $p = File::Spec->rootdir; 

	foreach (File::Spec->splitdir($dir)) {
		$p = Filer::Tools->catpath($p, $_); 

		if (! -e $p) {
			mkdir($p) || return undef;
		}
	}

	return 1;
}

sub suggest_filename_helper {
	my $filename  = pop;
	my $suggested = "";
	my $suffix    = "";
	my $i         = 1;

	if (-f $filename) {
		if ($filename =~ /((\..+)+)$/) {
			my $re_sx = $1;
			$suffix = $re_sx;

			# escape parentheses.
			$re_sx =~ s/\(/\\(/g;
			$re_sx =~ s/\)/\\)/g;
			$re_sx =~ s/\[/\\[/g;
			$re_sx =~ s/\]/\\]/g;

			$filename =~ s/$re_sx//g;
		}
	}

	if ($filename =~ /(_\(copy\))$/) {
		my $r = $1;
		$r =~ s/\(/\\(/g;
		$r =~ s/\)/\\)/g;
		$filename =~ s/$r//g;
		$i = 2;
	} elsif ($filename =~ /(_\(another copy\))$/) {
		my $r = $1;
		$r =~ s/\(/\\(/g;
		$r =~ s/\)/\\)/g;
		$filename =~ s/$r//g;
		$i = 3;
	} elsif ($filename =~ /(_\(3rd copy\))$/) {
		my $r = $1;
		$r =~ s/\(/\\(/g;
		$r =~ s/\)/\\)/g;
		$filename =~ s/$r//g;
		$i = 4;
	}

	while (1) {
		if ($i == 1) {
			$suggested = "$filename\_(copy)";
		} elsif ($i == 2) {
			$suggested = "$filename\_(another_copy)";
		} elsif ($i == 3) {
			$suggested = "$filename\_(3rd_copy)";
		} else {
			$suggested = "$filename\_($i" . "th" . "_copy)";
		}

		last if (! -e "$suggested$suffix");
		$i++;
	}

	return "$suggested$suffix";
}

sub calculate_size {
	my $size = pop;

	if ($size >= 1073741824) {
		return sprintf("%.2f GB", $size/1073741824);
	} elsif ($size >= 1048576) {
		return sprintf("%.2f MB", $size/1048576);
	} elsif ($size >= 1024) {
		return sprintf("%.2f kB", $size/1024);
	}

	return $size;	
}

# Utility functions for Gtk+ classes:

package Gtk2::Gdk::Pixbuf;

sub intelligent_scale {
	my ($self,$scale) = @_;
	my $w;
	my $h;

	my $ow = $self->get_width;
	my $oh = $self->get_height;

	if ($ow <= $scale and $oh <= $scale) {

		return $self;

	} else {
		if ($ow > $oh) {
			$w = $scale;
			$h = $scale * ($oh/$ow);
        	} else {
			$h = $scale;
			$w = $scale * ($ow/$ow);
		}

		return $self->scale_simple($w, $h, 'GDK_INTERP_BILINEAR');
	}
}

package Gtk2::ComboBox;

sub set_popdown_strings {
	my ($self,@strings) = @_;
	
	foreach (@strings) {
		$self->append_text($_);
	}
}

1;
