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

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename;

use Filer::Constants;
use Filer::DND;

# attributes:
my %filer;
my %side;
my %vbox;
my %treeview;
my %treemodel;
my %treeselection;
my %mouse_motion_select;
my %mouse_motion_y_pos_old;

use enum qw(:COL_ ICON NAME FILEINFO);

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless anon_scalar(), $class;
	my ($hbox,$button,$scrolled_window,$cell_pixbuf,$cell_text,$i,$col,$cell);

	$filer{ident $self}               = $filer;
	$side{ident $self}                = $side;
	$mouse_motion_select{ident $self} = FALSE;

	$vbox{ident $self} = new Gtk2::VBox(0,0);
	$vbox{ident $self}->set_size_request(200,0);

	$hbox = new Gtk2::HBox(0,0);
	$vbox{ident $self}->pack_start($hbox, 0, 1, 0);

	$scrolled_window = new Gtk2::ScrolledWindow;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$vbox{ident $self}->pack_start($scrolled_window, 1, 1, 0);

	$treeview{ident $self} = new Gtk2::TreeView;
	$treeview{ident $self}->set_rules_hint(1);
	$treeview{ident $self}->set_headers_visible(0);
	$treeview{ident $self}->signal_connect("grab-focus", sub { $self->treeview_grab_focus_cb(@_) });
	$treeview{ident $self}->signal_connect("event", sub { $self->treeview_event_cb(@_) });
	$treeview{ident $self}->signal_connect("row-expanded", sub { $self->treeview_row_expanded_cb(@_) });
	$treeview{ident $self}->signal_connect("row-collapsed", sub { $self->treeview_row_collapsed_cb(@_) });

	$treemodel{ident $self} = new Gtk2::TreeStore(qw(Glib::Object Glib::String Glib::Scalar));
	$treeview{ident $self}->set_model($treemodel{ident $self});

	# Drag and Drop
	my $dnd = new Filer::DND($filer{ident $self},$self);
	$treeview{ident $self}->drag_dest_set('all', ['move','copy'], $dnd->target_table);
	$treeview{ident $self}->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $dnd->target_table);
	$treeview{ident $self}->signal_connect("drag_data_get", sub { $dnd->filepane_treeview_drag_data_get(@_) });
	$treeview{ident $self}->signal_connect("drag_data_received", sub { $dnd->filepane_treeview_drag_data_received(@_) });

	$scrolled_window->add($treeview{ident $self});

	$treeselection{ident $self} = $treeview{ident $self}->get_selection;
	$treeselection{ident $self}->set_mode("multiple");

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => COL_ICON);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => COL_NAME);

	$treeview{ident $self}->append_column($col);

	$self->CreateRootNodes();

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $filer{ident $self};
	delete $side{ident $self};
	delete $vbox{ident $self};
	delete $treeview{ident $self};
	delete $treemodel{ident $self};
	delete $treeselection{ident $self};
	delete $mouse_motion_select{ident $self};
	delete $mouse_motion_y_pos_old{ident $self};
}

sub get_type {
	my ($self) = @_;
	return "TREE";
}

sub get_side {
	my ($self) = @_;
	return $side{ident $self};
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
		$uimanager->get_widget("$ui_path/PopupItems1/Paste")->set_sensitive(0);
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

sub treeview_grab_focus_cb {
	my ($self) = @_;

	return 1;
}

sub treeview_event_cb {
	my ($self,$w,$e,$d) = @_;

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Return'})
	or ($e->type eq "2button-press" and $e->button == 1))
	{
		$filer{ident $self}->get_inactive_pane->open_path_helper($self->get_item);

		my $path = $treemodel{ident $self}->get_path($self->get_iter);

		if ($treeview{ident $self}->row_expanded($path)) {
			$treeview{ident $self}->collapse_row($path)
		} else {
			$treeview{ident $self}->expand_row($path,0);
		}

		return 1;
	}

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Delete'})) {
		$filer{ident $self}->delete_cb;
		return 1;
	}

	if ($e->type eq "button-press" and $e->button == 1) {
		my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

		if (! defined $p) {
			$treeselection{ident $self}->unselect_all;
		}
	}

	if ($e->type eq "button-press" and $e->button == 2) {
		$mouse_motion_select{ident $self}    = 1;
		$mouse_motion_y_pos_old{ident $self} = $e->y;

		my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

		if (defined $p) {
			$treeselection{ident $self}->unselect_all;
			$treeselection{ident $self}->select_path($p);
		}

		$self->set_focus;
		return 1;
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

	if ($e->type eq "button-press" and $e->button == 3) {
		$self->set_focus;
		$self->show_popup_menu($e);
		return 1;
	}

	return 0;
}

