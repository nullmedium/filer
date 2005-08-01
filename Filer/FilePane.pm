#     Copyright (C) 2004-2005-2005 Jens Luedicke <jens.luedicke@gmail.com>
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

package Filer::FilePane;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename;

use Filer::Constants;
use Filer::DND;

use enum qw(
	FILER
	SIDE
	FILEPATH
	OVERRIDES
	VBOX
	TREEVIEW
	TREEMODEL
	TREESELECTION
	PATH_COMBO
	MIME
	MIMEICONS
	LOCATION_BAR_PARENT
	LOCATION_BAR
	NAVIGATION_BOX
	NAVIGATION_BUTTONS
	STATUS
	MOUSE_MOTION_SELECT
	MOUSE_MOTION_Y_POS_OLD
	SELECT
	UNSELECT
);

use enum qw(:COL_ ICON NAME SIZE MODE TYPE DATE FILEINFO N);

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless [], $class;
	my ($hbox,$button,$scrolled_window,$col,$cell,$i);

	$self->[FILER] = $filer;
	$self->[SIDE] = $side;
	$self->[MIME] = $self->[FILER]->{mime};
	$self->[MIMEICONS] = $self->[FILER]->{mimeicons};
	$self->[OVERRIDES] = {};
	$self->[MOUSE_MOTION_SELECT] = FALSE;

	$self->[VBOX] = new Gtk2::VBox(0,0);

	$self->[LOCATION_BAR_PARENT] = new Gtk2::HBox(0,0);
	$self->[VBOX]->pack_start($self->[LOCATION_BAR_PARENT], 0, 1, 0);

	$self->[LOCATION_BAR] = new Gtk2::HBox(0,0);
	$self->[LOCATION_BAR_PARENT]->pack_start($self->[LOCATION_BAR], 1, 1, 0);

	$button = new Gtk2::Button("Up");
	$button->signal_connect("clicked", sub {
		$self->open_path_helper($self->get_updir);
	});
	$self->[LOCATION_BAR]->pack_start($button, 0, 1, 0);

	$self->[PATH_COMBO] = Gtk2::ComboBoxEntry->new_text;
	$self->[LOCATION_BAR]->pack_start($self->[PATH_COMBO], 1, 1, 0);

	$button = new Gtk2::Button("Go");
	$button->signal_connect("clicked", sub {
		$self->open_file(new Filer::FileInfo($self->[PATH_COMBO]->get_active_text));
	});
	$self->[LOCATION_BAR]->pack_start($button, 0, 1, 0);

	$self->[NAVIGATION_BOX] = new Gtk2::HBox(0,0);
	$self->[VBOX]->pack_start($self->[NAVIGATION_BOX], 0, 1, 0);

	$scrolled_window = new Gtk2::ScrolledWindow;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$self->[VBOX]->pack_start($scrolled_window, 1, 1, 0);

	$self->[TREEVIEW] = new Gtk2::TreeView;
	$self->[TREEVIEW]->set_rules_hint(1);
	$self->[TREEVIEW]->set_enable_search(0);
  	$self->[TREEVIEW]->signal_connect("grab-focus", sub { $self->treeview_grab_focus_cb(@_) });
 	$self->[TREEVIEW]->signal_connect("key-press-event", sub { $self->treeview_event_cb(@_) });
 	$self->[TREEVIEW]->signal_connect("button-press-event", sub { $self->treeview_event_cb(@_) });
 	$self->[TREEVIEW]->signal_connect("button-release-event", sub { $self->treeview_event_cb(@_) });
 	$self->[TREEVIEW]->signal_connect("motion-notify-event", sub { $self->treeview_event_cb(@_) });

	$self->[TREEMODEL] = new Gtk2::ListStore(qw(Glib::Object Glib::String Glib::String Glib::String Glib::String Glib::String Glib::Scalar));
	$self->[TREEVIEW]->set_model($self->[TREEMODEL]);

	# Drag and Drop
	my $dnd = new Filer::DND($self->[FILER],$self);
	$self->[TREEVIEW]->drag_dest_set('all', ['move','copy'], $dnd->target_table);
	$self->[TREEVIEW]->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $dnd->target_table);
	$self->[TREEVIEW]->signal_connect("drag_data_get", sub { $dnd->filepane_treeview_drag_data_get(@_) });
	$self->[TREEVIEW]->signal_connect("drag_data_received", sub { $dnd->filepane_treeview_drag_data_received(@_) });
	$self->[TREESELECTION] = $self->[TREEVIEW]->get_selection;
	$self->[TREESELECTION]->set_mode("multiple");

	$scrolled_window->add($self->[TREEVIEW]);

	my %s; # size
	my %m; # mode
	my %t; # time

	my $sort_func = sub {
		my ($model,$a,$b) = @_;
		my ($sort_column_id,$order) = $model->get_sort_column_id;

		my $fi1 = $model->get($a, COL_FILEINFO);
		my $fi2 = $model->get($b, COL_FILEINFO);

		return 0 if (not ($fi1 && $fi2));

		my $fp1 = $fi1->get_path;
		my $fp2 = $fi2->get_path;

		if ((-d $fp1) and !( -d $fp2)) {
			return ($order eq "ascending") ? -1 : 1;

		} elsif (!( -d $fp1) and (-d $fp2)) {
			return ($order eq "ascending") ? 1 : -1;
		}

		my $name_sort = sub {
			return ($model->get($a, COL_NAME) cmp $model->get($b, COL_NAME));
		};

		if ($sort_column_id == COL_NAME) { # size

			return $name_sort->();

		} elsif ($sort_column_id == COL_SIZE) { # size

			my $s = (($s{$fp1} ||= $fi1->get_raw_size) - ($s{$fp2} ||= $fi2->get_raw_size));
			return ($s == 0) ? $name_sort->() : $s;

		} elsif ($sort_column_id == COL_MODE) { # mode

			# do we need to use the numeric mode values to sort?

			my $s = (($m{$fp1} ||= $fi1->get_raw_mode) - ($m{$fp2} ||= $fi2->get_raw_mode));
			return ($s == 0) ? $name_sort->() : $s;

		} elsif ($sort_column_id == COL_DATE) { # date

			my $s = (($t{$fp1} ||= $fi1->get_raw_mtime) - ($t{$fp2} ||= $fi2->get_raw_mtime));
			return ($s == 0) ? $name_sort->() : $s;

		} else {
			# currently this can only be the 'type' column and the type column doesn't need any special treatment:
			my $s = ($model->get($a, $sort_column_id) cmp $model->get($b, $sort_column_id));
			return ($s == 0) ? $name_sort->() : $s;
		}
	};

	# a column with a pixbuf renderer and a text renderer
	$col = new Gtk2::TreeViewColumn;
	$col->set_sort_column_id(COL_NAME);
	$col->set_sort_indicator(1);
	$col->set_title("Name");
	$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');

	$cell = new Gtk2::CellRendererPixbuf;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => COL_ICON);

	$cell = new Gtk2::CellRendererText;
