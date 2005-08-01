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

package Filer::Move;

use strict;
use warnings;

use Fcntl;
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);

use Filer::Constants;

use English;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	return $self;
}

sub move {
	my ($self,$FILES,$DEST) = @_;
	my $rename_failed = FALSE;

	foreach my $source (@{$FILES}) {
		my $my_dest = Filer::Tools->catpath($DEST, basename($source));

		if (! rename($source,$my_dest)) {
			$rename_failed = TRUE;
			last;
		}
	}

	return if ($rename_failed == FALSE);

	$self->{total_bytes} = 0;
	$self->{completed_bytes} = 0;

	my $dirwalk = new File::DirWalk;
	my $filecopy = new Filer::FileCopy($self);

	$dirwalk->onFile(sub {
		$self->{total_bytes} += -s $ARG[0];
		return 1;
	});

	$dirwalk->walk($ARG) for (@{$FILES});

	$dirwalk->onBeginWalk(sub {
		return ($self->{CANCELLED} == FALSE) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		symlink(readlink($ARG[0]), Filer::Tools->catpath($DEST, basename($ARG[0]))) || return File::DirWalk::FAILED;
		unlink($ARG[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		$DEST = Filer::Tools->catpath($DEST, basename($ARG[0]));

		if ((-e $DEST) and (dirname($ARG[0]) eq dirname($DEST))) {
			$DEST = Filer::Tools->suggest_filename_helper($DEST);
		}

		mkdir($DEST) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		$DEST = abs_path(Filer::Tools->catpath($DEST, UPDIR));

		rmdir($ARG[0]) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $my_dest = Filer::Tools->catpath($DEST, basename($ARG[0]));

		if (-e $my_dest) {
			if (dirname($ARG[0]) eq dirname($my_dest)) {

				$my_dest = Filer::Tools->suggest_filename_helper($my_dest);

			} else {
				# TODO: Ask Overwrite Dialog

				Filer::Dialog->msgbox_error("File $ARG[0] exists at $my_dest!\n");
				return File::DirWalk::ABORTED;
			}
		}

		if ((my $r = $filecopy->filecopy($ARG[0],$my_dest)) != File::DirWalk::SUCCESS) {
			return $r;
		}

		unlink($ARG[0]) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
 	});

	$self->{CANCELLED} = FALSE;

	my $timeout = Glib::Timeout->add(200, sub {
		return 1 if ($self->{total_bytes} == 0);
		return 0 if ($self->{CANCELLED} == TRUE);

		my $percent_written = $self->{completed_bytes}/$self->{total_bytes};

		$self->{progressbar_total}->set_text(sprintf("%.0f", ($percent_written * 100)) . "%");
		$self->{progressbar_total}->set_fraction($percent_written);

		return 1;
	});

	$self->{progress_dialog} = new Filer::ProgressDialog;
	$self->{progress_dialog}->dialog->set_title("Moving ...");
	$self->{progress_dialog}->label1->set_markup("<b>Moving: \nto: </b>");

	$self->{progress_label} = $self->{progress_dialog}->label2;
	$self->{progressbar_total} = $self->{progress_dialog}->add_progressbar;

	my $button = $self->{progress_dialog}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->{CANCELLED} = TRUE;
		$self->{progress_dialog}->destroy;
	});

	$self->{progress_dialog}->show;

	foreach my $source (@{$FILES}) {
		return 0 if ($self->{CANCELLED} == TRUE);
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_error("Moving of $source to " . $DEST . " failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Moving of $source to " . $DEST . " aborted!");
			last;
		}
	}

	Glib::Source->remove($timeout);
	$self->{progress_dialog}->destroy;
}

*action = \&move;

1;
