package Filer::Tools;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

sub exec {
	my ($self,%opts) = @_;

	my $cmd  = $opts{command} || die "no command defined!";
	my $wait = $opts{wait};

	my $main_loop = Glib::MainLoop->new;

	print "open $cmd\n";
	my $pid = open my $child, '-|', $cmd || die "can't fork $cmd: $!";

	Glib::IO->add_watch(fileno $child, ['hup'], sub {
		$main_loop->quit;
		return 0;
	});

	print "run\n";
	$main_loop->run;

	print "close $child\n";
	close $child or warn "$cmd died with exit status ".($? >> 8)."\n";
}

####

sub catpath {
	my ($self,$dir,@p) = @_;
	File::Spec->catfile(File::Spec->splitdir($dir), @p);
}

sub suggest_filename_helper {
	my $filename  = pop;
	my $suggested = "";
	my $suffix    = "";
	my $i         = 1;

	if (-f $filename) {
		$suffix = $1 if ($filename =~ /((\..+)+)$/);
		$filename =~ s/$suffix//g;
	}

	$filename =~ s/(_\d+)$//g;

	while (1) {
		$suggested = sprintf("%s_%s", $filename, $i++);
		return "$suggested$suffix" if (! -e "$suggested$suffix");
	}
}

sub calculate_size {
	my $size = pop;

	(! $size)             ? undef                                :
	($size >= 1073741824) ? sprintf("%.2f GB", $size/1073741824) :
	($size >= 1048576)    ? sprintf("%.2f MB", $size/1048576)    :
	($size >= 1024)       ? sprintf("%.2f kB", $size/1024)       : $size;
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
