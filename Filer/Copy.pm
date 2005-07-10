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
use Cwd qw( abs_path );
use File::Spec::Functions qw(catfile splitdir);
use File::Basename qw(dirname basename);

Memoize::memoize("abs_path");
Memoize::memoize("catfile");
Memoize::memoize("splitdir");
Memoize::memoize("basename");

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

sub copy {
	my ($self,$source,$dest) = @_;

	my $dirwalk = new File::DirWalk;

	$dirwalk->onBeginWalk(sub {
		if ($self->{progress} == 0) {
			return File::DirWalk::ABORTED;
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onLink(sub {
		my ($source) = @_;
		my $target = readlink($source);

		symlink($target, abs_path(catfile(splitdir($dest), basename($source)))) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my ($dir) = @_;
		$dest = abs_path(catfile(splitdir($dest), basename($dir)));

		if (! -e $dest) {
			mkdir($dest) || return File::DirWalk::FAILED;
		}

		if ((-e $dest) and (dirname($source) eq dirname($dest))) {
			my $i = 1;
			while (1) {
				last unless (-e "$dest-$i");
				$i++;
			}

			$dest = "$dest-$i";

			mkdir($dest) || return File::DirWalk::FAILED;
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		$dest = abs_path(catfile(splitdir($dest), File::Spec->updir));
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my ($source) = @_;
		my $my_source = $source;
		my $my_dest = abs_path(catfile(splitdir($dest), basename($my_source)));

		if (-e $my_dest) {
			if (dirname($my_source) eq dirname($my_dest)) {
				my $i = 1;
				while (1) {
					last unless (-e "$my_dest-$i");
					$i++;
				}

				$my_dest = "$my_dest-$i";
			} else {
				if ($main::SKIP_ALL) {
					return File::DirWalk::SUCCESS;
				}

				if (!$main::OVERWRITE_ALL) {
					my $r = Filer::Dialog->ask_overwrite_dialog("Overwrite", "Overwrite: <b>$my_dest</b>\nwith: <b>$my_source</b>");

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
		}

 		$self->{progress_label}->set_text("$my_source\n$my_dest");
		$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
		$self->{progressbar_total}->set_text("Copying file $self->{progress_count} of $self->{progress_total} ...");

		while (Gtk2->events_pending) { Gtk2->main_iteration; }

		if ($my_source ne $dest) {
			return (new Filer::FileCopy($self->{progressbar_part}, \$self->{progress}))->filecopy($my_source,$my_dest);
		} else {
			Filer::Dialog->msgbox_error("Destination and target are the same! Aborting!");
			return File::DirWalk::ABORTED;
		}
	});

	return $dirwalk->walk($source);
}

*action = \&copy;

1;
