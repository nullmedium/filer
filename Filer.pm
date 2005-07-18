package Filer;

no utf8;

use strict;
use warnings;

use Storable;
use Gtk2;
use Gtk2::Gdk::Keysyms;

use Cwd qw(abs_path);
use Fcntl;
use Memoize;
use File::Spec;
use File::Spec::Functions qw(catfile splitdir);
use File::BaseDir;
use File::Basename;
use File::MimeInfo::Magic;
use File::Temp;
use File::DirWalk;
use Stat::lsMode;

use Unicode::String qw(utf8 latin1);

use Filer::Constants;

require Filer::Config;
require Filer::Bookmarks;
require Filer::FileInfo;
require Filer::Tools;
require Filer::Mime;
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

Memoize::memoize("abs_path");
Memoize::memoize("catfile");
Memoize::memoize("splitdir");

sub new {
	my ($class) = @_; 
	my $self = bless {}, $class;
	
	$self->{VERSION} = "0.0.13-svn";
	$self->{widgets} = ();
	$self->{pane} = [];
	$self->{active_pane} = ();
	$self->{inactive_pane} = ();
	$self->{config} = ();

	return $self;
}

sub create_main_window {
	my ($self) = @_;
	my ($window,$hbox,$button,$accel_group,$toolbar);

	$self->{widgets}->{main_window} = new Gtk2::Window('toplevel');
	$self->{widgets}->{main_window}->set_title("Filer $self->{VERSION}");

	my $size = $self->{config}->get_option("WindowSize");
	my ($w,$h) = split /:/, $size;

 	$self->{widgets}->{main_window}->resize($w,$h);
#	$self->{widgets}->{main_window}->resize(784,606);

	$self->{widgets}->{main_window}->signal_connect("event", sub { $self->window_event_cb(@_) });
	$self->{widgets}->{main_window}->signal_connect("delete-event", sub { $self->quit_cb });
	$self->{widgets}->{main_window}->set_icon(Gtk2::Gdk::Pixbuf->new_from_file((new Filer::Mime($self))->get_icon('inode/directory')));

	$self->{widgets}->{vbox} = new Gtk2::VBox(0,0);
	$self->{widgets}->{main_window}->add($self->{widgets}->{vbox});

	my $actions = new Gtk2::ActionGroup("Actions");

	my $a_entries = [
	{
		name => "FileMenuAction",
		label => "File",
	},
	{
		name => "open-terminal-action",
		label => "Open Terminal",
		callback => sub { $self->open_terminal_cb },
		accelerator => "F2",
	},
	{
		name => "open-action",
		stock_id => "gtk-open",
		label => "Open",
		callback => sub { $self->open_cb },
		accelerator => "F3",
	},
	{
		name => "open-with-action",
		label => "Open With",
		callback => sub { $self->open_with_cb },
	},
	{
		name => "quit-action",
		stock_id => "gtk-quit",
		callback => sub { $self->quit_cb },
		accelerator => "<control>Q",
	},
	{
		name => "EditMenuAction",
		label => "Edit",
	},
	{
		name => "cut-action",
		stock_id => "gtk-cut",
		callback => sub { $self->cut_cb },
		tooltip => "Cut Selection", 
		accelerator => "<control>X",
	},
	{
		name => "copy-action",
		stock_id => "gtk-copy",
		callback => sub { $self->copy_cb },
		tooltip => "Copy Selection", 
		accelerator => "<control>C",
	},
	{
		name => "paste-action",
		stock_id => "gtk-paste",
		callback => sub { $self->paste_cb },
		tooltip => "Paste Clipboard", 
		accelerator => "<control>V",
	},
	{
		name => "rename-action",
		label => "Rename",
		callback => sub { $self->rename_cb },
		tooltip => "Rename", 
		accelerator => "F6",
	},
	{
		name => "mkdir-action",
		label => "MkDir",
		callback => sub { $self->mkdir_cb },
		tooltip => "Make Directory", 
		accelerator => "F7",
	},
	{
		name => "delete-action",
		stock_id => "gtk-delete",
		callback => sub { $self->delete_cb },
		tooltip => "Delete files", 
		accelerator => "F8",
	},
	{
		name => "link-action",
		label => "Link",
		callback => sub { $self->link_cb },
	},
	{
		name => "symlink-action",
		label => "SymLink",
		callback => sub { $self->symlink_cb },
	},
	{
		name => "refresh-action",
		stock_id => "gtk-refresh",
		callback => sub { $self->refresh_cb },
		tooltip => "Refresh", 
		accelerator => "<control>R",
	},
	{
		name => "search-action",
		label => "Search",
		stock_id => "gtk-find",
		callback => sub { $self->search_cb },
	},
	{
		name => "select-action",
		label => "Select",
		callback => sub { $self->select_cb },
		accelerator => "KP_Add",
	},
	{
		name => "unselect-action",
		label => "Unselect",
		callback => sub { $self->unselect_cb },
		accelerator => "KP_Subtract",
	},
	{
		name => "BookmarksMenuAction",
		label => "Bookmarks",
	},
	{
		name => "OptionsMenuAction",
		label => "Options",
	},
	{
		name => "ModeMenuAction",
		label => "View Mode",
	},
	{
		name => "ConfirmationMenuAction",
		label => "Ask Confirmation for ...",
	},
	{
		name => "set-terminal-action",
		label => "Set Terminal",
		callback => sub { $self->set_terminal_cb },
	},
	{
		name => "set-editor-action",
		label => "Set Editor",
		callback => sub { $self->set_terminal_cb },
	},
	{
		name => "file-assoc-action",
		label => "File Associations",
		callback => sub { $self->file_ass_cb },
	},
	{
		name => "HelpMenuAction",
		label => "Help",
	},
	{
		name => "about-action",
		stock_id => "gtk-about",
		callback => sub { $self->about_cb },
	},

# Toolbar items
# the other toolbar items are merged into the toolbar. see filer.ui	

	{
		name => "home-action",
		stock_id => "gtk-home",
		tooltip => "Go Home", 
		callback => sub { $self->go_home_cb },
	},
	{
		name => "synchronize-action",
		label => "Synchronize",
		tooltip => "Synchronize Folders", 
		callback => sub { $self->synchronize_cb },
	},

# PopupMenu items 
# the other menuitems items are merged into the menu. see filer.ui	

	{
		name => "OpenPopupMenuAction",
		stock_id => "gtk-open",
	},
	{
		name => "ArchiveMenuAction",
		label => "Archive",
	},
	{
		name => "create-tgz-action",
		label => "Create tar.gz",
		callback => sub { $self->{active_pane}->create_tar_gz_archive; }
	},
	{
		name => "create-tbz2-action",
		label => "Create tar.bz2",
		callback => sub { $self->{active_pane}->create_tar_bz2_archive; }
	},
	{
		name => "extract-action",
		label => "Extract",
		callback => sub { $self->{active_pane}->extract_archive; }
	},
	{
		name => "BookmarksPopupMenuAction",
		label => "Bookmarks",
	},
	{
		name => "properties-action",
		label => "Properties",
		callback => sub { $self->{active_pane}->set_properties; }
	},
	];

	my $a_radio_entries = [
	{
		name => "commander-style-action",
		label => "Norton Commander Style",
		value => NORTON_COMMANDER_MODE,
	},
	{
		name => "explorer-style-action",
		label => "MS Explorer View",
		value => EXPLORER_MODE,
	},
	];

	my $a_toggle_entries = [
	{
		name => "ask-copying-action",
		label => "Copying",
		callback => sub { $self->ask_copy_cb($_[0]) },
		is_active => $self->{config}->get_option("ConfirmCopy"),
	},
	{
		name => "ask-moving-action",
		label => "Moving",
		callback => sub { $self->ask_move_cb($_[0]) },
		is_active => $self->{config}->get_option("ConfirmMove"),
	},
	{
		name => "ask-deleting-action",
		label => "Deleting",
		callback => sub { $self->ask_delete_cb($_[0]) },
		is_active => $self->{config}->get_option("ConfirmDelete"),
	},
	{
		name => "show-hidden-action",
		label => "Show Hidden Files",
		callback => sub { $self->hidden_cb($_[0]) },
		accelerator => "<control>H",
		is_active => $self->{config}->get_option("ShowHiddenFiles"),
	},
	{
		name => "case-sort-action",
		label => "Case Insensitive Sort",
		callback => sub { $self->case_sort_cb($_[0]) },
		is_active => $self->{config}->get_option("CaseInsensitiveSort"),
	},
	];

	$actions->add_actions($a_entries);
	$actions->add_radio_actions($a_radio_entries, $self->{config}->get_option("Mode"), sub { 
		my ($action) = @_; 
		$self->{config}->set_option('Mode', $action->get_current_value);
		$self->switch_mode;
	});
	$actions->add_toggle_actions($a_toggle_entries);

	$self->{widgets}->{uimanager} = new Gtk2::UIManager;
	$self->{widgets}->{uimanager}->insert_action_group($actions, 0);
	$self->{widgets}->{uimanager}->add_ui_from_file("$main::libpath/filer.ui");

	my $accels = $self->{widgets}->{uimanager}->get_accel_group;
	$self->{widgets}->{main_window}->add_accel_group($accels);

	$self->{widgets}->{menubar} = $self->{widgets}->{uimanager}->get_widget("/ui/menubar");
 	$self->{widgets}->{vbox}->pack_start($self->{widgets}->{menubar}, 0, 0, 0);

	$self->{widgets}->{toolbar} = $self->{widgets}->{uimanager}->get_widget("/ui/toolbar");
	$self->{widgets}->{toolbar}->set_style('GTK_TOOLBAR_TEXT');
	$self->{widgets}->{sync_button} = $self->{widgets}->{uimanager}->get_widget("/ui/toolbar/Synchronize");
	$self->{widgets}->{vbox}->pack_start($self->{widgets}->{toolbar}, 0, 0, 0);

	$self->{widgets}->{location_bar} = new Gtk2::HBox(0,0);
	$self->{widgets}->{vbox}->pack_start($self->{widgets}->{location_bar}, 0, 0, 0);

	$self->{widgets}->{hpaned} = new Gtk2::HPaned();
	$self->{widgets}->{hbox} = new Gtk2::HBox(0,0);

	$self->{widgets}->{tree} = new Filer::FileTreePane($self,LEFT);
	$self->{widgets}->{list1} = new Filer::FilePane($self,LEFT);
	$self->{widgets}->{list2} = new Filer::FilePane($self,RIGHT);

	$self->{widgets}->{hpaned}->add1($self->{widgets}->{tree}->get_vbox);
	$self->{widgets}->{hpaned}->add2($self->{widgets}->{hbox});
	$self->{widgets}->{hbox}->pack_start($self->{widgets}->{list1}->get_vbox,1,1,0);
	$self->{widgets}->{hbox}->pack_start($self->{widgets}->{list2}->get_vbox,1,1,0);
	$self->{widgets}->{vbox}->pack_start($self->{widgets}->{hpaned},1,1,0);

	$self->{widgets}->{statusbar} = new Gtk2::Statusbar;
	$self->{widgets}->{vbox}->pack_start($self->{widgets}->{statusbar}, 0, 0, 0);

  	my $bookmarks = new Filer::Bookmarks($self);
  	$self->{widgets}->{uimanager}->get_widget("/ui/menubar/bookmarks-menu")->set_submenu($bookmarks->bookmarks_menu);
	$self->{widgets}->{uimanager}->get_widget("/ui/menubar/bookmarks-menu")->show;

	$self->{widgets}->{list1}->open_path((defined $ARGV[0] and -d $ARGV[0]) ? $ARGV[0] : $self->{config}->get_option('PathLeft'));
	$self->{widgets}->{list2}->open_path((defined $ARGV[1] and -d $ARGV[1]) ? $ARGV[1] : $self->{config}->get_option('PathRight'));

	$self->{widgets}->{main_window}->show_all;

	$self->{widgets}->{sync_button}->hide;
	$self->{widgets}->{tree}->get_vbox->hide;
	$self->{widgets}->{list1}->get_vbox->hide;
	$self->{widgets}->{list2}->get_vbox->show;

	$self->{pane}->[LEFT] = undef;
	$self->{pane}->[RIGHT] = $self->{widgets}->{list2};

	$self->switch_mode;

	$self->{pane}->[RIGHT]->set_focus;
}

