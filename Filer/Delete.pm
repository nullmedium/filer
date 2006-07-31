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

package Filer::Delete;
use base qw(Filer::DeleteJobDialog);

use strict;
use warnings;

use File::Basename;

use Filer::Constants;

use English;


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();

	return $self;
}

sub deep_count_files {
	my ($self,$files) = @_;

	for (@{$files}) {
		my $fi = Filer::FileInfo->new($_);
		$self->set_total_files($self->total_files + $fi->deep_count_files);
	}
}

sub delete {
	my ($self,$files) = @_;

	$self->deep_count_files($files);

	my $dirwalk = new File::DirWalk;

	$dirwalk->onBeginWalk(sub {
		return (!$self->cancelled) ? File::DirWalk::SUCCESS : File::DirWalk::ABORTED;
	});

	$dirwalk->onLink(sub {
		unlink($ARG[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onDirLeave(sub {
		rmdir($ARG[0]) || return File::DirWalk::FAILED;
		return File::DirWalk::SUCCESS;
	});

	$dirwalk->onFile(sub {
		unlink($ARG[0]) || return File::DirWalk::FAILED;

		$self->update_progress_label($ARG[0]);
		$self->set_deleted_files($self->deleted_files + 1);

		return File::DirWalk::SUCCESS;
	});

	$self->show_job_dialog;

	foreach my $source (@{$files}) {
		my $r = $dirwalk->walk($source);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_info("Deleting of $source failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Deleting of $source aborted!");
			last;
		}
	}

	$self->destroy_job_dialog;
}

1;
