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

package Filer::Delete;

use strict;
use warnings;

use File::Basename;

use Filer::Constants qw(:bool);

sub delete {
	my ($FILES) = @_;

    my $confirm = Filer::Config->instance()->get_option("ConfirmDelete");

	if ($confirm) {
    	my $items_count = scalar @{$FILES};

		my $message =
		 ($items_count == 1)
		 ? "Delete \"$FILES->[0]\"?"
		 : "Delete $items_count selected files?";

        my $answer = Filer::Dialog->show_yesno_dialog($message);

		if ($answer eq 'no') {
		    return;
		}
	}

	_delete($FILES);
}

sub _delete {
	my ($FILES) = @_;

    my $job_dialog = Filer::JobDialog->new("Deleting ...","<b>Deleting:</b> ");
	my $dirwalk = File::DirWalk->new;

	$dirwalk->onBeginWalk(sub {
		if (! $job_dialog->cancelled) {
		  return File::DirWalk::SUCCESS;  
		} else {
		  return File::DirWalk::ABORTED;
		}
	});

	$dirwalk->onLink(sub {
        my $file = shift;
		unlink($file) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
        my $dir = shift;
		rmdir($dir) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
	    my $file = shift;
		unlink($file) || return File::DirWalk::FAILED;

		$job_dialog->update_progress_label($file);
		$job_dialog->set_completed($job_dialog->get_completed + 1);

		return File::DirWalk::SUCCESS;
	});

	$job_dialog->set_total(Filer::Tools->deep_count_files($FILES));
	$job_dialog->show_all;

	foreach my $source (@{$FILES}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->show_information("Deleting of $source failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->show_information("Deleting of $source aborted!");
			last;
		}
	}

	$job_dialog->destroy;
}

1;
