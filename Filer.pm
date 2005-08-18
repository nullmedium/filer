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
use Class::Std::Utils;

use strict;
use warnings;

use Storable;
use Gtk2 qw(-init);
use Gtk2::Gdk::Keysyms;

use Fcntl;
use Memoize;
use File::Spec;
use File::BaseDir;
use File::Basename;
use File::MimeInfo::Magic;
use File::Temp;
use File::DirWalk;
use Stat::lsMode;

use Filer::Constants;

require Filer::Config;
require Filer::Bookmarks;
require Filer::FileInfo;
require Filer::Tools;
require Filer::Mime;
require Filer::FileAssociationDialog;
require Filer::Archive;
require Filer::Properties;
require Filer::Dialog;
require Filer::ProgressDialog;
require Filer::FilePane;
require Filer::FileTreePane;
require Filer::FileCopy;
require Filer::Copy;
require Filer::Move;
require Filer::Delete;
require Filer::Search;

# attributes:
my %VERSION;
my %config;
my %mime;
my %mimeicons;
my %widgets;
my %pane;
my %active_pane;
my %inactive_pane;

sub new {
	my ($class) = @_;
	my $self = bless anon_scalar(), $class;

	$VERSION{ident $self} = "0.0.13-svn";
	$mime{ident $self} = new Filer::Mime($self);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	
	delete $VERSION{ident $self};
	delete $config{ident $self};
	delete $mime{ident $self};
	delete $mimeicons{ident $self};
	delete $widgets{ident $self};
	delete $pane{ident $self};
	delete $active_pane{ident $self};
	delete $inactive_pane{ident $self};
}

sub get_version {
	my ($self) = @_;
	return $VERSION{ident $self};
}

sub init_config {
	my ($self) = @_;
	$config{ident $self} = new Filer::Config;

	if ($config{ident $self}->get_option("HonorUmask") == 0) {
		umask 0000;
	}
}

sub get_config {
	my ($self) = @_;
	return $config{ident $self};
}

sub init_mimeicons {
	my ($self) = @_;
	my $icons = $mime{ident $self}->get_icons;

	$mimeicons{ident $self} = {};

	while (my ($key,$value) = each %{$icons}) {
		$mimeicons{ident $self}->{$key} = Filer::Tools->intelligent_scale(Gtk2::Gdk::Pixbuf->new_from_file($value), 22);
	}
}

sub get_mime {
	my ($self) = @_;
	return $mime{ident $self};
}

sub get_mimeicons {
	my ($self) = @_;
	return $mimeicons{ident $self};
}

