package Filer::Tools;

use Cwd qw(abs_path);
use File::Spec;

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
}

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
