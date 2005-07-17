package Filer::FileInfo; 

use Memoize;
use File::Basename;
use File::MimeInfo;
use Stat::lsMode qw(format_mode);
use Unicode::String qw(utf8 latin1);

Memoize::memoize("format_mode");

use Filer::Tools;

sub new {
	my ($class,$filepath) = @_;
	my $self = bless {}, $class;
	
	$self->{filepath} = utf8($filepath)->latin1; 
	$self->{stat} = [ lstat($self->{filepath}) ];
	$self->{type} = (-l $self->{filepath}) ? "inode/symlink" : mimetype($self->{filepath});

	return $self;
}

sub get_path {
	my ($self) = @_;
	return $self->{filepath};
}

sub get_basename {
	my ($self) = @_; 
	return basename($self->get_path);
}

sub get_mimetype {
	my ($self) = @_; 
	return $self->{type};
}

sub get_mimetype_description {
	my ($self) = @_; 
	return describe($self->{type});
}

sub get_stat {
	my ($self) = @_;
	return $self->{stat};
}

sub get_raw_size {
	my ($self) = @_; 
	return $self->{stat}->[7];
}

sub get_raw_mtime {
	my ($self) = @_; 
	return $self->{stat}->[9];
}

sub get_raw_uid {
	my ($self) = @_; 
	return $self->{stat}->[4];
}

sub get_raw_gid {
	my ($self) = @_; 
	return $self->{stat}->[5];
}

sub get_raw_mode {
	my ($self) = @_; 
	return $self->{stat}->[2];
}

sub get_size {
	my ($self) = @_; 
	return Filer::Tools->calculate_size($self->get_raw_size);
}

sub get_mtime {
	my ($self) = @_; 
	my $time = localtime($self->get_raw_mtime);
	return $time;
}

sub get_uid {
	my ($self) = @_; 
	return getpwuid($self->get_raw_uid);
}

sub get_gid {
	my ($self) = @_; 
	return getgrgid($self->get_raw_gid);
}

sub get_mode {
	my ($self) = @_; 
	return format_mode($self->get_raw_mode);
}

1;
