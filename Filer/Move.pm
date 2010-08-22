#     Copyright (C) 2004-2010 Jens Luedicke <jens.luedicke@gmail.com>
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
use base qw(Filer::MoveJobDialog);

use strict;
use warnings;

use Fcntl;
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);

use Filer::Constants qw(:filer);

sub new {
	my ($class,$filer) = @_;
	my $self = $class->SUPER::new();

	$self->{filer} = $filer;

	return $self;
}

sub move {
	my ($self,$FILES,$DEST) = @_;
	my $items_count = scalar @{$FILES};

	if ($items_count == 1) {
		my $dialog = Filer::SourceTargetDialog->new("Move/Rename");

		my $label = $dialog->get_source_label;
		$label->set_markup("<b>Move/Rename: </b>");

		my $source_entry = $dialog->get_source_entry;
		$source_entry->set_text($FILES->[0]);
		$source_entry->set_activates_default($TRUE);

		my $target_label = $dialog->get_target_label;
		$target_label->set_markup("<b>to: </b>");

		my $target_entry  = $dialog->get_target_entry;
		$target_entry->set_text($DEST);
		$target_entry->set_activates_default($TRUE);

		if ($dialog->run eq 'ok') {
			my $target = $target_entry->get_text;
			$DEST      = $target;

			$dialog->destroy;
		} else {
			$dialog->destroy;
			return;
		}

	} else {
		if ($self->{filer}->get_config->get_option("ConfirmMove") == $TRUE) {
			return if (Filer::Dialog->yesno_dialog("Move $items_count files to $DEST?") eq 'no');
		}
	}

	$self->_move($FILES,$DEST);
	$self->{filer}->refresh_cb;
}

sub _move {
	my ($self,$FILES,$DEST) = @_;

	# don't try the copy + delete method for moving if rename was successful:
	if ($self->move_by_rename($FILES,$DEST)) {
		return;
	}

	$self->move_by_copy_delete($FILES,$DEST);
}

sub move_by_rename {
	my ($self,$FILES,$DEST) = @_;

	foreach my $source (@{$FILES}) {
		my $my_dest;

		if (dirname($DEST) eq File::Spec->curdir) {
			$my_dest = Filer::Tools->catpath(dirname($source), $DEST);
		} else {
			$my_dest = Filer::Tools->catpath($DEST, basename($source));
		}

		if (! rename($source,$my_dest)) {
			return $FALSE;
		}
	}

	return $TRUE;
}

sub move_by_copy_delete {
	my ($self,$FILES,$DEST) = @_;

	my $dirwalk  = new File::DirWalk;
	my $filecopy = new Filer::FileCopy($self);

	$dirwalk->onBeginWalk(sub {
		return (!$self->cancelled) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		my $file = $_[0];

		symlink(readlink($file), Filer::Tools->catpath($DEST, basename($file))) || return File::DirWalk::FAILED;
		unlink($file) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my $dir = $_[0];
		$DEST   = Filer::Tools->catpath($DEST, basename($dir));

		if (-e $DEST and $self->overwrite_all == $FALSE) {
		
			if ($self->skip_all == $TRUE) {
				return File::DirWalk::SUCCESS;
			}
	
			my ($response,$new_my_dest) = $self->show_file_exists_dialog($dir, $DEST);

			if ($response != File::DirWalk::SUCCESS) {
				return $response;				
			} else {
				$DEST = $new_my_dest;
			}
		}

		if (! -e $DEST) {
			mkdir($DEST) || return File::DirWalk::FAILED;
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		my $dir = $_[0];
		$DEST   = abs_path(Filer::Tools->catpath($DEST, $UPDIR));

		if ($self->skip_all == $TRUE) {
			return File::DirWalk::SUCCESS;
		}

		rmdir($dir) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $file = $_[0];
		my $my_dest = Filer::Tools->catpath($DEST, basename($file));

		if (-e $my_dest and $self->overwrite_all == $FALSE) {

			if ($self->skip_all == $TRUE) {
				return File::DirWalk::SUCCESS;
			}

			my ($response,$new_my_dest) = $self->show_file_exists_dialog($file, $my_dest);

			if ($response != File::DirWalk::SUCCESS) {
				return $response;				
			} else {
				$my_dest = $new_my_dest;
			}
		}

		if ((my $r = $filecopy->filecopy($file,$my_dest)) != File::DirWalk::SUCCESS) {
			return $r;
		}

		unlink($file) || return File::DirWalk::FAILED;

		$self->update_progress_label("$file\n$my_dest");

		return File::DirWalk::SUCCESS;
 	});

	$self->set_total(Filer::Tools->deep_count_bytes($FILES));
	$self->show_job_dialog;

	foreach my $source (@{$FILES}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_error("Moving of $source to " . $DEST . " failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Moving of $source to " . $DEST . " aborted!");
			last;
		}
	}

	$self->destroy_job_dialog;
}

1;
