package Filer::FileInfo; 

use File::Basename;
use File::MimeInfo;
use Stat::lsMode qw(format_mode);
use Unicode::String qw(utf8 latin1 utf16);

use Memoize;

Memoize::memoize("format_mode");

use Filer::Tools;

sub new {
	my ($class,$filepath) = @_;
	my $self = bless {}, $class;
	
	$self->{filepath} = $filepath; 
	$self->{stat} = [ lstat($self->get_path_latin1) ];
	$self->{type} = (-l $self->get_path_latin1) ? "inode/symlink" : mimetype($self->{filepath});
	$self->{size} = $self->{stat}->[7];
	$self->{mtime} = $self->{stat}->[9];
	$self->{uid} = $self->{stat}->[4];
	$self->{gid} = $self->{stat}->[5];
	$self->{mode} = $self->{stat}->[2];

	return $self;
}

sub get_path_latin1 {
	my ($self) = @_;
	return utf8($self->{filepath})->latin1;
}

sub get_path_utf8 {
	my ($self) = @_;
	return $self->{filepath};
}

sub get_basename {
	my ($self) = @_; 
	return basename($self->get_path_latin1);
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
	return $self->{size};
}

sub get_raw_mtime {
	my ($self) = @_; 
	return $self->{mtime};
}

sub get_raw_uid {
	my ($self) = @_; 
	return $self->{uid};
}

sub get_raw_gid {
	my ($self) = @_; 
	return $self->{uid};
}

sub get_raw_mode {
	my ($self) = @_; 
	return $self->{mode};
}

sub get_size {
	my ($self) = @_; 
	return Filer::Tools->calculate_size($self->get_raw_size);
}

sub get_mtime {
	my ($self) = @_; 
	my $time = localtime($self->{mtime});
	return $time;
}

sub get_uid {
	my ($self) = @_; 
	return getpwuid($self->{uid});
}

sub get_gid {
	my ($self) = @_; 
	return getgrgid($self->{gid});
}

sub get_mode {
	my ($self) = @_; 
	return format_mode($self->{mode});
}

1;
