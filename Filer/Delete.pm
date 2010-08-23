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
use base qw(Filer::DeleteJobDialog);

use strict;
use warnings;

use File::Basename;

use Filer::Constants qw(:bool);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	return $self;
}

sub delete {
	my ($self,$FILES) = @_;

	my $items_count = scalar @{$FILES};

	if (Filer::Config->instance()->get_option("ConfirmDelete") == $TRUE) {
		my $message =
		 ($items_count == 1)
		 ? "Delete \"$FILES->[0]\"?"
		 : "Delete $items_count selected files?";

		return if (Filer::Dialog->show_yesno_dialog($message) eq 'no');
	}

	$self->_delete($FILES);
}

sub _delete {
	my ($self,$FILES) = @_;

	my $dirwalk = new File::DirWalk;

	$dirwalk->onBeginWalk(sub {
		return (!$self->cancelled) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		unlink($_[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		rmdir($_[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		unlink($_[0]) || return File::DirWalk::FAILED;

		$self->update_progress_label($_[0]);
		$self->set_completed($self->get_completed + 1);

		return File::DirWalk::SUCCESS;
	});

	$self->set_total(Filer::Tools->deep_count_files($FILES));
	$self->show_job_dialog;

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

	$self->destroy_job_dialog;
}

1;
