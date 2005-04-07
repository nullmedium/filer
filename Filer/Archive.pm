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

my %supported_archives = (
	'application/x-gzip' =>			{ extension => 'gz',		create => 'gzip -c',	extract => 'gzip -d'},
	'application/x-bzip' =>			{ extension => 'bz2',		create => 'bzip2 -c',	extract => 'gzip2 -d'},
	'application/zip' =>			{ extension => 'zip',		create => 'zip',	extract => 'unzip'},
	'application/x-tar' =>			{ extension => 'tar',		create => 'tar -cf',	extract => 'tar -xf'},
	'application/x-compressed-tar' =>	{ extension => 'tar.gz',	create => 'tar -czf',	extract => 'tar -xzf'},
	'application/x-bzip-compressed-tar' =>	{ extension => 'tar.bz2',	create => 'tar -cjf',	extract => 'tar -xjf'}
);

sub new {
	my ($class,$filepath) = @_;
	my $self = bless {}, $class;

	$self->{filepath} = $filepath;
	$self->{path} = File::Basename::dirname($filepath);
	$self->{file} = File::Basename::basename($filepath);

	return $self;
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	$self->{requested_archivetype} = 'application/x-bzip-compressed-tar';

	create_archive($self)
}

sub create_tar_gz_archive {
	my ($self) = @_;
	$self->{requested_archivetype} = 'application/x-compressed-tar';

	create_archive($self)
}

sub create_archive {
	my ($self) = @_;
	my $path = $self->{path};
	my $file = $self->{file};
	my $type = $self->{requested_archivetype};
	my $archive_file = $file.'.'.$supported_archives{$type}{extension};
	my $archive_command = $supported_archives{$type}{create};

#TODO check if binary exists; split by space
	if (1){
		system("cd '$path' && $archive_command '$archive_file' '$file'");
	} else {
		Filer::Dialog->msgbox_error("This is not an supported Archive!");
	}
}

sub extract_archive {
	my ($self) = @_;
	my $path = $self->{path};
	my $file = $self->{file};
	my $type = File::MimeInfo::Magic::mimetype($self->{filepath});

	my $archive_extract_command = $supported_archives{$type}{'extract'};
	if ($archive_extract_command){
		system("cd '$path' && $archive_extract_command '$file'");
	} else {
		Filer::Dialog->msgbox_error("This is not an supported Archive!");
	}
}

sub is_supported_archive {
	my ($type) = @_;

	if (exists($supported_archives{$type})) {
		return 1;
	} else {
		return 0;
	}
}

1;
