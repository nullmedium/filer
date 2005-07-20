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

use Cwd qw(abs_path);
use File::Basename; 

use Filer::Constants;
use Filer::DND;

use strict;
use warnings;

my $i = 0;

use constant FILER			=> $i++; # important. must be -> 0 <- !!!
use constant SIDE			=> $i++;
use constant FILEPATH			=> $i++;
use constant VBOX			=> $i++;
use constant TREEVIEW			=> $i++;
use constant TREEMODEL			=> $i++;
use constant TREESELECTION		=> $i++;
use constant PATH_COMBO			=> $i++;
use constant PATH_ENTRY			=> $i++;
use constant SELECTED_ITEM		=> $i++;
use constant SELECTED_ITER		=> $i++;
use constant OVERRIDES			=> $i++;
use constant MIMEICONS			=> $i++;
use constant FOLDER_STATUS		=> $i++;
use constant LOCATION_BAR_PARENT	=> $i++;
use constant LOCATION_BAR		=> $i++;
use constant NAVIGATION_BOX		=> $i++;
use constant NAVIGATION_BUTTONS		=> $i++;
use constant MOUSE_MOTION_SELECT	=> $i++;
use constant MOUSE_MOTION_Y_POS_OLD	=> $i++;

use constant SELECT => 0;
use constant UNSELECT => 1;

my $cols = 0; 

