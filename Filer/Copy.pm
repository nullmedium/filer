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

use Fcntl;
use File::Basename;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{progress} = 1;
	$self->{progress_dialog} = new Filer::ProgressDialog;
	$self->{progress_dialog}->dialog->set_title("Copying ...");
	$self->{progress_dialog}->label1->set_markup("<b>Copying: \nto: </b>");

	$self->{progress_label} = $self->{progress_dialog}->label2;
	$self->{progressbar_total} = $self->{progress_dialog}->add_progressbar;
	$self->{progressbar_part} = $self->{progress_dialog}->add_progressbar;

	my $button = $self->{progress_dialog}->dialog->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->{progress} = 0;
		$self->destroy;
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

sub copy {
	my ($self,$source,$dest) = @_;
#	my $copy_inside_same_directory = 0;

	my $dirwalk = new File::DirWalk;

# 	if (dirname($dest) eq ".") {
# 		$dest = dirname($source) . "/" . $dest;
# 		$copy_inside_same_directory = 1;
#
# 		if (-d $source) {
# 			mkdir($dest);
# 		}
# 	}

	$dirwalk->onBeginWalk(sub {
		if ($self->{progress} == 0) {
			return File::DirWalk::ABORTED;
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onLink(sub {
		my ($source) = @_;
		my $target = readlink($source);

		symlink($target, Cwd::abs_path("$dest/" . basename($source))) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my ($dir) = @_;

# 		if ($copy_inside_same_directory == 1) {
# 			$copy_inside_same_directory = 0;
# 		} else {
			$dest = Cwd::abs_path("$dest/" . basename($dir));
#		}

		if (! -e $dest) {
			mkdir($dest) || return File::DirWalk::FAILED;
		} else {
			if (dirname($dir) eq dirname($dest)) {
				my $i = 1;
				while (1) {
					if (-e "$dest-$i") {
						$i++;
					} else {
						$dest = "$dest-$i";
						last;
					}
				}

				mkdir($dest) || return File::DirWalk::FAILED;
			}
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		$dest = Cwd::abs_path("$dest/..");
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my ($file) = @_;
		my $my_dest = $dest;

# 		if ($copy_inside_same_directory == 1) {
# 			$copy_inside_same_directory = 0;
# 		} else {
			$my_dest = Cwd::abs_path("$dest/" . basename($file));
#		}

 		$self->{progress_label}->set_text("$file\n$my_dest");
		$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
		$self->{progressbar_total}->set_text("Copying file $self->{progress_count} of $self->{progress_total} ...");

		while (Gtk2->events_pending) { Gtk2->main_iteration; }

		if ($file ne $dest) {
			my $filecopy = new Filer::FileCopy($self->{progressbar_part}, \$self->{progress});
			return $filecopy->filecopy($file,$my_dest);
		} else {
			Filer::Dialog->msgbox_error("Destination and target are the same! Aborting!");
			return File::DirWalk::ABORTED;
		}
	});

	return $dirwalk->walk($source);
}

*action = \&copy;

1;
