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

package Filer::Bookmarks;

use strict;
use warnings;

sub new {
	my ($class,$side) = @_;
	my $self = bless {}, $class;
	$self->{cfg_home} = (new File::BaseDir)->xdg_config_home . "/filer";

	if (! -e "$self->{cfg_home}/bookmarks") {
		$self->store([]);
	}

	return $self;
}

sub store {
	my ($self,$bookmarks) = @_;
	Storable::store($bookmarks, "$self->{cfg_home}/bookmarks");
}

sub get {
	my ($self) = @_;
	return Storable::retrieve("$self->{cfg_home}/bookmarks");
}

sub get_bookmarks {
	my ($self) = @_;
	return sort @{$self->get};
}

sub set_bookmark {
	my ($self,$path) = @_;
	my @bookmarks = $self->get_bookmarks;

	return if (!$path); 

	push @bookmarks, $path;

	$self->store(\@bookmarks);
}

sub remove_bookmark {
	my ($self,$path) = @_;
	my @bookmarks = $self->get_bookmarks;
	my @b = ();

	foreach (@bookmarks) {
		if ($_ ne $path) {
			push @b, $_;
		}
	}

	$self->store(\@b);
}

1;
