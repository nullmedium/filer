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

package Filer::FilePaneDND;

use strict;
use warnings;

use Readonly; 

use Filer::Constants qw(:bool :filepane_columns);

Readonly my $TARGET_URI_LIST => 0;

sub target_table {
	{'target' => "text/uri-list", 'flags' => [], 'info' => $TARGET_URI_LIST};
}

# sub drag_begin {
# 	my $self = shift;
# 	my ($widget,$context) = @_;
# 
# 	$context->status('move',);
# }

sub drag_data_get {
	my $self = shift;
	my ($widget,$context,$data,$info,$time) = @_;

	if ($info == $TARGET_URI_LIST) {
		if ($self->count_items > 0) {
			my $d = join "\r\n", @{$self->get_uri_list};
			$data->set($data->target, 8, $d);
		}
	}

	return 1;
}

sub drag_data_received {
	my $self = shift;
	my ($widget,$context,$x,$y,$data,$info,$time) = @_;

	if (($data->length >= 0) && ($data->format == 8)) {
		my $action      = $context->action;
		my ($p)         = $widget->get_dest_row_at_pos($x,$y);
		my $path;

		my @items       = map {	
			$_ = Glib->filename_from_uri($_,"localhost");
		} split(/\r\n/, $data->data);

		my $items_count = scalar @items;

		if (defined $p) {
			$path = $self->get_path_by_treepath($p);
		}
		
		if (! $path) {
			$path = $self->get_pwd;
		}

		my $cfg = $self->{filer}->get_config;

		if (($cfg->get_option("ConfirmCopy") == $TRUE)
		 or ($cfg->get_option("ConfirmMove") == $TRUE)) {
			my $do = ($action eq "copy") ? "Copy" : "Move";

			if ($items_count == 1) {
				return if (Filer::Dialog->yesno_dialog("$do \"$items[0]\" to $path?") eq 'no');
			} else {
				return if (Filer::Dialog->yesno_dialog("$do $items_count files to $path?") eq 'no');
			}
		}
		
		if ($action eq "copy") {
			my $copy = Filer::Copy->new;
			$copy->copy(\@items,$path);

		} elsif ($action eq "move") {
			my $move = Filer::Move->new;
			$move->move(\@items,$path);
		}
	}

	$context->finish (0, 0, $time);

	$self->refresh;
}

# sub drag_motion {
# 	my $self = shift;
# 	my ($widget,$context,$x,$y,$time,$data) = @_;
# 	my $action = $context->action;
# 
# 	my ($p) = $widget->get_dest_row_at_pos($x,$y);
# 	my $path;
# 
# 	if (defined $p) {
# 		$path = $self->get_path_by_treepath($p);
# 
# 		if (-d $path) {
# 			$context->status('move',$time);
# 			return $TRUE;
# 		} else {
# 			$context->status([],$time);
# 			return $FALSE;
# 		}
# 	}
# 
# 	return $FALSE;
# }

1;
