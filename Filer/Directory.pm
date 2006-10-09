package Filer::Directory;

use warnings;
use strict;

use overload '""' => \&to_string;

sub to_string {
	my ($self) = @_;
	return $self->{path};
}

sub new {
	my ($class,$path) = @_;
	my $self = bless {}, $class;

	if (! -d $path) {
		$path = $ENV{'HOME'};
	}

	if (! -R $path) {
		die "directory $path not readable!\n";
	}

	$self->{list}        = [];
	$self->{path}        = $path;
	$self->{total_size}  = 0;

	opendir my $dirh, "$path";
	my @dir_contents = readdir $dirh;
	@dir_contents = File::Spec->no_upwards(@dir_contents);

	my @dirs = File::Spec->splitdir("$path");

	foreach my $f (@dir_contents) {
		my $path = File::Spec->catfile(@dirs, $f);

		my $fi   = Filer::FileInfo->new($path);
 		push @{$self->{list}}, $fi;

		$self->{total_size} += -s $path;
	}

	closedir $dirh;

	return $self;
}

sub all {
	my ($self) = @_;
	return $self->{list};
}

sub all_files {
	my ($self) = @_;
	return [ grep { !$_->is_dir } @{$self->{list}} ];
}

sub all_dirs {
	my ($self) = @_;
	return [ grep { $_->is_dir } @{$self->{list}} ];
}

sub total_size {
	my ($self) = @_;
	return Filer::Tools->humanize_size($self->{total_size});
}

sub dirs_count {
	my ($self) = @_;
	return scalar @{$self->all_dirs};
}

sub files_count {
	my ($self) = @_;
	return scalar @{$self->all_files};
}

1;
