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

	return -1 if (&{$self->{onBeginWalk}}($path) != 1);

	if (-l $path) {

		return -1 if (&{$self->{onLink}}($path) != 1);

	} elsif (-d $path) {

		return -1 if (&{$self->{onDirEnter}}($path) != 1);

		opendir(DIR, $path) || return 0;

		foreach my $f (readdir(DIR)) {
			next if ($f eq "." or $f eq "..");

			return -1 if (&{$self->{onForEach}}("$path/$f") == 0);

			return -1 if ($self->walk("$path/$f") != 1);
		}

		closedir(DIR);

		return -1 if (&{$self->{onDirLeave}}($path) != 1);
	} else {
		return -1 if (&{$self->{onFile}}($path) != 1);
	}

	return 1;
}

1;