#	$cell->set("width-chars" => 20, 'ellipsize-set' => 0, ellipsize => 'PANGO_ELLIPSIZE_MIDDLE');
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => COL_NAME);

	$self->[TREEMODEL]->set_sort_func(COL_NAME, $sort_func);
	$self->[TREEVIEW]->append_column($col);

	my @cols = ();
	$cols[COL_SIZE] = "Size";
	$cols[COL_TYPE] = "Type";
	$cols[COL_MODE] = "Mode";
	$cols[COL_DATE] = "Date";

	for (my $n = 2; $n <= $#cols; $n++) {
		$cell = new Gtk2::CellRendererText;
		$col = Gtk2::TreeViewColumn->new_with_attributes($cols[$n], $cell, text => $n);
		$col->set_sort_column_id($n);
		$col->set_sort_indicator(1);
		$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');
		$self->[TREEMODEL]->set_sort_func($n, $sort_func);
		$self->[TREEVIEW]->append_column($col);
	}

	$self->[TREEMODEL]->set_sort_column_id(COL_NAME,'ascending');

	$self->[STATUS] = new Gtk2::Label;
	$self->[STATUS]->set_alignment(0.0,0.5);
	$self->[VBOX]->pack_start($self->[STATUS], 0, 1, 2);

	return $self;
}

sub get_type {
	my ($self) = @_;
	return "LIST";
}

sub get_location_bar_parent {
	my ($self) = @_;
	return $self->[LOCATION_BAR_PARENT];
}

sub get_location_bar {
	my ($self) = @_;
	return $self->[LOCATION_BAR];
}

sub get_navigation_box {
	my ($self) = @_;
	return $self->[NAVIGATION_BOX];
}

