#     Copyright (C) 2004-2005 Jens Luedicke <jens.luedicke@gmail.com>
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program; if not, write to the Free Software
#     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package Filer::FileInfo; 

use Memoize;
use File::Basename;
use File::MimeInfo;
use Stat::lsMode qw(format_mode);
use Unicode::String qw(utf8 latin1);

use Filer::Tools;

Memoize::memoize("format_mode");
Memoize::memoize("File::MimeInfo::Magic::mimetype");
Memoize::memoize("File::MimeInfo::Magic::describe");
Memoize::memoize("Filer::Tools::calculate_size");

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

sub is_hidden {
	my ($self) = @_;
	return ($self->get_basename =~ /^\./);
}

1;
