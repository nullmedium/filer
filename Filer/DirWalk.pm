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

use constant FAILED => 0;
use constant SUCCESS => 1;
use constant ABORTED => -1;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	foreach (qw(onBeginWalk onLink onFile onDirEnter onDirLeave onForEach)) {
		$self->{$_} = sub { SUCCESS; };
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

	if ((my $r = &{$self->{onBeginWalk}}($path)) != SUCCESS) {
		return $r;
	}
	
	if (-l $path) {

		if ((my $r = &{$self->{onLink}}($path)) != SUCCESS) {
			return $r;
		}

	} elsif (-d $path) {

		if ((my $r = &{$self->{onDirEnter}}($path)) != SUCCESS) {
			return $r;
		}

		opendir(DIR, $path) || return FAILED;

		foreach my $f (readdir(DIR)) {
			next if ($f eq "." or $f eq "..");

			if ((my $r = &{$self->{onForEach}}("$path/$f")) != SUCCESS) {
				return $r;
			}

			if ((my $r = $self->walk("$path/$f")) != SUCCESS) {
				return $r;
			}
		}

		closedir(DIR);

		if ((my $r = &{$self->{onDirLeave}}($path)) != SUCCESS) {
			return $r;
		}
	} else {
		if ((my $r = &{$self->{onFile}}($path) != SUCCESS)) {
			return $r;
		}
	}

	return SUCCESS;
}

1;