sub init_main_window {
	my ($self) = @_;
	my ($window,$hbox,$button,$accel_group,$toolbar);

	$widgets{ident $self}->{main_window} = new Gtk2::Window('toplevel');
	$widgets{ident $self}->{main_window}->set_title("Filer $VERSION{ident $self}");

	$widgets{ident $self}->{main_window}->resize(split ":", $config{ident $self}->get_option("WindowSize"));
#	$widgets{ident $self}->{main_window}->resize(784,606);

	$widgets{ident $self}->{main_window}->signal_connect("event", sub { $self->window_event_cb(@_) });
	$widgets{ident $self}->{main_window}->signal_connect("delete-event", sub { $self->quit_cb });
	$widgets{ident $self}->{main_window}->set_icon(Gtk2::Gdk::Pixbuf->new_from_file("$main::libpath/icons/folder.png"));

	$widgets{ident $self}->{vbox} = new Gtk2::VBox(0,0);
	$widgets{ident $self}->{main_window}->add($widgets{ident $self}->{vbox});

	my $actions = new Gtk2::ActionGroup("Actions");

	my $a_entries =
	[{
		name => "FileMenuAction",
		label => "File",
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
		label => "Edit",
	},{
		name => "cut-action",
		stock_id => "gtk-cut",
		tooltip => "Cut Selection",
		accelerator => "<control>X",
		callback => sub { $self->cut_cb },
	},{
		name => "copy-action",
		stock_id => "gtk-copy",
		tooltip => "Copy Selection",
		accelerator => "<control>C",
		callback => sub { $self->copy_cb },
	},{
		name => "paste-action",
		stock_id => "gtk-paste",
		tooltip => "Paste Clipboard",
		accelerator => "<control>V",
		callback => sub { $self->paste_cb },
	},{
		name => "rename-action",
		label => "Rename",
		tooltip => "Rename",
		accelerator => "F6",
		callback => sub { $self->rename_cb },
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
		name => "link-action",
		label => "Link",
		callback => sub { $self->link_cb },
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
		label => "Bookmarks",
	},{
		name => "OptionsMenuAction",
		label => "Options",
	},{
		name => "ModeMenuAction",
		label => "View Mode",
	},{
		name => "ConfirmationMenuAction",
		label => "Ask Confirmation for ...",
	},{
		name => "set-terminal-action",
		label => "Set Terminal",
		callback => sub { $self->set_terminal_cb },
	},{
		name => "set-editor-action",
		label => "Set Editor",
		callback => sub { $self->set_editor_cb },
	},{
		name => "file-assoc-action",
		label => "File Associations",
		callback => sub { $self->file_ass_cb },
	},{
		name => "HelpMenuAction",
		label => "Help",
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
		name => "OpenPopupMenuAction",
		stock_id => "gtk-open",
	},{
		name => "ArchiveMenuAction",
		label => "Archive",
	},{
		name => "create-tgz-action",
		label => "Create tar.gz",
		callback => sub { $active_pane{ident $self}->create_tar_gz_archive; }
	},{
		name => "create-tbz2-action",
		label => "Create tar.bz2",
		callback => sub { $active_pane{ident $self}->create_tar_bz2_archive; }
	},{
		name => "extract-action",
		label => "Extract",
		callback => sub { $active_pane{ident $self}->extract_archive; }
	},{
		name => "properties-action",
		stock_id => "gtk-properties",
		callback => sub { $self->set_properties; }
	}];

	my $a_radio_entries = [
	{
		name => "commander-style-action",
		label => "Norton Commander Style",
		value => NORTON_COMMANDER_MODE,
	},{
		name => "explorer-style-action",
		label => "MS Explorer View",
		value => EXPLORER_MODE,
	}];

	my $a_toggle_entries =
	[{
		name => "ask-copying-action",
		label => "Copying",
		callback => sub { $self->ask_copy_cb($_[0]) },
		is_active => $config{ident $self}->get_option("ConfirmCopy"),
	},{
		name => "ask-moving-action",
		label => "Moving",
		callback => sub { $self->ask_move_cb($_[0]) },
		is_active => $config{ident $self}->get_option("ConfirmMove"),
	},{
		name => "ask-deleting-action",
		label => "Deleting",
		callback => sub { $self->ask_delete_cb($_[0]) },
		is_active => $config{ident $self}->get_option("ConfirmDelete"),
	},{
		name => "show-hidden-action",
		label => "Show Hidden Files",
		callback => sub { $self->hidden_cb($_[0]) },
		accelerator => "<control>H",
		is_active => $config{ident $self}->get_option("ShowHiddenFiles"),
# 	},{
# 		name => "case-sort-action",
# 		label => "Case Insensitive Sort",
# 		callback => sub { $self->case_sort_cb($_[0]) },
# 		is_active => $config{ident $self}->get_option("CaseInsensitiveSort"),
	}];

	$actions->add_actions($a_entries);
	$actions->add_radio_actions($a_radio_entries, $config{ident $self}->get_option("Mode"), sub {
		my ($action) = @_;
		$config{ident $self}->set_option('Mode', $action->get_current_value);
		$self->switch_mode;
	});
	$actions->add_toggle_actions($a_toggle_entries);

	$widgets{ident $self}->{uimanager} = new Gtk2::UIManager;
	$widgets{ident $self}->{uimanager}->add_ui_from_file("$main::libpath/filer.ui");
	$widgets{ident $self}->{uimanager}->insert_action_group($actions, 0);

	my $accels = $widgets{ident $self}->{uimanager}->get_accel_group;
	$widgets{ident $self}->{main_window}->add_accel_group($accels);

	$widgets{ident $self}->{menubar} = $widgets{ident $self}->{uimanager}->get_widget("/ui/menubar");
 	$widgets{ident $self}->{vbox}->pack_start($widgets{ident $self}->{menubar}, 0, 0, 0);

	$widgets{ident $self}->{toolbar} = $widgets{ident $self}->{uimanager}->get_widget("/ui/toolbar");
	$widgets{ident $self}->{toolbar}->set_style('GTK_TOOLBAR_TEXT');
	$widgets{ident $self}->{sync_button} = $widgets{ident $self}->{uimanager}->get_widget("/ui/toolbar/Synchronize");
	$widgets{ident $self}->{vbox}->pack_start($widgets{ident $self}->{toolbar}, 0, 0, 0);

# 	$widgets{ident $self}->{location_bar} = new Gtk2::HBox(0,0);
# 	$widgets{ident $self}->{vbox}->pack_start($widgets{ident $self}->{location_bar}, 0, 0, 0);

	$widgets{ident $self}->{hpaned} = new Gtk2::HPaned();
	$widgets{ident $self}->{hbox} = new Gtk2::HBox(0,0);

	$widgets{ident $self}->{tree} = new Filer::FileTreePane($self,LEFT);
	$widgets{ident $self}->{list1} = new Filer::FilePane($self,LEFT);
	$widgets{ident $self}->{list2} = new Filer::FilePane($self,RIGHT);

	$widgets{ident $self}->{hpaned}->add1($widgets{ident $self}->{tree}->get_vbox);
	$widgets{ident $self}->{hpaned}->add2($widgets{ident $self}->{hbox});
	$widgets{ident $self}->{hbox}->pack_start($widgets{ident $self}->{list1}->get_vbox,1,1,0);
	$widgets{ident $self}->{hbox}->pack_start($widgets{ident $self}->{list2}->get_vbox,1,1,0);
	$widgets{ident $self}->{vbox}->pack_start($widgets{ident $self}->{hpaned},1,1,0);

  	my $bookmarks = new Filer::Bookmarks($self);
	$widgets{ident $self}->{uimanager}->get_widget("/ui/menubar/bookmarks-menu")->set_submenu($bookmarks->generate_bookmarks_menu);
	$widgets{ident $self}->{uimanager}->get_widget("/ui/menubar/bookmarks-menu")->show;

	$widgets{ident $self}->{list1}->open_path_helper((defined $ARGV[0] and -d $ARGV[0]) ? $ARGV[0] : $config{ident $self}->get_option('PathLeft'));
	$widgets{ident $self}->{list2}->open_path_helper((defined $ARGV[1] and -d $ARGV[1]) ? $ARGV[1] : $config{ident $self}->get_option('PathRight'));

	$widgets{ident $self}->{main_window}->show_all;

	$widgets{ident $self}->{sync_button}->hide;
	$widgets{ident $self}->{tree}->get_vbox->hide;
	$widgets{ident $self}->{list1}->get_vbox->hide;
	$widgets{ident $self}->{list2}->get_vbox->show;

	$pane{ident $self}->[LEFT] = undef;
	$pane{ident $self}->[RIGHT] = $widgets{ident $self}->{list2};

	$self->switch_mode;

	$active_pane{ident $self}   = $pane{ident $self}->[RIGHT];
	$inactive_pane{ident $self} = $pane{ident $self}->[LEFT];

	$active_pane{ident $self}->set_focus;
}

