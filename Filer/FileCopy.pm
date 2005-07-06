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

package Filer::FileCopy;

use strict;
use warnings;

use Fcntl;

use constant PROGRESSBAR => 0;
use constant STOPPED => 1;

use constant STOP => 0;

sub new {
	my ($class,$progressbar,$stop_ref) = @_;
	my $self = bless [], $class;

	$self->[PROGRESSBAR] = $progressbar;
	$self->[STOPPED] = $stop_ref;

	$self->[PROGRESSBAR]->set_text(" ");

	return $self;
}

sub filecopy {
	my ($self,$source,$dest) = @_;
	my $return_overwrite_all = 0;
	
	if (File::Basename::dirname($source) eq File::Basename::dirname($dest)) {
		my $i = 1;
		while (1) {
			if (-e "$dest-$i") {
				$i++;
			} else {
				$dest = "$dest-$i";
				last;
			}
		}
	}

	if (-e $dest) {
		if ($main::SKIP_ALL) {
			return File::DirWalk::SUCCESS;
		}
		
		if (!$main::OVERWRITE_ALL) {
			my $r = Filer::Dialog->ask_overwrite_dialog("Overwrite", "Overwrite: <b>$dest</b>\nwith: <b>$source</b>");

			if ($r eq 'no') {
				return File::DirWalk::SUCCESS;
			} elsif ($r == 1) {
				$return_overwrite_all = 1;
			} elsif ($r == 2) {
				$main::SKIP_ALL = 1;
				return File::DirWalk::SUCCESS;
			}
		}
	}

	my @stat = stat $source;
	my $mode = $stat[2] || return File::DirWalk::FAILED;
	my $size = $stat[7];
	my $buf;
	my $buf_size = $stat[11] || return File::DirWalk::FAILED; # use filesystem blocksize
	my $written = 0;
	my $written_avg = 0;

	my $id = Glib::Timeout->add(1000, sub {
		return 0 if ($written_avg == 0);

		$self->[PROGRESSBAR]->set_text(&Filer::FilePane::calculate_size($written_avg) . "/s");
		$written_avg = 0;

		return 1;
	});

	sysopen(SOURCE, $source, O_RDONLY) || return File::DirWalk::FAILED;
	sysopen(DEST, $dest, O_CREAT|O_WRONLY) || return File::DirWalk::FAILED;

	while (sysread(SOURCE, $buf, $buf_size)) {
		syswrite DEST, $buf, $buf_size;

		return File::DirWalk::ABORTED if (${$self->[STOPPED]} == STOP);

		my $l = length($buf);
		$written += $l;
		$written_avg += $l;

		$self->[PROGRESSBAR]->set_fraction($written/$size);
		while (Gtk2->events_pending) { Gtk2->main_iteration; }
	}

	Glib::Source->remove($id);

	close(SOURCE);
	close(DEST);

	chmod $mode, $dest;

	if ($return_overwrite_all) {
		$main::OVERWRITE_ALL = 1;
		return File::DirWalk::SUCCESS;
	}

	return 1;
}

1;
