package Filer::Tools;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

use Proc::Simple;

sub exec {
	my ($self,%opts) = @_;

	my $cmd  = $opts{command} || die "no command defined!";
	my $wait = $opts{wait};

	my $myproc = Proc::Simple->new();        # Create a new process object
	$myproc->start($cmd);

	if ($wait) {
		while ($myproc->poll()) {};           # Poll Running Process
	}
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
	my $i         = 0;

	if (-f $filename) {
		$suffix = $1 if ($filename =~ /((\..+)+)$/);
		$filename =~ s/$suffix//g;
	}

	$filename =~ s/(_\d+)$//g;

	while (-e ($suggested = sprintf("%s_%s%s", $filename, ++$i, $suffix))) {}

	return "$suggested";
}

sub humanize_size {
	my $size = pop;

	return undef if (! $size);
	return
	($size >= 1073741824) ? sprintf("%.2f GB", $size/1073741824) :
	($size >= 1048576)    ? sprintf("%.2f MB", $size/1048576)    :
	($size >= 1024)       ? sprintf("%.2f kB", $size/1024)       : $size;
}

sub deep_count_files {
	my ($self,$files) = @_;
	my $count = 0;

	for (@{$files}) {
		my $fi = Filer::FileInfo->new($_);
		$count += _deep_count_files($fi->get_path);
	}

	return $count;
}

sub deep_count_bytes {
	my ($self,$FILES) = @_;
	my $count = 0;

	for (@{$FILES}) {
		my $fi = Filer::FileInfo->new($_);
		$count += _deep_count_bytes($fi->get_path);
	}

	return $count;
}

sub _deep_count_files {
	my ($path) = @_;

	my $dirwalk = new File::DirWalk;
	my $count = 0;

	$dirwalk->onFile(sub {
		++$count;
		return 1;
	});

	$dirwalk->walk($path);

	return $count;
}

sub _deep_count_bytes {
	my ($path) = @_;
	
	my $dirwalk = new File::DirWalk;
	my $count = 0;

	$dirwalk->onFile(sub {
		my ($file) = @_;
		$count += -s $file;
		return 1;
	});

	$dirwalk->walk($path);

	return $count;
}

# Utility functions for Gtk+ classes:

# package Gtk2::Gdk::Pixbuf;
# 
# sub intelligent_scale {
# 	my ($self,$scale) = @_;
# 	my $w;
# 	my $h;
# 
# 	my $ow = $self->get_width;
# 	my $oh = $self->get_height;
# 
# 	if ($ow <= $scale and $oh <= $scale) {
# 
# 		return $self;
# 
# 	} else {
# 		if ($ow > $oh) {
# 			$w = $scale;
# 			$h = $scale * ($oh/$ow);
#         	} else {
# 			$h = $scale;
# 			$w = $scale * ($ow/$ow);
# 		}
# 
# 		return $self->scale_simple($w, $h, 'GDK_INTERP_BILINEAR');
# 	}
# }

package Gtk2::ComboBox;

sub set_popdown_strings {
	my ($self,@strings) = @_;
	
	foreach (@strings) {
		$self->append_text($_);
	}
}

1;
