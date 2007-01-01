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

package Filer;

use strict;
use warnings;

use Gtk2 qw(-init -threads-init);
use Gtk2::Gdk::Keysyms;

use Fcntl;
use File::Spec;
use File::BaseDir;
use File::Basename;
use File::MimeInfo::Magic;
use File::Temp;
use File::DirWalk;
use Stat::lsMode;

use Clipboard;

use Filer::Constants qw(:filer);

require Filer::Config;
require Filer::Bookmarks;
require Filer::Directory;
require Filer::FileInfo;
require Filer::MimeTypeIcon;
require Filer::MimeTypeHandler;
require Filer::Tools;

require Filer::Dialog;
require Filer::DefaultDialog;
require Filer::PropertiesDialog;
require Filer::FileExistsDialog;
require Filer::SourceTargetDialog;

require Filer::CellRendererSize;
require Filer::CellRendererDate;
require Filer::FilePaneInterface;
require Filer::FilePane;
require Filer::FileTreePane;

require Filer::FileCopy;
require Filer::JobDialog;
require Filer::CopyMoveJobDialogCommon;
require Filer::CopyJobDialog;
require Filer::MoveJobDialog;
require Filer::DeleteJobDialog;
require Filer::Copy;
require Filer::Move;
require Filer::Delete;
require Filer::Search;

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{VERSION} = "0.0.15-svn";

	return $self;
}

sub get_version {
	my ($self) = @_;
	return $self->{VERSION};
}

sub init_config {
	my ($self) = @_;
	$self->{config} = Filer::Config->new;

	if ($self->{config}->get_option("HonorUmask") == $FALSE) {
		umask 0000;
	}
}

sub get_config {
	my ($self) = @_;
	return $self->{config};
}

