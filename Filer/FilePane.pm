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

use constant LEFT	=> 0;
use constant RIGHT	=> 1;

use constant SIDE		=> 0;
use constant FILEPATH		=> 1;
use constant VBOX		=> 2;
use constant TREEVIEW		=> 3;
use constant TREEMODEL		=> 4;
use constant TREESELECTION	=> 5;
use constant PATH_ENTRY		=> 6;
use constant SELECTED_ITEM	=> 7;
use constant SELECTED_ITER	=> 8;
use constant OVERRIDES		=> 10;
use constant MIMEICONS		=> 11;
use constant FOLDER_STATUS	=> 12;

use constant LOCATION_BAR	=> 13;
use constant HBOX		=> 14;

Memoize::memoize("calculate_size");
Memoize::memoize("Stat::lsMode::format_mode");
Memoize::memoize("File::MimeInfo::mimetype");
Memoize::memoize("File::MimeInfo::describe");
Memoize::memoize("Cwd::abs_path");

sub new {
	my ($class,$side) = @_;
	my $self = bless [], $class;
	my ($hbox,$button,$scrolled_window,$col,$cell,$i);

	$self->[SIDE] = $side;
	$self->[OVERRIDES] = {};

	$self->[VBOX] = new Gtk2::VBox(0,0);

	$self->[LOCATION_BAR] = new Gtk2::HBox(0,0);
	$self->[VBOX]->pack_start($self->[LOCATION_BAR], 0, 1, 0);

	$self->[HBOX] = new Gtk2::HBox(0,0);
	$self->[LOCATION_BAR]->pack_start($self->[HBOX], 1, 1, 0);

	$button = new Gtk2::Button("Up");
	$button->signal_connect("clicked", sub {
		$self->open_path(Cwd::abs_path($self->[FILEPATH] . "/.."));
	});
	$self->[HBOX]->pack_start($button, 0, 1, 0);

	$self->[PATH_ENTRY] = new Gtk2::Entry;
	$self->[PATH_ENTRY]->signal_connect('key-press-event', sub {
		if ($_[1]->keyval == $Gtk2::Gdk::Keysyms{'Return'}) {
			$self->open_file($self->[PATH_ENTRY]->get_text);
		}
	});

	$self->[PATH_ENTRY]->drag_source_set(['button1_mask', 'button3_mask'], ['copy', 'move'], &Filer::DND::target_table);
	$self->[PATH_ENTRY]->drag_dest_set('all', ['copy', 'move'], &Filer::DND::target_table);
	$self->[PATH_ENTRY]->signal_connect("drag_data_get", \&Filer::DND::filepane_path_entry_drag_data_get_cb, $self);
	$self->[PATH_ENTRY]->signal_connect("drag_data_received", \&Filer::DND::filepane_path_entry_drag_data_received_cb, $self);

	$self->[HBOX]->pack_start($self->[PATH_ENTRY], 1, 1, 0);

	$button = new Gtk2::Button("Go");
	$button->signal_connect("clicked", sub {
		$self->open_file($self->[PATH_ENTRY]->get_text)
	});
	$self->[HBOX]->pack_start($button, 0, 1, 0);

	$scrolled_window = new Gtk2::ScrolledWindow;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$self->[VBOX]->pack_start($scrolled_window, 1, 1, 0);

	$self->[TREEVIEW] = new Gtk2::TreeView;
	$self->[TREEVIEW]->set_rules_hint(1);
	$self->[TREEVIEW]->signal_connect("grab-focus", \&treeview_grab_focus_cb, $self);
	$self->[TREEVIEW]->signal_connect("key-press-event", \&treeview_event_cb, $self);
	$self->[TREEVIEW]->signal_connect("button-press-event", \&treeview_event_cb, $self);

	$self->[TREEMODEL] = new Gtk2::ListStore('Glib::Object','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String','Glib::String');
	$self->[TREEVIEW]->set_model($self->[TREEMODEL]);

	# Drag and Drop
	$self->[TREEVIEW]->drag_source_set(['button1_mask', 'button3_mask'], ['copy', 'move'], &Filer::DND::target_table);
	$self->[TREEVIEW]->drag_dest_set('all', ['copy', 'move'], &Filer::DND::target_table);
	$self->[TREEVIEW]->signal_connect("drag_data_get", \&Filer::DND::filepane_treeview_drag_data_get_cb, $self);
	$self->[TREEVIEW]->signal_connect("drag_data_received", \&Filer::DND::filepane_treeview_drag_data_received_cb, $self);

	$self->[TREESELECTION] = $self->[TREEVIEW]->get_selection;
	$self->[TREESELECTION]->set_mode("multiple");
	$self->[TREESELECTION]->signal_connect("changed", \&selection_changed_cb, $self);

	$scrolled_window->add($self->[TREEVIEW]);

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_resizable(1);
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => 0);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => 1);

	$self->[TREEVIEW]->append_column($col);

	$i = 2;
	foreach (qw(Type Size Date Owner Group Mode Link)) {
		$cell = new Gtk2::CellRendererText;
		$col = Gtk2::TreeViewColumn->new_with_attributes($_, $cell, text => $i++);
		$col->set_resizable(1);
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
	return $self->[LOCATION_BAR];
}

