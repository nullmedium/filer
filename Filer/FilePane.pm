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
use File::Spec::Functions qw(catfile splitdir);
use Stat::lsMode qw(format_mode);

Memoize::memoize("File::MimeInfo::mimetype");
Memoize::memoize("File::MimeInfo::describe");
Memoize::memoize("format_mode");
Memoize::memoize("abs_path");
Memoize::memoize("catfile");
Memoize::memoize("splitdir");
Memoize::memoize("calculate_size");

use constant LEFT	=> 0;
use constant RIGHT	=> 1;

use constant SIDE			=> 0;
use constant FILEPATH			=> 1;
use constant VBOX			=> 2;
use constant TREEVIEW			=> 3;
use constant TREEMODEL			=> 4;
use constant TREESELECTION		=> 5;
use constant PATH_ENTRY			=> 6;
use constant SELECTED_ITEM		=> 7;
use constant SELECTED_ITER		=> 8;
use constant OVERRIDES			=> 10;
use constant MIMEICONS			=> 11;
use constant FOLDER_STATUS		=> 12;
use constant LOCATION_BAR_PARENT	=> 13;
use constant LOCATION_BAR		=> 14;
use constant NAVIGATION_BOX		=> 15;
use constant NAVIGATION_BUTTONS		=> 16;
use constant MOUSE_MOTION_SELECT	=> 17;
use constant MOUSE_MOTION_Y_POS_OLD	=> 18;

use constant SORT_COLUMN => 19;

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
		if ($main::config->get_option("Mode") == &main::EXPLORER_MODE) {
			$self->open_path_helper($self->get_updir);
		} else {
			$self->open_path($self->get_updir);
		}
	});
	$self->[LOCATION_BAR]->pack_start($button, 0, 1, 0);

	$self->[PATH_ENTRY] = new Gtk2::Entry;
	$self->[PATH_ENTRY]->signal_connect('key-press-event', sub {
		if ($_[1]->keyval == $Gtk2::Gdk::Keysyms{'Return'}) {
			$self->open_file($self->[PATH_ENTRY]->get_text);
		}
	});

	$self->[LOCATION_BAR]->pack_start($self->[PATH_ENTRY], 1, 1, 0);

	$button = new Gtk2::Button("Go");
	$button->signal_connect("clicked", sub {
		$self->open_file($self->[PATH_ENTRY]->get_text)
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
	$self->[TREEVIEW]->signal_connect("event", \&treeview_event_cb, $self);

	$self->[TREEMODEL] = new Gtk2::ListStore(
		'Glib::Object','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String',
		'Glib::String','Glib::Int','Glib::Int','Glib::Int','Glib::Int','Glib::Int' # hidden values;
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

		my $fp1 = $model->get($a, 9);
		my $fp2 = $model->get($b, 9);

		if (defined $fp1 and defined $fp2) {
			if (-d $fp1 and -f $fp2) {

				return ($order eq "ascending") ? -1 : 1;

			} elsif (-f $fp1 and -d $fp2) {

				return ($order eq "ascending") ? 1 : -1;

			} else {
				if ($sort_column_id == 2) { # size

					return ($model->get($a, 10) <=> $model->get($b, 10))

				} elsif ($sort_column_id == 4) { # date

					return ($model->get($a, 11) <=> $model->get($b, 11))

				} elsif ($sort_column_id == 5) { # owner

					return ($model->get($a, 12) <=> $model->get($b, 12))

				} elsif ($sort_column_id == 6) { # group

					return ($model->get($a, 13) <=> $model->get($b, 13))

				} elsif ($sort_column_id == 7) { # mode

					return ($model->get($a, 14) <=> $model->get($b, 14))

				} else {

					return ($model->get($a, $sort_column_id) cmp $model->get($b, $sort_column_id));
				}
			}
		}
	};

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_sort_column_id(1);
	$col->set_sort_indicator(1);
	$col->set_resizable(1);
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => 0);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => 1);

	$self->[TREEVIEW]->append_column($col);

	$self->[TREEMODEL]->set_sort_func(1, $sort_func); 

	$i = 2;
