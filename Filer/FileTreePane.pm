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

package Filer::FileTreePane;
use base qw(Filer::FilePaneInterface);

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename;

use Filer::Constants qw(:filer :filepane_columns);

sub new {
	my ($class,$filer,$side) = @_;
	my $self = $class->SUPER::new($filer,$side);
	$self = bless $self, $class;

	my $hbox = Gtk2::HBox->new(0,0);
	$self->{vbox}->pack_start($hbox, 0, 1, 0);

	$self->{treemodel} = Gtk2::TreeStore->new(qw(Glib::Scalar Glib::Object Glib::String));
	$self->{treeview}  = Gtk2::TreeView->new($self->{treemodel});

	$self->{treeview}->set_rules_hint($TRUE);
	$self->{treeview}->set_headers_visible($FALSE);
	$self->{treeview}->signal_connect("grab-focus", sub { $self->treeview_grab_focus_cb(@_) });
	$self->{treeview}->signal_connect("event", sub { $self->treeview_event_cb(@_) });
	$self->{treeview}->signal_connect("row-expanded", sub { $self->treeview_row_expanded_cb(@_) });
	$self->{treeview}->signal_connect("row-collapsed", sub { $self->treeview_row_collapsed_cb(@_) });

	# Drag and Drop
	$self->{treeview}->drag_dest_set('all', ['move','copy'], $self->target_table);
	$self->{treeview}->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $self->target_table);
	$self->{treeview}->signal_connect("drag_data_get", sub { $self->drag_data_get(@_) });
#	$self->{treeview}->signal_connect("drag_motion", sub { $self->drag_motion(@_) });
	$self->{treeview}->signal_connect("drag_data_received", sub { $self->drag_data_received(@_) });

	$self->{treeselection} = $self->{treeview}->get_selection;
	$self->{treeselection}->set_mode("single");

	my $scrolled_window = Gtk2::ScrolledWindow->new;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$scrolled_window->add($self->{treeview});
	$self->{vbox}->pack_start($scrolled_window, 1, 1, 0);

	# a column with a pixbuf renderer and a text renderer
	my $col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	my $cell0 = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell0, 0);
	$col->add_attribute($cell0, pixbuf => $COL_ICON);

	my $cell1 = Gtk2::CellRendererText->new;
	$col->pack_start($cell1, 1);
	$col->add_attribute($cell1, text => $COL_NAME);

	$self->{treeview}->append_column($col);

	$self->CreateRootNodes();

	return $self;
}

sub get_type {
	my ($self) = @_;
	return "TREE";
}

sub show_popup_menu {
	my ($self,$e) = @_;

	my ($p) = $self->{treeview}->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $self->{treeselection}->path_is_selected($p)) {
			$self->{treeselection}->select_path($p);
		}

		my $uimanager = $self->{filer}->get_uimanager;
		my $ui_path   = '/ui/list-popupmenu';

		my $popup_menu = $uimanager->get_widget($ui_path);

# 		$uimanager->get_widget("$ui_path/PopupItems1/Rename")->set_sensitive($TRUE);
		$uimanager->get_widget("$ui_path/PopupItems1/Delete")->set_sensitive($TRUE);
# 		$uimanager->get_widget("$ui_path/PopupItems1/Cut")->set_sensitive($TRUE);
# 		$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive($TRUE);
# 		$uimanager->get_widget("$ui_path/PopupItems1/Paste")->set_sensitive($TRUE);
		$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive($TRUE);
		$uimanager->get_widget("$ui_path/PopupItems1/Move")->set_sensitive($TRUE);
		$uimanager->get_widget("$ui_path/Properties")->set_sensitive($TRUE);

		$uimanager->get_widget("$ui_path/PopupItems1/Open")->hide;
		$uimanager->get_widget("$ui_path/PopupItems1/Open With")->hide;

		my $bookmarks = Filer::Bookmarks->new($self->{filer});
		$uimanager->get_widget("$ui_path/Bookmarks")->set_submenu($bookmarks->generate_bookmarks_menu);

		$popup_menu->show_all;
		$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
	}
}