sub get_widgets {
	my ($self) = @_;
	return $widgets{ident $self};
}

sub get_active_pane {
	my ($self) = @_;
	return $active_pane{ident $self};
}

sub get_inactive_pane {
	my ($self) = @_;
	return $inactive_pane{ident $self};
}

sub set_active_pane {
	my ($self,$pane) = @_;
	$active_pane{ident $self} = $pane;
}

sub set_inactive_pane {
	my ($self,$pane) = @_;
	$inactive_pane{ident $self} = $pane;
}

sub window_event_cb {
	my ($self,$w,$e,$d) = @_;

	if (($e->type eq "key-press" and $e->keyval == $Gtk2::Gdk::Keysyms{'Tab'})) {
		if ($active_pane{ident $self}->get_side == LEFT) {
			$active_pane{ident $self}   = $pane{ident $self}->[RIGHT];
			$inactive_pane{ident $self} = $pane{ident $self}->[LEFT];

		} elsif ($active_pane{ident $self}->get_side == RIGHT) {

			$active_pane{ident $self}   = $pane{ident $self}->[LEFT];
			$inactive_pane{ident $self} = $pane{ident $self}->[RIGHT];
		}

		$active_pane{ident $self}->set_focus;

		return 1;
	}

	return 0;
}

sub quit_cb {
	my ($self) = @_;

	$config{ident $self}->set_option('PathLeft', $pane{ident $self}->[LEFT]->get_pwd);
	$config{ident $self}->set_option('PathRight', $pane{ident $self}->[RIGHT]->get_pwd);
	$config{ident $self}->set_option('WindowSize', join ":", $widgets{ident $self}->{main_window}->get_size());

	Gtk2->main_quit;
}

