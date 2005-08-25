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

use Filer::Constants;

use English;


sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{CANCELLED} = $FALSE;
	$self->{progress_dialog} = new Filer::ProgressDialog;
	$self->{progress_dialog}->dialog->set_title("Deleting ...");
	$self->{progress_dialog}->label1->set_markup("<b>Deleting: </b>");

	$self->{progress_label} = $self->{progress_dialog}->label2;
	$self->{progressbar_total} = $self->{progress_dialog}->add_progressbar;

	my $button = $self->{progress_dialog}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->{CANCELLED} = $TRUE;
		$self->{progress_dialog}->destroy;
	});

	return $self;
}

sub delete {
	my ($self,$files) = @_;
	$self->{deleted_total} = 0;
	$self->{deleted_files} = 0;

	my $dirwalk = new File::DirWalk;

	$dirwalk->onFile(sub {
		++$self->{deleted_total};
		return 1;
	});

	$dirwalk->walk($ARG) for (@{$files});

	$dirwalk->onBeginWalk(sub {
		return ($self->{CANCELLED} == $FALSE) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		unlink($ARG[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		rmdir($ARG[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		$self->{progress_label}->set_text($ARG[0]);
		$self->{progressbar_total}->set_fraction(++$self->{deleted_files}/$self->{deleted_total});
		while (Gtk2->events_pending) { Gtk2->main_iteration; }

		unlink($ARG[0]) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$self->{progress_dialog}->show;

	foreach my $source (@{$files}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_info("Deleting of $source failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Deleting of $source aborted!");
			last;
		}
	}

	$self->{progress_dialog}->destroy;
}

1;
