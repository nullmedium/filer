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
use strict;
use warnings;
use Moose;

use File::Basename; # qw(basename dirname fileparse);
use File::MimeInfo::Magic; # qw(mimetype describe);
use Stat::lsMode qw(format_mode);

use Filer::Stat qw(:stat);
use Filer::Tools;
use Filer::Constants;
use Filer::FilePaneConstants;

has 'filepath'    => (is => 'rw', isa => 'Str',      reader => 'get_path');
has 'dirname'     => (is => 'rw', isa => 'Str',      reader => 'get_dirname');
has 'basename'    => (is => 'rw', isa => 'Str',      reader => 'get_basename');
has 'mimetype'    => (is => 'rw', isa => 'Str',      reader => 'get_mimetype');
has 'description' => (is => 'rw', isa => 'Str',      reader => 'get_description');
has 'stat'	  => (is => 'rw', isa => 'ArrayRef', reader => 'get_stat');

# $File::MimeInfo::DEBUG = 1;

sub get_homedir {
	return Filer::FileInfo->new($HOMEDIR);
}

sub get_rootdir {		
	return Filer::FileInfo->new($ROOTDIR);
}

sub new {
	my ($class,$filepath) = @_;
	my $self = bless {}, $class;

	$self->filepath($filepath);
	$self->dirname(File::Basename::dirname($filepath));
	$self->basename(File::Basename::basename($filepath));
	$self->mimetype(File::MimeInfo::Magic::mimetype($filepath));
	$self->description(File::MimeInfo::Magic::describe($self->mimetype));

	if ($self->mimetype eq "inode/mount-point") {
		$self->mimetype("inode/directory");
	}
	
	$self->stat([ CORE::stat($filepath) ]);

	return $self;
}

sub get_uri {
	my $self = shift;
#	my $uri = "file://$self->get_path";
# 	my $str = ""; 
# 
# 	foreach my $c (split //, $uri) {
# 		if (ord($c) > 32 and ord($c) < 128 and $c ne "&" and $c ne "+" and $c ne "%") {
# 			$str .= $c;
# 		} else {
# 			$str .= '%' . unpack("h", chr(ord($c) >> 4)) . unpack("h", chr(ord($c) & 0xf));
# 		}
# 	}

	my $uri = Glib->filename_to_uri($self->get_path, "localhost");
	return $uri;
}

sub get_mimetype_handler {
	my $self = shift;

	my $mh = Filer::MimeTypeHandler->new;
	return $mh->get_mimetype_handler($self->get_mimetype);
}

sub set_mimetype_handler {
	my ($self,$handler) = @_;

	my $mh = Filer::MimeTypeHandler->new;
	return $mh->set_mimetype_handler($self->get_mimetype,$handler);
}

sub get_mimetype_icon {
	my $self = shift;

	my $icon   = Filer::MimeTypeIcon->new($self->get_mimetype);
	my $pixbuf = $icon->get_pixbuf;

	if ($self->is_hidden) {
		$pixbuf->saturate_and_pixelate($pixbuf, 0.5, $TRUE)
	}

	return $pixbuf;
}

sub get_raw_size {
	my $self = shift;
	return $self->get_stat->[$STAT_SIZE];
}

sub get_raw_mtime {
	my $self = shift;
	return $self->get_stat->[$STAT_MTIME];
}

sub get_raw_uid {
	my $self = shift;
	return $self->get_stat->[$STAT_UID];
}

sub get_raw_gid {
	my $self = shift;
	return $self->get_stat->[$STAT_GID];
}

sub get_raw_mode {
	my $self = shift;
	return $self->get_stat->[$STAT_MODE];
}

sub get_size {
	my $self = shift;
	return Filer::Tools->humanize_size($self->get_raw_size);
}

sub get_mtime {
	my $self = shift;
	return scalar localtime($self->get_raw_mtime || 0);
}

sub get_uid {
	my $self = shift;
	return getpwuid($self->get_raw_uid);
}

sub get_gid {
	my $self = shift;
	return getgrgid($self->get_raw_gid);
}

sub get_mode {
	my $self = shift;
	my $format = format_mode($self->get_raw_mode);
	return $format;
}

sub exist {
	my $self = shift;
	return (-e $self->get_path);
}

sub is_readable {
	my $self = shift;
	return (-R $self->get_path);
}

sub is_symlink {
	my $self = shift;
	return (-l $self->get_path);
}

sub is_dir {
	my $self = shift;
	return (-d $self->get_path);
}

sub is_file {
	my $self = shift;
	return (!$self->is_dir);
}

sub is_executable {
	my $self = shift;
	return (-x $self->get_path);
}

sub is_hidden {
	my $self = shift;
	return ($self->get_basename =~ /^\./);
}

sub is_supported_archive {
	my $self = shift;
	return Filer::Archive->is_supported_archive($self->get_mimetype);
}

1;
