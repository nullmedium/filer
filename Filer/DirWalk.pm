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

package Filer::DirWalk;

use strict;
use warnings;

use File::Basename;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	foreach (qw(onBeginWalk onLink onFile onDirEnter onDirLeave onForEach)) {
		$self->{$_} = sub { 1; };
	}
	
	return $self;
}

sub onBeginWalk {
	my ($self,$func) = @_;
	$self->{onBeginWalk} = $func;
}

sub onLink {
	my ($self,$func) = @_;
	$self->{onLink} = $func;
}

sub onFile {
	my ($self,$func) = @_;
	$self->{onFile} = $func;
}

sub onDirEnter {
	my ($self,$func) = @_;
	$self->{onDirEnter} = $func;
}

sub onDirLeave {
	my ($self,$func) = @_;
	$self->{onDirLeave} = $func;
}

sub onForEach {
	my ($self,$func) = @_;
	$self->{onForEach} = $func;
}

sub walk {
	my ($self,$path) = @_;
	my $dirname_path = dirname($path);
	my $basename_path = basename($path);
	my $r;

	$r = &{$self->{onBeginWalk}}($path);

	if ($r != 1) {
		return $r;
	}

	if (-l $path) {
		my $r = &{$self->{onLink}}($path);

		if ($r != 1) {
			return $r;
		}
	} elsif (-d $path) {
		$r = &{$self->{onDirEnter}}($path);

		if ($r != 1) {
			return $r;
		}

		opendir(DIR, $path) || return 0;
		my @dir_contents = sort readdir(DIR);
		closedir(DIR);

		@dir_contents = @dir_contents[2 .. $#dir_contents]; # no . and ..

		foreach my $f (@dir_contents) {
			my $r;

			$r = &{$self->{onForEach}}("$path/$f");

			if ($r == 0) {
				next;
			}

			$r = $self->walk("$path/$f");

			if ($r != 1) {
				return $r;
			}
		}

		$r = &{$self->{onDirLeave}}($path);

		if ($r != 1) {
			return $r;
		}
	} else {
		$r = &{$self->{onFile}}($path);

		if ($r != 1) {
			return $r;
		}
	}

	return 1;
}

1;