sub init_main_window {
	my ($self) = @_;

	$self->{main_window} = Gtk2::Window->new('toplevel');
	$self->{main_window}->set_title("Filer $self->{VERSION}");

	$self->{main_window}->resize(split ":", $self->{config}->get_option("WindowSize"));
#	$self->{main_window}->resize(784,606);

	$self->{main_window}->signal_connect("event", sub { $self->window_event_cb(@_) });
	$self->{main_window}->signal_connect("delete-event", sub { $self->quit_cb });
	$self->{main_window}->set_icon(Filer::MimeTypeIcon->new("inode/directory")->get_pixbuf);

	$self->{main_window_vbox} = Gtk2::VBox->new(0,0);
	$self->{main_window}->add($self->{main_window_vbox});

	my $actions = Gtk2::ActionGroup->new("Actions");

	my $a_entries =
	[{
		name => "FileMenuAction",
		label => "_File",
	},{
		name => "open-terminal-action",
		label => "Open Terminal",
		accelerator => "F2",
		callback => sub { $self->open_terminal_cb },
	},{
		name => "open-action",
		stock_id => "gtk-open",
		callback => sub { $self->open_cb },
		accelerator => "F3",
	},{
		name => "open-with-action",
		label => "Open With",
		callback => sub { $self->open_with_cb },
	},{
		name => "quit-action",
		stock_id => "gtk-quit",
		accelerator => "<control>Q",
		callback => sub { $self->quit_cb },
	},{
		name => "EditMenuAction",
		label => "_Edit",
# 	},{
# 		name => "cut-action",
# 		stock_id => "gtk-cut",
# 		tooltip => "Cut Selection",
# 		accelerator => "<control>X",
# 		callback => sub { $self->cut_cb },
# 	},{
# 		name => "copy-action",
# 		stock_id => "gtk-copy",
# 		tooltip => "Copy Selection",
# 		accelerator => "<control>C",
# 		callback => sub { $self->copy_cb },
# 	},{
# 		name => "paste-action",
# 		stock_id => "gtk-paste",
# 		tooltip => "Paste Clipboard",
# 		accelerator => "<control>V",
# 		callback => sub { $self->paste_cb },

	},{
		name => "copy-action",
		label => "Copy",
		tooltip => "Copy selected files",
		accelerator => "F5",
		callback => sub { $self->copy_cb },
	},{
		name => "move-action",
		label => "Move",
		tooltip => "Move selected files",
		accelerator => "F6",
		callback => sub { $self->move_cb },

# 	},{
# 		name => "rename-action",
# 		label => "Rename",
# 		tooltip => "Rename",
# 		accelerator => "F6",
# 		callback => sub { $self->rename_cb },
	},{
		name => "mkdir-action",
		label => "New folder",
		tooltip => "Make Directory",
		accelerator => "F7",
		callback => sub { $self->mkdir_cb },
	},{
		name => "delete-action",
		stock_id => "gtk-delete",
		tooltip => "Delete files",
		accelerator => "F8",
		callback => sub { $self->delete_cb },
	},{
		name => "symlink-action",
		label => "Symlink",
		callback => sub { $self->symlink_cb },
	},{
		name => "refresh-action",
		stock_id => "gtk-refresh",
		tooltip => "Refresh",
		accelerator => "<control>R",
		callback => sub { $self->refresh_cb },
	},{
		name => "search-action",
		stock_id => "gtk-find",
		label => "Search",
		callback => sub { $self->search_cb },
	},{
		name => "select-action",
		label => "Select",
		accelerator => "KP_Add",
		callback => sub { $self->select_cb },
	},{
		name => "unselect-action",
		label => "Unselect",
		accelerator => "KP_Subtract",
		callback => sub { $self->unselect_cb },
	},{
		name => "BookmarksMenuAction",
		label => "_Bookmarks",
	},{
		name => "OptionsMenuAction",
		label => "_Options",
	},{
		name => "ModeMenuAction",
		label => "View Mode",
	},{
		name => "ConfirmationMenuAction",
		label => "Ask Confirmation for ...",
	},{
		name => "HelpMenuAction",
		label => "_Help",
	},{
		name => "about-action",
		stock_id => "gtk-about",
		callback => sub { $self->about_cb },
	},{
		name => "home-action",
		stock_id => "gtk-home",
		tooltip => "Go Home",
		callback => sub { $self->go_home_cb },
	},{
		name => "synchronize-action",
		label => "Synchronize",
		tooltip => "Synchronize Folders",
		callback => sub { $self->synchronize_cb },
	},{
		name => "properties-action",
		stock_id => "gtk-properties",
		callback => sub { $self->set_properties; }
	}];

	my $a_radio_entries = [
	{
		name => "commander-style-action",
		label => "Norton Commander Style",
		value => $NORTON_COMMANDER_MODE,
	},{
		name => "explorer-style-action",
		label => "MS Explorer View",
		value => $EXPLORER_MODE,
	}];

	my $a_toggle_entries =
	[{
		name => "ask-copying-action",
		label => "Copying",
		callback => sub { $self->ask_copy_cb($_[0]) },
		is_active => $self->{config}->get_option("ConfirmCopy"),
	},{
		name => "ask-moving-action",
		label => "Moving",
		callback => sub { $self->ask_move_cb($_[0]) },
		is_active => $self->{config}->get_option("ConfirmMove"),
	},{
		name => "ask-deleting-action",
		label => "Deleting",
		callback => sub { $self->ask_delete_cb($_[0]) },
		is_active => $self->{config}->get_option("ConfirmDelete"),
	},{
		name => "show-hidden-action",
		label => "Show Hidden Files",
		callback => sub { $self->hidden_cb($_[0]) },
		accelerator => "<control>H",
		is_active => $self->{config}->get_option("ShowHiddenFiles"),
	}];

	$actions->add_actions($a_entries);
	$actions->add_radio_actions($a_radio_entries, $self->{config}->get_option("Mode"), sub {
		my ($action) = @_;
		$self->{config}->set_option('Mode', $action->get_current_value);
		$self->switch_mode;
	});
	$actions->add_toggle_actions($a_toggle_entries);

	$self->{uimanager} = Gtk2::UIManager->new;
	$self->{uimanager}->add_ui_from_file("$main::libpath/filer.ui");
	$self->{uimanager}->insert_action_group($actions, 0);

	my $accels = $self->{uimanager}->get_accel_group;
	$self->{main_window}->add_accel_group($accels);

	$self->{menubar} = $self->{uimanager}->get_widget("/ui/menubar");
 	$self->{main_window_vbox}->pack_start($self->{menubar}, 0, 0, 0);

	$self->{toolbar} = $self->{uimanager}->get_widget("/ui/toolbar");
	$self->{toolbar}->set_style('GTK_TOOLBAR_TEXT');
	$self->{sync_button} = $self->{uimanager}->get_widget("/ui/toolbar/Synchronize");
	$self->{main_window_vbox}->pack_start($self->{toolbar}, 0, 0, 0);

	my $hpaned = Gtk2::HPaned->new();
	my $hbox   = Gtk2::HBox->new(0,0);

	$self->{treepane}  = Filer::FileTreePane->new($self,$LEFT);
	$self->{filepane1} = Filer::FilePane->new($self,$LEFT);
	$self->{filepane2} = Filer::FilePane->new($self,$RIGHT);

	$hpaned->add1($self->{treepane}->get_vbox);
	$hpaned->add2($hbox);
	$hbox->pack_start($self->{filepane1}->get_vbox,1,1,0);
	$hbox->pack_start($self->{filepane2}->get_vbox,1,1,0);
	$self->{main_window_vbox}->pack_start($hpaned,1,1,0);

  	my $bookmarks      = Filer::Bookmarks->new($self);
	my $bookmarks_menu = $self->{uimanager}->get_widget("/ui/menubar/bookmarks-menu");

	$bookmarks_menu->set_submenu($bookmarks->generate_bookmarks_menu);
	$bookmarks_menu->show;

	$self->{filepane1}->open_path(
		(defined $ARGV[0] and -d $ARGV[0])
		? $ARGV[0]
		: $self->{config}->get_option('PathLeft')
	);

	$self->{filepane2}->open_path(
		(defined $ARGV[1] and -d $ARGV[1])
		? $ARGV[1]
		: $self->{config}->get_option('PathRight')
	);

	$self->{main_window}->show_all;

	$self->{sync_button}->hide;
	$self->{treepane}->get_vbox->hide;
	$self->{filepane1}->get_vbox->hide;
	$self->{filepane2}->get_vbox->show;
	
	$self->{pane}->[$LEFT]  = $self->{filepane1};
	$self->{pane}->[$RIGHT] = $self->{filepane2};

	$self->switch_mode;

	$self->{pane}->[$RIGHT]->set_focus;
}

