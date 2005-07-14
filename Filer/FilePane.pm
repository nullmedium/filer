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

# use strict;
# use warnings;

use Cwd qw(abs_path);
use File::Basename; 
use File::Spec::Functions qw(catfile splitdir);

use Filer;
use Filer::Constants;
our @ISA = qw(Filer);

use Filer::DND;

my $i = 0;

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
use constant MOUSE_MOTION_TREEPATH_BEGIN => $i++; 

my $cols = 0; 

use constant COL_ICON => $cols++;
use constant COL_NAME => $cols++;
use constant COL_SIZE => $cols++;
use constant COL_MODE => $cols++;
use constant COL_TYPE => $cols++;
use constant COL_DATE => $cols++;
use constant COL_FILEINFO => $cols++;

Memoize::memoize("abs_path");
Memoize::memoize("catfile");
Memoize::memoize("splitdir");

sub new {
	my ($class,$side) = @_;
	my $self = bless [], $class;
	my ($hbox,$button,$scrolled_window,$col,$cell,$i);

	$self->[SIDE] = $side;
	$self->[OVERRIDES] = {};

	$self->[VBOX] = new Gtk2::VBox(0,0);

	$self->[LOCATION_BAR_PARENT] = new Gtk2::HBox(0,0);
	$self->[VBOX]->pack_start($self->[LOCATION_BAR_PARENT], 0, 1, 0);

	$self->[LOCATION_BAR] = new Gtk2::HBox(0,0);
	$self->[LOCATION_BAR_PARENT]->pack_start($self->[LOCATION_BAR], 1, 1, 0);

	$button = new Gtk2::Button("Up");
	$button->signal_connect("clicked", sub {
		if ($config->get_option("Mode") == EXPLORER_MODE) {
			$self->open_path_helper($self->get_updir);
		} else {
			$self->open_path($self->get_updir);
		}
	});
	$self->[LOCATION_BAR]->pack_start($button, 0, 1, 0);

	$self->[PATH_COMBO] = Gtk2::ComboBoxEntry->new_text;
	$self->[PATH_COMBO]->signal_connect("changed", sub {
		my ($combo) = @_;
		return if ($combo->get_active == -1);

		if ($config->get_option("Mode") == EXPLORER_MODE) {
			$self->open_path_helper($combo->get_active_text);
		} else {
			$self->open_path($combo->get_active_text);
		}
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
 	$self->[TREEVIEW]->signal_connect("grab-focus", \&treeview_grab_focus_cb, $self);
	$self->[TREEVIEW]->signal_connect("key-press-event", \&treeview_event_cb, $self);
	$self->[TREEVIEW]->signal_connect("button-press-event", \&treeview_event_cb, $self);
	$self->[TREEVIEW]->signal_connect("button-release-event", \&treeview_event_cb, $self);
	$self->[TREEVIEW]->signal_connect("motion-notify-event", \&treeview_event_cb, $self);

	$self->[TREEMODEL] = new Gtk2::ListStore(
	'Glib::Object','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String',
	'Glib::Scalar' # the Filer::FileInfo object
	);

	$self->[TREEVIEW]->set_model($self->[TREEMODEL]);

	# Drag and Drop
	$self->[TREEVIEW]->drag_dest_set('all', ['move','copy'], &Filer::DND::target_table);
	$self->[TREEVIEW]->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], &Filer::DND::target_table);

	$self->[TREEVIEW]->signal_connect("drag_data_get", \&Filer::DND::filepane_treeview_drag_data_get_cb, $self);
	$self->[TREEVIEW]->signal_connect("drag_data_received", \&Filer::DND::filepane_treeview_drag_data_received_cb, $self);

	$self->[TREESELECTION] = $self->[TREEVIEW]->get_selection;
	$self->[TREESELECTION]->set_mode("multiple");
	$self->[TREESELECTION]->signal_connect("changed", \&selection_changed_cb, $self);

	$scrolled_window->add($self->[TREEVIEW]);

	my $sort_func = sub {
		my ($model,$a,$b,$data) = @_;
		my ($sort_column_id,$order) = $model->get_sort_column_id; 

		my $fi1 = $model->get($a, COL_FILEINFO);
		my $fi2 = $model->get($b, COL_FILEINFO);

		return 0 if (not defined $fi1 and not defined $fi2);
		
		my $fp1 = $fi1->get_path_latin1;
		my $fp2 = $fi2->get_path_latin1;
	
		if (defined $fp1 and -d $fp1) {

			return ($order eq "ascending") ? -1 : 1;

		} elsif (defined $fp2 and -d $fp2) {

			return ($order eq "ascending") ? 1 : -1;

		} else {
			if ($sort_column_id == COL_SIZE) { # size

				my $s1 = $fi1->get_raw_size;
				my $s2 = $fi2->get_raw_size;

				return $s1 - $s2;

			} elsif ($sort_column_id == COL_MODE) { # mode

				my $s1 = $fi1->get_raw_mode;
				my $s2 = $fi2->get_raw_mode;

				return $s1 - $s2;

			} elsif ($sort_column_id == COL_DATE) { # date

				my $s1 = $fi1->get_raw_mtime;
				my $s2 = $fi2->get_raw_mtime;

				return $s1 - $s2;

			} else {
				my $s1 = $model->get($a, $sort_column_id); 
				my $s2 = $model->get($b, $sort_column_id); 

				if (defined $s1 and defined $s2) {
					return ($s1 cmp $s2);
				}
			}
		}
	};

	# a column with a pixbuf renderer and a text renderer
	$col = new Gtk2::TreeViewColumn;
	$col->set_sort_column_id(1);
	$col->set_sort_indicator(1);
	$col->set_resizable(1);
	$col->set_title("Name");

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
		Mode => COL_MODE,
		Type => COL_TYPE,
		Date => COL_DATE,
	);

	while (my ($name,$n) = each %cols) { 
		$cell = new Gtk2::CellRendererText;
		$col = Gtk2::TreeViewColumn->new_with_attributes($name, $cell, text => $n);
		$col->set_sort_column_id($n);
		$col->set_sort_indicator(1);
		$col->set_resizable(1);

		$self->[TREEMODEL]->set_sort_func($n, $sort_func); 
		$self->[TREEVIEW]->append_column($col);
	}

	$self->init_icons;

	$self->[MOUSE_MOTION_SELECT] = 0;

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
	my $item_factory = new Gtk2::ItemFactory("Gtk2::Menu", '<main>', undef);
	my $popup_menu = $item_factory->get_widget('<main>');

	my @menu_items = (
		{ path => '/Open',										item_type => '<Item>'},
		{ path => '/sep1',								      		item_type => '<Separator>'},
		{ path => '/Copy',			callback => \&Filer::copy_cb,				item_type => '<Item>'},
		{ path => '/Cut',			callback => \&Filer::cut_cb,				item_type => '<Item>'},
		{ path => '/Paste',			callback => \&Filer::paste_cb,				item_type => '<Item>'},
		{ path => '/sep2',								      		item_type => '<Separator>'},
#		{ path => '/Move',			callback => \&Filer::move_cb,				item_type => '<Item>'},
		{ path => '/Rename',			callback => \&Filer::rename_cb,				item_type => '<Item>'},
		{ path => '/MkDir',			callback => \&Filer::mkdir_cb,				item_type => '<Item>'},
		{ path => '/Delete',			callback => \&Filer::delete_cb,				item_type => '<Item>'},
		{ path => '/sep3',								      		item_type => '<Separator>'},
		{ path => '/Open Terminal',		callback => \&Filer::open_terminal_cb, item_type => '<Item>'},
		{ path => '/Archive/Create tar.gz',	callback => sub { $self->create_tar_gz_archive },	item_type => '<Item>'},
		{ path => '/Archive/Create tar.bz2',	callback => sub { $self->create_tar_bz2_archive },	item_type => '<Item>'},
		{ path => '/Archive/Extract',		callback => sub { $self->extract_archive },		item_type => '<Item>'},
		{ path => '/Bookmarks',								 		item_type => '<Item>'},		
		{ path => '/sep4',										item_type => '<Separator>'},
		{ path => '/Properties',		callback => sub { $self->set_properties },		item_type => '<Item>'},
	);

	$item_factory->create_items(undef, @menu_items);

	$item = $item_factory->get_item('/Bookmarks');
	$item->set_submenu((new Filer::Bookmarks)->bookmarks_menu);

	my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $self->[TREESELECTION]->path_is_selected($p)) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_path($p);
		}

		my $mime = new Filer::Mime;
		my $fi = $self->[TREEMODEL]->get($self->[SELECTED_ITER], COL_FILEINFO);
		my $type = $fi->get_mimetype;

		# Customize archive submenu
		if (! Filer::Archive::is_supported_archive($type)) {
			$item_factory->get_item('/Archive/Extract')->set_sensitive(0);
		}

		if ($self->count_items == 1) {
			my $commands_menu = new Gtk2::Menu;
			$item = $item_factory->get_item('/Open');
			$item->set_submenu($commands_menu);

			foreach ($mime->get_commands($type)) {
				$item = new Gtk2::MenuItem(File::Basename::basename($_));
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
		} else {		
			$item_factory->get_item('/Open')->set_sensitive(0);
			$item_factory->get_item('/Rename')->set_sensitive(0);			
		}
	} else {		
		$item_factory->get_item('/Open')->set_sensitive(0);
		$item_factory->get_item('/Rename')->set_sensitive(0);
		$item_factory->get_item('/Delete')->set_sensitive(0);
		$item_factory->get_item('/Copy')->set_sensitive(0);
		$item_factory->get_item('/Cut')->set_sensitive(0);
		$item_factory->get_item('/Archive')->set_sensitive(0);
		$item_factory->get_item('/Properties')->set_sensitive(0);
	}

	my $hide_paste = 1;

	foreach (split /\n/, &Filer::get_clipboard_contents) { 
		$hide_paste = 0 if (-e $_);
	}
	
	if ($hide_paste) {
		$item_factory->get_item('/Paste')->set_sensitive(0);
	}

	$popup_menu->show_all;
	$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
}

