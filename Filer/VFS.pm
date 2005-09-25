package Filer::VFS;
use Class::Std::Utils;

use Memoize qw(memoize);

%path;
%list;
%dirs_count;
%files_count;
%total_size;

# memoize("new");

sub get_homedir {
	return Filer::FileInfo->new($ENV{'HOME'});
}

sub get_tmpdir {
	return Filer::FileInfo->new(File::Spec->tmpdir);
}

sub get_rootdir {
	return Filer::FileInfo->new(File::Spec->rootdir);
}

sub new {
	my ($class,%opts) = @_;
	my $self = bless anon_scalar(), $class;

	my $path        = $opts{path};
	my $show_hidden = $opts{hidden};

	if (! $path) {
		die "option 'path' must be defined in Filer::VFS constructor\n";
	}

	if (! -R $path) {
		die "directory $path not readable!\n";
	}

	$list{ident $self}        = [];
	$path{ident $self}        = $path;
	$dirs_count{ident $self}  = 0;
	$files_count{ident $self} = 0;
	$total_size{ident $self}  = 0;
	my $pos = 0;

# 	my ($t0,$t1,$elapsed);
#  	use Time::HiRes qw(gettimeofday tv_interval);
#  	$t0 = [gettimeofday];

	opendir my $dirh, $path || die "$filepath: $!";

	while (my $file = readdir $dirh) {
		next if (($file =~ /^\.{1,2}$/) || ($file =~ /^\./ && !$show_hidden));
			
		$list{ident $self}->[$pos++] = Filer::FileInfo->new("$path/$file");

		if (-d "$path/$file") {
			++$dirs_count{ident $self};
		} else {
			++$files_count{ident $self};
		}

		$total_size{ident $self} += -s "$path/$file";
	}

	closedir $dirh;

# 	$t1 = [gettimeofday];
# 	$elapsed = tv_interval($t0,$t1);
# 	print "time to read $path: $elapsed\n";

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
# 	print "DESTROY: " . $self . "\n";
	
	delete $path{ident $self};
	delete $list{ident $self};
	delete $dirs_count{ident $self};
	delete $files_count{ident $self};
	delete $total_size{ident $self};
}

sub get_fileinfo_list {
	my ($self) = @_;
	return $list{ident $self};
}

sub get_all {
	my ($self) = @_;
	return $list{ident $self};
}

sub get_dirs {
	my ($self) = @_;
	my @list = grep { $_->is_dir } @{$list{ident $self}};
	return \@list;
}

sub total_size {
	my ($self) = @_;
	return Filer::Tools->calculate_size($total_size{ident $self});
}

sub dirs_count {
	my ($self) = @_;
	return $dirs_count{ident $self};
}

sub files_count {
	my ($self) = @_;
	return $files_count{ident $self};
}

1;