sub get_uimanager {
	my ($self) = @_;
	return $self->{uimanager};
}

sub get_active_pane {
	my ($self) = @_;
	return $self->{active_pane};
}

sub get_inactive_pane {
	my ($self) = @_;
	return $self->{inactive_pane};
}

sub change_active_pane {
	my ($self,$side) = @_;

	$self->{active_pane}   = $self->{pane}->[ $side];
	$self->{inactive_pane} = $self->{pane}->[!$side];
}

sub get_left_pane {
	my ($self) = @_;
	return $self->{pane}->[$LEFT];
}

sub get_right_pane {
	my ($self) = @_;
	return $self->{pane}->[$RIGHT];
}

sub window_event_cb {
	my ($self,$w,$e,$d) = @_;

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Tab'})) {
		$self->{inactive_pane}->set_focus;
		return 1;
	}

	return 0;
}

sub quit_cb {
	my ($self) = @_;

	$self->{config}->set_options(
		'PathLeft'   => $self->{filepane1}->get_pwd,
		'PathRight'  => $self->{filepane2}->get_pwd,
		'WindowSize' => join ":", $self->{main_window}->get_size,
	);

 	Gtk2->main_quit;
}

sub about_cb {
	my ($self) = @_;

	my $license = join "", <DATA>;
	$license =~ s/__VERSION__/$self->{VERSION}/g;

	my $dialog = Gtk2::AboutDialog->new;
	$dialog->set_name("Filer");
	$dialog->set_version($self->{VERSION});
	$dialog->set_copyright("Copyright (c) 2004-2006 Jens Luedicke");
	$dialog->set_license($license);
	$dialog->set_website("http://perldude.de/");
	$dialog->set_website_label("http://perldude.de/");
	$dialog->set_authors(
		"Jens Luedicke <jens.luedicke\@gmail.com>",
		"Bjoern Martensen <bjoern.martensen\@gmail.com>"
	);

	$dialog->show;
}

sub open_cb {
	my ($self) = @_;

	my $mode = $self->{config}->get_option('Mode');
	my $pane =
		($mode == $NORTON_COMMANDER_MODE) 
		? $self->{active_pane} 
		: $self->{pane}->[$RIGHT];

	$pane->open_file($pane->get_fileinfo_list->[0]);
}

