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
use File::Basename;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{progress} = 1;
	$self->{progress_dialog} = new Filer::ProgressDialog;
	$self->{progress_dialog}->dialog->set_title("Moving ...");
	$self->{progress_dialog}->label1->set_markup("<b>Moving: \nto: </b>");

	$self->{progress_label} = $self->{progress_dialog}->label2;
	$self->{progressbar_total} = $self->{progress_dialog}->add_progressbar;
	$self->{progressbar_part} = $self->{progress_dialog}->add_progressbar;

	my $button = $self->{progress_dialog}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->{progress} = 0;
		$self->{progress_dialog}->destroy;
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

sub move {
	my ($self,$source,$dest) = @_;
	my $dirname_source = dirname($source);
	my $dirname_dest = dirname($dest);
	my $basename_source = basename($source);
	my $r;

	if ($dirname_dest ne '.') {
		$r = rename($source, Cwd::abs_path("$dest/$basename_source")) && return Filer::DirWalk::SUCCESS;
	} else {
		$r = rename($source, Cwd::abs_path("$dirname_source/$dest")) && return Filer::DirWalk::SUCCESS;
	}

	if (!$r) {
		my $dirwalk = new Filer::DirWalk;

		$dirwalk->onBeginWalk(sub {
			if ($self->{progress} == 0) {
				return Filer::DirWalk::ABORTED;
			}

			return Filer::DirWalk::SUCCESS;
		});

		$dirwalk->onLink(sub {
			my ($source) = @_;

			my $target = readlink($source);
			symlink($target, Cwd::abs_path("$dest/" . basename($source))) || return Filer::DirWalk::FAILED;

			return Filer::DirWalk::SUCCESS;
		});

		$dirwalk->onDirEnter(sub {
			my ($dir) = @_;

			$dest = Cwd::abs_path("$dest/" . basename($dir));

			if (! -e  $dest) {
				mkdir($dest) || return Filer::DirWalk::FAILED;
			}

			return Filer::DirWalk::SUCCESS;
		});

		$dirwalk->onDirLeave(sub {
			my ($dir) = @_;

			$dest = Cwd::abs_path("$dest/..");

			return Filer::DirWalk::SUCCESS;
		});

		$dirwalk->onFile(sub {
			my ($file) = @_;
			my $dest = Cwd::abs_path("$dest/" . basename($file));

	 		$self->{progress_label}->set_text("$file\n$dest");
			$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
			while (Gtk2->events_pending) { Gtk2->main_iteration; }

			if ($file ne $dest) {
				my $filecopy = new Filer::FileCopy($self->{progressbar_part}, \$self->{progress});

				if ((my $r = $filecopy->filecopy($file,$dest)) != Filer::DirWalk::SUCCESS) {
					return $r;
				}

				unlink($file) || return Filer::DirWalk::FAILED;

				return Filer::DirWalk::SUCCESS;
			} else {
				Filer::Dialog->msgbox_error("Destination and target are the same! Aborting!");
				return Filer::DirWalk::ABORTED;
			}
		});

		return $dirwalk->walk($source);
	}
}

*action = \&move;

1;
