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
use Class::Std::Utils;

use Filer::FilePaneInterface;

require Exporter;
our @ISA = qw(Exporter Filer::FilePaneInterface);

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename;

use Filer::Constants;
use Filer::DND;

# attributes:
# all attributes are imported by Filer::FilePaneInterface

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless anon_scalar(), $class;

	$filer{ident $self}               = $filer;
	$side{ident $self}                = $side;
	$mouse_motion_select{ident $self} = $FALSE;

	$vbox{ident $self} = new Gtk2::VBox(0,0);
	$vbox{ident $self}->set_size_request(200,0);

	my $hbox = new Gtk2::HBox(0,0);
	$vbox{ident $self}->pack_start($hbox, 0, 1, 0);

	$treemodel{ident $self} = new Gtk2::TreeStore(qw(Glib::Scalar Glib::Object Glib::String ));
	$treeview{ident $self}  = new Gtk2::TreeView($treemodel{ident $self});

	$treeview{ident $self}->set_rules_hint(1);
	$treeview{ident $self}->set_headers_visible(0);
	$treeview{ident $self}->signal_connect("grab-focus", sub { $self->treeview_grab_focus_cb(@_) });
	$treeview{ident $self}->signal_connect("event", sub { $self->treeview_event_cb(@_) });
	$treeview{ident $self}->signal_connect("row-expanded", sub { $self->treeview_row_expanded_cb(@_) });
	$treeview{ident $self}->signal_connect("row-collapsed", sub { $self->treeview_row_collapsed_cb(@_) });

	# Drag and Drop
	my $dnd = new Filer::DND($filer{ident $self},$self);
	$treeview{ident $self}->drag_dest_set('all', ['move','copy'], $dnd->target_table);
	$treeview{ident $self}->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $dnd->target_table);
	$treeview{ident $self}->signal_connect("drag_data_get", sub { $dnd->filepane_treeview_drag_data_get(@_) });
	$treeview{ident $self}->signal_connect("drag_data_received", sub { $dnd->filepane_treeview_drag_data_received(@_) });

	$treeselection{ident $self} = $treeview{ident $self}->get_selection;
	$treeselection{ident $self}->set_mode("multiple");

	my $scrolled_window = new Gtk2::ScrolledWindow;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$vbox{ident $self}->pack_start($scrolled_window, 1, 1, 0);
	$scrolled_window->add($treeview{ident $self});

	# a column with a pixbuf renderer and a text renderer
	my $col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	my $cell0 = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell0, 0);
	$col->add_attribute($cell0, pixbuf => $COL_ICON);

	my $cell1 = Gtk2::CellRendererText->new;
	$col->pack_start($cell1, 1);
	$col->add_attribute($cell1, text => $COL_NAME);

	$treeview{ident $self}->append_column($col);

	$self->CreateRootNodes();

	return $self;
}

# sub DESTROY {
# 	my ($self) = @_;
# 
# 	delete $filer{ident $self};
# 	delete $side{ident $self};
# 	delete $vbox{ident $self};
# 	delete $treeview{ident $self};
# 	delete $treemodel{ident $self};
# 	delete $treeselection{ident $self};
# 	delete $mouse_motion_select{ident $self};
# 	delete $mouse_motion_y_pos_old{ident $self};
# }

sub get_type {
	my ($self) = @_;
	return "TREE";
}

sub show_popup_menu {
	my ($self,$e) = @_;

	my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $treeselection{ident $self}->path_is_selected($p)) {
			$treeselection{ident $self}->unselect_all;
			$treeselection{ident $self}->select_path($p);
		}

		my $uimanager  = $filer{ident $self}->get_widgets->{uimanager};
		my $ui_path    = '/ui/list-popupmenu';
		my $popup_menu = $uimanager->get_widget($ui_path);

		$popup_menu->show_all;

		$uimanager->get_widget("$ui_path/Open")->show;
		$uimanager->get_widget("$ui_path/Open")->set_sensitive(1);
		$uimanager->get_widget("$ui_path/PopupItems1/Rename")->set_sensitive(1);
		$uimanager->get_widget("$ui_path/PopupItems1/Delete")->set_sensitive(1);
		$uimanager->get_widget("$ui_path/PopupItems1/Cut")->set_sensitive(1);
		$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive(1);