sub get_location_bar {
	my ($self) = @_;
	return $self->[HBOX];
}

sub show_popup_menu {
	my ($self,$e) = @_;

	return if ($self->count_selected_items == 0);

	my $item;
	my $item_factory = new Gtk2::ItemFactory("Gtk2::Menu", '<main>', undef);
	my $popup_menu = $item_factory->get_widget('<main>');
	my $commands_menu = new Gtk2::Menu;

	my @menu_items = (
	{ path => '/Copy',					callback => \&main::copy_cb,				item_type => '<Item>'},
	{ path => '/Move',					callback => \&main::move_cb,				item_type => '<Item>'},
	{ path => '/Rename',					callback => \&main::rename_cb,				item_type => '<Item>'},
	{ path => '/MkDir',					callback => \&main::mkdir_cb,				item_type => '<Item>'},
	{ path => '/Delete',					callback => \&main::delete_cb,		        	item_type => '<Item>'},
	{ path => '/sep1',								        			item_type => '<Separator>'},
	{ path => '/Bookmarks',												item_type => '<Item>'},
	{ path => '/sep2',								        			item_type => '<Separator>'},
	{ path => '/Open',												item_type => '<Item>'},
	{ path => '/Open Terminal',				callback => sub { $self->open_terminal },	        item_type => '<Item>'},
	{ path => '/Archive/Create gzipped tar Archive',	callback => sub { $self->create_tar_gz_archive },	item_type => '<Item>'},
	{ path => '/Archive/Create bzipped tar Archive',	callback => sub { $self->create_tar_bz2_archive },	item_type => '<Item>'},
	{ path => '/Archive/Extract',				callback => sub { $self->extract_archive },	        item_type => '<Item>'},
	{ path => '/sep3',								       				item_type => '<Separator>'},
	{ path => '/Refresh',					callback => sub { $self->refresh },		        item_type => '<Item>'},
	{ path => '/sep4',									       			item_type => '<Separator>'},
	{ path => '/Properties',				callback => sub { $self->set_properties },	        item_type => '<Item>'},
	{ path => '/Set Icon',					callback => sub { $self->set_mime_icon },	        item_type => '<Item>'},
	{ path => '/sep5',												item_type => '<Separator>'},
	{ path => '/Quit',					callback => \&main::quit_cb,				item_type => '<Item>'},
	);

	$item_factory->create_items(undef, @menu_items);

	if ($self->count_selected_items == 1) {
		$item = $item_factory->get_item('/Bookmarks');
		$item->set_submenu(&main::get_bookmarks_menu);

		$item = new Gtk2::SeparatorMenuItem;
		$commands_menu->add($item);

		$item = $item_factory->get_item('/Open');
		$item->set_submenu($commands_menu);

		if (-e $self->[SELECTED_ITEM]) {
        		my $mime = new Filer::Mime;
        		my $type = File::MimeInfo::Magic::mimetype($self->[SELECTED_ITEM]);

        		foreach ($mime->get_commands($type)) {
                		$item = new Gtk2::MenuItem(File::Basename::basename($_));
                		$item->signal_connect("activate", sub {
                        		my $command = $_[1];
                        		system("$command '$self->[SELECTED_ITEM]' & exit");
                		}, $_);
                		$commands_menu->add($item);
        		}
		}

		$item = new Gtk2::MenuItem('Other ...');
		$item->signal_connect("activate", sub {	$self->open_file_with });
		$commands_menu->add($item);
	} else {
		$item_factory->delete_item('/Rename');
		$item_factory->delete_item('/MkDir');
		$item_factory->delete_item('/Bookmarks');
		$item_factory->delete_item('/Open');
		$item_factory->delete_item('/Open Terminal');
		$item_factory->delete_item('/Archive');
		$item_factory->delete_item('/Set Icon');
		$item_factory->delete_item('/Refresh');
		$item_factory->delete_item('/Properties');
		$item_factory->delete_item('/sep2');
		$item_factory->delete_item('/sep3');
		$item_factory->delete_item('/sep4');
		$item_factory->delete_item('/sep5');
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
# 		my $size = 0;
# 		for (@{$self->get_selected_items}) {
# 			$size += (lstat($_))[7] if (-R $_);
# 		}
# 	
# 		$main::widgets->{statusbar}->push(1, "$c files selected (Size: " . &calculate_size($size) . ")");

		$main::widgets->{statusbar}->push(1, "$c files selected");
	}

# 	my $clipboard = Gtk2::Clipboard->get_for_display(Gtk2::Gdk::Display->get_default, undef);
# 	$clipboard->set_text(join("", map { "file://$_\n" } @{$self->get_selected_items}) . pack("x", 1));

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
		$self->open_path(Cwd::abs_path("$self->[FILEPATH]/.."));
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

	if ($e->type eq "button-press" and $e->button == 3) {
		$self->show_popup_menu($e);
		return 1;
	}

	return 0;
}