sub selection_changed_cb {
	my ($selection,$self) = @_;
	my $c = $selection->count_selected_rows;

	$self->[SELECTED_ITER] = $self->get_iters->[0];
	$self->[SELECTED_ITEM] = $self->get_items->[0];

	if ($c > 1) {
		$widgets->{statusbar}->push(1, "$c files selected");
	}

	return 1;
}

sub treeview_grab_focus_cb {
	my ($w,$self) = @_;

	$active_pane = $self;
	$inactive_pane = $pane->[!$self->[SIDE]]; # the other side
}

sub treeview_event_cb {
	my ($w,$e,$self) = @_;

	$widgets->{statusbar}->push(1,$self->[FOLDER_STATUS]);

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'BackSpace'})) {
		if ($config->get_option("Mode") == EXPLORER_MODE) {
			$self->open_path_helper($self->get_updir);
		} else {
			$self->open_path($self->get_updir);
		}

		return 1;
	}

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Delete'})) {
		&Filer::delete_cb;
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
		($self->[MOUSE_MOTION_TREEPATH_BEGIN]) = $self->[TREEVIEW]->get_path_at_pos($e->x,$self->[MOUSE_MOTION_Y_POS_OLD]);

		my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

		if (defined $p) {
 			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_path($p);
		}

		$self->set_focus;
		return 1;
	}

	if ($e->type eq "button-release" and $e->button == 2) {
		$self->[MOUSE_MOTION_SELECT] = 0;
		return 1;
	}

	if (($e->type eq "motion-notify") and ($self->[MOUSE_MOTION_SELECT] == 1)) {
#		my ($p_old) = $self->[TREEVIEW]->get_path_at_pos($e->x,$self->[MOUSE_MOTION_Y_POS_OLD]);
		my ($p_new) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

		if (defined $self->[MOUSE_MOTION_TREEPATH_BEGIN] and defined $p_new) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_range($self->[MOUSE_MOTION_TREEPATH_BEGIN],$p_new);
		}

		return 0;
	}

	if ($e->type eq "button-press" and $e->button == 3) {
		$self->set_focus;
		$self->show_popup_menu($e);
		return 1;
	}

	return 0;
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
	return abs_path(catfile(splitdir($self->[FILEPATH]), File::Spec->updir));
}