sub show_popup_menu {
	my ($self,$e) = @_;

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

	my $bookmarks = new Filer::Bookmarks($self->[FILER]);
	$uimanager->get_widget('/ui/list-popupmenu/Bookmarks')->set_submenu($bookmarks->bookmarks_menu);

	my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $self->[TREESELECTION]->path_is_selected($p)) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_path($p);
		}

		if ($self->count_items == 1) {
			my $fi = $self->get_fileinfo->[0];
			my $type = $fi->get_mimetype;

			# Customize archive submenu
			if ((new Filer::Archive)->is_supported_archive($type)) {
				$uimanager->get_widget('/ui/list-popupmenu/archive-menu/Extract')->set_sensitive(1);
			} else {
				$uimanager->get_widget('/ui/list-popupmenu/archive-menu/Extract')->set_sensitive(0);
			}

			# add and create Open submenu
			my $commands_menu = new Gtk2::Menu;
			$item = $uimanager->get_widget('/ui/list-popupmenu/Open');
			$item->set_submenu($commands_menu);

			foreach ($self->[MIME]->get_commands($type)) {
				$item = new Gtk2::MenuItem(basename($_));
				$item->signal_connect("activate", sub {
					my @c = split /\s+/, $_[1];
					Filer::Tools->start_program(@c,$self->get_item);
				}, $_);
				$commands_menu->add($item);
			}

			$item = new Gtk2::MenuItem('Other ...');
			$item->signal_connect("activate", sub { $self->open_file_with });
			$commands_menu->add($item);

			$commands_menu->show_all;
		} else {
			$uimanager->get_widget('/ui/list-popupmenu/Open')->set_sensitive(0);
			$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Rename')->set_sensitive(0);
		}
	} else {
		$uimanager->get_widget('/ui/list-popupmenu/Open')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Rename')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Delete')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Cut')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Copy')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/archive-menu')->set_sensitive(0);
		$uimanager->get_widget('/ui/list-popupmenu/Properties')->set_sensitive(0);
	}

	foreach (split /\n\r/, $self->[FILER]->get_clipboard_contents) {
		if (-e $_) {
			$uimanager->get_widget('/ui/list-popupmenu/PopupItems1/Paste')->set_sensitive(1);
			last;
		}
	}

	$popup_menu->show_all;
	$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
}

sub treeview_grab_focus_cb {
	my ($self,$w) = @_;

	$self->[FILER]->{active_pane} = $self;
	$self->[FILER]->{inactive_pane} = $self->[FILER]->{pane}->[!$self->[SIDE]]; # the other side
	$self->[FILER]->{widgets}->{main_window}->set_title("$self->[FILEPATH] - Filer $self->[FILER]->{VERSION}");
}

sub treeview_event_cb {
	my ($self,$w,$e) = @_;

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'BackSpace'})) {
		$self->open_path_helper($self->get_updir);
		return 1;
	}

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Delete'})) {
		$self->[FILER]->delete_cb;
		return 1;
	}

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Return'})
	 or ($e->type eq "2button-press" and $e->button == 1)) {
		$self->open_file($self->get_fileinfo->[0]);
		return 1;
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
		my ($p_old) = $self->[TREEVIEW]->get_path_at_pos($e->x,$self->[MOUSE_MOTION_Y_POS_OLD]);
		my ($p_new) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

		if (defined $p_old and defined $p_new) {
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

sub get_vbox {
	my ($self) = @_;
	return $self->[VBOX];
}

sub get_treeview {
	my ($self) = @_;
	return $self->[TREEVIEW];
}

sub get_model {
	my ($self) = @_;
	return $self->[TREEMODEL];
}

sub set_model {
	my ($self,$model) = @_;

	$self->[TREEMODEL]->clear;

	$model->foreach(sub {
		my ($model,$path,$iter,$data) = @_;
		my $iter_new = $self->[TREEMODEL]->append;

		for (0 .. 6) {
			$self->[TREEMODEL]->set($iter_new, $_, $model->get($iter,$_));
		}

		return 0;
	});
}

sub set_focus {
	my ($self) = @_;
	$self->[TREEVIEW]->grab_focus;
}

sub get_pwd {
	my ($self) = @_;

	if (defined $self->[FILEPATH]) {
		return abs_path($self->[FILEPATH]);
	} else {
		return undef;
	}
}

sub get_updir {
	my ($self) = @_;
	return abs_path(Filer::Tools->catpath($self->[FILEPATH], UPDIR));
}

sub get_item {
	my ($self) = @_;
	return $self->get_items->[0];
}

sub set_item {
	my ($self,$fi) = @_;

	my $basename = $fi->get_basename;
	my $size = $fi->get_size;
	my $mode = $fi->get_mode;
	my $type = $fi->get_mimetype;
	my $time = $fi->get_mtime;

	$self->[TREEMODEL]->set($self->get_iter,
		COL_NAME, $basename,
		COL_SIZE, $size,
		COL_MODE, $mode,
		COL_TYPE, $type,
		COL_DATE, $time,
		COL_FILEINFO, $fi
	);
}

sub get_iter {
	my ($self) = @_;
	return $self->get_iters->[0];
}

sub get_iters {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get_iter($_) } $self->[TREESELECTION]->get_selected_rows ];
}

