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
use Class::Std::Utils;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use File::DirWalk;

use Filer::Constants;

my %SKIPALL;
my %OVERWRITEALL;
my %CANCELLED;
my %progress_dialog;
my %progress_label;
my %progressbar_total;
my %total_bytes;
my %completed_bytes;

sub new {
	my ($class) = @_;
	my $self    = bless {}, $class;

	$SKIPALL{ident $self}      = 0;
	$OVERWRITEALL{ident $self} = 0;
	$CANCELLED{ident $self}    = $FALSE;

	$progress_dialog{ident $self} = new Filer::ProgressDialog;
	$progress_dialog{ident $self}->dialog->set_title("Copying ...");
	$progress_dialog{ident $self}->label1->set_markup("<b>Copying: \nto: </b>");

	$progress_label{ident $self}    = $progress_dialog{ident $self}->label2;
	$progressbar_total{ident $self} = $progress_dialog{ident $self}->add_progressbar;

	my $button = $progress_dialog{ident $self}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$CANCELLED{ident $self} = $TRUE;
		$progress_dialog{ident $self}->destroy;
	});

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $SKIPALL{ident $self};
	delete $OVERWRITEALL{ident $self};
	delete $CANCELLED{ident $self};
	delete $progress_dialog{ident $self};
	delete $progress_label{ident $self};
	delete $progressbar_total{ident $self};
	delete $total_bytes{ident $self};
	delete $completed_bytes{ident $self};
}

sub cancelled {
	my ($self) = @_;
	return $CANCELLED{ident $self};
}

sub update_progress_label {
	my ($self,$str) = @_;
	$progress_label{ident $self}->set_text($str);
	while (Gtk2->events_pending) { Gtk2->main_iteration; }
}

sub update_written_bytes {
	my ($self,$bytes) = @_;
	$completed_bytes{ident $self} += $bytes;
}

sub copy {
	my ($self,$FILES,$DEST) = @_;

	$total_bytes{ident $self}     = 0;
	$completed_bytes{ident $self} = 0;

	my $dirwalk  = new File::DirWalk;
	my $filecopy = new Filer::FileCopy($self);

	$dirwalk->onFile(sub {
		my $file = pop;
		$total_bytes{ident $self} += -s $file;
		return 1;
	});

	for (@{$FILES}) {
		$dirwalk->walk($_); 
	}

	$dirwalk->onBeginWalk(sub {
		return ($CANCELLED{ident $self} == $FALSE) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		my $file = pop;
		symlink(readlink($file), Filer::Tools->catpath($DEST, basename($file))) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my $dir = pop;
		$DEST   = Filer::Tools->catpath($DEST, basename($dir));

		if ((-e $DEST) and (dirname($dir) eq dirname($DEST))) {
			$DEST = Filer::Tools->suggest_filename_helper($DEST);
		}

		mkdir($DEST) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		$DEST = abs_path(Filer::Tools->catpath($DEST, $UPDIR));
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $file    = pop;
		my $my_dest = Filer::Tools->catpath($DEST, basename($file));

		if (-e $my_dest) {
			if (dirname($file) eq dirname($my_dest)) {

				$my_dest = Filer::Tools->suggest_filename_helper($my_dest);

			} else {
				# TODO: Ask Overwrite Dialog

				Filer::Dialog->msgbox_error("File $file exists at $my_dest!\n");
				return File::DirWalk::ABORTED;
			}
		}

		return $filecopy->filecopy($file,$my_dest);
 	});

	my $timeout = Glib::Timeout->add(100, sub {
		return 1 if ($total_bytes{ident $self} == 0);
		return 0 if ($CANCELLED{ident $self} == $TRUE);

		my $percent_written = $completed_bytes{ident $self}/$total_bytes{ident $self};

		$progressbar_total{ident $self}->set_text(sprintf("%.0f", ($percent_written * 100)) . "%");
		$progressbar_total{ident $self}->set_fraction($percent_written);

		return 1;
	});

	$progress_dialog{ident $self}->show;

	foreach my $source (@{$FILES}) {
		$source =~ s/file:\///g;

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
	$progress_dialog{ident $self}->destroy;
}

*action = \&copy;

1;