sub init_config {
	my ($self) = @_;
	$self->{config} = new Filer::Config;
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

	$self->{config}->set_option('PathLeft', $self->{pane}->[LEFT]->get_pwd);
	$self->{config}->set_option('PathRight', $self->{pane}->[RIGHT]->get_pwd);
	$self->{config}->set_option('WindowSize', join ":", $self->{widgets}->{main_window}->get_size());

	Gtk2->main_quit;
}

sub about_cb {
	my ($self) = @_;

	my $dialog = new Gtk2::AboutDialog; 
	$dialog->set_name("Filer");
	$dialog->set_version($self->{VERSION});
	$dialog->set_copyright("Copyright © 2004-2005 Jens Luedicke");
	$dialog->set_website("http://perldude.de/"); 
	$dialog->set_website_label("http://perldude.de/");
	$dialog->set_authors(	"Jens Luedicke <jens.luedicke\@gmail.com>",
				"Bjoern Martensen <bjoern.martensen\@gmail.com>"
	);

	$dialog->show;
}

sub open_cb {
	my ($self) = @_;

	if ($self->{config}->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$self->{active_pane}->open_file($self->{active_pane}->get_item);
	} else {
		$self->{pane}->[RIGHT]->open_file($self->{pane}->[RIGHT]->get_item);
	}
}