use constant COL_ICON => $cols++;
use constant COL_NAME => $cols++;
use constant COL_SIZE => $cols++;
use constant COL_MODE => $cols++;
use constant COL_TYPE => $cols++;
use constant COL_DATE => $cols++;
use constant COL_FILEINFO => $cols++;

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless [], $class;
	my ($hbox,$button,$scrolled_window,$col,$cell,$i);

	$self->[FILER] = $filer;
	$self->[SIDE] = $side;
	$self->[OVERRIDES] = {};
	$self->[MOUSE_MOTION_SELECT] = 0;

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
	$self->[PATH_COMBO]->signal_connect("changed", sub {
		my ($combo) = @_;
		return if ($combo->get_active == -1);
		$self->open_path_helper($combo->get_active_text);
	});

	$self->[PATH_ENTRY] = $self->[PATH_COMBO]->get_child;

	$self->[LOCATION_BAR]->pack_start($self->[PATH_COMBO], 1, 1, 0);

	$button = new Gtk2::Button("Go");
	$button->signal_connect("clicked", sub {
		$self->open_file($self->[PATH_COMBO]->get_active_text)
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

	$self->[TREEMODEL] = new Gtk2::ListStore(
	'Glib::Object','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String',
	'Glib::Scalar' # the Filer::FileInfo object
	);

	$self->[TREEVIEW]->set_model($self->[TREEMODEL]);

	# Drag and Drop
	my $dnd = new Filer::DND($self->[FILER],$self);
	$self->[TREEVIEW]->drag_dest_set('all', ['move','copy'], $dnd->target_table);
	$self->[TREEVIEW]->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $dnd->target_table);
	$self->[TREEVIEW]->signal_connect("drag_data_get", sub { $dnd->filepane_treeview_drag_data_get(@_) });
	$self->[TREEVIEW]->signal_connect("drag_data_received", sub { $dnd->filepane_treeview_drag_data_received(@_) });

	$self->[TREESELECTION] = $self->[TREEVIEW]->get_selection;
	$self->[TREESELECTION]->set_mode("multiple");
	$self->[TREESELECTION]->signal_connect("changed", sub { $self->selection_changed_cb(@_) });

	$scrolled_window->add($self->[TREEVIEW]);

	my $sort_func = sub {
		my ($model,$a,$b,$data) = @_;
#  		print "sort\n";
# 
#  		my ($sort_column_id,$order) = $model->get_sort_column_id; 
# 		my $s1 = $model->get($a, $sort_column_id); 
# 		my $s2 = $model->get($b, $sort_column_id); 
# 
# 		return ($s1 cmp $s2) if (defined $s1 and defined $s2);

		my ($sort_column_id,$order) = $model->get_sort_column_id; 

		my $fi1 = $model->get($a, COL_FILEINFO);
		my $fi2 = $model->get($b, COL_FILEINFO);

		return 0 if (not defined $fi1 or not defined $fi2);
		
		my $fp1 = $fi1->get_path;
		my $fp2 = $fi2->get_path;

		# 1) sort directories first
		# 2) then hidden items
		# 3) sort by size/mode/date
		# 4) if both items are equal, subsort by filename

		if ((defined $fp1 and -d $fp1) and (defined $fp2 and -f $fp2)) {

			return ($order eq "ascending") ? -1 : 1;
			
		} elsif ((defined $fp2 and -d $fp2) and (defined $fp1 and -f $fp1)) {

			return ($order eq "ascending") ? 1 : -1;

		} elsif ($fi1->is_hidden and !$fi2->is_hidden) {

			return ($order eq "ascending") ? -1 : 1;

		} elsif ($fi2->is_hidden and !$fi1->is_hidden) {

			return ($order eq "ascending") ? 1 : -1;
		} else {
			my ($s1,$s2,$s);

			# the sort on COL_NAME returns directly as it doesn't
			# need a sub-sort on itself....

			if ($sort_column_id == COL_NAME) { # size

				$s1 = $model->get($a, COL_NAME);
				$s2 = $model->get($b, COL_NAME);

				if ($self->[FILER]->{config}->get_option("CaseInsensitiveSort") == 0) {
					return ($s1 cmp $s2);
				} else {
					return (lc($s1) cmp lc($s2));
				}
			} elsif ($sort_column_id == COL_SIZE) { # size

				$s1 = $fi1->get_raw_size;
				$s2 = $fi2->get_raw_size;
				$s = $s1 - $s2;

			} elsif ($sort_column_id == COL_MODE) { # mode
			
				# do we need to use the numeric mode values to sort? 

				$s1 = $fi1->get_raw_mode;
				$s2 = $fi2->get_raw_mode;
				$s = $s1 - $s2;

			} elsif ($sort_column_id == COL_DATE) { # date

				$s1 = $fi1->get_raw_mtime;
				$s2 = $fi2->get_raw_mtime;
				$s = $s1 - $s2;

			} else { # currently this can only be the 'type' column and the type column doesn't need any special treatment:
				$s1 = $model->get($a, $sort_column_id); 
				$s2 = $model->get($b, $sort_column_id); 
				$s = ($s1 cmp $s2);
			}

			# sub-sort on the name column if the compared terms are equal:

			if ($s == 0) {
				$s1 = $model->get($a, COL_NAME);
				$s2 = $model->get($b, COL_NAME);

				if ($self->[FILER]->{config}->get_option("CaseInsensitiveSort") == 0) {
					return ($s1 cmp $s2);
				} else {
					return (lc($s1) cmp lc($s2));
				}
			} else {
				return $s;
			}
		}
	};

	# a column with a pixbuf renderer and a text renderer
	$col = new Gtk2::TreeViewColumn;
	$col->set_sort_column_id(1);
	$col->set_sort_indicator(1);
	$col->set_resizable(1);
	$col->set_title("Name");
	$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');

	$cell = new Gtk2::CellRendererPixbuf;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => COL_ICON);

	$cell = new Gtk2::CellRendererText;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => COL_NAME);

	$self->[TREEMODEL]->set_sort_func(COL_NAME, $sort_func); 
	$self->[TREEVIEW]->append_column($col);

	my %cols = (
		Size => COL_SIZE,
		Type => COL_TYPE,
		Mode => COL_MODE,
		Date => COL_DATE,
	);

	foreach my $name (sort {$cols{$a} <=> $cols{$b}} keys %cols) { 
		my $n = $cols{$name};

		$cell = new Gtk2::CellRendererText;
		$col = Gtk2::TreeViewColumn->new_with_attributes($name, $cell, text => $n);
		$col->set_sort_column_id($n);
		$col->set_sort_indicator(1);
		$col->set_resizable(1);
		$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');

		$self->[TREEMODEL]->set_sort_func($n, $sort_func); 
		$self->[TREEVIEW]->append_column($col);
	}

	$self->init_icons;

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
			my $fi = $self->[TREEMODEL]->get($self->[SELECTED_ITER], COL_FILEINFO);
			my $type = $fi->get_mimetype;

			# Customize archive submenu
			if (Filer::Archive::is_supported_archive($type)) {
				$uimanager->get_widget('/ui/list-popupmenu/archive-menu/Extract')->set_sensitive(1);
			} else {
				$uimanager->get_widget('/ui/list-popupmenu/archive-menu/Extract')->set_sensitive(0);
			}

			# add and create Open submenu
			my $commands_menu = new Gtk2::Menu;
			$item = $uimanager->get_widget('/ui/list-popupmenu/Open');
			$item->set_submenu($commands_menu);

			my $mime = new Filer::Mime;
			foreach ($mime->get_commands($type)) {
				$item = new Gtk2::MenuItem(basename($_));
				$item->signal_connect("activate", sub {
					my $command = $_[1];
					my $item = quotemeta($self->[SELECTED_ITEM]);
					system("$command $item & exit");
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

sub selection_changed_cb {
	my ($self,$selection) = @_;
	my $c = $selection->count_selected_rows;

	$self->[SELECTED_ITER] = $self->get_iters->[0];
	$self->[SELECTED_ITEM] = $self->get_items->[0];

	if ($c > 1) {
		$self->[FILER]->{widgets}->{statusbar}->push(1, "$c files selected");
	}

	return 1;
}

sub treeview_grab_focus_cb {
	my ($self,$w) = @_;

	$self->[FILER]->{active_pane} = $self;
	$self->[FILER]->{inactive_pane} = $self->[FILER]->{pane}->[!$self->[SIDE]]; # the other side
}

sub treeview_event_cb {
	my ($self,$w,$e) = @_;

	$self->[FILER]->{widgets}->{statusbar}->push(1,$self->[FOLDER_STATUS]);

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
		$self->open_file($self->[SELECTED_ITEM]);
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

		return 1;
	}

	if ($e->type eq "button-release" and $e->button == 2) {
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

		return 0;
	}

	if ($e->type eq "button-press" and $e->button == 3) {
		$self->show_popup_menu($e);
		return 1;
	}

	return 0;
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
	return Filer::Tools->catpath($self->[FILEPATH], File::Spec->updir);
}

sub get_item {
	my ($self) = @_;
	return $self->[SELECTED_ITEM];
}

sub set_item {
	my ($self,$fi) = @_;

	$self->[SELECTED_ITEM] = $fi->get_path;
	$self->[TREEMODEL]->set($self->[SELECTED_ITER], 
		COL_NAME, $fi->get_basename,
		COL_SIZE, $fi->get_size,
		COL_MODE, $fi->get_mode,
		COL_TYPE, $fi->get_mimetype,
		COL_DATE, $fi->get_mtime,
		COL_FILEINFO, $fi
	);
}

sub get_iter {
	my ($self) = @_;
	return $self->[SELECTED_ITER];
}

sub get_iters {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get_iter($_) } $self->[TREESELECTION]->get_selected_rows ];
}

