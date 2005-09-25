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
use Class::Std::Utils;

use strict;
use warnings;

use YAML qw(LoadFile DumpFile Dump);

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

my %config_home;
my %config_file;
my %config;

sub new {
	my ($class) = @_;
	my $self = bless anon_scalar(), $class;
	my $xdg_config_home = File::BaseDir->new->xdg_config_home;
	$config_home{ident $self} = Filer::Tools->catpath($xdg_config_home, "filer");
	$config_file{ident $self} = Filer::Tools->catpath($config_home{ident $self}, "config.yml");

	if (! -e $config_home{ident $self}) {
 		mkdir($config_home{ident $self});
	}

	if (! -e $config_file{ident $self}) {
		$config{ident $self} = $default_config;
	} else {
		$config{ident $self} = LoadFile($config_file{ident $self});
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	DumpFile($config_file{ident $self}, $config{ident $self});

	delete $config_home{ident $self};
	delete $config_file{ident $self};
	delete $config{ident $self};
}

sub set_option {
	my ($self,$option,$value) = @_;
	$config{ident $self}->{$option} = $value;
}

sub set_options {
	my ($self,%vals) = @_;
	
	while (my ($option,$value) = each %vals) {
		$config{ident $self}->{$option} = $value;
	}
}

sub get_option {
	my ($self,$option) = @_;

	return (defined $config{ident $self}->{$option})
		? $config{ident $self}->{$option}
		: $default_config->{$option};
}

1;