sub open_with_cb {
	my ($self) = @_;

	if ($self->{config}->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$self->{active_pane}->open_file_with;
	} else {
		$self->{pane}->[RIGHT]->open_file_with;
	}
}

sub open_terminal_cb {
	my ($self) = @_;
	my $path = $self->{active_pane}->get_item;

	if (-d $path) {
		my $term = $self->{config}->get_option("Terminal");
		system("cd '$path' && $term & exit");
	}
}

sub switch_mode {
	my ($self) = @_;

	if ($self->{config}->get_option('Mode') == EXPLORER_MODE) {
		$self->{widgets}->{list2}->get_location_bar->hide;
		$self->{widgets}->{list2}->get_location_bar->reparent($self->{widgets}->{location_bar});
		$self->{widgets}->{list2}->get_location_bar->show;

		$self->{widgets}->{sync_button}->set("visible", 0);
		$self->{widgets}->{tree}->get_vbox->set("visible", 1);
		$self->{widgets}->{list1}->get_vbox->set("visible", 0);

		$self->{widgets}->{list1}->get_navigation_box->hide;
		$self->{widgets}->{list2}->get_navigation_box->show;

		$self->{pane}->[LEFT] = $self->{widgets}->{tree};
	} else {
		$self->{widgets}->{list2}->get_location_bar->hide;
		$self->{widgets}->{list2}->get_location_bar->reparent($self->{widgets}->{list2}->get_location_bar_parent);
		$self->{widgets}->{list2}->get_location_bar->show;

		$self->{widgets}->{sync_button}->set("visible", 1);
		$self->{widgets}->{tree}->get_vbox->set("visible", 0);
		$self->{widgets}->{list1}->get_vbox->set("visible", 1);

 		$self->{widgets}->{list1}->get_navigation_box->hide;
 		$self->{widgets}->{list2}->get_navigation_box->hide;

		$self->{pane}->[LEFT] = $self->{widgets}->{list1};
	}
}

