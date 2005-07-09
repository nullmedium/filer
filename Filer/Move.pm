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

	return File::DirWalk::FAILED if ($source eq $dest);

	my $my_dest = Cwd::abs_path("$dest/" . basename($source));

	if (-e $my_dest) {
		if ($main::SKIP_ALL) {
			return File::DirWalk::SUCCESS;
		}

		if (!$main::OVERWRITE_ALL) {
			my $r = Filer::Dialog->ask_overwrite_dialog("Replace", "Replace: <b>$my_dest</b>\nwith: <b>$source</b>");

			if ($r eq 'no') {
				return File::DirWalk::SUCCESS;
			} elsif ($r eq 1) {
				$main::OVERWRITE_ALL = 1;
			} elsif ($r eq 2) {
				$main::SKIP_ALL = 1;
				return File::DirWalk::SUCCESS;
			}
		}
	}

	if (! rename($source,$my_dest)) {

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
			my $my_source = $file;
			my $my_dest = Cwd::abs_path("$dest/" . basename($my_source));

	 		$self->{progress_label}->set_text("$my_source\n$my_dest");
			$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
			$self->{progressbar_total}->set_text("Moving file $self->{progress_count} of $self->{progress_total} ...");
			while (Gtk2->events_pending) { Gtk2->main_iteration; }

			if ((my $r = (new Filer::FileCopy($self->{progressbar_part}, \$self->{progress}))->filecopy($my_source,$my_dest)) != File::DirWalk::SUCCESS) {
				return $r;
			}

			unlink($my_source) || return File::DirWalk::FAILED;

			return File::DirWalk::SUCCESS;
		});

		return $dirwalk->walk($source);
	}

	return File::DirWalk::SUCCESS;

# 	my $dirwalk = new File::DirWalk;
# 
# 	$dirwalk->onBeginWalk(sub {
# 		if ($self->{progress} == 0) {
# 			return File::DirWalk::ABORTED;
# 		}
# 
# 		return File::DirWalk::SUCCESS;
# 	});
# 
# 	$dirwalk->onLink(sub {
# 		my ($source) = @_;
# 
# 		symlink(readlink($source), Cwd::abs_path("$dest/" . basename($source))) || return File::DirWalk::FAILED;
# 
# 		return File::DirWalk::SUCCESS;
# 	});
# 
# 	$dirwalk->onDirEnter(sub {
# 		my ($dir) = @_;
# 
# 		$dest = Cwd::abs_path("$dest/" . basename($dir));
# 
# 		if (! -e $dest) {
# 			mkdir($dest) || return File::DirWalk::FAILED;
# 		}
# 
# 		return File::DirWalk::SUCCESS;
# 	});
# 
# 	$dirwalk->onDirLeave(sub {
# 		my ($dir) = @_;
# 		$dest = Cwd::abs_path("$dest/..");
# 
# 		rmdir($dir) || return File::DirWalk::FAILED;
# 
# 		return File::DirWalk::SUCCESS;
# 	});
# 
# 	$dirwalk->onFile(sub {
# 		my ($file) = @_;
# 		my $my_source = $file;
# 		my $my_dest = Cwd::abs_path("$dest/" . basename($my_source));
# 
# 		if (-e $my_dest) {
# 			if ($main::SKIP_ALL) {
# 				return File::DirWalk::SUCCESS;
# 			}
# 
# 			if (!$main::OVERWRITE_ALL) {
# 				my $r = Filer::Dialog->ask_overwrite_dialog("Replace", "Replace: <b>$my_dest</b>\nwith: <b>$my_source</b>");
# 
# 				if ($r eq 'no') {
# 					return File::DirWalk::SUCCESS;
# 				} elsif ($r eq 1) {
# 					$main::OVERWRITE_ALL = 1;
# 				} elsif ($r eq 2) {
# 					$main::SKIP_ALL = 1;
# 					return File::DirWalk::SUCCESS;
# 				}
# 			}
# 		}
# 
# 	 	$self->{progress_label}->set_text("$my_source\n$my_dest");
# 		$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
# 		$self->{progressbar_total}->set_text("Moving file $self->{progress_count} of $self->{progress_total} ...");
# 		while (Gtk2->events_pending) { Gtk2->main_iteration; }
# 
# 		if (! rename($my_source,$my_dest)) {
# 			if ((my $r = (new Filer::FileCopy($self->{progressbar_part}, \$self->{progress}))->filecopy($my_source,$my_dest)) != File::DirWalk::SUCCESS) {
# 				return $r;
# 			}
# 
# 			unlink($my_source) || return File::DirWalk::FAILED;
# 		}
# 
# 		return File::DirWalk::SUCCESS;
# 	});
# 
# 	return $dirwalk->walk($source);
}

*action = \&move;

1;
