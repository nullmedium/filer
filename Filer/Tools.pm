package Filer::Tools;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

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
		while (Gtk2->events_pending) { Gtk2->main_iteration }
	}
}

####

# sub format_mode {
# 	my $mode = pop;
# 
# 	my @perms = qw(--- --x -w- -wx r-- r-x rw- rwx);
# 	my @ftype = qw(. p c ? d ? b ? - ? l ? s ? ? ?);
# 	$ftype[0] = '';
# 
# 	my $setids = ($mode & 07000) >> 9;
# 	my @permstrs = @perms[($mode & 0700) >> 6, ($mode & 0070) >> 3, $mode & 0007];
# 	my $ftype = $ftype[($mode & 0170000) >> 12];
# 
# 	if ($setids) {
# 		if ($setids & 01) {         # Sticky bit
# 			$permstrs[2] =~ s/([-x])$/$1 eq 'x' ? 't' : 'T'/e;
# 		}
# 		if ($setids & 04) {         # Setuid bit
# 			$permstrs[0] =~ s/([-x])$/$1 eq 'x' ? 's' : 'S'/e;
# 		}
# 		if ($setids & 02) {         # Setgid bit
# 			$permstrs[1] =~ s/([-x])$/$1 eq 'x' ? 's' : 'S'/e;
# 		}
# 	}
# 
# 	join '', $ftype, @permstrs;
# }

sub catpath {
	my ($self,$dir,@p) = @_;
	return File::Spec->catfile(File::Spec->splitdir($dir), @p);
}

sub calculate_size {
	my ($self,$size) = @_;

	if ($size >= 1073741824) {
		return sprintf("%.2f GB", $size/1073741824);
	} elsif ($size >= 1048576) {
		return sprintf("%.2f MB", $size/1048576);
	} elsif ($size >= 1024) {
		return sprintf("%.2f kB", $size/1024);
	} else {
		return sprintf("%d Byte", $size);
	}

	return $size;	
}

sub intelligent_scale {
	my ($self,$pixbuf,$scale) = @_;
	my $scaled;
	my $w;
	my $h;

	my $ow = $pixbuf->get_width;
	my $oh = $pixbuf->get_height;

	if ($ow <= $scale and $oh <= $scale) {
		$scaled = $pixbuf;
	} else {
		if ($ow > $oh) {
			$w = $scale;
			$h = $scale * ($oh/$ow);
        	} else {
			$h = $scale;
			$w = $scale * ($ow/$ow);
		}

		$scaled = $pixbuf->scale_simple($w, $h, 'GDK_INTERP_BILINEAR');
	}

	return $scaled;
}

1;
