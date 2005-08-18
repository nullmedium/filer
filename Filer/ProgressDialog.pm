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
use Class::Std::Utils;

use strict;
use warnings;

my %dialog;
my %label1;
my %label2;

sub new {
	my ($class) = @_;
	my $self = bless anon_scalar(), $class;

	$dialog{ident $self} = Gtk2::Dialog->new("", undef, 'modal');
	$dialog{ident $self}->set_has_separator(1);
	$dialog{ident $self}->set_size_request(450,150);
	$dialog{ident $self}->set_position('center');
	$dialog{ident $self}->set_modal(1);

	my $hbox = Gtk2::HBox->new(0,0);
	$dialog{ident $self}->vbox->pack_start($hbox,0,0,5);

	$label1{ident $self} = Gtk2::Label->new();
	$label1{ident $self}->set_justify('left');
	$label1{ident $self}->set_use_markup(1);
	$label1{ident $self}->set_alignment(0.0,0.0);
	$hbox->pack_start($label1{ident $self},0,0,0);

	$label2{ident $self} = Gtk2::Label->new();
	$label2{ident $self}->set_alignment(0.0,0.0);
	$label2{ident $self}->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
	$hbox->pack_start($label2{ident $self},1,1,0);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	delete $dialog{ident $self};
	delete $label1{ident $self};
	delete $label2{ident $self};	
}

sub show {
	my ($self) = @_;
	return $dialog{ident $self}->show_all;
}

sub destroy {
	my ($self) = @_;
	return $dialog{ident $self}->destroy;
}

sub dialog {
	my ($self) = @_;
	return $dialog{ident $self};
}

sub label1 {
	my ($self) = @_;
	return $label1{ident $self};
}

sub label2 {
	my ($self) = @_;
	return $label2{ident $self};
}

sub add_progressbar {
	my ($self) = @_;
	my $progressbar = new Gtk2::ProgressBar;
	$dialog{ident $self}->vbox->pack_start($progressbar,0,1,0);
	return $progressbar;
}

1;
