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

use Cwd qw(abs_path);
use File::Basename;

use Filer::Constants;
use Filer::DND;

use strict;
use warnings;

my $i = 0; 

use constant FILER			=> $i++; #  important! must be -> 0 <- !!!!
use constant SIDE 			=> $i++;
use constant VBOX			=> $i++;
use constant TREEVIEW			=> $i++;
use constant TREEMODEL			=> $i++;
use constant TREESELECTION		=> $i++;
use constant FILEPATH			=> $i++;
use constant FILEPATH_ITER		=> $i++;
use constant MIMEICONS			=> $i++;
use constant MOUSE_MOTION_SELECT	=> $i++;
use constant MOUSE_MOTION_Y_POS_OLD 	=> $i++;

use constant COL_ICON		=> 0;
use constant COL_NAME		=> 1;
use constant COL_FILEINFO	=> 2;

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless [], $class;
	my ($hbox,$button,$scrolled_window,$cell_pixbuf,$cell_text,$i,$col,$cell);

	$self->[FILER] = $filer;
	$self->[SIDE] = $side;
	$self->[MOUSE_MOTION_SELECT] = 0;

	$self->[VBOX] = new Gtk2::VBox(0,0);
	$self->[VBOX]->set_size_request(200,0);

	$hbox = new Gtk2::HBox(0,0);
	$self->[VBOX]->pack_start($hbox, 0, 1, 0);

	$scrolled_window = new Gtk2::ScrolledWindow;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$self->[VBOX]->pack_start($scrolled_window, 1, 1, 0);

	$self->[TREEVIEW] = new Gtk2::TreeView;
	$self->[TREEVIEW]->set_rules_hint(1);
	$self->[TREEVIEW]->set_headers_visible(0);
	$self->[TREEVIEW]->signal_connect("grab-focus", sub { $self->treeview_grab_focus_cb(@_) });
	$self->[TREEVIEW]->signal_connect("event", sub { $self->treeview_event_cb(@_) });
	$self->[TREEVIEW]->signal_connect("row-expanded", sub { $self->treeview_row_expanded_cb(@_) });
	$self->[TREEVIEW]->signal_connect("row-collapsed", sub { $self->treeview_row_collapsed_cb(@_) });

	$self->[TREEMODEL] = new Gtk2::TreeStore('Glib::Object','Glib::String','Glib::Scalar');
	$self->[TREEVIEW]->set_model($self->[TREEMODEL]);

	# Drag and Drop
	my $dnd = new Filer::DND($self->[FILER],$self);
	$self->[TREEVIEW]->drag_dest_set('all', ['move','copy'], $dnd->target_table);
	$self->[TREEVIEW]->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $dnd->target_table);
	$self->[TREEVIEW]->signal_connect("drag_data_get", sub { $dnd->filepane_treeview_drag_data_get(@_) });
	$self->[TREEVIEW]->signal_connect("drag_data_received", sub { $dnd->filepane_treeview_drag_data_received(@_) });

	$scrolled_window->add($self->[TREEVIEW]);

	$self->[TREESELECTION] = $self->[TREEVIEW]->get_selection;
	$self->[TREESELECTION]->set_mode("multiple");
	$self->[TREESELECTION]->signal_connect("changed", sub { $self->selection_changed_cb(@_) });

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start ($cell, 0);
	$col->add_attribute ($cell, pixbuf => COL_ICON);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start ($cell, 1);
	$col->add_attribute ($cell, text => COL_NAME);

	$self->[TREEVIEW]->append_column($col);

	$self->init_icons;
	$self->CreateRootNodes();

	return $self;
}

sub get_type {
	my ($self) = @_;
	return "TREE";
}

sub show_popup_menu {
	my ($self,$e) = @_;

	my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $self->[TREESELECTION]->path_is_selected($p)) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_path($p);
		}

		my $item;
		my $uimanager = $self->[FILER]->{widgets}->{uimanager};
		my $popup_menu = $uimanager->get_widget('/ui/list-popupmenu');
		$popup_menu->show_all;

		$uimanager->get_widget('/ui/list-popupmenu/Open')->show;
		$uimanager->get_widget('/ui/list-popupmenu/Open')->set_sensitive(1);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Rename')->set_sensitive(1);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Delete')->set_sensitive(1);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Cut')->set_sensitive(1);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Copy')->set_sensitive(1);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Paste')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/archive-menu')->set_sensitive(1);
		$uimanager->get_widget('/ui/list-popupmenu/Properties')->set_sensitive(1);

		$uimanager->get_widget('/ui/list-popupmenu/Open')->hide;
		$uimanager->get_widget('/ui/list-popupmenu/archive-menu/Extract')->hide;

		my $bookmarks = new Filer::Bookmarks($self->[FILER]);
		$uimanager->get_widget('/ui/list-popupmenu/Bookmarks')->set_submenu($bookmarks->bookmarks_menu);

		if ($self->count_items > 1) {
			$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Rename')->set_sensitive(0);
		}

		foreach (split /\n\r/, $self->[FILER]->get_clipboard_contents) { 
			if (-e $_) {
				$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Paste')->set_sensitive(1);
				last;
			}
		}

		$popup_menu->show_all;
		$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
	} else {
		$self->[TREESELECTION]->unselect_all;
	}
}

