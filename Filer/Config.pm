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

package Filer::Config;

use strict;
use warnings;

sub new {
	my ($class,$side) = @_;
	my $self = bless {}, $class;

	if (! -e "$ENV{HOME}/.filer/") { 
		mkdir("$ENV{HOME}/.filer/");
	}

	if (! -e "$ENV{HOME}/.filer/config") {
		my $cfg = {
			PathLeft		=> $ENV{HOME},
			PathRight		=> $ENV{HOME},
			ShowHiddenFiles 	=> 1,
			Mode			=> 0
		};

		$self->store($cfg);
	}

	return $self;
}

sub store {
	my ($self,$config) = @_;
	Storable::store($config, "$ENV{HOME}/.filer/config");
}

sub get {
	my ($self) = @_;
	return Storable::retrieve("$ENV{HOME}/.filer/config");
}

sub set_option {
	my ($self,$option,$value) = @_;
	my $config = $self->get;

	$config->{$option} = $value;
	$self->store($config);
}

sub get_option {
	my ($self,$option) = @_;
	my $config = $self->get;

	return $config->{$option};
}

1;