sub hidden_cb {
	my ($self,$action) = @_;
	$self->{config}->set_option('ShowHiddenFiles', ($action->get_active) ? 1 : 0);
	$self->{pane}->[LEFT]->refresh;
	$self->{pane}->[RIGHT]->refresh;
	return 1;
}

sub case_sort_cb {
	my ($self,$action) = @_;
	$self->{config}->set_option('CaseInsensitiveSort', ($action->get_active) ? 1 : 0);
	$self->{pane}->[LEFT]->refresh;
	$self->{pane}->[RIGHT]->refresh;
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

sub set_terminal_cb {
	my ($self) = @_;
	my $term = Filer::Dialog->ask_command_dialog("Set Terminal", $self->{config}->get_option('Terminal'));
	$self->{config}->set_option('Terminal', $term);	
}

sub set_editor_cb {
	my ($self) = @_;
	my $edit = Filer::Dialog->ask_command_dialog("Set Editor", $self->{config}->get_option('Editor'));
	$self->{config}->set_option('Editor', $edit);	
}

sub file_ass_cb {
	my ($self) = @_;
	my $mime = new Filer::Mime($self);
	$mime->file_association_dialog;
}

sub refresh_cb {
	my ($self) = @_;

	if ($self->{pane}->[LEFT]->get_pwd eq $self->{pane}->[RIGHT]->get_pwd) {
		if ($self->{pane}->[LEFT]->get_type eq $self->{pane}->[RIGHT]->get_type) {
			$self->{pane}->[LEFT]->refresh;
			$self->{pane}->[RIGHT]->set_model($self->{pane}->[LEFT]->get_model);
		} else {
			$self->{pane}->[LEFT]->refresh;
			$self->{pane}->[RIGHT]->refresh;
		}
	} else {
		$self->{pane}->[LEFT]->refresh;
		$self->{pane}->[RIGHT]->refresh;
	}

	return 1;
}

sub refresh_inactive_pane {
	my ($self) = @_;

	if ($self->{active_pane}->get_pwd eq $self->{inactive_pane}->get_pwd) {
		if ($self->{active_pane}->get_type eq $self->{inactive_pane}->get_type) {
			$self->{inactive_pane}->set_model($self->{active_pane}->get_model);
		} else {
			$self->{inactive_pane}->refresh;
		}
	} else {
		$self->{inactive_pane}->refresh;
	}
}

sub go_home_cb {
	my ($self) = @_;
	my $opt = $self->{config}->get_option('Mode');

	if ($opt == NORTON_COMMANDER_MODE) {
		$self->{active_pane}->open_path($ENV{HOME});
	} elsif ($opt == EXPLORER_MODE) {
		$self->{pane}->[RIGHT]->open_path($ENV{HOME});
	}
}

sub synchronize_cb {
	my ($self) = @_;
	$self->{inactive_pane}->open_path($self->{active_pane}->get_pwd);
}

sub select_cb {
	my ($self) = @_;
	my $p;

	if ($self->{active_pane}->get_type eq "TREE") {
		$p = $self->{pane}->[RIGHT];
	} else {
		$p = $self->{active_pane};
	}

	$p->select_dialog(Filer::FilePane->SELECT);
}

sub unselect_cb {
	my ($self) = @_;
	my $p;

	if ($self->{active_pane}->get_type eq "TREE") {
		$p = $self->{pane}->[RIGHT];
	} else {
		$p = $self->{active_pane};
	}

	$p->select_dialog(Filer::FilePane->UNSELECT);
}

sub search_cb {
	my ($self) = @_;
	new Filer::Search($self);
}

sub paste_cb {
	my ($self) = @_;
	my @files = split /\n\r/, $self->get_clipboard_contents;
	my $action = pop @files;
	my $target = ($self->{active_pane}->get_type eq "TREE") ? $self->{active_pane}->get_updir : $self->{active_pane}->get_pwd;
	my $do;

	return if (not defined $action);

	if ($action eq "copy") {
		$do = new Filer::Copy;
	} else {
		$do = new Filer::Move;
	}

	$do->set_total($self->files_count_paste);
	$do->show;

	foreach (@files) {
		return if (! -e $_);

		my $r = $do->action($_, $target);

		if ($action eq "copy") {
			if ($r == File::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Copying of $_ to " . $self->{inactive_pane}->get_pwd . " failed: $!");
				last;
			} elsif ($r == File::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Copying of $_ to " . $self->{inactive_pane}->get_pwd . " aborted!");
				last;
			}
		} else {
			if ($r == File::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Moving of $_ to " . $self->{inactive_pane}->get_pwd . " failed: $!");
				last;
			} elsif ($r == File::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Moving of $_ to " . $self->{inactive_pane}->get_pwd . " aborted!");
				last;
			}
		}
	}

	$do->destroy;

	# refresh panes.
	$self->{active_pane}->refresh;
	$self->refresh_inactive_pane;

	# reset clipboard
	if ($action eq "cut") {
		$self->set_clipboard_contents("");
	}
}

sub cut_cb {
	my ($self) = @_;
	return if ($self->{active_pane}->count_items == 0);

 	my @files =  (@{$self->{active_pane}->get_items}, "cut");	
 	$self->set_clipboard_contents(join "\n\r", @files);
}

sub copy_cb {
	my ($self) = @_;
	return if ($self->{active_pane}->count_items == 0);

	my @files =  (@{$self->{active_pane}->get_items}, "copy");
	$self->set_clipboard_contents(join "\n\r", @files);
}

sub rename_cb {
	my ($self) = @_;
	my ($dialog,$hbox,$label,$entry);

	return if ($self->{active_pane}->count_items == 0);

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
	$entry->set_text($self->{active_pane}->get_fileinfo->[0]->get_basename);
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $old_pwd = $self->{active_pane}->get_pwd;		
		my $old = $self->{active_pane}->get_item;
		my $new;
		
		if ($self->{active_pane}->get_type eq "TREE") {
			$new = abs_path(catfile(splitdir(dirname($old_pwd)), $entry->get_text));			
		} else {
			$new = abs_path(catfile(splitdir($old_pwd), $entry->get_text));			
		}
		
		if (rename($old,$new)) {
			$self->{active_pane}->set_item(new Filer::FileInfo($new));
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Rename failed: $!");
		}
	}

	$dialog->destroy;
}

