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

use Readonly;

use Memoize qw(memoize);
use File::Basename qw(basename);
use File::MimeInfo::Magic qw(mimetype describe);
use Stat::lsMode qw(format_mode);

use Filer::Stat qw(:stat);
use Filer::Tools;

# class attributes:
my $mimetype_icons; 
my %thumbnails;

# attributes;
my %filepath;
my %basename;
my %mimetype;
my %stat;

# memoize('new');

sub set_mimetype_icons {
	my ($self,$icons) = @_;
	$mimetype_icons = $icons; 
}

sub new {
	my ($class,$filepath) = @_;
	my $self = bless anon_scalar(), $class;

	$filepath{ident $self} = $filepath;

	return $self;
}

sub rename {
	my ($self,$newname) = @_;
	
	if (CORE::rename($filepath{ident $self}, $newname)) {
		$filepath{ident $self} = $newname;
		return 1;
	} else {
		return 0;
	}
}

sub DESTROY {
	my ($self) = @_;

	delete $filepath{ident $self};
	delete $basename{ident $self};
	delete $mimetype{ident $self};
	delete $stat{ident $self};
}

sub get_path {
	my ($self) = @_;
	return $filepath{ident $self};
}

sub get_uri {
	my ($self) = @_;
	my $uri = "file://$filepath{ident $self}";
	my $str = ""; 

	foreach my $c (split //, $uri) {
		if (ord($c) > 32 and ord($c) < 128 and $c ne "&" and $c ne "+" and $c ne "%") {
			$str .= $c;
		} else {
			$str .= '%' . unpack("h", chr(ord($c) >> 4)) . unpack("h", chr(ord($c) & 0xf));
		}
	}

	return $str;
}

sub get_basename {
	my ($self) = @_;
	return $basename{ident $self} ||= basename($filepath{ident $self});
}

sub get_mimetype {
	my ($self) = @_;
	return $mimetype{ident $self} ||= ($self->is_symlink) ? 'inode/symlink' : mimetype($filepath{ident $self});
}

sub get_mimetype_icon {
	my ($self) = @_;
	return ($mimetype_icons->{$self->get_mimetype} || $mimetype_icons->{'application/default'});
}

sub get_mimetype_description {
	my ($self) = @_;
	return describe($self->get_mimetype);
}

sub get_thumbnail {
	my ($self) = @_;
	
	$thumbnails{$filepath{ident $self}} ||= eval {
		use Digest::MD5 qw(md5_hex);
	
		my $thumbnail_file = md5_hex($self->get_uri);
		my $thumbnail_path = "$ENV{HOME}/.thumbnails/normal/$thumbnail_file.png";
		my $thumbnail      = undef;

		if (-e $thumbnail_path) {
			$thumbnail = Gtk2::Gdk::Pixbuf->new_from_file($thumbnail_path);
			$thumbnail = $thumbnail->intelligent_scale(22);
		}
		
		$thumbnail;
	};
		
	return $thumbnails{$filepath{ident $self}};
}

sub get_stat {
	my ($self) = @_;
	return [ stat($filepath{ident $self}) ];
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
	return Filer::Tools->calculate_size($self->get_raw_size);
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
	return format_mode($self->get_raw_mode);
}

sub exist {
	my ($self) = @_;
	return (-e $filepath{ident $self});
}

sub is_readable {
	my ($self) = @_;
	return (-R $filepath{ident $self});
}

sub is_symlink {
	my ($self) = @_;
	return (-l $filepath{ident $self});
}

sub is_dir {
	my ($self) = @_;
	return (-d $filepath{ident $self});
}

sub is_executable {
	my ($self) = @_;
	return (-x $filepath{ident $self});
}

sub is_hidden {
	my ($self) = @_;
	return ($basename{ident $self} =~ /^\./);
}

use Filer::FilePaneConstants;

sub get_by_column {
	my ($self,$column) = @_;

	($column == $COL_FILEINFO) ? $self                           :
	($column == $COL_ICON)     ? $self->get_thumbnail || $self->get_mimetype_icon        :
	($column == $COL_NAME)     ? $self->get_basename             :
	($column == $COL_SIZE)     ? $self->get_size                 :
	($column == $COL_TYPE)     ? $self->get_mimetype_description :
	($column == $COL_MODE)     ? $self->get_mode                 : $self->get_mtime;
}
	
sub get_raw_by_column {
	my ($self,$column) = @_;

	($column == $COL_NAME) ? $self->get_basename :  
	($column == $COL_SIZE) ? $self->get_raw_size : 
	($column == $COL_TYPE) ? $self->get_mimetype : 
	($column == $COL_MODE) ? $self->get_raw_mode : $self->get_raw_mtime;
}

1;
