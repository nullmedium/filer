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

use Readonly;

use File::Basename;
use File::MimeInfo;

Readonly my $GZ   => 'application/x-gzip';		   
Readonly my $BZ2  => 'application/x-bzip';		   
Readonly my $TAR  => 'application/x-tar';		   
Readonly my $TGZ  => 'application/x-compressed-tar';    
Readonly my $TBZ2 => 'application/x-bzip-compressed-tar';
Readonly my $ZIP  => 'application/zip';	   
Readonly my $RAR  => 'application/x-rar';		   

our @archive_types = ($GZ,$BZ2,$TAR,$TGZ,$TBZ2,$ZIP,$RAR);

sub is_supported_archive {
	my $type = pop;
	my %is_supported = map { $_ => 1 } @archive_types;

	return defined $is_supported{$type};
}

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	return $self;
}

sub create_tar_gz_archive {
	my ($self,$path,$files) = @_;
	return $self->create_archive($TGZ, $path, $files);
}

sub create_tar_bz2_archive {
	my ($self,$path,$files) = @_;
	return $self->create_archive($TBZ2, $path, $files);
}

sub create_archive {
	my ($self,$type,$path,$files) = @_;
	my $archive_file = "";
	my @files        = map { Filer::Tools->catpath(File::Spec->curdir, basename($_)) } @{$files};
	my @commandline  = ();

	if ($type eq $TGZ) {
		$archive_file = sprintf("%s.tar.gz", $files->[0]);
		@commandline  = ("tar", "-cz", "-C", $path, "-f", $archive_file, @files);
	
	} elsif ($type eq $TBZ2) {
		$archive_file = sprintf("%s.tar.bz2", $files->[0]);
		@commandline  = ("tar", "-cj", "-C", $path, "-f", $archive_file, @files);
	}

	my $pid = Filer::Tools->start_program(@commandline);
	Filer::Tools->wait_for_pid($pid);

	return $path;
}

sub extract_archive {
	my ($self,$path,$files) = @_;

	foreach my $f (@{$files}) {
		my $type = mimetype($f);

		my @cmdline =	($type eq $TAR)	 ? ("tar", "-x", "-C", $path, "-f", $f)	 :
				($type eq $TGZ)	 ? qw(tar -xz -C $path -f $f) :
				($type eq $TBZ2) ? ("tar", "-xj", "-C", $path, "-f", $f) :
				($type eq $GZ)	 ? ("gzip", "-d", $f)                    :
				($type eq $BZ2)	 ? ("bzip2", "-d", $f)                   :
				($type eq $ZIP)	 ? ("unzip", $f, "-d", $path)            :
				($type eq $RAR)	 ? ("unrar", "x", $f, $path)             : undef;

		if (@cmdline) {
			my $pid = Filer::Tools->start_program(@cmdline);
			Filer::Tools->wait_for_pid($pid);
		}
	}

	return $path;
}

1;