#		$uimanager->get_widget("$ui_path/PopupItems1/Paste")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/PopupItems1/Paste")->set_sensitive(1);
		$uimanager->get_widget("$ui_path/archive-menu")->set_sensitive(1);
		$uimanager->get_widget("$ui_path/Properties")->set_sensitive(1);

		$uimanager->get_widget("$ui_path/Open")->hide;
		$uimanager->get_widget("$ui_path/archive-menu/Extract")->hide;

		my $bookmarks = new Filer::Bookmarks($filer{ident $self});
		$uimanager->get_widget("$ui_path/Bookmarks")->set_submenu($bookmarks->generate_bookmarks_menu);

		if ($self->count_items > 1) {
			$uimanager->get_widget("$ui_path/PopupItems1/Rename")->set_sensitive(0);
			$uimanager->get_widget("$ui_path/Properties")->set_sensitive(0);
		}

		$popup_menu->show_all;
		$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
	} else {
		$treeselection{ident $self}->unselect_all;
	}
}

sub treeview_event_cb {
	my ($self,$w,$e,$d) = @_;

	if ($e->type eq "key-press") {
		if ($e->keyval == $Gtk2::Gdk::Keysyms{'Return'}) {

			my $iter = $self->get_iters->[0];
			my $p    = $treemodel{ident $self}->get_path($iter);
		
			$self->row_action($p);
			return 1;

		} elsif ($e->keyval == $Gtk2::Gdk::Keysyms{'Delete'}) {

			$filer{ident $self}->delete_cb;
			return 1;
		}
	}

	if ($e->type eq "button-press") {
		if ($e->button == 2) {
			$mouse_motion_select{ident $self}    = 1;
			$mouse_motion_y_pos_old{ident $self} = $e->y;

			my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

			if (defined $p) {
				$treeselection{ident $self}->unselect_all;
				$treeselection{ident $self}->select_path($p);
			}

			$self->set_focus;
			return 1;

		} elsif ($e->button == 3) {

			$self->set_focus;
			$self->show_popup_menu($e);
			return 1;
		}
	}

	if ($e->type eq "2button-press" and $e->button == 1) {
		my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);
		
		if (defined $p) {
			$self->row_action($p);
			return 1;
		}
	}

	if ($e->type eq "button-release" and $e->button == 2) {
		$self->set_focus;
		$mouse_motion_select{ident $self} = 0;
		return 1;
	}

	if (($e->type eq "motion-notify") and ($mouse_motion_select{ident $self} == 1)) {
		my ($p_old) = $treeview{ident $self}->get_path_at_pos($e->x, $mouse_motion_y_pos_old{ident $self});
		my ($p_new) = $treeview{ident $self}->get_path_at_pos($e->x, $e->y);

		if ((defined $p_old) and (defined $p_new)) {
			$treeselection{ident $self}->unselect_all;
			$treeselection{ident $self}->select_range($p_old,$p_new);
		}

		$self->set_focus;
		return 0;
	}

	return 0;
}

sub row_action {
	my ($self,$treepath) = @_;
	my $pane = $filer{ident $self}->get_inactive_pane;
	my $iter = $treemodel{ident $self}->get_iter($treepath);
	my $fi   = $treemodel{ident $self}->get_fileinfo($iter);

	$pane->open_file($fi);

	if ($treeview{ident $self}->row_expanded($treepath)) {
		$treeview{ident $self}->collapse_row($treepath);
	} else {
		$treeview{ident $self}->expand_row($treepath,0);
	}

	return 1;
}

sub treeview_row_expanded_cb {
	my ($self,$treeview,$iter,$path) = @_;
	my $fi = $treemodel{ident $self}->get_fileinfo($iter);

	$self->DirRead($fi->get_path,$iter);

	return 1;
}

