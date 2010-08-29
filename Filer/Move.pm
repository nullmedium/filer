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

use strict;
use warnings;

use Fcntl;
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);

use Filer::Constants qw(:filer);

sub move {
	my ($FILES,$DEST) = @_;
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
	    my $confirm = Filer::Config->instance()->get_option("ConfirmMove");
	    
		if ($confirm) {
		    my $answer = Filer::Dialog->show_yesno_dialog("Move $items_count files to $DEST?");
		    
			if ($answer eq 'no') {
			    return;
			}
		}
	}

	_move($FILES,$DEST);
}

sub _move {
	my ($FILES,$DEST) = @_;

	# don't try the copy + delete method for moving if rename was successful:
	if (move_by_rename($FILES,$DEST)) {
		return;
	}

	move_by_copy_delete($FILES,$DEST);
}

sub move_by_rename {
	my ($FILES,$DEST) = @_;

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
	my ($FILES,$DEST) = @_;

	my $job_dialog = Filer::JobDialog->new("Moving ...","<b>Moving: \nto: </b>");
	my $dirwalk  = File::DirWalk->new;
	my $filecopy = Filer::FileCopy->new($job_dialog);

	$dirwalk->onBeginWalk(sub {
		if (! $job_dialog->cancelled) {
		  return File::DirWalk::SUCCESS;  
		} else {
		  return File::DirWalk::ABORTED;
		}
	});

	$dirwalk->onLink(sub {
		my $file = shift;

		symlink(readlink($file), Filer::Tools->catpath($DEST, basename($file))) || return File::DirWalk::FAILED;
		unlink($file) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my $dir = shift;
		$DEST   = Filer::Tools->catpath($DEST, basename($dir));

		if ((-e $DEST) and (! $job_dialog->overwrite_all)) {
		
			if ($job_dialog->skip_all) {
				return File::DirWalk::SUCCESS;
			}
	
			my ($response,$new_my_dest) = $job_dialog->show_file_exists_dialog($dir, $DEST);

			if ($response == File::DirWalk::SUCCESS) {
				$DEST = $new_my_dest;
			} else {
				return $response;				
			}
		}

		if (! -e $DEST) {
			mkdir($DEST) || return File::DirWalk::FAILED;
		}

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		my $dir = shift;
		$DEST   = abs_path(Filer::Tools->catpath($DEST, $UPDIR));

		if ($job_dialog->skip_all) {
			return File::DirWalk::SUCCESS;
		}

		rmdir($dir) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $file = shift;
		my $my_dest = Filer::Tools->catpath($DEST, basename($file));

		if (-e $my_dest and (! $job_dialog->overwrite_all)) {

			if ($job_dialog->skip_all == $TRUE) {
				return File::DirWalk::SUCCESS;
			}

			my ($response,$new_my_dest) = $job_dialog->show_file_exists_dialog($file, $my_dest);

			if ($response == File::DirWalk::SUCCESS) {
				$my_dest = $new_my_dest;
			} else {
				return $response;				
			}
		}

        my $r = $filecopy->filecopy($file,$my_dest);
        
		if ($r != File::DirWalk::SUCCESS) {
			return $r;
		}

		unlink($file) || return File::DirWalk::FAILED;

		$job_dialog->update_progress_label("$file\n$my_dest");

		return File::DirWalk::SUCCESS;
 	});

	$job_dialog->set_total(Filer::Tools->deep_count_bytes($FILES));
	$job_dialog->show_all;

	foreach my $source (@{$FILES}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->show_error_message("Moving of $source to " . $DEST . " failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->show_information("Moving of $source to " . $DEST . " aborted!");
			last;
		}
	}

	$job_dialog->destroy;
}

1;