#     Copyright (C) 2004 Jens Luedicke <jens@irs-net.com>
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

sub new {
	my ($class,$filepath) = @_;
	my $self = bless {}, $class;

	$self->{filepath} = $filepath;
	$self->{path} = File::Basename::dirname($filepath);
	$self->{file} = File::Basename::basename($filepath);

	return $self;
}

sub create_tar_gz_archive {
	my ($self) = @_;
	my $path = $self->{path};
	my $file = $self->{file};

	system("cd $path && tar -c './$file' | gzip - > '$file.tar.gz'");
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	my $path = $self->{path};
	my $file = $self->{file};

	system("cd $path && tar -c './$file' | bzip2 - > '$file.tar.bz2'");
}

sub extract_archive {
	my ($self) = @_;
	my $path = $self->{path};
	my $file = $self->{file};
	my $type = File::MimeInfo::Magic::mimetype($self->{filepath});

	if ($type eq 'application/x-gzip') {

		system("cd '$path' && gzip -d '$file'");

	} elsif ($type eq 'application/x-bzip') {

		system("cd '$path' && bzip2 -d '$file'");

	} elsif ($type eq 'application/zip') {

		system("cd '$path' && unzip '$file'");

	} elsif ($type eq 'application/x-tar') {

		system("cd '$path' && tar -xf '$file'");

	} elsif ($type eq 'application/x-compressed-tar') {

		system("cd '$path' && tar -xzf '$file'");

	} elsif ($type eq 'application/x-bzip-compressed-tar') {

		system("cd '$path' && tar -xjf '$file'");

	} else {

		Filer::Dialog->msgbox_error("This is not an supported Archive!");
	}
}

1;
