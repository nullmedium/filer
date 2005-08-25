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

use Readonly; 

Readonly my $TARGET_URI_LIST => 0;

sub new {
	my ($class,$filer,$filepane) = @_;
	my $self = bless {}, $class;
	$self->{filer} = $filer;
	$self->{filepane} = $filepane;

	return $self;
}

sub target_table {
	my ($self) = @_;
	return ({'target' => "text/uri-list", 'flags' => [], 'info' => $TARGET_URI_LIST});
}

sub filepane_treeview_drag_data_get {
	my ($self,$widget,$context,$data,$info,$time) = @_;

	if ($info == $TARGET_URI_LIST) {
		if ($self->{filepane}->count_items > 0) {
			my $d = join "\r\n", @{$self->{filepane}->get_items};
			$data->set($data->target, 8, $d);
		}
	}
}

sub filepane_treeview_drag_data_received {
	my ($self,$widget,$context,$x,$y,$data,$info,$time) = @_;

	if (($data->length >= 0) && ($data->format == 8)) {
		my ($p)    = $widget->get_dest_row_at_pos($x,$y);
		my $action = $context->action;
		my $path;
		my $do;

		if (defined $p) {
			$path = $self->{filepane}->get_path_by_treepath($p);
		} else {
			$path = $self->{filepane}->get_pwd;
		}

 		if (! -d $path) {
			$path = $self->{filepane}->get_pwd;
		}

#		print $self->{filer}->get_active_pane->get_pwd, " <=> ", $path, "\n";

#		if ($self->{filer}->get_active_pane->get_pwd ne $path) {
			if ($action eq "copy") {
				if ($self->{filer}->get_config->get_option("ConfirmCopy") == 1) {
					if ($self->{filer}->get_active_pane->count_items == 1) {
						my $f = $self->{filer}->get_active_pane->get_fileinfo->[0]->get_basename;
						$f =~ s/&/&amp;/g; # sick fix. meh.

						return if (Filer::Dialog->yesno_dialog("Copy $f to $path?") eq 'no');
					} else {
						return if (Filer::Dialog->yesno_dialog(sprintf("Copy %s files to $path?", $self->{filer}->get_active_pane->count_items)) eq 'no');
					}
				}

				$do = new Filer::Copy;
			} elsif ($action eq "move") {
				if ($self->{filer}->get_config->get_option("ConfirmMove") == 1) {
					if ($self->{filer}->get_active_pane->count_items == 1) {
						my $f = $self->{filer}->get_active_pane->get_fileinfo->[0]->get_basename;
						$f =~ s/&/&amp;/g; # sick fix. meh.

						return if (Filer::Dialog->yesno_dialog("Move $f to $path?") eq 'no');
					} else {
						return if (Filer::Dialog->yesno_dialog(sprintf("Move %s files to $path?", $self->{filer}->get_active_pane->count_items)) eq 'no');
					}
				}

				$do = new Filer::Move;
			}

			my @files = split /\r\n/, $data->data;

			$do->action(\@files,$path);

# # 			if ($action eq "move") {
# # 				$self->{filer}->get_active_pane->remove_selected;
# # 			}
# # 
# # 			$self->{filer}->refresh_inactive_pane;
# 			
# 			$self->{filer}->refresh_cb;

			$self->{filepane}->refresh;			
			
			$context->finish (1, 0, $time);
# 			return;
# 		}
# 
#  		$context->finish (0, 0, $time);
	}

	$context->finish (0, 0, $time);
}

1;
