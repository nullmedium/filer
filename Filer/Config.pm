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

our ($default_config);

$default_config = {
	PathLeft		=> $ENV{HOME},
	PathRight		=> $ENV{HOME},
	ShowHiddenFiles 	=> 1,
	CaseInsensitiveSort 	=> 1,
	Mode			=> 0,
	ConfirmCopy		=> 1,
	ConfirmMove		=> 1,
	ConfirmDelete		=> 1,
	WindowSize		=> "800:600",
	Terminal		=> "xterm",
	Editor			=> "nedit",
};

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	my $xdg_config_home = (new File::BaseDir)->xdg_config_home;
	$self->{cfg_home} = File::Spec->catfile(File::Spec->splitdir($xdg_config_home), "filer");
	$self->{config_store} = File::Spec->catfile($self->{cfg_home}, "config");

	if (! -e $xdg_config_home) {
		mkdir($xdg_config_home);
	}

	if (! -e $self->{cfg_home}) {
		mkdir($self->{cfg_home});
	}

	if (! -e $self->{config_store}) {
		$self->store($default_config);
	}

	return $self;
}

sub store {
	my ($self,$config) = @_;
	Storable::store($config, $self->{config_store});
}

sub get {
	my ($self) = @_;
	return Storable::retrieve($self->{config_store});
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
	
	if (defined $config->{$option}) {
		return $config->{$option};
	}

	return $default_config->{$option};
}

1;