sub treeview_row_collapsed_cb {
	my ($self,$treeview,$iter,$path) = @_;

	while (my $i = $treemodel{ident $self}->iter_children($iter)) {
		$treemodel{ident $self}->remove($i);
	}

	$treemodel{ident $self}->append($iter);

	return 1;
}

sub filepath {
	my ($self) = @_;
	my $path   = $self->get_items->[0];

	if (defined $path) {
		return abs_path($path);
	}

	return undef;
}

*get_pwd = \&filepath;
*get_path = \&filepath;
*get_item = \&filepath;

sub get_updir {
	my ($self) = @_;
	return Filer::Tools->catpath($self->get_item, $UPDIR);
}

sub set_item {
	my ($self,$fi) = @_;

	$treemodel{ident $self}->set($self->get_iter,
		$COL_FILEINFO, $fi,
		$COL_NAME,     $fi->get_basename,
	);
}

sub refresh {
	my ($self) = @_;
	my $iter   = $self->get_iter;

	if (defined $iter) {
		my $path = $treemodel{ident $self}->get_path($iter);

		if ($treeview{ident $self}->row_expanded($path)) {
			$treeview{ident $self}->collapse_row($path);
			$treeview{ident $self}->expand_row($path, 0);
		}
	}
}

sub CreateRootNodes {
	my ($self)    = @_;
	my $mimeicons = $filer{ident $self}->get_mimeicons;
	my $iter;

	$iter = $treemodel{ident $self}->insert_with_values(undef, -1,
		$COL_FILEINFO, new Filer::FileInfo(File::Spec->rootdir),
		$COL_ICON,     $mimeicons->{'inode/directory'},
		$COL_NAME,     "Filesystem",
	);

	$treemodel{ident $self}->insert($iter, -1);

	$iter = $treemodel{ident $self}->insert_with_values(undef, -1,
		$COL_FILEINFO, new Filer::FileInfo($ENV{HOME}),
		$COL_ICON,     $mimeicons->{'inode/directory'},
		$COL_NAME,     "Home",
	);

	$treemodel{ident $self}->insert($iter, -1);
}

sub DirRead {
	my ($self,$dir,$parent_iter) = @_;

	my $show_hidden = $filer{ident $self}->get_config->get_option('ShowHiddenFiles');
	my $mimeicons   = $filer{ident $self}->get_mimeicons;

	opendir (my $dirh, $dir) 
		or return Filer::Dialog->msgbox_error("$dir: $!");

	my @dir_contents =
		map { Filer::FileInfo->new("$dir/$_") }
		grep { -d "$dir/$_" and (!/^\.{1,2}\Z(?!\n)/s) and (!/^\./ and !$show_hidden or $show_hidden) } 
		sort readdir($dirh);

	closedir($dirh);

	foreach my $fi (@dir_contents) {
		my $type     = $fi->get_mimetype;
		my $icon     = $fi->get_mimetype_icon;
		my $basename = $fi->get_basename;

		my $iter = $treemodel{ident $self}->insert_with_values($parent_iter, -1,
			$COL_FILEINFO, $fi,
 			$COL_ICON,     $icon,
			$COL_NAME,     $basename,
		);

		$treemodel{ident $self}->insert($iter, -1) if ($fi->is_readable);
	}

	my $dummy_iter = $treemodel{ident $self}->iter_nth_child($parent_iter, 0);
	$treemodel{ident $self}->remove($dummy_iter); # remove dummy iter
}

sub create_tar_gz_archive {
	my ($self) = @_;

	$treeview{ident $self}->set_sensitive(0);
	my $archive = new Filer::Archive;
	$archive->create_tar_gz_archive($self->get_updir, $self->get_items);
	$treeview{ident $self}->set_sensitive(1);

	$filer{ident $self}->refresh_inactive_pane;
}

sub create_tar_bz2_archive {
	my ($self) = @_;

	$treeview{ident $self}->set_sensitive(0);
	my $archive = new Filer::Archive;
	$archive->create_tar_bz2_archive($self->get_updir, $self->get_items);
	$treeview{ident $self}->set_sensitive(1);

	$filer{ident $self}->refresh_inactive_pane;
}

1;
