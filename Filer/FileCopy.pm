#     Copyright (C) 2004 Jens Luedicke <jens@irs-net.com>
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

sub new {
	my ($class,$progressbar,$stop_ref) = @_;
	my $self = bless {}, $class;

	$self->{progressbar} = $progressbar;
	$self->{stopped} = $stop_ref;

	return $self;
}

sub filecopy {
	my ($self,$source,$dest) = @_;

	my $mode = (stat $source)[2] || return Filer::DirWalk::FAILED;
	my $size = -s $source;
	my $buf;
	my $buf_size = (stat $source)[11] || return Filer::DirWalk::FAILED; # use filesystem blocksize
	my $written = 0;

	sysopen(SOURCE, $source, O_RDONLY) || return Filer::DirWalk::FAILED;
	sysopen(DEST, $dest, O_CREAT|O_WRONLY) || return Filer::DirWalk::FAILED;

	while (sysread(SOURCE, $buf, $buf_size)) {
		syswrite DEST, $buf, $buf_size;

		return Filer::DirWalk::ABORTED  if (!${$self->{stopped}});

		my $c = $written + $buf_size;

		if ($c < $size) {

			$written = $c;

		} elsif ($c > $size) {

			$written += ($size % $buf_size);
		}

		$self->{progressbar}->set_fraction($written/$size);
		while (Gtk2->events_pending) { Gtk2->main_iteration; }
	}

	close(SOURCE);
	close(DEST);

	chmod $mode, $dest;

	return 1;
}

1;
