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
use base qw(Filer::CopyJobDialog);

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname basename);
use File::DirWalk;

use Filer::Constants;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	
	return $self;
}

sub copy {
	my ($self,$FILES,$DEST) = @_;

	my $dirwalk  = new File::DirWalk;
	my $filecopy = new Filer::FileCopy($self);

	$dirwalk->onBeginWalk(sub {
		return (!$self->cancelled) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		my $file = pop;
		symlink(readlink($file), Filer::Tools->catpath($DEST, basename($file))) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirEnter(sub {
		my $dir = pop;
		$DEST   = Filer::Tools->catpath($DEST, basename($dir));

		if ((-e $DEST) and (dirname($dir) eq dirname($DEST))) {
			$DEST = Filer::Tools->suggest_filename_helper($DEST);
		}

		mkdir($DEST) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		$DEST = abs_path(Filer::Tools->catpath($DEST, $UPDIR));
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $file    = pop;
		my $my_dest = Filer::Tools->catpath($DEST, basename($file));

		if (-e $my_dest) {
			if ($self->skip_all == $TRUE) {
				return File::DirWalk::SUCCESS;
			}

			if (dirname($file) eq dirname($my_dest)) {

				$my_dest = Filer::Tools->suggest_filename_helper($my_dest);

			} else {
				my $dialog = Filer::FileExistsDialog->new($file, $my_dest);
				my $r = $dialog->show;
				
				if ($r == $Filer::FileExistsDialog::RENAME) {

					$my_dest = $dialog->get_suggested_filename;
					
				} elsif ($r == $Filer::FileExistsDialog::OVERWRITE) {

					# do nothing. 
				
				} elsif ($r == $Filer::FileExistsDialog::SKIP) {

					$dialog->destroy;
					return File::DirWalk::SUCCESS;

				} elsif ($r == $Filer::FileExistsDialog::SKIP_ALL) {

					# next time we encounter en existing file, return SUCCESS. 
					$self->set_skip_all($TRUE);
					$dialog->destroy;
					return File::DirWalk::SUCCESS;

				} elsif ($r eq 'cancel') {

					$dialog->destroy;
					return File::DirWalk::ABORTED;
				}
				
				$dialog->destroy;
			}
		}

		$self->update_progress_label("$file\n$my_dest");
 		return $filecopy->filecopy($file,$my_dest);
 	});

	$self->set_total_bytes(Filer::Tools->deep_count_bytes($FILES));
	$self->show_job_dialog;

	foreach my $source (@{$FILES}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_error("Copying of $source to $DEST failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Copying of $source to $DEST aborted!");
			last;
		}
	}

	$self->destroy_job_dialog;
}

*action = \&copy;

1;