sub get_item {
	my ($self) = @_;
	return $self->[SELECTED_ITEM];
}

sub set_item {
	my ($self,$fi) = @_;

	$self->[SELECTED_ITEM] = $fi->get_path_latin1;
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
	return [ map { ($self->[TREEMODEL]->get($_, COL_FILEINFO))->get_path_latin1 } @{$self->get_iters} ];
}

sub get_fileinfo {
	my ($self) = @_;
	return [ map { $self->[TREEMODEL]->get($_, COL_FILEINFO) } @{$self->get_iters} ];
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	return ($self->[TREEMODEL]->get($self->[TREEMODEL]->get_iter($p), COL_FILEINFO))->get_path_latin1;
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
		$self->[TREEMODEL]->remove($_) if (! -e ($self->[TREEMODEL]->get($_, COL_FILEINFO))->get_path_latin1);
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
	
	foreach (splitdir($filepath)) {
		$path = catfile(splitdir($path), $_);
		
		if (not defined $self->[NAVIGATION_BUTTONS]->{$path}) {
			$button = new Gtk2::RadioButton($self->[NAVIGATION_BUTTONS]->{$rootdir}, basename($path));
			$button->set(draw_indicator => 0); # i'm evil

			$button->signal_connect(toggled => sub {
				my ($widget, $data) = @_;
				my @w = $widget->get_children;

				if ($widget->get_active) {
					if ($data eq $rootdir and $] <= 5.008007) {
						$w[0]->set_markup("<b>$rootdir</b>");
					} else {
						$w[0]->set_markup(sprintf("<b>%s</b>", basename($data)));
					}

					# avoid an endless loop/recursion. 
					$self->open_path($data) if ($data ne $self->get_pwd);
				} else {
					if ($data eq $rootdir and $] <= 5.008007) {
						$w[0]->set_text($rootdir);
					} else {
						$w[0]->set_text(basename($data));
					}
				}
			}, $path);

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

	$filepath = $fileinfo->get_path_latin1;

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if (-d $filepath) {
		if ($config->get_option("Mode") == EXPLORER_MODE) {
			$self->open_path_helper($filepath);
		} else {
			$self->open_path($filepath);
		}
	} else {
		my $mime = new Filer::Mime;
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

				$button = Filer::Dialog::mixed_button_new('gtk-open',"_Open");
				$dialog->add_action_widget($button, 2);
			
				$dialog->show_all;
				my $r = $dialog->run;
				$dialog->destroy;

				if ($r eq 1) {
					system("$filepath & exit");
				} elsif ($r eq 2) {
 					system("$command $filepath & exit");
				}
			} else {
				system("$command $filepath & exit");
			}
		} else {
			if (-x $filepath) {
				$filepath = quotemeta($filepath);

				system("$filepath & exit");
				return;
			}
	
			if ($type =~ /^text\/.+/) {

				my $command = $config->get_option("Editor");
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

	my $mime = new Filer::Mime;
	my $fileinfo = $self->[TREEMODEL]->get($self->[SELECTED_ITER], 6);

	$mime->run_dialog($fileinfo);
}

sub open_path_helper {
	my ($self,$filepath) = @_;

	if (defined $self->[NAVIGATION_BUTTONS]->{$filepath}) {
		$self->[NAVIGATION_BUTTONS]->{$filepath}->set(active => 1);
		my @w = $self->[NAVIGATION_BUTTONS]->{$filepath}->get_children();

		if ($filepath eq File::Spec->rootdir and $] <= 5.008007) {
			$w[0]->set_markup(sprintf("<b>%s</b>", File::Spec->rootdir));
		} else {
			$w[0]->set_markup(sprintf("<b>%s</b>", File::Basename::basename($filepath)));
		}
	} else {
		$self->open_path($filepath);
	}
}