sub get_items {
	my ($self) = @_;
	return [ map { ($self->[TREEMODEL]->get($_, COL_FILEINFO))->get_path } @{$self->get_iters} ];
}

sub get_fileinfo {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get($_, COL_FILEINFO) } @{$self->get_iters} ];
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
	$self->init_icons;
	$self->open_path($self->[FILEPATH]);
}

sub remove_selected {
	my ($self) = @_;

	foreach (@{$self->get_iters}) {
		$self->[TREEMODEL]->remove($_) if (! -e ($self->[TREEMODEL]->get($_, COL_FILEINFO))->get_path);
	}
}

sub update_navigation_buttons {
	my ($self,$filepath) = @_;
	my $rootdir = File::Spec->rootdir; 
	my $path = $rootdir;
	my $button = undef;

	foreach (reverse sort keys %{$self->[NAVIGATION_BUTTONS]}) {
		last if ($_ eq $filepath);

		if (! /^$filepath/) {
			$self->[NAVIGATION_BUTTONS]->{$_}->destroy;
			delete $self->[NAVIGATION_BUTTONS]->{$_};
		}
	}
	
	foreach (File::Spec->splitdir($filepath)) {
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
					$label->modify_font($fd);

					# avoid an endless loop/recursion. 
					$self->open_path($data) if ($data ne $self->get_pwd);
				} else {
					$fd->set_weight('PANGO_WEIGHT_NORMAL');
					$label->modify_font($fd);
				}
			}, abs_path($path));

			$self->[NAVIGATION_BOX]->pack_start($button,0,0,0);
			$self->[NAVIGATION_BUTTONS]->{$path} = $button;
			$self->[NAVIGATION_BUTTONS]->{$path}->show;
		}
	}

	# set last button active. current directory.
	$self->[NAVIGATION_BUTTONS]->{$filepath}->set(active => 1);
}