sub delete_cb {
	my ($self) = @_;

	return if ($self->{active_pane}->count_items == 0);

	if ($self->{config}->get_option("ConfirmDelete") == 1) {
		if ($self->{active_pane}->count_items == 1) {
			my $f = $self->{active_pane}->get_fileinfo->[0]->get_basename; 
			$f =~ s/&/&amp;/g; # sick fix. meh. 

			if (-f $self->{active_pane}->get_item) {
				return if (Filer::Dialog->yesno_dialog("Delete file \"$f\"?") eq 'no');
			} elsif (-d $self->{active_pane}->get_item) {
				return if (Filer::Dialog->yesno_dialog("Delete directory \"$f\"?") eq 'no');
			}
		} else {
			return if (Filer::Dialog->yesno_dialog(sprintf("Delete %s selected files?", $self->{active_pane}->count_items)) eq 'no');
		}
	}

	my $delete = Filer::Delete->new;
	my $t = &files_count; 

	if (($t > 1) or (-d $self->{active_pane}->get_item)) {
		$delete->set_total($t);
		$delete->show;

		foreach (@{$self->{active_pane}->get_items}) {
			my $r = $delete->delete($_);

			if ($r == File::DirWalk::FAILED) {
				Filer::Dialog->msgbox_info("Deleting of $_ failed: $!");
				last;
			} elsif ($r == File::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Deleting of $_ aborted!");
				last;
			}
		}

		$delete->destroy;
	} else {
		my $f = $self->{active_pane}->get_item; 
		
		if (! unlink($f)) {
			Filer::Dialog->msgbox_info(sprintf("Deleting of \"%s\" failed: $!", $f));
		}
	}

	$self->{active_pane}->remove_selected;
	$self->refresh_inactive_pane;
}

