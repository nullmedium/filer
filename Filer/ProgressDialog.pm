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

package Filer::ProgressDialog;

use strict;
use warnings;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{dialog} = Gtk2::Dialog->new("", undef, 'modal');
	$self->{dialog}->set_has_separator(1);
	$self->{dialog}->set_size_request(450,150);
	$self->{dialog}->set_position('center');
	$self->{dialog}->set_modal(1);

	my $hbox = Gtk2::HBox->new(0,0);
	$self->{dialog}->vbox->pack_start($hbox,0,0,5);

	$self->{label1} = Gtk2::Label->new();
	$self->{label1}->set_justify('left');
	$self->{label1}->set_use_markup(1);
	$self->{label1}->set_alignment(0.0,0.0);
	$hbox->pack_start($self->{label1},0,0,0);

	$self->{label2} = Gtk2::Label->new();
	$self->{label2}->set_alignment(0.0,0.0);
	$self->{label2}->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
	$hbox->pack_start($self->{label2},1,1,0);

	return $self;
}

sub show {
	my ($self) = @_;
	return $self->{dialog}->show_all;
}

sub destroy {
	my ($self) = @_;
	return $self->{dialog}->destroy;
}

sub dialog {
	my ($self) = @_;
	return $self->{dialog};
}

sub label1 {
	my ($self) = @_;
	return $self->{label1};
}

sub label2 {
	my ($self) = @_;
	return $self->{label2};
}

sub add_progressbar {
	my ($self) = @_;
	my $progressbar = new Gtk2::ProgressBar;
	$self->{dialog}->vbox->pack_start($progressbar,0,1,0);
	return $progressbar;
}

1;
