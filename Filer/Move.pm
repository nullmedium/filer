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

	$main::SKIP_ALL = 0;
	$main::OVERWRITE_ALL = 0;

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
	my $r;

	return File::DirWalk::FAILED if ($source eq $dest);

# 	my $trashdir = (new File::BaseDir)->xdg_data_home . "/Trash";
# 	my $trashdir_files = "$trashdir/files";
# 	my $trashdir_info = "$trashdir/info";
# 	my $file_basename = basename($source);

	if (dirname($dest) ne '.') {
		my $my_dest = Cwd::abs_path("$dest/" . basename($source));
		
		if ((-e $my_dest) and (! -d $my_dest)) {
			if ($main::SKIP_ALL) {
				return File::DirWalk::SUCCESS;
			}

			if (!$main::OVERWRITE_ALL) {
				my $r = Filer::Dialog->ask_overwrite_dialog("Replace", "Replace: <b>$my_dest</b>\nwith: <b>$source</b>");

				if ($r eq 'no') {
					return File::DirWalk::SUCCESS;
				} elsif ($r == 1) {
					$main::OVERWRITE_ALL = 1;
				} elsif ($r == 2) {
					$main::SKIP_ALL = 1;
					return File::DirWalk::SUCCESS;
				}
			}
		}

		$r = rename($source,$my_dest);
		
# 		# it's 'renamed' out of the trash. so remove its .trashinfo file
# 		if (dirname($source) eq $trashdir_files) {
# 			unlink("$trashdir_info/$file_basename.trashinfo")
# 		}

	} else {
		$r = rename($source,Cwd::abs_path(dirname($source) . "/$dest"));

# 		# the file is renamed inside the trash -> rename its .trashinfo file too
# 		if (dirname($source) eq $trashdir_files) {
# 			rename("$trashdir_info/$file_basename.trashinfo", "$trashdir_info/" . basename($dest) . ".trashinfo");
# 		}
	}

	if (!$r) {
		my $dirwalk = new File::DirWalk;

		$dirwalk->onBeginWalk(sub {
			if ($self->{progress} == 0) {
				return File::DirWalk::ABORTED;
			}

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onLink(sub {
			my ($source) = @_;

			symlink(readlink($source), Cwd::abs_path("$dest/" . basename($source))) || return File::DirWalk::FAILED;

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onDirEnter(sub {
			my ($dir) = @_;

			$dest = Cwd::abs_path("$dest/" . basename($dir));

			if (! -e $dest) {
				mkdir($dest) || return File::DirWalk::FAILED;
			}

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onDirLeave(sub {
			my ($dir) = @_;
			$dest = Cwd::abs_path("$dest/..");

			rmdir($dir) || return File::DirWalk::FAILED;

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onFile(sub {
			my ($file) = @_;
			my $dest = Cwd::abs_path("$dest/" . basename($file));

	 		$self->{progress_label}->set_text("$file\n$dest");
			$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
			$self->{progressbar_total}->set_text("Moving file $self->{progress_count} of $self->{progress_total} ...");
			while (Gtk2->events_pending) { Gtk2->main_iteration; }

			if ($file ne $dest) {
				my $filecopy = new Filer::FileCopy($self->{progressbar_part}, \$self->{progress});

				if ((my $r = $filecopy->filecopy($file,$dest)) != File::DirWalk::SUCCESS) {
					return $r;
				}

				unlink($file) || return File::DirWalk::FAILED;

				return File::DirWalk::SUCCESS;
			} else {
				Filer::Dialog->msgbox_error("Destination and target are the same! Aborting!");
				return File::DirWalk::ABORTED;
			}
		});

		return $dirwalk->walk($source);
	}

	return File::DirWalk::SUCCESS;
}

*action = \&move;

1;