sub open_with_cb {
	my ($self) = @_;

	my $mode = $self->{config}->get_option('Mode');
	my $pane =
		($mode == $NORTON_COMMANDER_MODE) 
		? $self->{active_pane} 
		: $self->{pane}->[$RIGHT];

	$pane->open_file_with($pane->get_fileinfo_list->[0]);
}

sub open_terminal_cb {
	my ($self) = @_;
	my $path = $self->{active_pane}->get_pwd;
	Filer::Tools->exec("Terminal --working-directory $path");
}

sub switch_mode {
	my ($self) = @_;

	if ($self->{config}->get_option('Mode') == $EXPLORER_MODE) {
		$self->{filepane2}->get_location_bar->hide;

		$self->{sync_button}->hide;
		$self->{treepane}->get_vbox->show;
		$self->{filepane1}->get_vbox->hide;

		$self->{filepane1}->get_navigation_box->hide;
		$self->{filepane2}->get_navigation_box->show;

		$self->{pane}->[$LEFT] = $self->{treepane};
	} else {
		$self->{filepane2}->get_location_bar->show;

		$self->{sync_button}->show;
		$self->{treepane}->get_vbox->hide;
		$self->{filepane1}->get_vbox->show;

 		$self->{filepane1}->get_navigation_box->hide;
 		$self->{filepane2}->get_navigation_box->hide;

		$self->{pane}->[$LEFT] = $self->{filepane1};
	}
}

sub hidden_cb {
	my ($self,$action) = @_;

	my $opt = ($action->get_active) ? 1 : 0;
	$self->{config}->set_option('ShowHiddenFiles', $opt);

	$self->{pane}->[$LEFT]->set_show_hidden($opt);
	$self->{pane}->[$RIGHT]->set_show_hidden($opt);

	return 1;
}

sub ask_copy_cb {
	my ($self,$action) = @_;
	$self->{config}->set_option('ConfirmCopy', ($action->get_active) ? 1 : 0);
}

sub ask_move_cb {
	my ($self,$action) = @_;
	$self->{config}->set_option('ConfirmMove', ($action->get_active) ? 1 : 0);
}

sub ask_delete_cb {
	my ($self,$action) = @_;
	$self->{config}->set_option('ConfirmDelete', ($action->get_active) ? 1 : 0);
}

sub set_properties {
	my ($self) = @_;
	Filer::PropertiesDialog->new($self);
}

sub refresh_cb {
	my ($self) = @_;

	$self->{active_pane}->refresh;
	$self->{inactive_pane}->refresh;

	return 1;
}

sub go_home_cb {
	my ($self) = @_;
	my $opt  = $self->{config}->get_option('Mode');
	my $pane =
		($opt == $NORTON_COMMANDER_MODE)
		? $self->{active_pane}
		: $self->{pane}->[$RIGHT];

	$pane->open_path($HOMEDIR);
}

sub synchronize_cb {
	my ($self) = @_;
	$self->{inactive_pane}->open_path($self->{active_pane}->get_pwd);
}

sub select_cb {
	my ($self) = @_;
	my $pane =
		($self->{active_pane}->get_type eq "TREE")
		? $self->{pane}->[$RIGHT]
		: $self->{active_pane};

	$pane->select_dialog;
}

sub unselect_cb {
	my ($self) = @_;
	my $pane =
		($self->{active_pane}->get_type eq "TREE")
		? $self->{pane}->[$RIGHT]
		: $self->{active_pane};

	$pane->unselect_dialog;
}

sub search_cb {
	my ($self) = @_;
	Filer::Search->new($self);
}

