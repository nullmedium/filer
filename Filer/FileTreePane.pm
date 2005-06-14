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

use strict;
use warnings;

use constant LEFT 		=> 0;
use constant RIGHT		=> 1;

use constant SIDE 		=> 0;
use constant VBOX		=> 1;
use constant TREEVIEW		=> 2;
use constant TREEMODEL		=> 3;
use constant TREESELECTION	=> 4;
use constant FILEPATH		=> 5;
use constant FILEPATH_ITER	=> 6;
use constant MIMEICONS		=> 7;

use constant MOUSE_MOTION_SELECT => 8;
use constant MOUSE_MOTION_DESELECT => 9;

our ($y_old); 

sub new {
	my ($class,$side) = @_;
	my $self = bless [], $class;
	my ($hbox,$button,$scrolled_window,$cell_pixbuf,$cell_text,$i);
	my ($col, $cell);

	$self->[SIDE] = $side;

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
	$self->[TREEVIEW]->signal_connect("grab-focus", \&treeview_grab_focus_cb, $self);
# 	$self->[TREEVIEW]->signal_connect("key-press-event", \&treeview_event_cb, $self);
# 	$self->[TREEVIEW]->signal_connect("button-press-event", \&treeview_event_cb, $self);
	$self->[TREEVIEW]->signal_connect("event", \&treeview_event_cb, $self);
	$self->[TREEVIEW]->signal_connect("row-expanded", \&treeview_row_expanded_cb, $self);
	$self->[TREEVIEW]->signal_connect("row-collapsed", \&treeview_row_collapsed_cb, $self);

	$self->[TREEMODEL] = new Gtk2::TreeStore('Glib::Object','Glib::String','Glib::String');
	$self->[TREEVIEW]->set_model($self->[TREEMODEL]);

	# Drag and Drop
	$self->[TREEVIEW]->drag_source_set(['button1_mask', 'button3_mask'], ['copy', 'move'], &Filer::DND::target_table);
	$self->[TREEVIEW]->drag_dest_set('all', ['copy', 'move'], &Filer::DND::target_table);
	$self->[TREEVIEW]->signal_connect("drag_data_get", \&Filer::DND::filepane_treeview_drag_data_get_cb, $self);
	$self->[TREEVIEW]->signal_connect("drag_data_received", \&Filer::DND::filepane_treeview_drag_data_received_cb, $self);

	$scrolled_window->add($self->[TREEVIEW]);

	$self->[TREESELECTION] = $self->[TREEVIEW]->get_selection;
	$self->[TREESELECTION]->set_mode("multiple");
	$self->[TREESELECTION]->signal_connect("changed", \&selection_changed_cb, $self);

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start ($cell, 0);
	$col->add_attribute ($cell, pixbuf => 0);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start ($cell, 1);
	$col->add_attribute ($cell, text => 1);

	$self->[TREEVIEW]->append_column($col);

	$self->init_icons;

	$self->open_path("/");

	$self->[MOUSE_MOTION_SELECT] = 0;
	$self->[MOUSE_MOTION_DESELECT] = 0;

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
		my $item_factory = new Gtk2::ItemFactory("Gtk2::Menu", '<main>', undef);
		my $popup_menu = $item_factory->get_widget('<main>');
		my $bookmarks_menu = new Gtk2::Menu;
		my $commands_menu = new Gtk2::Menu;

		my @menu_items =
		(
		{ path => '/sep4',								        			item_type => '<Separator>'},
		{ path => '/Copy',					callback => \&main::copy_cb,				item_type => '<Item>'},
	#	{ path => '/Paste',					callback => \&main::paste_cb,				item_type => '<Item>'},
	#	{ path => '/sep5',								        			item_type => '<Separator>'},
		{ path => '/Move',					callback => \&main::move_cb,				item_type => '<Item>'},
		{ path => '/Rename',					callback => \&main::rename_cb,				item_type => '<Item>'},
		{ path => '/MkDir',					callback => \&main::mkdir_cb,				item_type => '<Item>'},
		{ path => '/Delete',					callback => \&main::delete_cb,		        	item_type => '<Item>'},
		{ path => '/sep1',								        			item_type => '<Separator>'},
		{ path => '/Bookmarks',												item_type => '<Item>'},
		{ path => '/sep2',								        			item_type => '<Separator>'},
	#	{ path => '/Open Terminal',				callback => sub { $self->open_terminal },	        item_type => '<Item>'},
		{ path => '/Archive/Create tar.gz',			callback => sub { $self->create_tar_gz_archive },	item_type => '<Item>'},
		{ path => '/Archive/Create tar.bz2',			callback => sub { $self->create_tar_bz2_archive },	item_type => '<Item>'},
		{ path => '/sep3',								       				item_type => '<Separator>'},
		{ path => '/Properties',				callback => sub { $self->set_properties },	        item_type => '<Item>'},
		);

		$item_factory->create_items(undef, @menu_items);

		# Bookmarks Menu

		$item = $item_factory->get_item('/Bookmarks');
		$item->set_submenu($bookmarks_menu);

		$item = new Gtk2::MenuItem("Set Bookmark");
		$item->signal_connect("activate", sub {
			my $bookmarks = new Filer::Bookmarks;
			foreach (@{$self->get_selected_items}) {
				if (-d $_) {
					$bookmarks->set_bookmark($_);
				}
			}
		});
		$bookmarks_menu->add($item);

		$item = new Gtk2::MenuItem("Remove Bookmark");
		$item->signal_connect("activate", sub {
			my $bookmarks = new Filer::Bookmarks;
			foreach (@{$self->get_selected_items}) {
				if (-d $_) {
					$bookmarks->remove_bookmark($_);
				}
			}
		});
		$bookmarks_menu->add($item);

		$item = new Gtk2::SeparatorMenuItem;
		$bookmarks_menu->add($item);

		my $bookmarks = new Filer::Bookmarks;
		foreach ($bookmarks->get_bookmarks) {
			$item = new Gtk2::MenuItem($_);
			$item->signal_connect("activate", sub {	$main::pane->[!$self->[SIDE]]->open_path($_[1]) }, $_);
			$bookmarks_menu->add($item);
		}

		$popup_menu->show_all;
		$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
	} else {
		$self->[TREESELECTION]->unselect_all;
	}
}