# internal and external functions and methods.

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

sub get_pwd {
	my ($self) = @_;
	return Cwd::abs_path($self->[FILEPATH]);
}

sub get_path {
	my ($self,$file) = @_;
	return Cwd::abs_path($self->[FILEPATH] . "/$file");
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

sub open_file {
	my ($self,$filepath) = @_;

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if (-d $filepath) {
		if (defined $self->[OVERRIDES]->{$filepath}) {
			$self->open_path($self->[OVERRIDES]->{$filepath});
		} else {
			$self->open_path($filepath);
		}
	} elsif (-x $filepath) {

		system("$filepath & exit");

	} else {
		my $type = File::MimeInfo::Magic::mimetype($filepath);
		my $mime = new Filer::Mime;

		if (defined $mime->get_default_command($type)) {
			my $command = $mime->get_default_command($type);
			system("$command '$filepath' & exit ");

		} else {
			if ($type eq 'application/x-compressed-tar') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && tar -xzf '$filepath'");
				$self->open_path($dir);

			} elsif ($type eq 'application/x-bzip-compressed-tar') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && tar -xjf '$filepath'");
				$self->open_path($dir);

			} elsif ($type eq 'application/x-tar') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && tar -xf '$filepath'");
				$self->open_path($dir);

			} elsif ($type eq 'application/zip') {

				my $dir = $self->get_temp_archive_dir();
				system("cd $dir && unzip '$filepath'");
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
			if (defined $ENV{'TERMCMD'}) {
				$command = "$ENV{TERMCMD} -e $command";
			} else {
				Filer::Dialog->msgbox_info("TERMCMD not defined!");

				$dialog->destroy;
				return;
			}
		}

		system("$command '$self->[SELECTED_ITEM]' & exit");
	}

	$dialog->destroy;
}

sub open_terminal {
	my ($self) = @_;

	if (-d $self->[SELECTED_ITEM]) {
		if (defined $ENV{'TERMCMD'}) {
			system("cd '$self->[SELECTED_ITEM]' && $ENV{TERMCMD} & exit");
		} else {
			Filer::Dialog->msgbox_info("TERMCMD not defined!");
		}
	}
}