sub open_file {
	my ($self,$filepath) = @_;
	my $fileinfo = new Filer::FileInfo($filepath);

	$filepath = $fileinfo->get_path;

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if (-d $filepath) {
		$self->open_path_helper($filepath);
	} else {
		my $mime = new Filer::Mime($self->[FILER]);
		my $type = $fileinfo->get_mimetype;
		my $command = $mime->get_default_command($type); 

               if (defined $command) {
			if (-x $filepath) {
				my ($dialog,$label,$button);
				$filepath = quotemeta($filepath);

				$dialog = new Gtk2::Dialog("Filer", undef, 'modal');
				$dialog->set_position('center');
				$dialog->set_modal(1);

				$label = new Gtk2::Label;
				$label->set_use_markup(1);
				$label->set_markup("Execute or open the selected file?");
				$label->set_alignment(0.0,0.0);
				$dialog->vbox->pack_start($label, 1,1,5);

				$button = Filer::Dialog::mixed_button_new('gtk-ok',"_Run");
				$dialog->add_action_widget($button, 1);

				$button = Gtk2::Button->new_from_stock('gtk-open');
				$dialog->add_action_widget($button, 2);
			
				$dialog->show_all;
				my $r = $dialog->run;
				$dialog->destroy;

				if ($r eq 1) {
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
	                        system("$command $filepath & exit");

			} elsif ($type eq 'application/x-compressed-tar') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && tar -xzf $filepath");
				$self->open_path($dir);

			} elsif ($type eq 'application/x-bzip-compressed-tar') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && tar -xjf $filepath");
				$self->open_path($dir);

			} elsif ($type eq 'application/x-tar') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && tar -xf $filepath");
				$self->open_path($dir);

			} elsif ($type eq 'application/zip') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && unzip $filepath");
				$self->open_path($dir);

			} else {
				$mime->run_dialog($self->get_fileinfo->[0]);
			}
		}
	}
}

sub open_file_with {
	my ($self) = @_;

	return 0 if (not defined $self->[SELECTED_ITER]);

	my $mime = new Filer::Mime($self->[FILER]);
	my $fileinfo = $self->[TREEMODEL]->get($self->[SELECTED_ITER], 6);

	$mime->run_dialog($fileinfo);
}

sub open_path_helper {
	my ($self,$filepath) = @_;

	if (defined $self->[NAVIGATION_BUTTONS]->{$filepath}) {
		$self->[NAVIGATION_BUTTONS]->{$filepath}->set(active => 1);
	} else {
		$self->open_path($filepath);
	}
}