sub about_cb {
	my ($self) = @_;

	my $dialog = new Gtk2::AboutDialog;
	$dialog->set_name("Filer");
	$dialog->set_version($VERSION{ident $self});
	$dialog->set_copyright("Copyright � 2004-2005 Jens Luedicke");
	$dialog->set_license(
<<EOF
Filer $VERSION{ident $self}
Copyright (C) 2004-2005 Jens Luedicke <jens.luedicke\@gmail.com>

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
EOF
	);
	$dialog->set_website("http://perldude.de/");
	$dialog->set_website_label("http://perldude.de/");
	$dialog->set_authors(	"Jens Luedicke <jens.luedicke\@gmail.com>",
				"Bjoern Martensen <bjoern.martensen\@gmail.com>"
	);

	$dialog->set_artists("Crystal SVG 16x16 mimetype icons by Everaldo (http://www.everaldo.com)");

	$dialog->show;
}

sub open_cb {
	my ($self) = @_;

	if ($config{ident $self}->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$active_pane{ident $self}->open_file($active_pane{ident $self}->get_fileinfo->[0]);
	} else {
		$pane{ident $self}->[RIGHT]->open_file($pane{ident $self}->[RIGHT]->get_fileinfo->[0]);
	}
}

sub open_with_cb {
	my ($self) = @_;

	if ($config{ident $self}->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$active_pane{ident $self}->open_file_with;
	} else {
		$pane{ident $self}->[RIGHT]->open_file_with;
	}
}

sub open_terminal_cb {
	my ($self) = @_;
	my $path = $active_pane{ident $self}->get_pwd;

	if (-d $path) {
		my $term = $config{ident $self}->get_option("Terminal");
		my @c = split /\s+/, $term;
		Filer::Tools->start_program(@c, "--working-directory", $path);
	}
}

