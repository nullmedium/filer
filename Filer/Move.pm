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
use base qw(Filer::MoveJobDialog);
use Class::Std::Utils;

use strict;
use warnings;

use Fcntl;
use Cwd qw(abs_path);
use File::Basename qw(dirname basename);

use Filer::Constants;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	return $self;
}

sub DESTROY {
	my ($self) = @_;
}

sub move {
	my ($self,$FILES,$DEST) = @_;

	# don't try the copy + delete method for moving if rename was successful:
	if ($self->move_by_rename($FILES,$DEST)) {
		return;
	}

	$self->move_by_copy_delete($FILES,$DEST);
}

*action = \&move;

sub move_by_rename {
	my ($self,$FILES,$DEST) = @_;

	foreach my $source (@{$FILES}) {
		my $my_dest = Filer::Tools->catpath($DEST, basename($source));

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

	for (@{$FILES}) {
		my $fi = Filer::FileInfo->new($_);
		$self->set_total_bytes($self->total_bytes + $fi->deep_count_bytes);
	}

	$dirwalk->onBeginWalk(sub {
		return (!$self->cancelled) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		my $file = pop;

		symlink(readlink($file), Filer::Tools->catpath($DEST, basename($file))) || return File::DirWalk::FAILED;
		unlink($file) || return File::DirWalk::FAILED;

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
		my $dir = pop;
		$DEST   = abs_path(Filer::Tools->catpath($DEST, $UPDIR));

		rmdir($dir) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		my $file = pop;
		my $my_dest = Filer::Tools->catpath($DEST, basename($file));

		if (-e $my_dest) {
			if (dirname($file) eq dirname($my_dest)) {

				$my_dest = Filer::Tools->suggest_filename_helper($my_dest);

			} else {
				# TODO: Ask Overwrite Dialog

				Filer::Dialog->msgbox_error("File $file exists at $my_dest!\n");
				return File::DirWalk::ABORTED;
			}
		}

		if ((my $r = $filecopy->filecopy($file,$my_dest)) != File::DirWalk::SUCCESS) {
			return $r;
		}

		unlink($file) || return File::DirWalk::FAILED;

		return File::DirWalk::SUCCESS;
 	});

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