sub selection_changed_cb {
	my ($self) = @_;

	$self->[FILEPATH] = $self->get_items->[0];
	$self->[FILEPATH_ITER] = $self->get_iters->[0];

	return 1;
}

sub treeview_grab_focus_cb {
	my ($self) = @_;

	$self->[FILER]->{active_pane} = $self; # self
	$self->[FILER]->{inactive_pane} = $self->[FILER]->{pane}->[!$self->[SIDE]];

	return 1;
}

sub treeview_event_cb {
	my ($self,$w,$e,$d) = @_;

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Return'})
	or ($e->type eq "2button-press" and $e->button == 1))
	 {
		$self->[FILER]->{inactive_pane}->open_path_helper($self->[FILEPATH]);

		my $path = $self->[TREEMODEL]->get_path($self->[FILEPATH_ITER]);

		if ($self->[TREEVIEW]->row_expanded($path)) {
			$self->[TREEVIEW]->collapse_row($path)
		} else {
			$self->[TREEVIEW]->expand_row($path,0);
		}

		return 1;
	}

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Delete'})) {
		$self->[FILER]->delete_cb;
		return 1;
	}

	if ($e->type eq "button-press" and $e->button == 1) {
		my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

		if (! defined $p) {
			$self->[TREESELECTION]->unselect_all;
		}
	}

	if ($e->type eq "button-press" and $e->button == 2) {
		$self->[MOUSE_MOTION_SELECT] = 1;
		$self->[MOUSE_MOTION_Y_POS_OLD] = $e->y;

		my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

		if (defined $p) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_path($p);
		}

		$self->set_focus;
		return 1;
	}

	if ($e->type eq "button-release" and $e->button == 2) {
		$self->set_focus;
		$self->[MOUSE_MOTION_SELECT] = 0;
		return 1;
	}

	if (($e->type eq "motion-notify") and ($self->[MOUSE_MOTION_SELECT] == 1)) {
		my ($p_old) = $self->[TREEVIEW]->get_path_at_pos($e->x, $self->[MOUSE_MOTION_Y_POS_OLD]);
		my ($p_new) = $self->[TREEVIEW]->get_path_at_pos($e->x, $e->y);

		if ((defined $p_old) and (defined $p_new)) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_range($p_old,$p_new);
		}

		$self->set_focus;
		return 0;
	}

	if ($e->type eq "button-press" and $e->button == 3) {
		$self->set_focus;
		$self->show_popup_menu($e);
		return 1;
	}

	return 0;
}

sub treeview_row_expanded_cb {
	my ($self,$treeview,$iter,$path) = @_;
	my $fi = $self->[TREEMODEL]->get($iter, COL_FILEINFO);

	$self->DirRead($fi->get_path,$iter);

	return 1;
}

sub treeview_row_collapsed_cb {
	my ($self,$treeview,$iter,$path) = @_;

	while (my $i = $self->[TREEMODEL]->iter_children($iter)) {
		$self->[TREEMODEL]->remove($i);
	}

	$self->[TREEMODEL]->append($iter);

	return 1;
}

sub init_icons {
	my ($self) = @_;
	my $mime = new Filer::Mime($self->[FILER]);
	$self->[MIMEICONS] = $mime->get_icons;
}

sub get_vbox {
	my ($self) = @_;
	return $self->[VBOX];
}

sub get_treeview {
	my ($self) = @_;
	return $self->[TREEVIEW];
}

sub set_focus {
	my ($self) = @_;
	$self->[TREEVIEW]->grab_focus;
}

sub filepath {
	my ($self) = @_;
	
	if (defined $self->[FILEPATH]) {
		return abs_path($self->[FILEPATH]);
	} else {
		return undef;
	}
}

*get_pwd = \&filepath;
*get_path = \&filepath;
*get_item = \&filepath;

sub get_updir { 
	my ($self) = @_;
	return Filer::Tools->catpath($self->[FILEPATH], File::Spec->updir);
}

sub get_iter {
	my ($self) = @_;
	return $self->[FILEPATH_ITER];
}

sub get_iters {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get_iter($_) } $self->[TREESELECTION]->get_selected_rows ];
}