sub open_path {
	my ($self,$filepath) = @_;

	if (! -e $filepath) {
		$filepath = $ENV{HOME};
	}

	my $opt = $config->get_option("Mode");

	if ($opt == NORTON_COMMANDER_MODE) {
		if (defined $self->[OVERRIDES]->{$filepath}) {
			$filepath = $self->[OVERRIDES]->{$filepath};
		}
	}

	opendir (DIR, $filepath) or return Filer::Dialog->msgbox_error("$filepath: $!");
	my @dir_contents = sort readdir(DIR);
	closedir(DIR);

	@dir_contents = File::Spec->no_upwards(@dir_contents);

# 	if ($opt == NORTON_COMMANDER_MODE and $filepath ne File::Spec->rootdir) {
# 		@dir_contents = (File::Spec->updir, @dir_contents); 
# 	}

	delete $self->[SELECTED_ITEM];
	delete $self->[SELECTED_ITER];

	$self->[FILEPATH] = $filepath;
	$self->[TREEMODEL]->clear;

	$self->update_navigation_buttons($filepath);

	my $show_hidden = $config->get_option('ShowHiddenFiles');
	my @dirs = grep { -d "$filepath/$_" } @dir_contents;
	my @files = grep {! -d "$filepath/$_" } @dir_contents;

	my $total_size = 0;
	my $dirs_count_total = my $dirs_count = scalar @dirs;
	my $files_count_total = my $files_count = scalar @files;

	if (!$show_hidden) {
		$dirs_count = $dirs_count_total - scalar(grep { $_ =~ /^\.+\w+/ } @dirs);
		$files_count = $files_count_total - scalar(grep { $_ =~ /^\.+\w+/ } @files);
	}

# 	my ($t0,$t1,$elapsed);
#
# 	if ($ENV{FILER_DEBUG}) {
# 	 	use Time::HiRes qw( gettimeofday tv_interval );
# 	 	$t0 = [gettimeofday];
# 	}

	foreach my $file (@dirs,@files) {
		next if ($file =~ /^\.+\w+/ and !$show_hidden);

		my $fp = catfile(splitdir($filepath), $file);
		my $fi = new Filer::FileInfo($fp);

		my $type = $fi->get_mimetype;
		my $mypixbuf = $self->[MIMEICONS]->{'default'};

		if (defined $self->[MIMEICONS]->{$type}) {
			$mypixbuf = $self->[MIMEICONS]->{$type};
		} else {
			(new Filer::Mime)->add_mimetype($type);
			$self->init_icons();
		}

		my $time = $fi->get_mtime;
		my $mode = $fi->get_mode;
		my $size = $fi->get_size;

 		$self->[TREEMODEL]->set($self->[TREEMODEL]->append,
			COL_ICON, $mypixbuf,
			COL_NAME, $file,
			COL_SIZE, $size, 
			COL_MODE, $mode,
			COL_TYPE, $type,
			COL_DATE, $time,
			COL_FILEINFO, $fi
		);
	}

# 	if ($ENV{FILER_DEBUG}) {
# 		$t1 = [gettimeofday];
# 		$elapsed = tv_interval($t0,$t1);
# 		print "time to load: $elapsed\n";
# 	}

	$total_size = Filer::Tools->calculate_size($total_size);

	$self->[TREEVIEW]->columns_autosize;

	$self->[PATH_ENTRY]->set_text($self->[FILEPATH]);
	$self->[PATH_COMBO]->insert_text(0, $self->[FILEPATH]);
	$self->[FOLDER_STATUS] = "$dirs_count ($dirs_count_total) directories and $files_count ($files_count_total) files: $total_size";
}

sub set_properties {
	my ($self) = @_;
	Filer::Properties->set_properties_dialog($self->[SELECTED_ITEM]);
}

sub create_tar_gz_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_items);
	$archive->create_tar_gz_archive;

	&Filer::refresh_cb; 
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_items);
	$archive->create_tar_bz2_archive;

	&Filer::refresh_cb; 
}

sub extract_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_items);
	$archive->extract_archive;

	&Filer::refresh_cb; 
}

sub get_temp_archive_dir {
	my ($self) = @_;
	my $dir = File::Temp::tempdir(CLEANUP => 1);
	my $dir_up = abs_path(catfile(splitdir($dir), File::Spec->updir));

	# this overrides the path if the user clicks on the .. inside the temp archive directory
	$self->[OVERRIDES]->{$dir_up} = $self->[FILEPATH];

	return $dir;
}

1;
