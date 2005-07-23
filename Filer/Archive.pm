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

package Filer::Archive;

use strict;
use warnings;

use File::Basename;
use File::MimeInfo;

sub new {
	my ($class,$filepath,$files) = @_;
	my $self = bless {}, $class;

	$self->{path} = $filepath;
	$self->{files} = $files;

	$self->{supported_archives} = {
		'application/x-gzip' 			=> { extension => 'gz',		create => 'gzip -c',	extract => 'gzip -d'},
		'application/x-bzip' 			=> { extension => 'bz2',	create => 'bzip2 -c',	extract => 'bzip2 -d'},
		'application/zip' 			=> { extension => 'zip',	create => 'zip',	extract => 'unzip'},
		'application/x-tar' 			=> { extension => 'tar',	create => 'tar -c',	extract => 'tar -x'},
		'application/x-compressed-tar'		=> { extension => 'tar.gz',	create => 'tar -cz',	extract => 'tar -xz'},
		'application/x-bzip-compressed-tar' 	=> { extension => 'tar.bz2',	create => 'tar -cj',	extract => 'tar -xj'},
		'application/x-rar' 			=> { extension => 'rar',	create => 'rar a',	extract => 'unrar x'}
	};

	return $self;
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	$self->create_archive('application/x-bzip-compressed-tar');
}

sub create_tar_gz_archive {
	my ($self) = @_;
	$self->create_archive('application/x-compressed-tar');
}

sub create_archive {
	my ($self,$type) = @_;
	my $path = $self->{path};

	my $archive_command = $self->{supported_archives}->{$type}->{create};
	my $archive_file = sprintf("%s.%s", $self->{files}->[0], $self->{supported_archives}->{$type}->{extension});
	
	# create a space delimited list of files and escape it properly to make shell happy
	my @f = map { Filer::Tools->catpath(File::Spec->curdir, basename($_)) } @{$self->{files}};

	my @c = split /\s+/, $archive_command;
	my $pid = Filer::Tools->start_program(@c, "-C", $path, "-f", $archive_file, @f);
	Filer::Tools->wait_for_pid($pid);
}

sub extract_archive {
	my ($self) = @_;
	my $path = $self->{path};

	foreach my $f (@{$self->{files}}) {
		my $type = mimetype($f);
		my $archive_extract_command = $self->{supported_archives}->{$type}->{extract};

		if ($archive_extract_command) {
			my @c = split /\s+/, $archive_extract_command;
			my $pid = Filer::Tools->start_program(@c, "-C", $path, "-f", $f);
			Filer::Tools->wait_for_pid($pid);
		}
	}
}

sub is_supported_archive {
	my ($self,$type) = @_;
	return (defined $self->{supported_archives}->{$type});
}

1;
