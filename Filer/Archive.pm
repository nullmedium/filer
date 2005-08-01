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

use constant {
	GZ   => 'application/x-gzip',		   
	BZ2  => 'application/x-bzip',		   
	TAR  => 'application/x-tar',		   
	TGZ  => 'application/x-compressed-tar',    
	TBZ2 => 'application/x-bzip-compressed-tar',
	ZIP  => 'application/zip',	   
	RAR  => 'application/x-rar',		   
};

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	$self->{supported_archives} = {};

	foreach (GZ, BZ2, TAR, TGZ, TBZ2, ZIP, RAR) {
		$self->{supported_archives}->{$_} = 1;
	}

	return $self;
}

sub create_tar_bz2_archive {
	my ($self,$path,$files) = @_;
	$self->create_archive('application/x-bzip-compressed-tar',$path,$files);
}

sub create_tar_gz_archive {
	my ($self,$path,$files) = @_;
	$self->create_archive('application/x-compressed-tar',$path,$files);
}

sub create_archive {
	my ($self,$type,$path,$files) = @_;
	my $archive_file = "";
	my @files = map { Filer::Tools->catpath(File::Spec->curdir, basename($_)) } @{$files};
	my @commandline = ();

	if ($type eq TGZ) {
		$archive_file = sprintf("%s.tar.gz", $files->[0]);
		@commandline = ("tar", "-cz", "-C", $path, "-f", $archive_file, @files);
	
	} elsif ($type eq TBZ2) {
		$archive_file = sprintf("%s.tar.bz2", $files->[0]);
		@commandline = ("tar", "-cj", "-C", $path, "-f", $archive_file, @files);
	}

	my $pid = Filer::Tools->start_program(@commandline);
	Filer::Tools->wait_for_pid($pid);
}

sub extract_archive {
	my ($self,$path,$files) = @_;

	foreach my $f (@{$files}) {
		my $type = mimetype($f);

		my @cmdline =	($type eq GZ)	? ("gzip", "-d", $f)			:
				($type eq BZ2)	? ("bzip2", "-d", $f)			:
				($type eq TAR)	? ("tar", "-x", "-C", $path, "-f", $f)	:
				($type eq TGZ)	? ("tar", "-xz", "-C", $path, "-f", $f)	:
				($type eq TBZ2)	? ("tar", "-xj", "-C", $path, "-f", $f)	:
				($type eq ZIP)	? ("unzip", $f, "-d", $path)		:
				($type eq RAR)	? ("unrar", "x", $f, $path)		: undef;

		if (@cmdline) {
			my $pid = Filer::Tools->start_program(@cmdline);
			Filer::Tools->wait_for_pid($pid);
		}
	}
}

sub is_supported_archive {
	my ($self,$type) = @_;
	return defined $self->{supported_archives}->{$type};
}

1;
