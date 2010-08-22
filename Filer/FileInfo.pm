#     Copyright (C) 2004-2010 Jens Luedicke <jens.luedicke@gmail.com>
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

use Readonly;

use File::Basename qw(basename dirname);
use File::MimeInfo::Magic qw(mimetype describe);
use Stat::lsMode qw(format_mode);

use Filer::Constants qw(:filer :stat);
use Filer::Tools;

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

	$self->{filepath} = $filepath;
	$self->{basename} = basename($filepath);

	return $self;
}

sub get_path {
	my ($self) = @_;
	return $self->{filepath};
}

sub get_uri {
	my ($self) = @_;
#	my $uri = "file://$self->{filepath}";
# 	my $str = ""; 
# 
# 	foreach my $c (split //, $uri) {
# 		if (ord($c) > 32 and ord($c) < 128 and $c ne "&" and $c ne "+" and $c ne "%") {
# 			$str .= $c;
# 		} else {
# 			$str .= '%' . unpack("h", chr(ord($c) >> 4)) . unpack("h", chr(ord($c) & 0xf));
# 		}
# 	}

	my $uri = Glib->filename_to_uri($self->{filepath}, "localhost");
	print $uri, "\n";
	return $uri;
}

sub get_basename {
	my ($self) = @_;
	return $self->{basename} ||= basename($self->{filepath});
}

sub get_dirname {
	my ($self) = @_;
	return dirname($self->{filepath});
}

sub get_mimetype {
	my ($self) = @_;
	$self->{mimetype} ||= mimetype($self->{filepath});

	if ($self->{mimetype} eq "inode/mount-point") {
		$self->{mimetype} = "inode/directory";
	}
	
	return $self->{mimetype};
}

sub get_mimetype_handler {
	my ($self) = @_;

	my $mh = Filer::MimeTypeHandler->new;
	return $mh->get_mimetype_handler($self->get_mimetype);
}

sub set_mimetype_handler {
	my ($self,$handler) = @_;

	my $mh = Filer::MimeTypeHandler->new;
	return $mh->set_mimetype_handler($self->get_mimetype,$handler);
}

sub get_mimetype_icon {
	my ($self) = @_;
	my $icon = Filer::MimeTypeIcon->new($self->get_mimetype);

	my $pixbuf = $icon->get_pixbuf;

	if ($self->is_hidden) {
		$pixbuf->saturate_and_pixelate($pixbuf, 0.5, $TRUE)
	}

	return $pixbuf;
}

sub get_description {
	my ($self) = @_;
	return describe($self->get_mimetype);
}

sub get_stat {
	my ($self) = @_;
	return $self->{stat} ||= [ stat($self->{filepath}) ];
}

sub get_raw_size {
	my ($self) = @_;
	return $self->get_stat->[$STAT_SIZE];
}

sub get_raw_mtime {
	my ($self) = @_;
	return $self->get_stat->[$STAT_MTIME];
}

sub get_raw_uid {
	my ($self) = @_;
	return $self->get_stat->[$STAT_UID];
}

sub get_raw_gid {
	my ($self) = @_;
	return $self->get_stat->[$STAT_GID];
}

sub get_raw_mode {
	my ($self) = @_;
	return $self->get_stat->[$STAT_MODE];
}

sub get_size {
	my ($self) = @_;
	return Filer::Tools->humanize_size($self->get_raw_size);
}

sub get_mtime {
	my ($self) = @_;
	my $time = localtime($self->get_raw_mtime || 0);
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
	my $format = format_mode($self->get_raw_mode);
	return $format;
}

sub exist {
	my ($self) = @_;
	return (-e $self->{filepath});
}

sub is_readable {
	my ($self) = @_;
	return (-R $self->{filepath});
}

sub is_symlink {
	my ($self) = @_;
	return (-l $self->{filepath});
}

sub is_dir {
	my ($self) = @_;
	return (-d $self->{filepath});
}

sub is_file {
	my ($self) = @_;
	return (!$self->is_dir);
}

sub is_executable {
	my ($self) = @_;
	return (-x $self->{filepath});
}

sub is_hidden {
	my ($self) = @_;
	return ($self->{basename} =~ /^\./);
}

sub is_supported_archive {
	my ($self) = @_;
	return Filer::Archive->is_supported_archive($self->get_mimetype);
}

1;