sub mkdir_cb {
	my ($self) = @_;
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("Make directory", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);
	$dialog->set_default_response('ok');

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox, 0,0,5);

	$label = new Gtk2::Label;
	$label->set_text($self->{active_pane}->get_pwd);
	$hbox->pack_start($label, 0,0,2);

	$entry = new Gtk2::Entry;
	$entry->set_text("New Folder");
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $dir = catfile(splitdir($self->{active_pane}->get_pwd), $entry->get_text);

		if (mkdir($dir)) {
			$self->{active_pane}->refresh;
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Make directory $dir failed: $!");
		}
	}

	$dialog->destroy;
}

sub link_cb {
	my ($self) = @_;
	return if ($self->{active_pane}->count_items == 0);

	my ($dialog,$link_label,$target_label,$link_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	$dialog->set_title("Link");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$link_label->set_markup("<b>Link: </b>");
	$link_entry->set_text(catfile(splitdir($self->{active_pane}->get_pwd), $self->{active_pane}->get_fileinfo->[0]->get_basename));
	$link_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($self->{active_pane}->get_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $link = $link_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($link) eq File::Spec->curdir) {
			$link = catfile(splitdir($self->{active_pane}->get_pwd), $link);
		}

		if (link($target, $link)) {
			$self->{active_pane}->refresh;
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create link! $!");
		}
	}

	$dialog->destroy;
}

