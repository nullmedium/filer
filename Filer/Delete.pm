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

package Filer::Delete;

use strict;
use warnings;

use File::Basename;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{progress} = 1;
	$self->{progress_dialog} = new Filer::ProgressDialog;
	$self->{progress_dialog}->dialog->set_title("Deleting ...");
	$self->{progress_dialog}->label1->set_markup("<b>Deleting: </b>");

	$self->{progress_label} = $self->{progress_dialog}->label2;
	$self->{progressbar_total} = $self->{progress_dialog}->add_progressbar;

	my $button = $self->{progress_dialog}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->{progress} = 0;
		$self->{progress_dialog}->destroy;
	});

	$self->{dirwalk} = new File::DirWalk;

	$self->{dirwalk}->onBeginWalk(sub {
		if ($self->{progress} == 0) {
			return File::DirWalk::ABORTED;
		}

		return File::DirWalk::SUCCESS;
	});

	$self->{dirwalk}->onLink(sub {
		my ($source) = @_;

		unlink($source) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$self->{dirwalk}->onDirLeave(sub {
		my ($source) = @_;

		rmdir($source) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$self->{dirwalk}->onFile(sub {
		my ($source) = @_;

		$self->{progress_label}->set_text($source);
		$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
		while (Gtk2->events_pending) { Gtk2->main_iteration; }

		unlink($source) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	return $self;
}

sub set_total {
	my ($self,$total) = @_;
	$self->{progress_count} = 0;
	$self->{progress_total} = $total;
}

sub show {
	my ($self) = @_;
	$self->{progress_dialog}->show;
}

sub destroy {
	my ($self) = @_;
	$self->{progress_dialog}->destroy;
}

sub delete {
	my ($self,$source) = @_;

	return $self->{dirwalk}->walk($source);
}

1;
