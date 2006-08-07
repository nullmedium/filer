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

use YAML::Syck qw(LoadFile DumpFile Dump);

use Filer::Constants;

my $default_config = {
	PathLeft		=> $ENV{HOME},
	PathRight		=> $ENV{HOME},
	ShowHiddenFiles 	=> $TRUE,
	CaseInsensitiveSort	=> $TRUE,
	Mode			=> $NORTON_COMMANDER_MODE,
	HonorUmask		=> $FALSE,
	ConfirmCopy		=> $TRUE,
	ConfirmMove		=> $TRUE,
	ConfirmDelete		=> $TRUE,
	WindowSize		=> "800:600",
	Terminal		=> "xterm",
	Editor			=> "nedit",
	Bookmarks		=> [],
};

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	$self->{config_home} = Filer::Tools->catpath($XDG_CONFIG_HOME, "filer");
	$self->{config_file} = Filer::Tools->catpath($self->{config_home}, "config.yml");

	if (! -e $self->{config_home}) {
 		mkdir($self->{config_home});
	}

	if (! -e $self->{config_file}) {
		$self->{config} = $default_config;
	} else {
		$self->{config} = LoadFile($self->{config_file});
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	DumpFile($self->{config_file}, $self->{config});
}

sub set_option {
	my ($self,$option,$value) = @_;
	$self->{config}->{$option} = $value;
}

sub set_options {
	my ($self,%vals) = @_;
	
	while (my ($option,$value) = each %vals) {
		$self->{config}->{$option} = $value;
	}
}

sub get_option {
	my ($self,$option) = @_;

# 	return (defined $self->{config}->{$option})
# 		? $self->{config}->{$option}
# 		: $default_config->{$option};
	return $self->{config}->{$option};
}

1;