sub switch_mode {
	my ($self) = @_;

	if ($config{ident $self}->get_option('Mode') == EXPLORER_MODE) {
# 		$widgets{ident $self}->{list2}->get_location_bar->hide;
# 		$widgets{ident $self}->{list2}->get_location_bar->reparent($widgets{ident $self}->{location_bar});
# 		$widgets{ident $self}->{list2}->get_location_bar->show;

		$widgets{ident $self}->{list2}->get_location_bar->hide;

		$widgets{ident $self}->{sync_button}->hide;
		$widgets{ident $self}->{tree}->get_vbox->show;
		$widgets{ident $self}->{list1}->get_vbox->hide;

		$widgets{ident $self}->{list1}->get_navigation_box->hide;
		$widgets{ident $self}->{list2}->get_navigation_box->show;

		$pane{ident $self}->[LEFT] = $widgets{ident $self}->{tree};
	} else {
# 		$widgets{ident $self}->{list2}->get_location_bar->hide;
# 		$widgets{ident $self}->{list2}->get_location_bar->reparent($widgets{ident $self}->{list2}->get_location_bar_parent);
# 		$widgets{ident $self}->{list2}->get_location_bar->show;

		$widgets{ident $self}->{list2}->get_location_bar->show;

		$widgets{ident $self}->{sync_button}->show;
		$widgets{ident $self}->{tree}->get_vbox->hide;
		$widgets{ident $self}->{list1}->get_vbox->show;

 		$widgets{ident $self}->{list1}->get_navigation_box->hide;
 		$widgets{ident $self}->{list2}->get_navigation_box->hide;

		$pane{ident $self}->[LEFT] = $widgets{ident $self}->{list1};
	}
}

sub hidden_cb {
	my ($self,$action) = @_;
	$config{ident $self}->set_option('ShowHiddenFiles', ($action->get_active) ? 1 : 0);
	$pane{ident $self}->[LEFT]->refresh;
	$pane{ident $self}->[RIGHT]->refresh;
	return 1;
}

# sub case_sort_cb {
# 	my ($self,$action) = @_;
# 	$config{ident $self}->set_option('CaseInsensitiveSort', ($action->get_active) ? 1 : 0);
# 
# 	if ($pane{ident $self}->[LEFT]->get_type ne "TREE") {
# 		my ($col,$order) = $pane{ident $self}->[LEFT]->get_model->get_sort_column_id;
# 
# 		$pane{ident $self}->[LEFT]->get_model->set_sort_column_id(-2, $order);
# 		$pane{ident $self}->[LEFT]->get_model->set_sort_column_id($col,$order);
# 	}
# 
# 	my ($col,$order) = $pane{ident $self}->[RIGHT]->get_model->get_sort_column_id;
# 	$pane{ident $self}->[RIGHT]->get_model->set_sort_column_id(-2,$order);
# 	$pane{ident $self}->[RIGHT]->get_model->set_sort_column_id($col,$order);
# 
# 	return 1;
# }

sub ask_copy_cb {
	my ($self,$action) = @_;
	$config{ident $self}->set_option('ConfirmCopy', ($action->get_active) ? 1 : 0);
}

sub ask_move_cb {
	my ($self,$action) = @_;
	$config{ident $self}->set_option('ConfirmMove', ($action->get_active) ? 1 : 0);
}

sub ask_delete_cb {
	my ($self,$action) = @_;
	$config{ident $self}->set_option('ConfirmDelete', ($action->get_active) ? 1 : 0);
}

sub set_terminal_cb {
	my ($self) = @_;
	my $term = Filer::Dialog->ask_command_dialog("Set Terminal", $config{ident $self}->get_option('Terminal'));
	$config{ident $self}->set_option('Terminal', $term);
}

# sub set_editor_cb {
# 	my ($self) = @_;
# 	my $edit = Filer::Dialog->ask_command_dialog("Set Editor", $config{ident $self}->get_option('Editor'));
# 	$config{ident $self}->set_option('Editor', $edit);
# }

sub file_ass_cb {
	my ($self) = @_;
	$mime{ident $self}->file_association_dialog;
}

sub set_properties {
	my ($self) = @_;
	Filer::Properties->set_properties_dialog($self);
}

sub refresh_cb {
	my ($self) = @_;

	$self->refresh_active_pane;
	$self->refresh_inactive_pane;

	return 1;
}

sub refresh_active_pane {
	my ($self) = @_;
	$active_pane{ident $self}->refresh;
}

