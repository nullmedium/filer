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

package Filer::Copy;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use File::DirWalk;

use English;

use Filer::Constants;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{SKIPALL} = 0;
	$self->{OVERWRITEALL} = 0;
	$self->{CANCELLED} = FALSE;

	$self->{progress_dialog} = new Filer::ProgressDialog;
	$self->{progress_dialog}->dialog->set_title("Copying ...");
	$self->{progress_dialog}->label1->set_markup("<b>Copying: \nto: </b>");

	$self->{progress_label} = $self->{progress_dialog}->label2;
	$self->{progressbar_total} = $self->{progress_dialog}->add_progressbar;

	my $button = $self->{progress_dialog}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->{CANCELLED} = TRUE;
		$self->{progress_dialog}->destroy;
	});

	return $self;
}

sub copy {
	my ($self,$FILES,$DEST) = @_;
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

		return $filecopy->filecopy($ARG[0],$my_dest);
 	});

	my $timeout = Glib::Timeout->add(100, sub {
		return 1 if ($self->{total_bytes} == 0);
		return 0 if ($self->{CANCELLED} == TRUE);

		my $percent_written = $self->{completed_bytes}/$self->{total_bytes};

		$self->{progressbar_total}->set_text(sprintf("%.0f", ($percent_written * 100)) . "%");
		$self->{progressbar_total}->set_fraction($percent_written);

		return 1;
	});

	$self->{progress_dialog}->show;

	foreach my $source (@{$FILES}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_error("Copying of $source to " . $DEST . " failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Copying of $source to " . $DEST . " aborted!");
			last;
		}
	}

	Glib::Source->remove($timeout);
	$self->{progress_dialog}->destroy;
}

*action = \&copy;

1;
