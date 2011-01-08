#     Copyright (C) 2004-2010 Jens Luedicke <jens.luedicke@gmail.com>
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

our $VERSION = '0.0.13-git';

use strict;
use warnings;

use Gtk2 qw(-init);
use Gtk2::Gdk::Keysyms;

use Fcntl;
use File::Spec;
use File::BaseDir;
use File::Basename;
use File::MimeInfo::Magic;
use File::Temp;
use File::DirWalk;
use Stat::lsMode;

use Filer::Constants qw(:filer);

require Filer::Config;
require Filer::Bookmarks;
require Filer::Directory;
require Filer::FileInfo;
require Filer::MimeTypeIcon;
require Filer::MimeTypeHandler;
require Filer::Tools;

require Filer::Dialog;
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
require Filer::Copy;
require Filer::Move;
require Filer::Delete;
require Filer::Search;

my $oneTrueSelf;

sub instance {
    unless (defined $oneTrueSelf) {
    	my ($type) = @_;
        my $this = {};

        $oneTrueSelf = bless $this, $type;
    }

    return $oneTrueSelf;
}

sub init_config {
    my ($self) = @_;
    my $config = Filer::Config->instance();

    if ($config->get_option("HonorUmask") == $FALSE) {
	umask 0000;
    }
}

sub init_main_window {
    my ($self) = @_;

    $self->{main_window} = Gtk2::Window->new('toplevel');
    $self->{main_window}->set_title("Filer $VERSION");

    $self->{main_window}->resize(split ":", Filer::Config->instance()->get_option("WindowSize"));
#	$self->{main_window}->resize(784,606);

    $self->{main_window}->signal_connect("event", sub { $self->window_event_cb($_[0], $_[1], $_[2]); });
    $self->{main_window}->signal_connect("delete-event", sub { $self->quit_cb(); });

    $self->{main_window}->set_icon(Filer::MimeTypeIcon->new("inode/directory")->get_pixbuf);

    $self->{main_window_vbox} = Gtk2::VBox->new(0,0);
    $self->{main_window}->add($self->{main_window_vbox});

    $self->init_actions;

    $self->{menubar} = $self->{uimanager}->get_widget("/ui/menubar");
    $self->{main_window_vbox}->pack_start($self->{menubar}, $FALSE, $FALSE, 0);

    $self->{toolbar} = $self->{uimanager}->get_widget("/ui/toolbar");
    $self->{toolbar}->set_style('GTK_TOOLBAR_TEXT');
    $self->{sync_button} = $self->{uimanager}->get_widget("/ui/toolbar/Synchronize");
    $self->{main_window_vbox}->pack_start($self->{toolbar}, $FALSE, $FALSE, 0);

    my $hpaned = Gtk2::HPaned->new();
    my $hbox   = Gtk2::HBox->new(0,0);

    $self->{treepane}  = Filer::FileTreePane->new($LEFT);
    $self->{filepane1} = Filer::FilePane->new($LEFT);
    $self->{filepane2} = Filer::FilePane->new($RIGHT);

    $hpaned->add1($self->{treepane}->get_vbox);
    $hpaned->add2($hbox);
    $hbox->pack_start($self->{filepane1}->get_vbox, $TRUE, $TRUE, 0);
    $hbox->pack_start($self->{filepane2}->get_vbox, $TRUE, $TRUE, 0);
    $self->{main_window_vbox}->pack_start($hpaned, $TRUE, $TRUE, 0);

    my $bookmarks      = Filer::Bookmarks->new($self);
    my $bookmarks_menu = $self->{uimanager}->get_widget("/ui/menubar/bookmarks-menu");

    $bookmarks_menu->set_submenu($bookmarks->generate_bookmarks_menu);
    $bookmarks_menu->show;

    $self->{filepane1}->open_path(
	(defined $ARGV[0] and -d $ARGV[0])
	? $ARGV[0]
	: Filer::Config->instance()->get_option('PathLeft')
	);

    $self->{filepane2}->open_path(
	(defined $ARGV[1] and -d $ARGV[1])
	? $ARGV[1]
	: Filer::Config->instance()->get_option('PathRight')
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

sub init_actions {
    my ($self) = @_;
    
    my $actions = Gtk2::ActionGroup->new("Actions");

    my $a_entries =
	[{
	    name => "FileMenuAction",
	    label => "_File",
	 },{
	     name => "open-terminal-action",
	     label => "Open Terminal",
	     accelerator => "F2",
	     callback => sub { $self->open_terminal_cb(); },
	 },{
	     name => "open-action",
	     stock_id => "gtk-open",
	     callback => sub { $self->open_cb(); },
	     accelerator => "F3",
	 },{
	     name => "open-with-action",
	     label => "Open With",
	     callback => sub { $self->open_with_cb(); },
	 },{
	     name => "quit-action",
	     stock_id => "gtk-quit",
	     accelerator => "<control>Q",
	     callback => sub { $self->quit_cb(); },
	 },{
	     name => "EditMenuAction",
	     label => "_Edit",
	 },{
	     name => "copy-action",
	     label => "Copy",
	     tooltip => "Copy selected files",
	     accelerator => "F5",
	     callback => sub { $self->copy_cb(); },
	 },{
	     name => "move-action",
	     label => "Move",
	     tooltip => "Move selected files",
	     accelerator => "F6",
	     callback => sub { $self->move_cb(); },
	 },{
	     name => "mkdir-action",
	     label => "New Folder",
	     tooltip => "New Folder",
	     accelerator => "F7",
	     callback => sub { $self->mkdir_cb(); },
	 },{
	     name => "delete-action",
	     stock_id => "gtk-delete",
	     tooltip => "Delete files",
	     accelerator => "F8",
	     callback => sub { $self->delete_cb(); },
	 },{
	     name => "symlink-action",
	     label => "Symlink",
	     callback => sub { $self->symlink_cb(); },
	 },{
	     name => "refresh-action",
	     stock_id => "gtk-refresh",
	     tooltip => "Refresh",
	     accelerator => "<control>R",
	     callback => sub { $self->refresh_cb(); },
	 },{
	     name => "search-action",
	     stock_id => "gtk-find",
	     label => "Search",
	     callback => sub { $self->show_search_dialog(); },
	 },{
	     name => "select-action",
	     label => "Select",
	     accelerator => "KP_Add",
	     callback => sub { $self->show_file_selection_dialog(); },
	 },{
	     name => "unselect-action",
	     label => "Unselect",
	     accelerator => "KP_Subtract",
	     callback => sub { $self->show_file_unselection_dialog(); },
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
	     callback => sub { $self->show_about_dialog(); },
	 },{
	     name => "home-action",
	     stock_id => "gtk-home",
	     tooltip => "Go Home",
	     callback => sub { $self->go_home_cb(); },
	 },{
	     name => "synchronize-action",
	     label => "Synchronize",
	     tooltip => "Synchronize Folders",
	     callback => sub { $self->synchronize_cb(); },
	 },{
	     name => "properties-action",
	     stock_id => "gtk-properties",
	     callback => sub { $self->set_properties(); },
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
	    callback => sub { $self->ask_copy_cb($_[0]); },
	    is_active => Filer::Config->instance()->get_option("ConfirmCopy"),
	 },{
	     name => "ask-moving-action",
	     label => "Moving",
	     callback => sub { $self->ask_move_cb($_[0]); },
	     is_active => Filer::Config->instance()->get_option("ConfirmMove"),
	 },{
	     name => "ask-deleting-action",
	     label => "Deleting",
	     callback => sub { $self->ask_delete_cb($_[0]); },
	     is_active => Filer::Config->instance()->get_option("ConfirmDelete"),
	 },{
	     name => "show-hidden-action",
	     label => "Show Hidden Files",
	     callback => sub { $self->show_hidden_files($_[0]); },
	     accelerator => "<control>H",
	     is_active => Filer::Config->instance()->get_option("ShowHiddenFiles"),
	 }];

    $actions->add_actions($a_entries);
    $actions->add_radio_actions($a_radio_entries, Filer::Config->instance()->get_option("Mode"), sub {
	my ($action) = @_;
	Filer::Config->instance()->set_option('Mode', $action->get_current_value);
	$self->switch_mode;
				});
    $actions->add_toggle_actions($a_toggle_entries);

    $self->{uimanager} = Gtk2::UIManager->new;
    $self->{uimanager}->add_ui_from_file("$main::libpath/filer.ui");
    $self->{uimanager}->insert_action_group($actions, 0);

    my $accels = $self->{uimanager}->get_accel_group;
    $self->{main_window}->add_accel_group($accels);
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

    Filer::Config->instance()->set_options(
	'PathLeft'   => $self->{filepane1}->get_pwd,
	'PathRight'  => $self->{filepane2}->get_pwd,
	'WindowSize' => join ":", $self->{main_window}->get_size,
	);

    Gtk2->main_quit;
}

sub show_about_dialog {
    my ($self) = @_;

    my $license = join "", <DATA>;
    $license =~ s/__VERSION__/$VERSION/g;

    my $dialog = Gtk2::AboutDialog->new;
    $dialog->set_name("Filer");
    $dialog->set_version($VERSION);
    $dialog->set_copyright("Copyright (c) 2004-2010 Jens Luedicke");
    $dialog->set_license($license);
    $dialog->set_website("http://nullmedium.org");
    $dialog->set_website_label("http://nullmedium.org");
    $dialog->set_authors(
	"Jens Luedicke <jens.luedicke\@gmail.com>",
	"Bjoern Martensen <bjoern.martensen\@gmail.com>"
	);

    $dialog->show;
}

sub open_cb {
    my ($self) = @_;

    my $mode = Filer::Config->instance()->get_option('Mode');
    my $pane =
	($mode == $NORTON_COMMANDER_MODE) 
	? $self->{active_pane} 
    : $self->{pane}->[$RIGHT];

    $pane->open_file($pane->get_fileinfo_list->[0]);
}

sub open_with_cb {
    my ($self) = @_;

    my $mode = Filer::Config->instance()->get_option('Mode');
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

    if (Filer::Config->instance()->get_option('Mode') == $EXPLORER_MODE) {
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

sub show_hidden_files {
    my ($self,$action) = @_;

    my $opt = ($action->get_active) ? 1 : 0;
    Filer::Config->instance()->set_option('ShowHiddenFiles', $opt);

    $self->{pane}->[$LEFT]->set_show_hidden($opt);
    $self->{pane}->[$RIGHT]->set_show_hidden($opt);

    return 1;
}

sub ask_copy_cb {
    my ($self,$action) = @_;
    Filer::Config->instance()->set_option('ConfirmCopy', ($action->get_active) ? 1 : 0);
}

sub ask_move_cb {
    my ($self,$action) = @_;
    Filer::Config->instance()->set_option('ConfirmMove', ($action->get_active) ? 1 : 0);
}

sub ask_delete_cb {
    my ($self,$action) = @_;
    Filer::Config->instance()->set_option('ConfirmDelete', ($action->get_active) ? 1 : 0);
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
    my $opt  = Filer::Config->instance()->get_option('Mode');
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

sub show_file_selection_dialog {
    my ($self) = @_;
    my $pane =
	($self->{active_pane}->get_type eq "TREE")
	? $self->{pane}->[$RIGHT]
	: $self->{active_pane};

    $pane->show_file_selection_dialog($Filer::FilePane::SELECT);
}

sub show_file_unselection_dialog {
    my ($self) = @_;
    my $pane =
	($self->{active_pane}->get_type eq "TREE")
	? $self->{pane}->[$RIGHT]
	: $self->{active_pane};

    $pane->show_file_selection_dialog($Filer::FilePane::UNSELECT);
}

sub show_search_dialog {
    my ($self) = @_;
    Filer::Search->new($self);
}

sub copy_cb {
    my ($self) = @_;

    my $items_count = $self->{active_pane}->count_items;
    return if ($items_count == 0);

    my $files = $self->{active_pane}->get_item_list;
    my $dest  = $self->{inactive_pane}->get_pwd;

    Filer::Copy::copy($files, $dest);

    $self->refresh_cb;
}

sub move_cb {
    my ($self) = @_;

    my $items_count = $self->{active_pane}->count_items;
    return if ($items_count == 0);

    my $files = $self->{active_pane}->get_item_list;
    my $dest  = $self->{inactive_pane}->get_pwd;
    
    Filer::Move::move($files, $dest);

    $self->refresh_cb;
}

sub delete_cb {
    my ($self) = @_;
    my $items       = $self->{active_pane}->get_item_list;
    my $items_count = $self->{active_pane}->count_items;

    return if ($items_count == 0);

    Filer::Delete::delete($items);

    $self->refresh_cb;
}

sub mkdir_cb {
    my ($self) = @_;

    my $dialog = Gtk2::Dialog->new(
	"New folder",
	undef,
	'modal',
	'gtk-cancel'  => 'cancel',
	'gtk-ok'      => 'ok'
	);

    $dialog->set_size_request(450,150);
    $dialog->set_position('center');

    my $label = Gtk2::Label->new;
    $label->set_text("New folder:");
    $label->set_alignment(0.0,0.0);
    $dialog->vbox->pack_start($label, $FALSE, $FALSE, 2);

    my $entry = Gtk2::Entry->new;
    $entry->set_text("New_Folder");
    $entry->set_activates_default($TRUE);
    $dialog->vbox->pack_start($entry, $TRUE, $TRUE, 0);

    $dialog->show_all;

    if ($dialog->run eq 'ok') {
	my $dir  = Filer::Tools->catpath($self->{active_pane}->get_pwd, $entry->get_text);

	if (!mkdir($dir)) {
	    Filer::Dialog->show_error_message("Make directory $dir failed: $!");
	}

    	$self->refresh_cb;
    }

    $dialog->destroy;
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
	    Filer::Dialog->show_error_message("Couldn't create symlink! $!");
	}
    }

    $dialog->destroy;

    $self->refresh_cb;
}

1;

__DATA__

    Filer __VERSION__
    Copyright (C) 2004-2010 Jens Luedicke <jens.luedicke@gmail.com>

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