# sub paste_cb {
# 	my ($self) = @_;
# 	my @files  = split /\n\r/, $self->get_clipboard_contents;
# 
# 	return if (scalar @files == 0);
# 
# 	my $action = pop @files;
# 	my $dest   = $self->{active_pane}->get_pwd;
# 	my $do;
# 
# 	if ($action eq "copy") {
# 
# 		$do = Filer::Copy->new;
# 		$do->action(\@files, $dest);
# 
# 	} elsif ($action eq "cut") {
# 		$do = Filer::Move->new;
# 		$do->action(\@files, $dest);
# 
# 		$self->set_clipboard_contents("");
# 	}
# 
# 	$self->refresh_cb;
# }
# 
# sub cut_cb {
# 	my ($self) = @_;
# 	my $pane = $self->{active_pane};
# 
# 	return if ($pane->count_items == 0);
# 
# 	my $str = join "\n\r", (@{$pane->get_item_list}, "cut");
# 	$self->set_clipboard_contents($str);
# }
# 
# sub copy_cb {
# 	my ($self) = @_;
# 	my $pane = $self->{active_pane};
# 
# 	return if ($pane->count_items == 0);
# 
# 	my $str = join "\n\r", (@{$pane->get_item_list}, "copy");
# 	$self->set_clipboard_contents($str);
# }

sub copy_cb {
	my ($self) = @_;

	my $items_count = $self->{active_pane}->count_items;
	return if ($items_count == 0);

 	my $files = $self->{active_pane}->get_item_list;
	my $dest  = $self->{inactive_pane}->get_pwd;

	if ($items_count == 1) {
		my $dialog = Filer::SourceTargetDialog->new("Copy");

		my $label = $dialog->get_source_label;
		$label->set_markup("<b>Copy: </b>");

		my $source_entry = $dialog->get_source_entry;
		$source_entry->set_text($files->[0]);
		$source_entry->set_activates_default($TRUE);

		my $target_label = $dialog->get_target_label;
		$target_label->set_markup("<b>to: </b>");

		my $target_entry  = $dialog->get_target_entry;
		$target_entry->set_text($dest);
		$target_entry->set_activates_default($TRUE);

		if ($dialog->run eq 'ok') {
			my $target = $target_entry->get_text;
			$dest      = $target;

			$dialog->destroy;
		} else {
			$dialog->destroy;
			return;
		}
	} else {
		if ($self->{config}->get_option("ConfirmCopy") == $TRUE) {
			return if (Filer::Dialog->yesno_dialog("Copy $items_count files to $dest?") eq 'no');
		}
	}

	my $copy = Filer::Copy->new;
	$copy->action($files, $dest);

	$self->refresh_cb;
}

sub move_cb {
	my ($self) = @_;

	my $items_count = $self->{active_pane}->count_items;
	return if ($items_count == 0);

 	my $files = $self->{active_pane}->get_item_list;
	my $dest  = $self->{inactive_pane}->get_pwd;
	
	if ($items_count == 1) {
		my $dialog = Filer::SourceTargetDialog->new("Move/Rename");

		my $label = $dialog->get_source_label;
		$label->set_markup("<b>Move/Rename: </b>");

		my $source_entry = $dialog->get_source_entry;
		$source_entry->set_text($files->[0]);
		$source_entry->set_activates_default($TRUE);

		my $target_label = $dialog->get_target_label;
		$target_label->set_markup("<b>to: </b>");

		my $target_entry  = $dialog->get_target_entry;
		$target_entry->set_text($dest);
		$target_entry->set_activates_default($TRUE);

		if ($dialog->run eq 'ok') {
			my $target = $target_entry->get_text;
			$dest      = $target;

			$dialog->destroy;
		} else {
			$dialog->destroy;
			return;
		}
	} else {
		if ($self->{config}->get_option("ConfirmMove") == $TRUE) {
			return if (Filer::Dialog->yesno_dialog("Move $items_count files to $dest?") eq 'no');
		}
	}

	my $copy = Filer::Move->new;
	$copy->action($files, $dest);

	$self->refresh_cb;
}

