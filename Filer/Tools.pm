package Filer::Tools;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;

use Proc::Simple;

sub exec {
	my ($self,$cmd) = @_;

	my $myproc = Proc::Simple->new();
	$myproc->start($cmd);
}

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

	my $dirwalk = new File::DirWalk;

	$dirwalk->onFile(sub {
		++$count;
		return 1;
	});

	for (@{$files}) {
    	$dirwalk->walk($_);
	}

	return $count;
}

sub deep_count_bytes {
	my ($self,$FILES) = @_;
	my $count = 0;

	my $dirwalk = new File::DirWalk;

	$dirwalk->onFile(sub {
		my ($file) = @_;
		$count += -s $file;
		return 1;
	});

	for (@{$FILES}) {
    	$dirwalk->walk($_);
	}

	return $count;
}

1;