sub get_items {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get($_, COL_FILEINFO)->get_path } @{$self->get_iters} ];
}

sub get_fileinfo {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get($_, COL_FILEINFO) } @{$self->get_iters} ];
}

sub set_item {
	my ($self,$fi) = @_;

	$self->[FILEPATH] = $fi->get_path;
	$self->[TREEMODEL]->set($self->[FILEPATH_ITER], 
		COL_NAME, $fi->get_basename,
		COL_FILEINFO, $fi
	);
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	my $fi = $self->[TREEMODEL]->get($self->[TREEMODEL]->get_iter($p), COL_FILEINFO);
	return $fi->get_path;
}

sub count_items {
	my ($self) = @_;
	return $self->[TREESELECTION]->count_selected_rows;
}

sub refresh {
	my ($self) = @_;

	if (defined $self->[FILEPATH_ITER]) {
		my $path = $self->[TREEMODEL]->get_path($self->[FILEPATH_ITER]);

		if ($self->[TREEVIEW]->row_expanded($path)) {
			$self->[TREEVIEW]->collapse_row($path);
			$self->[TREEVIEW]->expand_row($path, 0);
		}
	}
}

sub remove_selected {
	my ($self) = @_;

	foreach (@{$self->get_iters}) {
		my $fi = $self->[TREEMODEL]->get($_, COL_FILEINFO);

		if (! -e $fi->get_path) {
			$self->[TREEMODEL]->remove($_);
		}
	}

	delete $self->[FILEPATH];
	delete $self->[FILEPATH_ITER];
}

sub CreateRootNodes {
	my ($self) = @_;
	my $iter;

	$iter = $self->[TREEMODEL]->append(undef);
	$self->[TREEMODEL]->set($iter, COL_ICON, $self->[MIMEICONS]->{'inode/directory'}, COL_NAME, "Filesystem", COL_FILEINFO, new Filer::FileInfo(File::Spec->rootdir));
	$self->[TREEMODEL]->append($iter);

	$iter = $self->[TREEMODEL]->append(undef);
	$self->[TREEMODEL]->set($iter, COL_ICON, $self->[MIMEICONS]->{'inode/directory'}, COL_NAME, "Home", COL_FILEINFO, new Filer::FileInfo($ENV{HOME}));
	$self->[TREEMODEL]->append($iter);

# 	$iter = $self->[TREEMODEL]->append(undef);
# 	$self->[TREEMODEL]->set($iter, COL_ICON, $self->[MIMEICONS]->{'inode/directory'}, COL_NAME, "Desktop", COL_FILEINFO, new Filer::FileInfo("$ENV{HOME}/Desktop"));
# 	$self->[TREEMODEL]->append($iter);
}

sub DirRead {
	my ($self,$dir,$parent_iter) = @_;
	my $show_hidden = $self->[FILER]->{config}->get_option('ShowHiddenFiles');

	opendir (DIR, $dir) || return Filer::Dialog->msgbox_error("$dir: $!");
	my @dir_contents = 
			map { Filer::FileInfo->new($_) }
			grep { -d $_ }
			map { Filer::Tools->catpath($dir, $_) }
			sort File::Spec->no_upwards(readdir(DIR));

	closedir(DIR);

	foreach my $fi (@dir_contents) {
		next if (!$show_hidden and $fi->is_hidden);

		my $type = $fi->get_mimetype;
		my $icon = $self->[MIMEICONS]->{$type};

		my $iter = $self->[TREEMODEL]->insert($parent_iter, -1);
		$self->[TREEMODEL]->set($iter, COL_ICON, $icon, COL_NAME, $fi->get_basename, COL_FILEINFO, $fi);
		$self->[TREEMODEL]->insert($iter, -1) if (-R $fi->get_path);
	}

	$self->[TREEMODEL]->remove($self->[TREEMODEL]->iter_nth_child($parent_iter, 0)); # remove dummy iter
}

sub create_tar_gz_archive {
	my ($self) = @_;

	my $archive = new Filer::Archive($self->get_updir, $self->get_items);

	$self->[TREEVIEW]->set_sensitive(0);
	$archive->create_tar_gz_archive;
	$self->[TREEVIEW]->set_sensitive(1);

	$self->[FILER]->refresh_inactive_pane;
}

sub create_tar_bz2_archive {
	my ($self) = @_;

	my $archive = new Filer::Archive($self->get_updir, $self->get_items);

	$self->[TREEVIEW]->set_sensitive(0);
	$archive->create_tar_bz2_archive;
	$self->[TREEVIEW]->set_sensitive(1);

	$self->[FILER]->Filer::refresh_inactive_pane;
}

1;
