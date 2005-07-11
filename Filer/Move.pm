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

	my $my_dest = abs_path(catfile(splitdir($dest), basename($source)));

	if (-e $my_dest) {
		my ($dialog,$label,$button,$hbox,$entry);
		my $f1 = $my_dest; 
		my $f2 = $source
		$f1 =~ s/&/&amp;/g;
		$f2 =~ s/&/&amp;/g;

		$dialog = new Gtk2::Dialog("Overwrite", undef, 'modal');
		$dialog->set_position('center');
		$dialog->set_modal(1);

		$label = new Gtk2::Label;
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$label->set_markup("Overwrite: <b>$f1</b>\nwith: <b>$f2</b>");
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
			my ($w) = @_;
			my $suggest = Filer::Copy->_suggest_filename_helper($my_dest);
			$entry->set_text(basename($suggest));
			$w->set_sensitive(0);
		});
		$hbox->pack_start($button, 0,1,5);

		$dialog->add_button("Overwrite", 1);
		$dialog->add_button("Rename", 2);
		$dialog->add_button("Cancel", 'cancel');

		$dialog->show_all;
		my $r = $dialog->run;
		$dialog->destroy;

		if ($r eq '2') {
			$my_dest = catfile(dirname($my_dest), $entry->get_text);
		} else {
			return File::DirWalk::ABORTED;
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

			symlink(readlink($source), abs_path(catfile(splitdir($dest), basename($source)))) || return File::DirWalk::FAILED;

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onDirEnter(sub {
			my ($dir) = @_;
			$dest = abs_path(catfile(splitdir($dest), basename($dir)));

			if (! -e $dest) {
				mkdir($dest) || return File::DirWalk::FAILED;
			}

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onDirLeave(sub {
			my ($dir) = @_;
			$dest = abs_path(catfile(splitdir($dest), File::Spec->updir));

			rmdir($dir) || return File::DirWalk::FAILED;

			return File::DirWalk::SUCCESS;
		});

		$dirwalk->onFile(sub {
			my ($file) = @_;
			my $my_source = $file;
			my $my_dest = abs_path(catfile(splitdir($dest), basename($my_source)));

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
}

*action = \&move;

1;
