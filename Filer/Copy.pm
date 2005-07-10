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

 		$self->{progress_label}->set_text("$my_source\n$my_dest");
		$self->{progressbar_total}->set_fraction(++$self->{progress_count}/$self->{progress_total});
		$self->{progressbar_total}->set_text("Copying file $self->{progress_count} of $self->{progress_total} ...");

		while (Gtk2->events_pending) { Gtk2->main_iteration; }

		if (-e $my_dest) {
			if ($main::SKIP_ALL) {
				return File::DirWalk::SUCCESS;
			}

			if (!$main::OVERWRITE_ALL) {
				my ($dialog,$label,$button,$hbox,$entry);

				if (dirname($my_source) eq dirname($my_dest)) {
					$dialog = new Gtk2::Dialog("File exists already", undef, 'modal');
					$dialog->set_position('center');
					$dialog->set_modal(1);

					$label = new Gtk2::Label;
					$label->set_use_markup(1);
					$label->set_alignment(0.0,0.0);
					$label->set_markup("This action would overwrite '$my_source' with itself.\nPlease enter a new file name:");
					$dialog->vbox->pack_start($label, 1,1,5);

					$hbox = new Gtk2::HBox(0,0);
					$dialog->vbox->pack_start($hbox, 1,1,5);

					$entry = new Gtk2::Entry;
					$entry->set_alignment(0.0);
					$hbox->pack_start($entry, 1,1,5);

					$button = new Gtk2::Button("Suggest New Name");
					$button->signal_connect("clicked", sub {
						my $i = 1;
						while (1) {
							last unless (-e "$my_dest-$i");
							$i++;
						}

						$entry->set_text(basename("$my_dest-$i"));
					});
					$hbox->pack_start($button, 0,1,5);

					$dialog->add_button("Continue", 'ok');
					$dialog->add_button("Cancel", 'cancel');

					$dialog->show_all;
					my $r = $dialog->run;
					$dialog->destroy;

					if ($r eq 'ok') {
						$my_dest = catfile(dirname($my_dest), $entry->get_text);
					} elsif ($r eq 'cancel') {
						return File::DirWalk::ABORTED;
					}

				} else {
					my ($dialog,$label,$button,$hbox,$entry);

					$dialog = new Gtk2::Dialog("Overwrite", undef, 'modal');
					$dialog->set_position('center');
					$dialog->set_modal(1);

					$label = new Gtk2::Label;
					$label->set_use_markup(1);
					$label->set_alignment(0.0,0.0);
					$label->set_markup("Overwrite: <b>$my_dest</b>\nwith: <b>$my_source</b>");
					$dialog->vbox->pack_start($label, 1,1,5);

					$hbox = new Gtk2::HBox(0,0);
					$dialog->vbox->pack_start($hbox, 1,1,5);

					$label = new Gtk2::Label;
					$label->set_use_markup(1);
					$label->set_alignment(0.0,0.5);
					$label->set_markup("New Name: ");
					$hbox->pack_start($label, 0,0,0);

					$entry = new Gtk2::Entry;
					$entry->set_alignment(0.0);
					$hbox->pack_start($entry, 0,1,5);

					$button = new Gtk2::Button("Suggest new name");
					$button->signal_connect("clicked", sub {
						my $i = 1;
						while (1) {
							last unless (-e "$my_dest-$i");
							$i++;
						}

						$entry->set_text(basename("$my_dest-$i"));
					});
					$hbox->pack_start($button, 0,1,5);

					$dialog->add_button("Rename", 3);
					$dialog->add_button("Overwrite", 'yes');
					$dialog->add_button("Auto Skip", 'no');
					$dialog->add_button("Overwrite All", 1);
					$dialog->add_button("Overwrite None", 2);
					$dialog->add_button("Cancel", 'cancel');

					$dialog->show_all;
					my $r = $dialog->run;
					$dialog->destroy;

					if ($r eq 'no') {
						return File::DirWalk::SUCCESS;
					} elsif ($r eq 'cancel') {
						return File::DirWalk::ABORTED;
					} elsif ($r eq 1) {
						$main::OVERWRITE_ALL = 1;
					} elsif ($r eq 2) {
						$main::SKIP_ALL = 1;
						return File::DirWalk::SUCCESS;
					} elsif ($r eq 3) {
						$my_dest = catfile(dirname($my_dest), $entry->get_text);
					}
				}

				if ($my_source eq $my_dest) {
					Filer::Dialog->msgbox_error("Can't overwrite file with itself! Skipping!");
					return File::DirWalk::SUCCESS;
				}
			}
		}

 		$self->{progress_label}->set_text("$my_source\n$my_dest");
		$self->{progressbar_total}->set_fraction($self->{progress_count}/$self->{progress_total});
		$self->{progressbar_total}->set_text("Copying file $self->{progress_count} of $self->{progress_total} ...");

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