sub open_path {
	my ($self,$filepath) = @_;

	if (! -e $filepath) {
		$filepath = $ENV{HOME};
	}

	opendir (DIR, $filepath) or return Filer::Dialog->msgbox_error("$filepath: $!");
	my @dir_contents = sort readdir(DIR);
	closedir(DIR);

	@dir_contents = @dir_contents[(($filepath eq "/") ? 2 : 1) .. $#dir_contents];

	delete $self->[SELECTED_ITEM];
	delete $self->[SELECTED_ITER];

	$self->[FILEPATH] = $filepath;
	$self->[TREEMODEL]->clear;

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

# 	use Time::HiRes qw( gettimeofday tv_interval );
#
# 	my $t0 = [gettimeofday];

	foreach my $file (@dirs,@files) {
		if ($file =~ /^\.+\w+/ and $show_hidden == 0) {
			next;
		}

		my @stat = lstat("$filepath/$file");
		my $type = File::MimeInfo::mimetype("$filepath/$file");
		my $mypixbuf = $self->[MIMEICONS]->{'default'};

		my $size = calculate_size($stat[7]);
		my $ctime = localtime($stat[10]);
		my $uid = getpwuid($stat[4]);
		my $gid = getgrgid($stat[5]);
		my $mode = Stat::lsMode::format_mode($stat[2]);

		$total_size += $stat[7];

		my $abspath = Cwd::abs_path("$filepath/$file");
		my $target = readlink("$filepath/$file");

		if (-l "$filepath/$file") {
# 			my $dir_up = Cwd::abs_path("$abspath/..");
# 			$self->[OVERRIDES]->{$dir_up} = $filepath;

			$type = "inode/symlink";
		}

		if (defined $self->[MIMEICONS]->{$type}) {
			$mypixbuf = $self->[MIMEICONS]->{$type};
		} else {
			my $mime = new Filer::Mime;
			$mime->add_mimetype($type);
			$self->init_icons();
		}

		$type = File::MimeInfo::describe($type);

		$self->[TREEMODEL]->set($self->[TREEMODEL]->append, 0, $mypixbuf, 1, $file, 2, $type, 3, $size, 4, $ctime, 5, $uid, 6, $gid, 7, $mode, 8, $target, 9, $abspath);
	}

# 	my $t1 = [gettimeofday];
# 	my $elapsed = tv_interval ( $t0, $t1 );
# 	print "time to load: $elapsed\n";

	$total_size = &calculate_size($total_size);

	$self->[TREEVIEW]->columns_autosize;

	$self->[PATH_ENTRY]->set_text($self->[FILEPATH]);
	$self->[FOLDER_STATUS] = "$dirs_count ($dirs_count_total) directories and $files_count ($files_count_total) files: $total_size";
}

sub set_mime_icon {
	my ($self) = @_;
	my $mime = Filer::Mime->new;
	my $type = File::MimeInfo::Magic::mimetype($self->[SELECTED_ITEM]);

	if (-l $self->[SELECTED_ITEM]) {
		$type = "inode/symlink";
	}

	$mime->set_icon_dialog($type);

	$main::pane->[LEFT]->refresh;
	$main::pane->[RIGHT]->refresh
}

sub set_properties {
	my ($self) = @_;
	Filer::Properties->set_properties_dialog($self->[SELECTED_ITEM]);
	$self->refresh;
}

sub get_temp_archive_dir {
	my ($self) = @_;
	my $dir = File::Temp::tempdir(CLEANUP => 1);
	my $dir_up = Cwd::abs_path("$dir/..");

	# this overrides the path if the user clicks on the .. inside the temp archive directory
	$self->[OVERRIDES]->{$dir_up} = $self->[FILEPATH];

	return $dir;
}

sub create_tar_gz_archive {
	my ($self) = @_;
	my $archive = Filer::Archive->new($self->[SELECTED_ITEM]);
	$archive->create_tar_gz_archive;
	$self->refresh;
}

sub create_tar_bz2_archive {
	my ($self) = @_;
	my $archive = Filer::Archive->new($self->[SELECTED_ITEM]);
	$archive->create_tar_bz2_archive;
	$self->refresh;
}

sub extract_archive {
	my ($self) = @_;
	my $archive = Filer::Archive->new($self->[SELECTED_ITEM]);
	$archive->extract_archive;
	$self->refresh;
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
