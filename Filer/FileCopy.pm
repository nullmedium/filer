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

use File::Basename; 
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
	
	my @stat = stat($source); # || return File::DirWalk::FAILED;
	my $mode = $stat[2];
	my $size = $stat[7];
	my $buf_size = $stat[11]; # use filesystem blocksize
	my $buf = "";
	my $written = 0;
	my $written_avg = 0;
	my $percent_written = 0;
	my $size_h = &Filer::FilePane::calculate_size($size);

	my $id = Glib::Timeout->add(1000, sub {
		return 0 if ($written_avg == 0);
		
		my $p = sprintf("%.0f", $percent_written * 100);
		my $str = "$p% of $size_h (" .  &Filer::FilePane::calculate_size($written_avg) . "/s)"; 
  
		$self->[PROGRESSBAR]->get_parent_window->set_title($str);
		$self->[PROGRESSBAR]->set_text($str);

		$written_avg = 0;

		return 1;
	});

	sysopen(SOURCE, $source, O_RDONLY);
	sysopen(DEST, $dest, O_CREAT|O_WRONLY|O_TRUNC);

	while (sysread(SOURCE, $buf, $buf_size)) {
		syswrite DEST, $buf, $buf_size;

		return File::DirWalk::ABORTED if (${$self->[STOPPED]} == STOP);

		my $l = length($buf);
		$written += $l;
		$written_avg += $l;
		$percent_written = $written/$size; 

		$self->[PROGRESSBAR]->set_fraction($percent_written);
		while (Gtk2->events_pending) { Gtk2->main_iteration; }
	}

	close(SOURCE);
	close(DEST);

	chmod $mode, $dest || return File::DirWalk::FAILED;

	Glib::Source->remove($id);

	return File::DirWalk::SUCCESS;
}

1;