sub get_fileinfo {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get($_, COL_FILEINFO) } @{$self->get_iters} ];
}

sub get_items {
	my ($self) = @_;
	return [ map { $_->get_path } @{$self->get_fileinfo} ];
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	return ($self->[TREEMODEL]->get($self->[TREEMODEL]->get_iter($p), COL_FILEINFO))->get_path;
}

sub count_items {
	my ($self) = @_;
	return $self->[TREESELECTION]->count_selected_rows;
}

sub refresh {
	my ($self) = @_;
	$self->open_path($self->[FILEPATH]);
}

sub remove_selected {
	my ($self) = @_;

	foreach (@{$self->get_iters}) {
		$self->[TREEMODEL]->remove($_) if (! -e ($self->[TREEMODEL]->get($_, COL_FILEINFO))->get_path);
	}
}

sub update_navigation_buttons {
	my ($self) = @_;
	my $rootdir = File::Spec->rootdir;
	my $path = $rootdir;
	my $button = undef;

	foreach (sort { length($b) <=> length($a) } keys %{$self->[NAVIGATION_BUTTONS]}) {
		# check if $filepath isn't a parentdir of the current path button path $_
		if (! /^$self->[FILEPATH]/) {

			# check if the current path button path $_ isn't a parentdir of $filepath
			if ($self->[FILEPATH] !~ /^$_/) {

				# destroy path button
	 			$self->[NAVIGATION_BUTTONS]->{$_}->destroy;
	 			delete $self->[NAVIGATION_BUTTONS]->{$_};
			} else {
				# $_ is a parentdir of $filepath, so skip everything else.
				last;
			}
		}
	}

	foreach (File::Spec->splitdir($self->[FILEPATH])) {
		$path = Filer::Tools->catpath($path, $_);

		if (not defined $self->[NAVIGATION_BUTTONS]->{$path}) {
			$button = new Gtk2::RadioButton($self->[NAVIGATION_BUTTONS]->{$rootdir}, basename($path) || File::Spec->rootdir);
			$button->set(draw_indicator => 0); # i'm evil

			$button->signal_connect(toggled => sub {
				my ($widget,$data) = @_;

		 		my $label = $widget->get_child;
				my $pc = $label->get_pango_context;
				my $fd = $pc->get_font_description;

				if ($widget->get_active) {
					$fd->set_weight('PANGO_WEIGHT_BOLD');

					# avoid an endless loop/recursion.
					$self->open_path($data) if ($data ne $self->get_pwd);
				} else {
					$fd->set_weight('PANGO_WEIGHT_NORMAL');
				}

				$label->modify_font($fd);
			}, abs_path($path));

			$self->[NAVIGATION_BOX]->pack_start($button,0,0,0);
			$self->[NAVIGATION_BUTTONS]->{$path} = $button;
			$self->[NAVIGATION_BUTTONS]->{$path}->show;
		}
	}

	# set last button active. current directory.
	$self->[NAVIGATION_BUTTONS]->{$self->[FILEPATH]}->set(active => 1);
}

