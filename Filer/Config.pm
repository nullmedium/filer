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

package Filer::Config;

use strict;
use warnings;

sub new {
	my ($class,$side) = @_;
	my $self = bless {}, $class;
	$self->{cfg_home} = (new File::BaseDir)->xdg_config_home . "/filer";

	# move old config directory if it exists:
	if (-e "$ENV{HOME}/.filer/") {
		print "moving old config directory to new location ...\n";
		rename("$ENV{HOME}/.filer", $self->{cfg_home});
	}

	if (! -e File::BaseDir::xdg_config_home) {
		mkdir(File::BaseDir::xdg_config_home);
	}

	if (! -e $self->{cfg_home}) {
		mkdir($self->{cfg_home});
	}

	if (! -e "$self->{cfg_home}/config") {
		my $cfg = {
			PathLeft		=> $ENV{HOME},
			PathRight		=> $ENV{HOME},
			ShowHiddenFiles 	=> 1,
			Mode			=> 0,
			ConfirmCopy		=> 1,
			ConfirmMove		=> 1,
			ConfirmDelete		=> 1,
			MoveToTrash		=> 1,
			WindowSize		=> "800:600",
		};

		$self->store($cfg);
	}

	return $self;
}

sub store {
	my ($self,$config) = @_;
	Storable::store($config, "$self->{cfg_home}/config");
}

sub get {
	my ($self) = @_;
	return Storable::retrieve("$self->{cfg_home}/config");
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