sub selection_changed_cb {
	my ($selection,$self) = @_;

	$self->[FILEPATH] = $self->get_selected_items->[0];
	$self->[FILEPATH_ITER] = $self->get_selected_iters->[0];

#	$main::pane->[!$self->[SIDE]]->open_path($self->[FILEPATH]);

	return 1;
}

sub treeview_grab_focus_cb {
	my ($w,$self) = @_;

	$main::active_pane = $self; # self
	$main::inactive_pane = $main::pane->[!$self->[SIDE]];

	return 1;
}

sub treeview_event_cb {
	my ($w,$e,$self) = @_;

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Return'})
	or ($e->type eq "2button-press" and $e->button == 1))
	 {
		$main::pane->[!$self->[SIDE]]->open_path($self->[FILEPATH]);

		my $path = $self->[TREEMODEL]->get_path($self->[FILEPATH_ITER]);

		if ($self->[TREEVIEW]->row_expanded($path)) {
			$self->[TREEVIEW]->collapse_row($path)
		} else {
			$self->[TREEVIEW]->expand_row($path,0);
		}

		return 1;
	}

	if ($e->type eq "button-press" and $e->button == 1) {
		$self->set_focus;
		$self->_select_helper_button1($e->x,$e->y);
	}

	if ($e->type eq "button-press" and $e->button == 2) {
		$self->[MOUSE_MOTION_SELECT] = 1;
		$self->set_focus;
		$y_old = $e->y;
		$self->_select_helper_button2($e->x,$e->y);
		return 1;
	}

	if ($e->type eq "button-release" and $e->button == 2) {
		$self->[MOUSE_MOTION_SELECT] = 0;
		return 1;
	}

	if (($e->type eq "motion-notify") and ($self->[MOUSE_MOTION_SELECT] == 1)) {
		$self->_select_helper_motion($e->x,$y_old,$e->y);
		return 0;
	}

	if ($e->type eq "button-press" and $e->button == 3) {
		$self->set_focus;
		$self->show_popup_menu($e);
		return 1;
	}

	return 0;
}

sub _select_helper_button1 {
	my ($self,$x,$y) = @_;
	my ($p) = $self->[TREEVIEW]->get_path_at_pos($x,$y);
	
	if (! defined $p) {
		$self->[TREESELECTION]->unselect_all;
	}
}

sub _select_helper_button2 {
	my ($self,$x,$y) = @_;
	my ($p) = $self->[TREEVIEW]->get_path_at_pos($x,$y);

	if (defined $p) {
		$self->[TREESELECTION]->unselect_all;
		$self->[TREESELECTION]->select_path($p);
	} else {
		$self->[TREESELECTION]->unselect_all;
	}
}