sub symlink_cb {
	my ($self) = @_;
	return if ($self->{active_pane}->count_items == 0);

	my ($dialog,$symlink_label,$target_label,$symlink_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	$dialog->set_title("Symlink");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$symlink_label->set_markup("<b>Symlink: </b>");
	$symlink_entry->set_text(catfile(splitdir($self->{active_pane}->get_pwd), $self->{active_pane}->get_fileinfo->[0]->get_basename));
	$symlink_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($self->{active_pane}->get_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $symlink = $symlink_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($symlink) eq File::Spec->curdir) {
			$symlink = catfile(splitdir($self->{active_pane}->get_pwd), $symlink);
		}

		if (symlink($target, $symlink)) {
			$self->{active_pane}->refresh;
			$self->refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create symlink! $!");
		}
	}

	$dialog->destroy;
}

sub files_count {
	my ($self) = @_;
	my $c = 0;

	if (($self->{active_pane}->count_items == 1) and (! -d $self->{active_pane}->get_item)) {
		$c = 1;
	} else {
		my $dialog = new Filer::ProgressDialog;
		$dialog->dialog->set_title("Please wait ...");
		$dialog->label1->set_markup("<b>Please wait ...</b>");

		my $progressbar = $dialog->add_progressbar;

		$dialog->show;

		my $id = Glib::Timeout->add(50, sub {
			$progressbar->pulse;
			return 1;
		});

		my $dirwalk = new File::DirWalk;
		$dirwalk->onFile(sub {
			++$c;
			while (Gtk2->events_pending) { Gtk2->main_iteration }
			return File::DirWalk::SUCCESS;
		});

		foreach (@{$self->{active_pane}->get_items}) {
			if (-d $_) {
				$dirwalk->walk($_);
			} else {
				++$c;
			}
		}

		Glib::Source->remove($id);

		$dialog->destroy;
	}

	return $c;
}

sub files_count_paste {
	my ($self) = @_;
	my $c = 0;
	my $dirwalk = new File::DirWalk;

	my $dialog = new Filer::ProgressDialog;
	$dialog->dialog->set_title("Please wait ...");
	$dialog->label1->set_markup("<b>Please wait ...</b>");

	my $progressbar = $dialog->add_progressbar;

	$dialog->show;

	my $id = Glib::Timeout->add(50, sub {
		$progressbar->pulse;
		while (Gtk2->events_pending) { Gtk2->main_iteration }
		return 1;
	});

	$dirwalk->onFile(sub {
		++$c;
		while (Gtk2->events_pending) { Gtk2->main_iteration }
		return File::DirWalk::SUCCESS;
	});

	foreach (split /\n/, $self->get_clipboard_contents) {
		if (-e $_) {
			$dirwalk->walk($_);
		}
	}

	Glib::Source->remove($id);

	$dialog->destroy;

	return $c;
}

sub get_clipboard_contents {
	my ($self) = @_;
	my $clipboard = Gtk2::Clipboard->get_for_display($self->{widgets}->{main_window}->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
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
	my $clipboard = Gtk2::Clipboard->get_for_display($self->{widgets}->{main_window}->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
	$clipboard->set_text($contents);
}

1;