sub treeview_row_expanded_cb {
	my ($self,$treeview,$iter,$path) = @_;
	my $fi = $treemodel{ident $self}->get($iter, COL_FILEINFO);

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

sub get_vbox {
	my ($self) = @_;
	return $vbox{ident $self};
}

sub get_treeview {
	my ($self) = @_;
	return $treeview{ident $self};
}

sub set_focus {
	my ($self) = @_;
	$treeview{ident $self}->grab_focus;
}

sub filepath {
	my ($self) = @_;
	my $path = $self->get_items->[0];

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
	return Filer::Tools->catpath($self->get_item, UPDIR);
}

sub get_iter {
	my ($self) = @_;
	return $self->get_iters->[0];
}

sub get_iters {
	my ($self) = @_;
	return [ map { $treemodel{ident $self}->get_iter($_) } $treeselection{ident $self}->get_selected_rows ];
}

sub get_fileinfo {
	my ($self) = @_;
	return [ map { $treemodel{ident $self}->get($_, COL_FILEINFO) } @{$self->get_iters} ];
}

sub get_items {
	my ($self) = @_;
	return [ map { $_->get_path } @{$self->get_fileinfo} ];
}

sub set_item {
	my ($self,$fi) = @_;

	$treemodel{ident $self}->set($self->get_iter,
		COL_NAME,     $fi->get_basename,
		COL_FILEINFO, $fi
	);
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	my $fi = $treemodel{ident $self}->get($treemodel{ident $self}->get_iter($p), COL_FILEINFO);
	return $fi->get_path;
}

sub count_items {
	my ($self) = @_;
	return $treeselection{ident $self}->count_selected_rows;
}

sub refresh {
	my ($self) = @_;

	if (defined $self->get_iter) {
		my $path = $treemodel{ident $self}->get_path($self->get_iter);

		if ($treeview{ident $self}->row_expanded($path)) {
			$treeview{ident $self}->collapse_row($path);
			$treeview{ident $self}->expand_row($path, 0);
		}
	}
}

sub remove_selected {
	my ($self) = @_;

	foreach (@{$self->get_iters}) {
		my $fi = $treemodel{ident $self}->get($_, COL_FILEINFO);

		if (! -e $fi->get_path) {
			$treemodel{ident $self}->remove($_);
		}
	}
}

sub CreateRootNodes {
	my ($self) = @_;
	my $iter;

	$iter = $treemodel{ident $self}->insert(undef, -1);
	$treemodel{ident $self}->set($iter,
		COL_ICON,     $filer{ident $self}->get_mimeicons->{'inode/directory'},
		COL_NAME,     "Filesystem",
		COL_FILEINFO, new Filer::FileInfo(File::Spec->rootdir)
	);

	$treemodel{ident $self}->insert($iter, -1);

	$iter = $treemodel{ident $self}->insert(undef, -1);
	$treemodel{ident $self}->set($iter,
		COL_ICON,     $filer{ident $self}->get_mimeicons->{'inode/directory'},
		COL_NAME,     "Home",
		COL_FILEINFO, new Filer::FileInfo($ENV{HOME})
	);

	$treemodel{ident $self}->insert($iter, -1);
}

sub DirRead {
	my ($self,$dir,$parent_iter) = @_;
	my $show_hidden = $filer{ident $self}->get_config->get_option('ShowHiddenFiles');

	opendir (my $dirh, $dir) || return Filer::Dialog->msgbox_error("$dir: $!");
	my @dir_contents =
			map { Filer::FileInfo->new(Filer::Tools->catpath($dir, $_)) }
			grep { -d "$dir/$_" and (!/^\.{1,2}\Z(?!\n)/s) and (!/^\./ and !$show_hidden or $show_hidden) } 
			sort readdir($dirh);
	closedir($dirh);

	foreach my $fi (@dir_contents) {
		my $type     = $fi->get_mimetype;
		my $icon     = $filer{ident $self}->get_mimeicons->{$type};
		my $basename = $fi->get_basename;

		my $iter = $treemodel{ident $self}->insert($parent_iter, -1);
		$treemodel{ident $self}->set($iter,
			COL_ICON,     $icon,
			COL_NAME,     $basename,
			COL_FILEINFO, $fi
		);

		$treemodel{ident $self}->insert($iter, -1) if (-R $fi->get_path);
	}

	$treemodel{ident $self}->remove($treemodel{ident $self}->iter_nth_child($parent_iter, 0)); # remove dummy iter
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

	$filer{ident $self}->Filer::refresh_inactive_pane;
}

1;
