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

package Filer::DND;

use strict;
use warnings;
use File::Basename;

use constant TARGET_URI_LIST => 0;

sub target_table {
	return ({'target' => "text/uri-list", 'flags' => [], 'info' => TARGET_URI_LIST});
}

sub filepane_treeview_drag_begin_cb {
	my ($widget, $context) = @_;

	return 1;
}

sub filepane_treeview_drag_data_get_cb {
	my ($widget,$context,$data,$info,$time,$self) = @_;

	if ($info == TARGET_URI_LIST) {
		if ($self->count_selected_items > 0) {
			my $d = join "\r\n", @{$self->get_selected_items};
			$data->set($data->target, 8, $d);
		}
	}
}

sub filepane_treeview_drag_data_received_cb {
	my ($widget,$context,$x,$y,$data,$info,$time,$self) = @_;

	if (($data->length >= 0) && ($data->format == 8)) {
		my ($p) = $widget->get_dest_row_at_pos($x,$y);
		my $action = $context->action;
		my $path;
		my $do;

		if (defined $p) {
			$path = $self->get_path_by_treepath($p);
		} else {
			$path = $self->get_pwd;
		}

 		if (! -d $path) {
			$path = $self->get_pwd;
		}

		if ($main::active_pane->get_pwd ne $path) {

			if ($action eq "copy") {
				if ($main::config->get_option("ConfirmCopy") == 1) {
					if ($main::active_pane->count_selected_items == 1) {
						return if (Filer::Dialog->yesno_dialog(sprintf("Copy %s to $path?", basename($main::active_pane->get_selected_item))) eq 'no');
					} else {
						return if (Filer::Dialog->yesno_dialog(sprintf("Copy %s files to $path?", $main::active_pane->count_selected_items)) eq 'no');
					}
				}

				$do = Filer::Copy->new;
			} elsif ($action eq "move") {
				if ($main::config->get_option("ConfirmMove") == 1) {
					if ($main::active_pane->count_selected_items == 1) {
						return if (Filer::Dialog->yesno_dialog(sprintf("Move %s to $path?", basename($main::active_pane->get_selected_item))) eq 'no');
					} else {
						return if (Filer::Dialog->yesno_dialog(sprintf("Move %s files to $path?", $main::active_pane->count_selected_items)) eq 'no');
					}
				}

				$do = Filer::Move->new;
			}

			$do->set_total(&main::files_count);
			$do->show;

			for (split /\r\n/, $data->data) {
				$_ =~ s/file:\/\///g;

				last if ($_ eq $path);

				my $r = $do->action($_, $path);

				if ($r == File::DirWalk::FAILED) {
					Filer::Dialog->msgbox_info("Copying of $_ to $path failed!");
					last;
				} elsif ($r == File::DirWalk::ABORTED) {
					Filer::Dialog->msgbox_info("Moving of $_ to $path aborted!");
					last;
				}
			}

			$do->destroy;

			if ($action eq "move") {
				$main::active_pane->remove_selected;
			}

			&main::refresh_inactive_pane;

			$context->finish (1, 0, $time);
			return;
		}

 		$context->finish (0, 0, $time);
	}
}

1;