# sub rename_cb {
# 	my ($self) = @_;
# 	my ($dialog,$hbox,$label,$entry);
# 
# 	my $pane = $self->{active_pane};
# 
# 	return if ($pane->count_items == 0);
# 
# 	my $fileinfo = $pane->get_fileinfo_list->[0];
# 
# 	$dialog = Filer::DefaultDialog->new("Rename");
# 
# 	$hbox = Gtk2::HBox->new(0,0);
# 	$dialog->vbox->pack_start($hbox,0,0,5);
# 
# 	$label = Gtk2::Label->new;
# 	$label->set_text("Rename: ");
# 	$hbox->pack_start($label, 0,0,2);
# 
# 	$entry = Gtk2::Entry->new;
# 	$entry->set_text($fileinfo->get_basename);
# 	$entry->set_activates_default($TRUE);
# 	$hbox->pack_start($entry, 1,1,0);
# 
# 	$dialog->show_all;
# 
# 	if ($dialog->run eq 'ok') {
# 		my $old_pwd = $pane->get_pwd;
# 		my $old     = $fileinfo->get_path;
# 		my $new;
# 
# 		if ($self->{active_pane}->get_type eq "TREE") {
# 			$new = Filer::Tools->catpath(dirname($old_pwd), $entry->get_text);
# 		} else {
# 			$new = Filer::Tools->catpath($old_pwd, $entry->get_text);
# 		}
# 
# 		if (!rename($old,$new)) {
# 			Filer::Dialog->msgbox_error("Rename failed: $!");
# 		}
# 	}
# 
# 	$dialog->destroy;
# }

sub delete_cb {
	my ($self) = @_;
	my $items       = $self->{active_pane}->get_item_list;
	my $items_count = $self->{active_pane}->count_items;

	return if ($items_count == 0);

	if ($self->{config}->get_option("ConfirmDelete") == 1) {

		my $message =
		 ($items_count == 1)
		 ? "Delete \"$items->[0]\"?"
		 : "Delete $items_count selected files?";

		return if (Filer::Dialog->yesno_dialog($message) eq 'no');
	}

	my $delete = Filer::Delete->new;
	$delete->delete($items);

	$self->refresh_cb;
}

sub mkdir_cb {
	my ($self) = @_;
	my ($dialog,$hbox,$label,$entry);

	$dialog = Filer::DefaultDialog->new("Rename");

	$label = Gtk2::Label->new;
	$label->set_text("Enter Folder Name:");
	$label->set_alignment(0.0,0.0);
	$dialog->vbox->pack_start($label, 0,0,2);

	$entry = Gtk2::Entry->new;
	$entry->set_text("New_Folder");
	$entry->set_activates_default($TRUE);
	$dialog->vbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $dir  = Filer::Tools->catpath($self->{active_pane}->get_pwd, $entry->get_text);

		if (!mkdir($dir)) {
			Filer::Dialog->msgbox_error("Make directory $dir failed: $!");
		}
	}

	$dialog->destroy;

	$self->refresh_cb;
}

sub symlink_cb {
	my ($self) = @_;

	return if ($self->{active_pane}->count_items == 0);

	my $active_pwd      = $self->{active_pane}->get_pwd;
	my $inactive_pwd    = $self->{inactive_pane}->get_pwd;

	my $fi              = $self->{active_pane}->get_fileinfo_list->[0];
	my $active_selected = $fi->get_path;
	my $active_basename = $fi->get_basename;	

	my $dialog = Filer::SourceTargetDialog->new("Symlink");

	my $symlink_label = $dialog->get_source_label;
	$symlink_label->set_markup("<b>Symlink: </b>");

	my $symlink_entry = $dialog->get_source_entry;
	$symlink_entry->set_text(Filer::Tools->catpath($inactive_pwd, $active_basename));
	$symlink_entry->set_activates_default($TRUE);

	my $target_label = $dialog->get_target_label;
	$target_label->set_markup("<b>linked object: </b>");

	my $target_entry  = $dialog->get_target_entry;
	$target_entry->set_text($active_selected);
	$target_entry->set_activates_default($TRUE);

	if ($dialog->run eq 'ok') {
		my $symlink = $symlink_entry->get_text;
		my $target  = $target_entry->get_text;

		if (dirname($symlink) eq File::Spec->curdir) {
			$symlink = Filer::Tools->catpath($active_pwd, $symlink);
		}

		if (!symlink($target, $symlink)) {
			Filer::Dialog->msgbox_error("Couldn't create symlink! $!");
		}
	}

	$dialog->destroy;

	$self->refresh_cb;
}

# sub get_clipboard_contents {
# 	my ($self) = @_;
# 	my $c = Clipboard->paste;
# 	return $c;
# }
# 
# sub set_clipboard_contents {
# 	my ($self,$contents) = @_;
# 	Clipboard->copy($contents);
# }

1;

__DATA__

Filer __VERSION__
Copyright (C) 2004-2006 Jens Luedicke <jens.luedicke@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
