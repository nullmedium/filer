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

package Filer::FileCopy;

use strict;
use warnings;

use Fcntl;

sub filecopy {
	my ($job,$source,$dest) = @_;

	return if ($source eq $dest);

	my @stat     = stat($source);
	my $mode     = $stat[2];
	my $buf_size = 4 * $stat[11];
	my $buf      = "";

	sysopen(my $in_fh, $source, O_RDONLY);
	sysopen(my $out_fh, $dest, O_CREAT|O_WRONLY|O_TRUNC, $mode);

	my ($r,$w,$t);

	while (($r = sysread($in_fh, $buf, $buf_size)) && !$job->cancelled) {

		for ($w = 0; $w < $r; $w += $t) {
			$t = syswrite($out_fh, $buf, $r - $w, $w)
				or return File::DirWalk::FAILED;

			$job->set_completed($job->get_completed + $t);
		}
	}

	close($in_fh) || return File::DirWalk::FAILED;
	close($out_fh) || return File::DirWalk::FAILED;

	return File::DirWalk::SUCCESS;
}

1;