sub open_path {
	my ($self,$filepath) = @_;
	my ($t0,$t1,$elapsed);

# 	if ($ENV{FILER_DEBUG}) {
# 	 	use Time::HiRes qw(gettimeofday tv_interval);
# 	 	$t0 = [gettimeofday];
# 	}

	if (defined $self->[OVERRIDES]->{$filepath}) {
		$filepath = $self->[OVERRIDES]->{$filepath};
	}
	
	opendir (DIR, $filepath) or return Filer::Dialog->msgbox_error("$filepath: $!");
	my @dir_contents;

	# from right to left:
	# 1) readdir
	# 2) remove . and ..
	# 3) map (prepend) filepath to filename
	# 4) sort

	use sort '_mergesort';

	if ($self->[FILER]->{config}->get_option("CaseInsensitiveSort") == 0) {
		@dir_contents = sort {
			if (-d $a and -f $b) {
				return -1;
			} elsif (-f $a and -d $b) {
				return 1;
			}

			return ($a cmp $b);
		} map { Filer::Tools->catpath($filepath, $_) } File::Spec->no_upwards(readdir(DIR));
	} else {
		@dir_contents = sort {
			if (-d $a and -f $b) {
				return -1;
			} elsif (-f $a and -d $b) {
				return 1;
			}

			return (uc($a) cmp uc($b));
		} map { Filer::Tools->catpath($filepath, $_) } File::Spec->no_upwards(readdir(DIR));
	}
	
	closedir(DIR);

# 	if ($self->[FILER]->{config}->get_option("Mode") == NORTON_COMMANDER_MODE and $filepath ne File::Spec->rootdir) {
# 		@dir_contents = (File::Spec->updir, @dir_contents); 
# 	}

	delete $self->[SELECTED_ITEM];
	delete $self->[SELECTED_ITER];

	$self->[FILEPATH] = abs_path($filepath);

	my $show_hidden = $self->[FILER]->{config}->get_option('ShowHiddenFiles');
	my $total_size = 0;
 	my $dirs_count_total = my $dirs_count = 0; 
 	my $files_count_total = my $files_count = 0; 

	$self->[TREEMODEL]->clear;

	foreach my $fp (@dir_contents) {

		if (-d $fp) {
			$dirs_count_total++;

			if (!$show_hidden and basename($fp) =~ /^\./) {
				next;
			}

			$dirs_count++;
		} else {
			$files_count_total++;

			if (!$show_hidden and basename($fp) =~ /^\./) {
				next;
			}

			$files_count++;
		}

# 		$self->[TREEMODEL]->insert_with_values(-1, COL_FILEINFO, new Filer::FileInfo($fp));
# 		while (Gtk2->events_pending) { Gtk2->main_iteration; }

		my $fi = new Filer::FileInfo($fp);
		my $type = $fi->get_mimetype;
		my $mypixbuf = $self->[MIMEICONS]->{'default'};

		if (defined $self->[MIMEICONS]->{$type}) {
			$mypixbuf = $self->[MIMEICONS]->{$type};
		} else {
			my $mime = new Filer::Mime($self->[FILER]);
			$mime->add_mimetype($type);
			$self->init_icons();
		}

		$total_size += $fi->get_raw_size;

		my $basename = $fi->get_basename;
		my $size = $fi->get_size;
		my $mode = $fi->get_mode;
		my $time = $fi->get_mtime;

 		$self->[TREEMODEL]->insert_with_values(-1,
			COL_ICON, $mypixbuf,
			COL_NAME, $basename,
			COL_SIZE, $size, 
			COL_MODE, $mode,
			COL_TYPE, $type,
			COL_DATE, $time,
			COL_FILEINFO, $fi
		);
	}

	$total_size = Filer::Tools->calculate_size($total_size);
	
	$self->[PATH_ENTRY]->set_text($self->[FILEPATH]);
	$self->[PATH_COMBO]->insert_text(0, $self->[FILEPATH]);
	$self->[FOLDER_STATUS] = "$dirs_count ($dirs_count_total) directories and $files_count ($files_count_total) files: $total_size";
	$self->update_navigation_buttons($filepath);

# 	if ($ENV{FILER_DEBUG}) {
# 		$t1 = [gettimeofday];
# 		$elapsed = tv_interval($t0,$t1);
# 		print "time to load $filepath: $elapsed\n";
# 	}

#	$self->treemodel_sort;
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
#		my $bx = (split //, $str)[0];

		$str =~ s/\//\\\//g;
		$str =~ s/\./\\./g;
		$str =~ s/\*/\.*/g;
		$str =~ s/\?/\./g;

		$self->[TREEMODEL]->foreach(sub {
			my $model = $_[0];
			my $iter = $_[2];
			my $item = $model->get($iter, COL_NAME);

# 			if (-d $mypane->get_path($item)) {
# 				if ($bx eq '/') {
# 					$item = "/$item";
# 				} else {
# 					return 0;
# 				}
# 			}

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
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_items);
	$archive->create_tar_gz_archive;

	$self->[FILER]->refresh_cb; 
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_items);
	$archive->create_tar_bz2_archive;

	$self->[FILER]->refresh_cb; 
}

sub extract_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_items);
	$archive->extract_archive;

	$self->[FILER]->refresh_cb; 
}

sub get_temp_archive_dir {
	my ($self) = @_;
	my $dir = File::Temp::tempdir(CLEANUP => 1);
	my $dir_up = Filer::Tools->catpath($dir, File::Spec->updir);

	# this overrides the path if the user clicks on the .. inside the temp archive directory
	$self->[OVERRIDES]->{$dir_up} = $self->[FILEPATH];

	return $dir;
}

1;