sub refresh_inactive_pane {
	my ($self) = @_;

	if ($active_pane{ident $self}->get_type eq $inactive_pane{ident $self}->get_type) {
		if ($active_pane{ident $self}->get_pwd eq $inactive_pane{ident $self}->get_pwd) {
			$inactive_pane{ident $self}->set_model($active_pane{ident $self}->get_model);
		} else {
			$inactive_pane{ident $self}->refresh;
		}
	} else {
		$inactive_pane{ident $self}->refresh;
	}
}

sub go_home_cb {
	my ($self) = @_;
	my $opt = $config{ident $self}->get_option('Mode');

	if ($config{ident $self}->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$active_pane{ident $self}->open_path_helper($ENV{HOME});
	} else {
		$pane{ident $self}->[RIGHT]->open_path_helper($ENV{HOME});
	}
}

sub synchronize_cb {
	my ($self) = @_;
	$inactive_pane{ident $self}->open_path_helper($active_pane{ident $self}->get_pwd);
}

sub select_cb {
	my ($self) = @_;
	$self->select_dialog(Filer::FilePane->SELECT);
}

sub unselect_cb {
	my ($self) = @_;
	$self->select_dialog(Filer::FilePane->UNSELECT);
}

sub select_dialog {
	my ($self,$type) = @_;

	if ($active_pane{ident $self}->get_type eq "TREE") {
		$pane{ident $self}->[RIGHT]->select_dialog($type);
	} else {
		$active_pane{ident $self}->select_dialog($type);
	}
}

sub search_cb {
	my ($self) = @_;
	new Filer::Search($self);
}

sub paste_cb {
	my ($self) = @_;
	my @files  = split /\n\r/, $self->get_clipboard_contents;
	my $action = pop @files;
	my $target = $active_pane{ident $self}->get_pwd;
	my $do;

	return if (! defined $action);

	if ($action eq "copy") {
		$do = new Filer::Copy;
		$do->action(\@files, $target);
	} else {
		$do = new Filer::Move;
		$do->action(\@files, $target);
	}

	# refresh panes.
	$active_pane{ident $self}->refresh;
	$self->refresh_inactive_pane;

	# reset clipboard
	if ($action eq "cut") {
		$self->set_clipboard_contents("");
	}
}

sub cut_cb {
	my ($self) = @_;
	return if ($active_pane{ident $self}->count_items == 0);

 	my @files =  (@{$active_pane{ident $self}->get_items}, "cut");
 	$self->set_clipboard_contents(join "\n\r", @files);
}

sub copy_cb {
	my ($self) = @_;
	return if ($active_pane{ident $self}->count_items == 0);

	my @files =  (@{$active_pane{ident $self}->get_items}, "copy");
	$self->set_clipboard_contents(join "\n\r", @files);
}

sub rename_cb {
	my ($self) = @_;
	my ($dialog,$hbox,$label,$entry);

	return if ($active_pane{ident $self}->count_items == 0);

	$dialog = new Gtk2::Dialog("Rename", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);
	$dialog->set_default_response('ok');

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,0,0,5);

	$label = new Gtk2::Label;
	$label->set_text("Rename: ");
	$hbox->pack_start($label, 0,0,2);

	$entry = new Gtk2::Entry;
	$entry->set_text($active_pane{ident $self}->get_fileinfo->[0]->get_basename);
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $old_pwd = $active_pane{ident $self}->get_pwd;
		my $old     = $active_pane{ident $self}->get_item;
		my $new;

		if ($active_pane{ident $self}->get_type eq "TREE") {
			$new = Filer::Tools->catpath(dirname($old_pwd), $entry->get_text);
		} else {
			$new = Filer::Tools->catpath($old_pwd, $entry->get_text);
		}

		if (rename($old,$new)) {
			$active_pane{ident $self}->set_item(new Filer::FileInfo($new));
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Rename failed: $!");
		}
	}

	$dialog->destroy;
}

