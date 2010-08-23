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

package Filer::Copy;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use File::DirWalk;

use Filer::Constants qw(:filer);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	return $self;
}

sub copy {
	my ($self,$FILES,$DEST) = @_;
	my $items_count = scalar @{$FILES};

	if ($items_count == 1) {
		my $dialog = Filer::SourceTargetDialog->new("Copy");

		my $label = $dialog->get_source_label;
		$label->set_markup("<b>Copy: </b>");

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
		if (Filer::instance()->get_config->get_option("ConfirmCopy") == $TRUE) {
			return if (Filer::Dialog->show_yesno_dialog("Copy $items_count files to $DEST?") eq 'no');
		}
	}

	$self->_copy($FILES,$DEST);
	Filer::instance()->refresh_cb;
}

sub _copy {
	my ($self,$FILES,$DEST) = @_;

	my $dirwalk  = new File::DirWalk;
	my $filecopy = new Filer::FileCopy($self);

	$dirwalk->onBeginWalk(sub {
		return (!$self->cancelled) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		my $file = $_[0];
		symlink(readlink($file), Filer::Tools->catpath($DEST, basename($file))) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my $dir = $_[0];

		if (dirname($DEST) eq File::Spec->curdir) {
			$DEST = Filer::Tools->catpath(dirname($dir), $DEST);
		} else {
			$DEST = Filer::Tools->catpath($DEST, basename($dir));
		}

		if (-e $DEST and $self->overwrite_all == $FALSE) {
		
			if ($self->skip_all == $TRUE) {
				return File::DirWalk::SUCCESS;
			}

			if (dirname($dir) eq dirname($DEST)) {
				$DEST = Filer::Tools->suggest_filename_helper($DEST);

			} else {
				my ($response,$new_my_dest) = $self->show_file_exists_dialog($dir, $DEST);

				if ($response != File::DirWalk::SUCCESS) {
					return $response;				
				} else {
					$DEST = $new_my_dest;
				}
			}
		}

		if (! -e $DEST) {
			mkdir($DEST) || return File::DirWalk::FAILED;
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		$DEST = abs_path(Filer::Tools->catpath($DEST, $UPDIR));
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $file    = $_[0];
		my $my_dest;
		
		if (dirname($DEST) eq File::Spec->curdir) {
			$my_dest = Filer::Tools->catpath(dirname($file), $DEST);
		} else {
			$my_dest = Filer::Tools->catpath($DEST, basename($file));
		}

		if (! -d dirname($my_dest)) {
			$my_dest = $DEST;
		}

		if (-e $my_dest and $self->overwrite_all == $FALSE) {

			if ($self->skip_all == $TRUE) {
				return File::DirWalk::SUCCESS;
			}

			if (dirname($file) eq dirname($my_dest)) {

				$my_dest = Filer::Tools->suggest_filename_helper($my_dest);

			} else {
				my ($response,$new_my_dest) = $self->show_file_exists_dialog($file, $my_dest);

				if ($response != File::DirWalk::SUCCESS) {
					return $response;				
				} else {
					$my_dest = $new_my_dest;
				}
			}
		}

		$self->update_progress_label("$file\n$my_dest");

 		return $filecopy->filecopy($file,$my_dest);
 	});

	$self->set_total(Filer::Tools->deep_count_bytes($FILES));
	$self->show_job_dialog;

	foreach my $source (@{$FILES}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->show_error_message("Copying of $source to $DEST failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->show_information("Copying of $source to $DEST aborted!");
			last;
		}
	}

	$self->destroy_job_dialog;
}

1;