sub open_file {
	my ($self,$fileinfo) = @_;
	my $filepath = abs_path($fileinfo->get_path);

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if (-d $filepath) {
		$self->open_path_helper($filepath);
	} else {
		my $type = $fileinfo->get_mimetype;
		my $command = $self->[MIME]->get_default_command($type);

               if (defined $command) {
			if (-x $filepath) {
				my ($dialog,$label,$button);

				$dialog = new Gtk2::Dialog("Filer", undef, 'modal');
				$dialog->set_position('center');
				$dialog->set_modal(1);

				$label = new Gtk2::Label;
				$label->set_use_markup(1);
				$label->set_markup("The selected file is executable and has an associated command for its mimetype.\nExecute or open the selected file?");
				$label->set_alignment(0.0,0.0);
				$dialog->vbox->pack_start($label, 1,1,5);

				$button = Gtk2::Button->new_from_stock('gtk-cancel');
				$dialog->add_action_widget($button, 'cancel');

				$button = Gtk2::Button->new_from_stock('gtk-open');
				$dialog->add_action_widget($button, 2);

				$button = Filer::Dialog::mixed_button_new('gtk-ok',"_Run");
				$dialog->add_action_widget($button, 1);

				$dialog->show_all;
				my $r = $dialog->run;
				$dialog->destroy;

				if ($r eq 'cancel') {
					return;
				} elsif ($r eq 1) {
					Filer::Tools->start_program($filepath);
				} elsif ($r eq 2) {
					my @c = split /\s+/, $command;
					Filer::Tools->start_program(@c,$filepath);
				}
			} else {
				my @c = split /\s+/, $command;
				Filer::Tools->start_program(@c,$filepath);
			}
		} else {
			if (-x $filepath) {
				Filer::Tools->start_program($filepath);
				return;
			}

			if ($type =~ /^text\/.+/) {

				my $command = $self->[FILER]->{config}->get_option("Editor");
				my @c = split /\s+/, $command;
				Filer::Tools->start_program(@c,$filepath);

			} elsif ($type eq 'application/x-compressed-tar') {

				my $dir = $self->get_temp_archive_dir();
				my $pid = Filer::Tools->start_program("tar", "-C", $dir, "-xzf", $filepath);

				$self->[VBOX]->set_sensitive(0);
				Filer::Tools->wait_for_pid($pid);
				$self->[VBOX]->set_sensitive(1);

				$self->open_path($dir);

			} elsif ($type eq 'application/x-bzip-compressed-tar') {

				my $dir = $self->get_temp_archive_dir();
				my $pid = Filer::Tools->start_program("tar", "-C", $dir, "-xjf", $filepath);

				$self->[VBOX]->set_sensitive(0);
				Filer::Tools->wait_for_pid($pid);
				$self->[VBOX]->set_sensitive(1);

				$self->open_path($dir);

			} elsif ($type eq 'application/x-tar') {

				my $dir = $self->get_temp_archive_dir();
				my $pid = Filer::Tools->start_program("tar", "-C", $dir, "-xf", $filepath);

				$self->[VBOX]->set_sensitive(0);
				Filer::Tools->wait_for_pid($pid);
				$self->[VBOX]->set_sensitive(1);

				$self->open_path($dir);

			} elsif ($type eq 'application/zip') {

				my $dir = $self->get_temp_archive_dir();
				my $pid = Filer::Tools->start_program("unzip", "-d", $dir, $filepath);

				$self->[VBOX]->set_sensitive(0);
				Filer::Tools->wait_for_pid($pid);
				$self->[VBOX]->set_sensitive(1);

				$self->open_path($dir);

			} else {
				$self->[MIME]->run_dialog($self->get_fileinfo->[0]);
			}
		}
	}
}

sub open_file_with {
	my ($self) = @_;

	return 0 if (not defined $self->get_iter);

	$self->[MIME]->run_dialog($self->get_fileinfo->[0]);
}

sub open_path_helper {
	my ($self,$filepath) = @_;

	if (defined $self->[NAVIGATION_BUTTONS]->{$filepath}) {
		$self->[NAVIGATION_BUTTONS]->{$filepath}->set(active => 1);
	} else {
		$self->open_path($filepath);
		$self->update_navigation_buttons;
	}
}

