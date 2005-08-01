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

use YAML qw(LoadFile DumpFile Dump);

use Filer::Constants;

our ($default_config);

$default_config = {
	PathLeft		=> $ENV{HOME},
	PathRight		=> $ENV{HOME},
	ShowHiddenFiles 	=> TRUE,
	CaseInsensitiveSort 	=> TRUE,
	Mode			=> NORTON_COMMANDER_MODE,
	HonorUmask		=> FALSE,
	ConfirmCopy		=> TRUE,
	ConfirmMove		=> TRUE,
	ConfirmDelete		=> TRUE,
	WindowSize		=> "800:600",
	Terminal		=> "xterm",
	Editor			=> "nedit",
	Bookmarks		=> [],
};

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	my $xdg_config_home = (new File::BaseDir)->xdg_config_home;
	$self->{cfg_home} = Filer::Tools->catpath($xdg_config_home, "filer");
	$self->{config_store} = Filer::Tools->catpath($self->{cfg_home}, "config.yml");

	if (! -e $self->{cfg_home}) {
 		Filer::Tools->_mkdir($self->{cfg_home});
	}

	if (! -e $self->{config_store}) {
		$self->{config} = $default_config;
	} else {
		$self->{config} = LoadFile($self->{config_store});
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	DumpFile($self->{config_store}, $self->{config});
}

sub set_option {
	my ($self,$option,$value) = @_;
	$self->{config}->{$option} = $value;
}

sub get_option {
	my ($self,$option) = @_;

	if (defined $self->{config}->{$option}) {
		return $self->{config}->{$option};
	} else {
		return $default_config->{$option};
	}
}

1;
