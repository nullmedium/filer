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
use Class::Std::Utils;

use strict;
use warnings;

use Memoize;
use File::Basename qw(basename);
use File::MimeInfo::Magic qw(inodetype mimetype describe);
use Stat::lsMode qw(format_mode);

use Filer::Tools;

my $S_IFDIR = 0040000;
my $S_IXUSR = 00100;

use enum qw(
	:STAT_
	DEV
	INO
	MODE
	NLINK
	UID
	GID
	RDEV
	SIZE
	ATIME
	MTIME
	CTIME
	BLKSIZE
	BLOCKS
);

# attributes;
my %filepath;
my %stat;
my %mimetype;

sub new {
	my ($class,$filepath) = @_;
	my $self = bless anon_scalar(), $class;

	$filepath{ident $self} = $filepath;
	$stat{ident $self}     = [ lstat($filepath) ];
	$mimetype{ident $self} = mimetype($filepath);

	return $self;
}

sub DESTROY {
	my ($self) = @_;

#	print "$self DESTROY: $filepath{ident $self}\n";

	delete $filepath{ident $self};
	delete $stat{ident $self};
	delete $mimetype{ident $self};
}

sub get_path {
	my ($self) = @_;
	return $filepath{ident $self};
}

sub get_basename {
	my ($self) = @_;
	return basename($self->get_path);
}

sub get_mimetype {
	my ($self) = @_;
	return $mimetype{ident $self};
}

sub get_mimetype_description {
	my ($self) = @_;
	return describe($self->get_mimetype);
}

sub get_stat {
	my ($self) = @_;
	return $stat{ident $self};
}

sub get_raw_size {
	my ($self) = @_;
	return $stat{ident $self}->[STAT_SIZE];
}

sub get_raw_mtime {
	my ($self) = @_;
	return $stat{ident $self}->[STAT_MTIME];
}

sub get_raw_uid {
	my ($self) = @_;
	return $stat{ident $self}->[STAT_UID];
}

sub get_raw_gid {
	my ($self) = @_;
	return $stat{ident $self}->[STAT_GID];
}

sub get_raw_mode {
	my ($self) = @_;
	return $stat{ident $self}->[STAT_MODE];
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

sub is_dir {
	my ($self) = @_;
	return ($self->get_raw_mode & $S_IFDIR);
}

sub is_executable {
	my ($self) = @_;
	return ($self->get_raw_mode & $S_IXUSR);
}

sub is_hidden {
	my ($self) = @_;
	return ($self->get_basename =~ /^\./);
}

1;
