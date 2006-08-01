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
use YAML::Syck qw(LoadFile DumpFile);

use Filer::Stat qw(:stat);
use Filer::Tools;
use Filer::FilePaneConstants;

# $File::MimeInfo::DEBUG = 1;

# class attributes:
# my $mimetype_icons; 
# my %thumbnails;

# attributes;
my %filepath;
my %basename;
my %mimetype;
my %stat;

# memoize('new');

# sub set_mimetype_icons {
# 	my ($self,$icons) = @_;
# 	$mimetype_icons = $icons; 
# }

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
# 	my $uri = "file://$filepath{ident $self}";
# 	my $str = ""; 
# 
# 	foreach my $c (split //, $uri) {
# 		if (ord($c) > 32 and ord($c) < 128 and $c ne "&" and $c ne "+" and $c ne "%") {
# 			$str .= $c;
# 		} else {
# 			$str .= '%' . unpack("h", chr(ord($c) >> 4)) . unpack("h", chr(ord($c) & 0xf));
# 		}
# 	}

	my $uri = URI::file->new($filepath{ident $self});

	return $uri->as_string;
}

sub get_basename {
	my ($self) = @_;
	return $basename{ident $self} ||= basename($filepath{ident $self});
}

sub get_mimetype {
	my ($self) = @_;
	$mimetype{ident $self} ||= mimetype($filepath{ident $self});

# 	if ($mimetype{ident $self} eq "inode/mount-point") {
# 		$mimetype{ident $self} = "inode/directory";
# 	}
	
	return $mimetype{ident $self};
}

sub get_mimetype_handler {
	my ($self) = @_;

	my $mime_file = Filer::Tools->catpath(File::BaseDir::xdg_config_home, "filer", "mime-2.yml");

	if (-e $mime_file) {
		my $mime = LoadFile($mime_file);
		return $mime->{$self->get_mimetype};	
	}

	return undef;
}

sub set_mimetype_handler {
	my ($self,$handler) = @_;

	my $mime_file = Filer::Tools->catpath(File::BaseDir::xdg_config_home, "filer", "mime-2.yml");
	my $mime      = {};

	if (-e $mime_file) {
		$mime = LoadFile($mime_file);
	}

	$mime->{$self->get_mimetype} = $handler;	

	DumpFile($mime_file, $mime);
}

sub get_mimetype_icon {
	my ($self) = @_;
	my $icon = Filer::MimeTypeIcon->new($self->get_mimetype);
	return $icon->get_icon;
}

sub get_description {
	my ($self) = @_;
	return describe($self->get_mimetype);
}

sub get_stat {
	my ($self) = @_;
	return $stat{ident $self} ||= [ stat($filepath{ident $self}) ];
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
	my $format = format_mode($self->get_raw_mode);
	return $format;
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

sub is_file {
	my ($self) = @_;
	return (!$self->is_dir);
}

sub is_executable {
	my ($self) = @_;
	return (-x $filepath{ident $self});
}

sub is_hidden {
	my ($self) = @_;
	return ($basename{ident $self} =~ /^\./);
}

sub is_supported_archive {
	my ($self) = @_;
	return Filer::Archive->is_supported_archive($self->get_mimetype);
}


sub deep_count_files {
	my ($self) = @_;

	my $dirwalk = new File::DirWalk;
	my $count = 0;

	$dirwalk->onFile(sub {
		++$count;
		return 1;
	});

	$dirwalk->walk($filepath{ident $self});

	return $count;
}

sub deep_count_bytes {
	my ($self) = @_;
	
	my $dirwalk = new File::DirWalk;
	my $count;

	$dirwalk->onFile(sub {
		my ($file) = @_;
		$count += -s $file;
		return 1;
	});

	$dirwalk->walk($filepath{ident $self});

	return $count;
}


1;