#	foreach (qw(Size Type Date Owner Group Mode Link d1 d2 d3 d4 d5 d6)) {
	foreach (qw(Size Type Date Owner Group Mode Link)) {
		$cell = new Gtk2::CellRendererText;
		$col = Gtk2::TreeViewColumn->new_with_attributes($_, $cell, text => $i);
		$col->set_sort_column_id($i);
		$col->set_sort_indicator(1);
		$col->set_clickable(1);
		$col->set_resizable(1);

		$self->[TREEMODEL]->set_sort_func($i, $sort_func); 
		$self->[TREEVIEW]->append_column($col);
		$i++; 
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
		{ path => '/Copy',			callback => \&main::copy_cb,				item_type => '<Item>'},
		{ path => '/Cut',			callback => \&main::cut_cb,				item_type => '<Item>'},
		{ path => '/Paste',			callback => \&main::paste_cb,				item_type => '<Item>'},
		{ path => '/sep2',								      		item_type => '<Separator>'},
#		{ path => '/Move',			callback => \&main::move_cb,				item_type => '<Item>'},
		{ path => '/Rename',			callback => \&main::rename_cb,				item_type => '<Item>'},
		{ path => '/MkDir',			callback => \&main::mkdir_cb,				item_type => '<Item>'},
		{ path => '/Delete',			callback => \&main::delete_cb,				item_type => '<Item>'},
		{ path => '/sep3',								      		item_type => '<Separator>'},
		{ path => '/Open Terminal',		callback => \&main::open_terminal_cb, item_type => '<Item>'},
		{ path => '/Archive/Create tar.gz',	callback => sub { $self->create_tar_gz_archive },	item_type => '<Item>'},
		{ path => '/Archive/Create tar.bz2',	callback => sub { $self->create_tar_bz2_archive },	item_type => '<Item>'},
		{ path => '/Archive/Gzip\/Gunzip',	callback => sub { $self->create_tar_gz_archive },	item_type => '<Item>'},
		{ path => '/Archive/Create tar.bz2',	callback => sub { $self->create_tar_bz2_archive },	item_type => '<Item>'},
		{ path => '/Archive/Extract',		callback => sub { $self->extract_archive },		item_type => '<Item>'},
		{ path => '/Bookmarks',								 		item_type => '<Item>'},		
		{ path => '/sep4',										item_type => '<Separator>'},
		{ path => '/Properties',		callback => sub { $self->set_properties },		item_type => '<Item>'},
	);

	$item_factory->create_items(undef, @menu_items);

	$item = $item_factory->get_item('/Bookmarks');
	$item->set_submenu(&main::get_bookmarks_menu);

	my ($p) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $self->[TREESELECTION]->path_is_selected($p)) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_path($p);
		}

		if (! defined $self->[SELECTED_ITEM]) {
			return;
		}

		my $mime = new Filer::Mime;
		my $type = File::MimeInfo::Magic::mimetype($self->[SELECTED_ITEM]);

		# Customize archive submenu
		if (! Filer::Archive::is_supported_archive($type)) {
			$item_factory->get_item('/Archive/Extract')->set_sensitive(0);
		}

		if ($self->count_selected_items == 1) {
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

	foreach (split /\n/, &main::get_clipboard_contents) { 
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

	$self->[SELECTED_ITER] = $self->get_selected_iters->[0];
	$self->[SELECTED_ITEM] = $self->get_selected_items->[0];

	if ($c > 1) {
		$main::widgets->{statusbar}->push(1, "$c files selected");
	}

	return 1;
}

sub treeview_grab_focus_cb {
	my ($w,$self) = @_;

	$main::active_pane = $self;
	$main::inactive_pane = $main::pane->[!$self->[SIDE]]; # the other side
}

sub treeview_event_cb {
	my ($w,$e,$self) = @_;

	$main::widgets->{statusbar}->push(1,$self->[FOLDER_STATUS]);

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'BackSpace'})) {
		if ($main::config->get_option("Mode") == &main::EXPLORER_MODE) {
			$self->open_path_helper($self->get_updir);
		} else {
			$self->open_path($self->get_updir);
		}

		return 1;
	}

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Delete'})) {
		&main::delete_cb;
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

		$self->set_focus;
		return 1;
	}

	if ($e->type eq "button-release" and $e->button == 2) {
		$self->[MOUSE_MOTION_SELECT] = 0;
		return 1;
	}

	if (($e->type eq "motion-notify") and ($self->[MOUSE_MOTION_SELECT] == 1)) {
		my ($p_old) = $self->[TREEVIEW]->get_path_at_pos($e->x,$self->[MOUSE_MOTION_Y_POS_OLD]);
		my ($p_new) = $self->[TREEVIEW]->get_path_at_pos($e->x,$e->y);

		if ((defined $p_old) and (defined $p_new)) {
			$self->[TREESELECTION]->unselect_all;
			$self->[TREESELECTION]->select_range($p_old,$p_new);
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

		for (0 .. 9) {
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

sub get_selected_item {
	my ($self) = @_;
	return $self->[SELECTED_ITEM];
}

sub set_selected_item {
	my ($self,$str) = @_;
	$self->[SELECTED_ITEM] = $str;
}

sub get_selected_iter {
	my ($self) = @_;
	return $self->[SELECTED_ITER];
}

sub get_selected_iters {
	my ($self) = @_;

	return [ map { $self->[TREEMODEL]->get_iter($_) } $self->[TREESELECTION]->get_selected_rows ];
}

sub get_selected_items {
	my ($self) = @_;

	return [ map { $self->[TREEMODEL]->get($_,9) } @{$self->get_selected_iters} ];
}

sub get_iter_by_treepath {
	my ($self,$p) = @_;
	return $self->[TREEMODEL]->get_iter($p);
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	return $self->[TREEMODEL]->get($self->[TREEMODEL]->get_iter($p), 9);
}

sub count_selected_items {
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

	foreach (@{$self->get_selected_iters}) {
		$self->[TREEMODEL]->remove($_) if (! -e $self->[TREEMODEL]->get($_, 9));
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

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if (-d $filepath) {
		if ($main::config->get_option("Mode") == &main::EXPLORER_MODE) {
			$self->open_path_helper($filepath);
		} else {
			$self->open_path($filepath);
		}
	} elsif (-x $filepath) {

		system("$filepath & exit");

	} else {
		my $type = File::MimeInfo::Magic::mimetype($filepath);
		my $mime = new Filer::Mime;

		$filepath = quotemeta($filepath);

                if (defined $mime->get_default_command($type)) {
                        my $command = $mime->get_default_command($type);
                        system("$command $filepath & exit");
		} else {
			if ($type =~ /^text\/.+/) {

				my $command = $main::config->get_option("Editor");
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
				$self->open_file_with;
			}
		}
	}
}

sub open_file_with {
	my ($self) = @_;
	my ($dialog,$table,$label,$button,$type_label,$cmd_browse_button,$remember_checkbutton,$run_terminal_checkbutton,$command_combo);

	return 0 if ((not defined $self->[SELECTED_ITEM]) or (not -R $self->[SELECTED_ITEM]) or (-l $self->[SELECTED_ITEM]));

	my $mime = new Filer::Mime;
	my $type = File::MimeInfo::Magic::mimetype($self->[SELECTED_ITEM]);

	$dialog = new Gtk2::Dialog("Open With", undef, 'modal', 'gtk-close' => 'close');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$table = new Gtk2::Table(3,3);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

	$label = new Gtk2::Label;
	$label->set_justify('left');
	$label->set_text("Type: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$type_label = new Gtk2::Label;
	$type_label->set_justify('left');
	$type_label->set_text($type);
	$type_label->set_alignment(0.0,0.0);
	$table->attach($type_label, 1, 3, 0, 1, [ "expand","fill" ], [], 0, 0);

	$label = new Gtk2::Label;
	$label->set_justify('left');
	$label->set_text("Command:");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$command_combo = new Gtk2::Combo;
	$command_combo->set_popdown_strings($mime->get_commands($type));
	$table->attach($command_combo, 1, 2, 1, 2, [ "expand","fill" ], [], 0, 0);

	$cmd_browse_button = new Gtk2::Button;
	$cmd_browse_button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
	$cmd_browse_button->signal_connect("clicked", sub {
		my $fs = new Gtk2::FileChooserDialog("Select Command", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		$fs->set_filename($command_combo->entry->get_text);

		if ($fs->run eq 'ok') {
			$command_combo->entry->set_text($fs->get_filename);
		}

		$fs->destroy;
	});
	$table->attach($cmd_browse_button, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$remember_checkbutton = new Gtk2::CheckButton("Remember application association for this type of file (sets default)");
	$dialog->vbox->pack_start($remember_checkbutton, 0,1,0);

	$run_terminal_checkbutton = new Gtk2::CheckButton("Run in Terminal");
	$dialog->vbox->pack_start($run_terminal_checkbutton, 0,1,0);

	$button = Filer::Dialog::mixed_button_new('gtk-ok',"_Run");
	$dialog->add_action_widget($button, 'ok');

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $command = $command_combo->entry->get_text;

		if ($remember_checkbutton->get_active) {
			$mime->set_default_command($type, $command);
		}

		if ($run_terminal_checkbutton->get_active) {
			my $term = $main::config->get_option("Terminal");
			$command = "$term -x $command";
		}
		
		system("$command '$self->[SELECTED_ITEM]' & exit");
	}

	$dialog->destroy;
}

sub open_terminal {
	my ($self) = @_;

	if (-d $self->[SELECTED_ITEM]) {
		my $path = $self->get_pwd;
		my $term = $main::config->get_option("Terminal");
		system("cd '$path' && $term & exit");
	}
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

	my $opt = $main::config->get_option("Mode");

	if ($opt == &main::NORTON_COMMANDER_MODE) {
		if (defined $self->[OVERRIDES]->{$filepath}) {
			$filepath = $self->[OVERRIDES]->{$filepath};
		}
	}

	opendir (DIR, $filepath) or return Filer::Dialog->msgbox_error("$filepath: $!");
	my @dir_contents = sort readdir(DIR);
	closedir(DIR);

	@dir_contents = File::Spec->no_upwards(@dir_contents);

# 	if ($opt == &main::NORTON_COMMANDER_MODE and $filepath ne File::Spec->rootdir) {
# 		@dir_contents = (File::Spec->updir, @dir_contents); 
# 	}

	delete $self->[SELECTED_ITEM];
	delete $self->[SELECTED_ITER];

	$self->[FILEPATH] = $filepath;
	$self->[TREEMODEL]->clear;

	$self->update_navigation_buttons($filepath);

	my $show_hidden = $main::config->get_option('ShowHiddenFiles');
	my @dirs = grep { -d "$filepath/$_" } @dir_contents;
	my @files = grep {! -d "$filepath/$_" } @dir_contents;

	my $total_size = 0;
	my $dirs_count_total = my $dirs_count = scalar @dirs;
	my $files_count_total = my $files_count = scalar @files;

	if ($show_hidden == 0) {
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
		next if ($file =~ /^\.+\w+/ and $show_hidden == 0);
		
		my $fp = catfile(splitdir($filepath), $file);
		my @stat = lstat($fp);
		my $type = (-l $fp) ? "inode/symlink" : File::MimeInfo::mimetype($fp);
		my $mypixbuf = $self->[MIMEICONS]->{'default'};

		my $size = calculate_size($stat[7]);
		my $ctime = localtime($stat[10]);
		my $uid = getpwuid($stat[4]);
		my $gid = getgrgid($stat[5]);
		my $mode = Stat::lsMode::format_mode($stat[2]);

		$total_size += $stat[7];

		my $abspath = abs_path($fp);
		my $target = readlink($fp);

		if (defined $self->[MIMEICONS]->{$type}) {
			$mypixbuf = $self->[MIMEICONS]->{$type};
		} else {
			my $mime = new Filer::Mime;
			$mime->add_mimetype($type);
			$self->init_icons();
		}

		$type = File::MimeInfo::describe($type);

		my $iter = $self->[TREEMODEL]->append; 

		$self->[TREEMODEL]->set($iter, 0, $mypixbuf, 1, $file, 2, $size, 3, $type, 4, $ctime, 5, $uid, 6, $gid, 7, $mode, 8, $target);  # shown
		$self->[TREEMODEL]->set($iter, 9, $abspath, 10, $stat[7], 11, $stat[10], 12, $stat[4], 13, $stat[5], 14, $stat[2]);		# hidden
	}

# 	if ($ENV{FILER_DEBUG}) {
# 		$t1 = [gettimeofday];
# 		$elapsed = tv_interval($t0,$t1);
# 		print "time to load: $elapsed\n";
# 	}

	$total_size = &calculate_size($total_size);

	$self->[TREEVIEW]->columns_autosize;

	$self->[TREEMODEL]->set_sort_column_id(1, "ascending"); 

	$self->[PATH_ENTRY]->set_text($self->[FILEPATH]);
	$self->[FOLDER_STATUS] = "$dirs_count ($dirs_count_total) directories and $files_count ($files_count_total) files: $total_size";
}

sub set_properties {
	my ($self) = @_;
	Filer::Properties->set_properties_dialog($self->[SELECTED_ITEM]);

	&main::refresh_cb; 
}

sub create_tar_gz_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_selected_items);
	$archive->create_tar_gz_archive;

	&main::refresh_cb; 
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_selected_items);
	$archive->create_tar_bz2_archive;

	&main::refresh_cb; 
}

sub extract_archive {
	my ($self) = @_;
	my $archive = new Filer::Archive($self->[FILEPATH], $self->get_selected_items);
	$archive->extract_archive;

	&main::refresh_cb; 
}

sub get_temp_archive_dir {
	my ($self) = @_;
	my $dir = File::Temp::tempdir(CLEANUP => 1);
	my $dir_up = abs_path(catfile(splitdir($dir), File::Spec->updir));

	# this overrides the path if the user clicks on the .. inside the temp archive directory
	$self->[OVERRIDES]->{$dir_up} = $self->[FILEPATH];

	return $dir;
}

sub calculate_size {
	my ($size) = @_;

	if ($size >= 1073741824) {
		return sprintf("%.2f GB", $size/1073741824);
	} elsif ($size >= 1048576) {
		return sprintf("%.2f MB", $size/1048576);
	} elsif ($size >= 1024) {
		return sprintf("%.2f kB", $size/1024);
	}

	return $size;
}

1;