sub open_path {
	my ($self,$filepath) = @_;

# 	my ($t0,$t1,$elapsed);
#  	use Time::HiRes qw(gettimeofday tv_interval);
#  	$t0 = [gettimeofday];

	if (defined $self->[OVERRIDES]->{$filepath}) {
		$filepath = $self->[OVERRIDES]->{$filepath};
		$self->[OVERRIDES]->{$filepath} = 0;
	}

	unless (-d $filepath) {
		$filepath = $ENV{HOME};
	}

	opendir (DIR, $filepath) or return Filer::Dialog->msgbox_error("$filepath: $!");
	my @dir_contents = map { Filer::FileInfo->new(Filer::Tools->catpath($filepath, $_)) } File::Spec->no_upwards(readdir(DIR));
	closedir(DIR);

	$self->[FILEPATH] = $filepath;

	my $show_hidden = $self->[FILER]->{config}->get_option('ShowHiddenFiles');
	my $total_size = 0;
	my $dirs_count = 0;
	my $files_count = 0;

	$self->[TREEMODEL]->clear;

	foreach my $fi (@dir_contents) {
		next if (!$show_hidden and $fi->is_hidden);

		my $type = $fi->get_mimetype;
		my $mypixbuf = $self->[MIMEICONS]->{'application/default'};

		if (defined $self->[MIMEICONS]->{$type}) {
			$mypixbuf = $self->[MIMEICONS]->{$type};
		}

		my $basename = $fi->get_basename;
		my $size = $fi->get_size; $total_size += $fi->get_raw_size;
		my $mode = $fi->get_mode;
		my $time = $fi->get_mtime;

 		my $iter= $self->[TREEMODEL]->insert_with_values(-1,
			COL_ICON, $mypixbuf,
			COL_NAME, $basename,
			COL_SIZE, $size,
			COL_MODE, $mode,
			COL_TYPE, $type,
			COL_DATE, $time,
			COL_FILEINFO, $fi
		);

		if (-d $fi->get_path) {
			$dirs_count++;
		} else {
			$files_count++;
		}
	}

	$self->[PATH_COMBO]->insert_text(0, $self->[FILEPATH]);
	$self->[PATH_COMBO]->set_active(0);
	$self->[STATUS]->set_text("$dirs_count directories and $files_count files: " . Filer::Tools->calculate_size($total_size));

	$self->[FILER]->{widgets}->{main_window}->set_title("$self->[FILEPATH] - Filer $self->[FILER]->{VERSION}");

# 	$t1 = [gettimeofday];
# 	$elapsed = tv_interval($t0,$t1);
# 	print "time to load $filepath: $elapsed\n";
}

sub select_dialog {
	my ($self,$type) = @_;
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_default_response('ok');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,0,1,5);

	$label = new Gtk2::Label;
	$hbox->pack_start($label,0,0,0);

	$entry = new Gtk2::Entry;
	$entry->set_activates_default(1);
	$entry->set_text("*");
	$hbox->pack_start($entry,0,0,0);

	if ($type == SELECT) {
		$dialog->set_title("Select Files");
		$label->set_text("Select: ");
	} else {
		$dialog->set_title("Unselect Files");
		$label->set_text("Unselect: ");
	}

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $str = $entry->get_text;

		$str =~ s/\//\\\//g;
		$str =~ s/\./\\./g;
		$str =~ s/\*/\.*/g;
		$str =~ s/\?/\./g;

		$self->[TREEMODEL]->foreach(sub {
			my $model = $_[0];
			my $iter = $_[2];
			my $item = $model->get($iter, COL_NAME);

			if ($item =~ /\A$str\Z/)  {
				if ($type == SELECT) {
					$self->[TREESELECTION]->select_iter($iter);
				}

				if ($type == UNSELECT) {
					$self->[TREESELECTION]->unselect_iter($iter);
				}
			}
		});
	}

	$dialog->destroy;
}

sub create_tar_gz_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive;

	$self->[VBOX]->set_sensitive(0);
	$archive->create_tar_gz_archive($self->[FILEPATH], $self->get_items);
	$self->[VBOX]->set_sensitive(1);

	$self->[FILER]->refresh_cb;
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive;

	$self->[VBOX]->set_sensitive(0);
	$archive->create_tar_bz2_archive($self->[FILEPATH], $self->get_items);
	$self->[VBOX]->set_sensitive(1);

	$self->[FILER]->refresh_cb;
}

sub extract_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive;

	$self->[VBOX]->set_sensitive(0);
	$archive->extract_archive($self->[FILEPATH], $self->get_items);
	$self->[VBOX]->set_sensitive(1);

	$self->[FILER]->refresh_cb;
}

sub get_temp_archive_dir {
	my ($self) = @_;
	my $dir = File::Temp::tempdir(CLEANUP => 1);
	my $tmp = File::Spec->tmpdir;

	$self->[OVERRIDES]->{$tmp} = $self->[FILEPATH];

	return $dir;
}

1;