sub _select_helper_motion {
	my ($self,$x,$y_old,$y_new) = @_;
	my ($p_old) = $self->[TREEVIEW]->get_path_at_pos($x,$y_old);
	my ($p_new) = $self->[TREEVIEW]->get_path_at_pos($x,$y_new);

	if ((defined $p_old) and (defined $p_new)) {
		$self->[TREESELECTION]->unselect_all;
		$self->[TREESELECTION]->select_range($p_old,$p_new);
	}
}



sub treeview_row_expanded_cb {
	my ($treeview,$iter,$path,$self) = @_;
	my $dir = $self->[TREEMODEL]->get($iter, 2);

	$self->DirRead($dir,$iter);

	return 1;
}

sub treeview_row_collapsed_cb {
	my ($treeview,$iter,$path,$self) = @_;

	while (my $i = $self->[TREEMODEL]->iter_children($iter)) {
		$self->[TREEMODEL]->remove($i);
	}

	$self->[TREEMODEL]->append($iter);

	return 1;
}

sub init_icons {
	my ($self) = @_;
	my $mime = new Filer::Mime;

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
	return Cwd::abs_path($self->[FILEPATH]);
}

*get_pwd = \&filepath;
*get_path = \&filepath;
*get_selected_item = \&filepath;

sub get_selected_iter {
	my ($self) = @_;
	return $self->[FILEPATH_ITER];
}

sub get_selected_iters {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get_iter($_) } $self->[TREESELECTION]->get_selected_rows ];
}

sub get_selected_items {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get($_, 2) } @{$self->get_selected_iters} ];
}

sub set_selected_item {
	my ($self,$name) = @_;
	$self->[FILEPATH] = $name;
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	return $self->[TREEMODEL]->get($self->[TREEMODEL]->get_iter($p), 2);
}

sub count_selected_items {
	my ($self) = @_;
	return $self->[TREEVIEW]->get_selection->count_selected_rows;
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

	foreach (@{$self->get_selected_iters}) {
		my $file = $self->[TREEMODEL]->get($_, 2);

		if (! -e $file) {
			$self->[TREEMODEL]->remove($_);
		}
	}

	delete $self->[FILEPATH];
	delete $self->[FILEPATH_ITER];
}

sub open_path {
	my ($self,$filepath) = @_;
	$self->DirRead($filepath,undef);
	$self->[FILEPATH] = $filepath;
}

sub DirRead {
	my ($self,$dir,$parent_iter) = @_;
	my $show_hidden = $main::config->get_option('ShowHiddenFiles');

	opendir (DIR, $dir) || return Filer::Dialog->msgbox_error("$dir: $!");
	my @dir_contents = sort readdir(DIR);
	closedir(DIR);

	my @dirs = grep { -d "$dir/$_" and (($show_hidden == 0 and $_ !~ /^\.+\w+/) or ($show_hidden == 1)) } @dir_contents;

#	splice @dirs, 0, 1; # no .
	@dirs = @dirs[1 .. $#dirs];

	if ($dir ne "/") {
#		splice @dirs, 0, 1; # no ..
		@dirs = @dirs[1 .. $#dirs];
	}

	foreach my $file (@dirs) {
		my $iter = $self->[TREEMODEL]->append($parent_iter);

		$self->[TREEMODEL]->set(
			$iter,
			0, (-l "$dir/$file") ? $self->[MIMEICONS]->{'inode/symlink'} : $self->[MIMEICONS]->{'inode/directory'},
			1, $file,
			2, Cwd::abs_path("$dir/$file")
		);

		if (-r "$dir/$file") {
			$self->[TREEMODEL]->append($iter);
		}
	}

	my $iter = $self->[TREEMODEL]->iter_nth_child($parent_iter, 0); # dummy iter
	$self->[TREEMODEL]->remove($iter);
}

sub set_properties {
	my ($self) = @_;

	Filer::Properties->set_properties_dialog($self->[FILEPATH]);
}

sub create_tar_gz_archive {
	my ($self) = @_;

	my $archive = Filer::Archive->new($self->[FILEPATH]);
	$archive->create_tar_gz_archive;

	$main::inactive_pane->open_path($self->[FILEPATH]. "/..");
}

sub create_tar_bz2_archive {
	my ($self) = @_;

	my $archive = Filer::Archive->new($self->[FILEPATH]);
	$archive->create_tar_bz2_archive;

	$main::inactive_pane->open_path($self->[FILEPATH]. "/..");
}

1;