sub treeview_event_cb {
	my ($self,$w,$e,$d) = @_;

	if ($e->type eq "key-press") {
		if ($e->keyval == $Gtk2::Gdk::Keysyms{'Return'}) {

			my $iter = $self->get_iter_list->[0];
			my $p    = $self->{treemodel}->get_path($iter);
		
			$self->row_action($p);
			return 1;

		} elsif ($e->keyval == $Gtk2::Gdk::Keysyms{'Delete'}) {

			$self->{filer}->delete_cb;
			return 1;
		}
	}

	if ($e->type eq "button-press") {
		if ($e->button == 1) {
			my ($p) = $self->{treeview}->get_path_at_pos($e->x,$e->y);

			if (defined $p) {
 				$self->{treeselection}->select_path($p);

# 				my $pane = $self->{filer}->get_right_pane;
# 				my $iter = $self->{treemodel}->get_iter($p);
# 				my $fi   = $self->get_fileinfo($iter);
# 
# 				$pane->open_path($fi->get_path);
			}

		} elsif ($e->button == 3) {

			$self->set_focus;
			$self->show_popup_menu($e);
			return 1;
		}
	}

	if ($e->type eq "2button-press" and $e->button == 1) {
		my ($p) = $self->{treeview}->get_path_at_pos($e->x,$e->y);
		
		if (defined $p) {
			$self->row_action($p);
			return 1;
		}
	}

	return 0;
}

sub row_action {
	my ($self,$treepath) = @_;

	if ($self->{treeview}->row_expanded($treepath)) {
		$self->{treeview}->collapse_row($treepath);
	} else {
		$self->{treeview}->expand_row($treepath,0);
	}

	return 1;
}

sub treeview_row_expanded_cb {
	my ($self,$treeview,$iter,$path) = @_;

	my $fi = $self->get_fileinfo($iter);
	$self->DirRead($fi->get_path,$iter);

	return 1;
}

sub treeview_row_collapsed_cb {
	my ($self,$treeview,$iter,$path) = @_;

	while (my $i = $self->{treemodel}->iter_children($iter)) {
		$self->{treemodel}->remove($i);
	}

	$self->{treemodel}->append($iter);

	return 1;
}

sub get_pwd {
	my ($self) = @_;
	return $self->get_item_list->[0];
}

sub get_updir {
	my ($self) = @_;
	return abs_path(Filer::Tools->catpath($self->get_pwd, $UPDIR));
}

sub refresh {
	my ($self) = @_;
	my $iter   = $self->get_iter_list->[0];

	if (defined $iter) {
		my $path = $self->{treemodel}->get_path($iter);

		if ($self->{treeview}->row_expanded($path)) {
			$self->{treeview}->collapse_row($path);
			$self->{treeview}->expand_row($path, 2);
		}
	}
}

sub CreateRootNodes {
	my ($self) = @_;

	foreach (Filer::FileInfo->get_rootdir, Filer::FileInfo->get_homedir) {
		my $iter = $self->{treemodel}->insert_with_values(undef, -1,
			$COL_FILEINFO, $_,
			$COL_ICON,     $_->get_mimetype_icon,
			$COL_NAME,     $_->get_basename, # eq $ROOTDIR) ? "Filesystem" : "Home",
		);

		$self->{treemodel}->insert($iter, -1);
	}
}

sub DirRead {
	my ($self,$dir,$parent_iter) = @_;

	$self->{directory} = Filer::Directory->new($dir);

	my $dir_contents = $self->{directory}->all_dirs;

	foreach my $fi (sort { $a->get_basename cmp $b->get_basename } @{$dir_contents}) {
		next if (($self->{ShowHiddenFiles} == $FALSE) && $fi->is_hidden);
	
		my $icon     = $fi->get_mimetype_icon;
		my $basename = $fi->get_basename;

		my $iter = $self->{treemodel}->insert_with_values($parent_iter, -1,
			$COL_FILEINFO, $fi,
 			$COL_ICON,     $icon,
			$COL_NAME,     $basename,
		);

		$self->{treemodel}->insert($iter, -1) if ($fi->is_readable);
	}

	my $dummy_iter = $self->{treemodel}->iter_nth_child($parent_iter, 0);
	$self->{treemodel}->remove($dummy_iter); # remove dummy iter
}

1;