sub delete_cb {
	my ($self) = @_;

	return if ($active_pane{ident $self}->count_items == 0);

	if ($config{ident $self}->get_option("ConfirmDelete") == 1) {
		if ($active_pane{ident $self}->count_items == 1) {
			my $fi = $active_pane{ident $self}->get_fileinfo->[0];
			my $f  = $fi->get_basename;
			$f =~ s/&/&amp;/g; # sick fix. meh.

			if ($fi->is_dir) {
				return if (Filer::Dialog->yesno_dialog("Delete directory \"$f\"?") eq 'no');
			} else {
				return if (Filer::Dialog->yesno_dialog("Delete file \"$f\"?") eq 'no');
			}
		} else {
			return if (Filer::Dialog->yesno_dialog(sprintf("Delete %s selected files?", $active_pane{ident $self}->count_items)) eq 'no');
		}
	}

	my $delete = new Filer::Delete;
	$delete->delete($active_pane{ident $self}->get_items);

	$active_pane{ident $self}->remove_selected;
	$self->refresh_inactive_pane;
}

sub mkdir_cb {
	my ($self) = @_;
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog(
		"Make directory",
		$widgets{ident $self}->{main_window},
		'modal',
		'gtk-cancel' => 'cancel',
		'gtk-ok' => 'ok'
	);

	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_default_response('ok');

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox, 0,0,5);

	$label = new Gtk2::Label;
	$label->set_text($active_pane{ident $self}->get_pwd . "/");
	$hbox->pack_start($label, 0,0,2);

	$entry = new Gtk2::Entry;
	$entry->set_text("New Folder");
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $dir = Filer::Tools->catpath($active_pane{ident $self}->get_pwd, $entry->get_text);

		if (Filer::Tools->_mkdir($dir)) {
			$active_pane{ident $self}->refresh;
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Make directory $dir failed: $!");
		}
	}

	$dialog->destroy;
}

sub link_cb {
	my ($self) = @_;
	return if ($active_pane{ident $self}->count_items == 0);

	my ($dialog,$link_label,$target_label,$link_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	$dialog->set_title("Link");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$link_label->set_markup("<b>Link: </b>");
	$link_entry->set_text(Filer::Tools->catpath($inactive_pane{ident $self}->get_pwd, $active_pane{ident $self}->get_fileinfo->[0]->get_basename));
	$link_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($active_pane{ident $self}->get_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $link = $link_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($link) eq File::Spec->curdir) {
			$link = Filer::Tools->catpath($active_pane{ident $self}->get_pwd, $link);
		}

		if (link($target, $link)) {
			$active_pane{ident $self}->refresh;
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create link! $!");
		}
	}

	$dialog->destroy;
}

sub symlink_cb {
	my ($self) = @_;
	return if ($active_pane{ident $self}->count_items == 0);

	my ($dialog,$symlink_label,$target_label,$symlink_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	$dialog->set_title("Symlink");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$symlink_label->set_markup("<b>Symlink: </b>");
	$symlink_entry->set_text(Filer::Tools->catpath($inactive_pane{ident $self}->get_pwd, $active_pane{ident $self}->get_fileinfo->[0]->get_basename));
	$symlink_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($active_pane{ident $self}->get_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $symlink = $symlink_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($symlink) eq File::Spec->curdir) {
			$symlink = Filer::Tools->catpath($active_pane{ident $self}->get_pwd, $symlink);
		}

		if (symlink($target, $symlink)) {
			$active_pane{ident $self}->refresh;
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create symlink! $!");
		}
	}

	$dialog->destroy;
}

sub get_clipboard_contents {
	my ($self) = @_;
	my $clipboard = Gtk2::Clipboard->get_for_display($widgets{ident $self}->{main_window}->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
	my $contents = "";

	$clipboard->request_text(sub {
		my ($c,$t) = @_;
		return if (!$t);

		$contents = $t;
	});

	return $contents;
}

sub set_clipboard_contents {
	my ($self,$contents) = @_;
	my $clipboard = Gtk2::Clipboard->get_for_display($widgets{ident $self}->{main_window}->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
	$clipboard->set_text($contents);
}

1;
