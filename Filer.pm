package Filer;

use strict;
use warnings;

require Exporter; 
our @ISA = qw(Exporter);
our @EXPORT = qw($VERSION $widgets $pane $active_pane $inactive_pane $config $CLIPBOARD_ACTION $SKIP_ALL $OVERWRITE_ALL);

our $VERSION = "0.0.13-svn";
our $widgets;
our $pane;
our $active_pane;
our $inactive_pane;
our $config;
our $CLIPBOARD_ACTION;
our $SKIP_ALL;
our $OVERWRITE_ALL;

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
require Filer::SelectDialog;

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

sub main_window {
	my ($window,$hbox,$button,$accel_group,$toolbar);

	my @menu_items	=
	(
	{ path => '/_File/Open Terminal',		accelerator => 'F2',		callback => \&open_terminal_cb, item_type => '<Item>'},
	{ path => '/_File/Open',			accelerator => 'F3',		callback => \&open_cb,		item_type => '<Item>'},
	{ path => '/_File/Open With',							callback => \&open_with_cb,	item_type => '<Item>'},
	{ path => '/_File/sep', 									 		item_type => '<Separator>'},
	{ path => '/_File/Quit',			accelerator => 'F10',		callback => \&quit_cb, 	 	item_type => '<Item>'},

	{ path => '/_Edit/_Copy',			accelerator => '<control>C',	callback => \&copy_cb, 	 	item_type => '<Item>'},
	{ path => '/_Edit/_Cut',			accelerator => '<control>X',	callback => \&cut_cb, 	 	item_type => '<Item>'},
	{ path => '/_Edit/_Paste',			accelerator => '<control>V',	callback => \&paste_cb,	 	item_type => '<Item>'},

	{ path => '/_Edit/_Rename',			accelerator => 'F6',		callback => \&rename_cb, 	item_type => '<Item>'},
	{ path => '/_Edit/M_kDir',			accelerator => 'F7',		callback => \&mkdir_cb,	 	item_type => '<Item>'},
	{ path => '/_Edit/_Delete',			accelerator => 'F8',		callback => \&delete_cb,	item_type => '<Item>'},
	{ path => '/_Edit/sep', 											item_type => '<Separator>'},
	{ path => '/_Edit/_Link',							callback => \&link_cb,		item_type => '<Item>'},
	{ path => '/_Edit/_Symlink',							callback => \&symlink_cb,	item_type => '<Item>'},
	{ path => '/_Edit/sep', 											item_type => '<Separator>'},
	{ path => '/_Edit/Refresh',			accelerator => '<control>R',	callback => \&refresh_cb,	item_type => '<Item>'},
	{ path => '/_Edit/sep', 									 		item_type => '<Separator>'},
	{ path => '/_Edit/Search',							callback => \&search_cb,	item_type => '<Item>'},
	{ path => '/_Edit/sep', 											item_type => '<Separator>'},
	{ path => '/_Edit/Select',			accelerator => 'KP_Add',	callback => \&select_cb,	item_type => '<Item>'},
	{ path => '/_Edit/Unselect',			accelerator => 'KP_Subtract',	callback => \&unselect_cb,	item_type => '<Item>'},
	{ path => '/_Bookmarks',											item_type => '<Item>'},
	{ path => '/_Options/Mode/Norton Commander Style',				callback => \&ncmc_cb,		item_type => '<RadioItem>'},
	{ path => '/_Options/Mode/MS Explorer Style',					callback => \&explorer_cb,	item_type => '<RadioItem>'},
	{ path => '/_Options/sep',											item_type => '<Separator>'},
	{ path => '/_Options/Ask confirmation for/Copying',				callback => \&ask_copy_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/Ask confirmation for/Moving',				callback => \&ask_move_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/Ask confirmation for/Deleting',				callback => \&ask_delete_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/Show Hidden Files',	accelerator => '<control>H',	callback => \&hidden_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/sep',											item_type => '<Separator>'},
	{ path => '/_Options/Set Terminal',						callback => \&set_terminal_cb,	item_type => '<Item>'},
	{ path => '/_Options/Set Editor',						callback => \&set_editor_cb,	item_type => '<Item>'},
	{ path => '/_Options/sep',											item_type => '<Separator>'},
	{ path => '/_Options/File Associations',					callback => \&file_ass_cb,	item_type => '<Item>'},
	{ path => '/_Help/About',							callback => \&about_cb,		item_type => '<Item>'},
	);

	$widgets->{main_window} = new Gtk2::Window('toplevel');
	$widgets->{main_window}->set_title("Filer $VERSION");

	my $size = $config->get_option("WindowSize");
	my ($w,$h) = split /:/, $size;

 	$widgets->{main_window}->resize($w,$h);
#	$widgets->{main_window}->resize(784,606);

	$widgets->{main_window}->signal_connect("event", \&window_event_cb);
	$widgets->{main_window}->signal_connect("delete-event", \&quit_cb);
	$widgets->{main_window}->set_icon(Gtk2::Gdk::Pixbuf->new_from_file((new Filer::Mime)->get_icon('inode/directory')));

	$widgets->{vbox} = new Gtk2::VBox(0,0);
	$widgets->{main_window}->add($widgets->{vbox});

	$accel_group = new Gtk2::AccelGroup;
	$widgets->{main_window}->add_accel_group($accel_group);

	$widgets->{item_factory} = new Gtk2::ItemFactory("Gtk2::MenuBar", '<main>', $accel_group);
	$widgets->{item_factory}->create_items(undef, @menu_items);
	$widgets->{vbox}->pack_start($widgets->{item_factory}->get_widget('<main>'), 0, 0, 0);

	$toolbar = new Gtk2::Toolbar;
	$toolbar->set_style('GTK_TOOLBAR_TEXT');

	$widgets->{home_button} = Gtk2::ToolButton->new_from_stock('gtk-home');
	$widgets->{home_button}->signal_connect("clicked", \&go_home_cb);
	$toolbar->insert($widgets->{home_button}, 0);

	$widgets->{refresh_button} = Gtk2::ToolButton->new_from_stock('gtk-refresh');
	$widgets->{refresh_button}->signal_connect("clicked", \&refresh_cb);
	$toolbar->insert($widgets->{refresh_button}, 1);

	$widgets->{sync_button} = Gtk2::ToolButton->new(undef, "Synchronize");
	$widgets->{sync_button}->signal_connect("clicked", \&synchronize_cb);
	$toolbar->insert($widgets->{sync_button}, 2);

	$toolbar->insert(new Gtk2::SeparatorToolItem, 3);

	$button = Gtk2::ToolButton->new_from_stock('gtk-copy');
	$button->signal_connect("clicked", \&copy_cb);
	$toolbar->insert($button, 4);

	$button = Gtk2::ToolButton->new_from_stock('gtk-cut');
	$button->signal_connect("clicked", \&cut_cb);
	$toolbar->insert($button, 5);

	$button = Gtk2::ToolButton->new_from_stock('gtk-paste');
	$button->signal_connect("clicked", \&paste_cb);
	$toolbar->insert($button, 6);

	$toolbar->insert(new Gtk2::SeparatorToolItem, 7);

	$button = Gtk2::ToolButton->new(undef, "Rename");
	$button->signal_connect("clicked", \&rename_cb);
	$toolbar->insert($button, 8);

	$button = Gtk2::ToolButton->new(undef, "Mkdir");
	$button->signal_connect("clicked", \&mkdir_cb);
	$toolbar->insert($button, 9);
	
	$button = Gtk2::ToolButton->new_from_stock('gtk-delete');
	$button->signal_connect("clicked", \&delete_cb);
	$toolbar->insert($button, 10);

	$widgets->{vbox}->pack_start($toolbar, 0, 0, 0);

	$widgets->{location_bar} = new Gtk2::HBox(0,0);
	$widgets->{vbox}->pack_start($widgets->{location_bar}, 0, 0, 0);

	$pane = [];
	$widgets->{hpaned} = new Gtk2::HPaned();
	$widgets->{hbox} = new Gtk2::HBox(0,0);

	$widgets->{tree} = new Filer::FileTreePane(LEFT);
	$widgets->{list1} = new Filer::FilePane(LEFT);
	$widgets->{list2} = new Filer::FilePane(RIGHT);

	$widgets->{hpaned}->add1($widgets->{tree}->get_vbox);
	$widgets->{hpaned}->add2($widgets->{hbox});
	$widgets->{hbox}->pack_start($widgets->{list1}->get_vbox,1,1,0);
	$widgets->{hbox}->pack_start($widgets->{list2}->get_vbox,1,1,0);
	$widgets->{vbox}->pack_start($widgets->{hpaned},1,1,0);

	$widgets->{statusbar} = new Gtk2::Statusbar;
	$widgets->{vbox}->pack_start($widgets->{statusbar}, 0, 0, 0);

	my $bookmarks = $widgets->{item_factory}->get_item("/Bookmarks");
	$bookmarks->set_submenu((new Filer::Bookmarks)->bookmarks_menu);

	my $i1 = $widgets->{item_factory}->get_item("/Options/Mode/Norton Commander Style");
	my $i2 = $widgets->{item_factory}->get_item("/Options/Mode/MS Explorer Style");

	$i2->set_group($i1->get_group);

	if ($config->get_option('Mode') == EXPLORER_MODE) {
		$i1->set_active(0);
		$i2->set_active(1);
	} else {
		$i1->set_active(1);
		$i2->set_active(0);
	}

	$widgets->{list1}->open_path((defined $ARGV[0] and -d $ARGV[0]) ? $ARGV[0] : $config->get_option('PathLeft'));
	$widgets->{list2}->open_path((defined $ARGV[1] and -d $ARGV[1]) ? $ARGV[1] : $config->get_option('PathRight'));

	$widgets->{main_window}->show_all;

	$widgets->{sync_button}->hide;
	$widgets->{tree}->get_vbox->hide;
	$widgets->{list1}->get_vbox->hide;
	$widgets->{list2}->get_vbox->show;

	$pane->[LEFT] = undef;
	$pane->[RIGHT] = $widgets->{list2};

	&switch_mode;

	$widgets->{item_factory}->get_item("/Options/Show Hidden Files")->set_active($config->get_option('ShowHiddenFiles'));
	$widgets->{item_factory}->get_item("/Options/Ask confirmation for/Copying")->set_active($config->get_option('ConfirmCopy'));
	$widgets->{item_factory}->get_item("/Options/Ask confirmation for/Moving")->set_active($config->get_option('ConfirmMove'));
	$widgets->{item_factory}->get_item("/Options/Ask confirmation for/Deleting")->set_active($config->get_option('ConfirmDelete'));

	$pane->[RIGHT]->set_focus;
}

sub init_config {
	$config = new Filer::Config;
}

sub window_event_cb {
	if (($_[1]->type eq "key-press" and $_[1]->keyval == $Gtk2::Gdk::Keysyms{'Tab'})) {
		$inactive_pane->set_focus;
		return 1;
	}

	return 0;
}

sub quit_cb {
	$config->set_option('PathLeft', $pane->[LEFT]->get_pwd);
	$config->set_option('PathRight', $pane->[RIGHT]->get_pwd);
	$config->set_option('WindowSize', join ":", $widgets->{main_window}->get_size());

	Gtk2->main_quit;
}

sub about_cb {
	my $dialog = new Gtk2::AboutDialog; 
	$dialog->set_name("Filer");
	$dialog->set_version($VERSION);
	$dialog->set_copyright("&copy; 2004-2005 Jens Luedicke");
	$dialog->set_website("http://perldude.de/"); 
	$dialog->set_website_label("http://perldude.de/");
	$dialog->set_authors(	"Jens Luedicke <jens.luedicke\@gmail.com>",
				"Bjoern Martensen <bjoern.martensen\@gmail.com>"
	);

	$dialog->show;
}

sub open_cb {
	if ($config->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$active_pane->open_file($active_pane->get_item);
	} else {
		$pane->[RIGHT]->open_file($pane->[RIGHT]->get_item);
	}
}

sub open_with_cb {
	if ($config->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$active_pane->open_file_with;
	} else {
		$pane->[RIGHT]->open_file_with;
	}
}

sub open_terminal_cb {
	my $path = $active_pane->get_pwd;

	if (-d $path) {
		my $term = $config->get_option("Terminal");
		system("cd '$path' && $term & exit");
	}
}

sub ncmc_cb {
	# check if item is checked
	if ($_[2]->get_active) {
		$config->set_option('Mode', NORTON_COMMANDER_MODE);
		&switch_mode;
	}

	return 1;
}

sub explorer_cb {
	# check if item is checked
	if ($_[2]->get_active) {
		$config->set_option('Mode', EXPLORER_MODE);
		&switch_mode;
	}
	return 1;
}

sub switch_mode {
	if ($config->get_option('Mode') == EXPLORER_MODE) {
		$widgets->{list2}->get_location_bar->hide;
		$widgets->{list2}->get_location_bar->reparent($widgets->{location_bar});
		$widgets->{list2}->get_location_bar->show;

		$widgets->{sync_button}->set("visible", 0);
		$widgets->{tree}->get_vbox->set("visible", 1);
		$widgets->{list1}->get_vbox->set("visible", 0);

		$widgets->{list1}->get_navigation_box->hide;
		$widgets->{list2}->get_navigation_box->show;

		$pane->[LEFT] = $widgets->{tree};

	} else {
		$widgets->{list2}->get_location_bar->hide;
		$widgets->{list2}->get_location_bar->reparent($widgets->{list2}->get_location_bar_parent);
		$widgets->{list2}->get_location_bar->show;

		$widgets->{sync_button}->set("visible", 1);
		$widgets->{tree}->get_vbox->set("visible", 0);
		$widgets->{list1}->get_vbox->set("visible", 1);

		$widgets->{list1}->get_navigation_box->hide;
		$widgets->{list2}->get_navigation_box->hide;

		$pane->[LEFT] = $widgets->{list1};
	}

	$widgets->{list1}->refresh;
	$widgets->{list2}->refresh;
}

sub hidden_cb {
	$config->set_option('ShowHiddenFiles', ($_[2]->get_active) ? 1 : 0);
	$pane->[LEFT]->refresh;
	$pane->[RIGHT]->refresh;
	return 1;
}

sub move_to_trash_cb {
	$config->set_option('MoveToTrash', ($_[2]->get_active) ? 1 : 0);
	return 1;
}

sub ask_copy_cb {
	$config->set_option('ConfirmCopy', ($_[2]->get_active) ? 1 : 0);
}

sub ask_move_cb {
	$config->set_option('ConfirmMove', ($_[2]->get_active) ? 1 : 0);
}

sub ask_delete_cb {
	$config->set_option('ConfirmDelete', ($_[2]->get_active) ? 1 : 0);
}

sub set_terminal_cb {
	my $term = Filer::Dialog->ask_command_dialog("Set Terminal", $config->get_option('Terminal'));
	$config->set_option('Terminal', $term);	
}

sub set_editor_cb {
	my $edit = Filer::Dialog->ask_command_dialog("Set Editor", $config->get_option('Editor'));
	$config->set_option('Editor', $edit);	
}

sub file_ass_cb {
	Filer::Mime->file_association_dialog;
}

sub refresh_cb {
	if ($pane->[LEFT]->get_pwd eq $pane->[RIGHT]->get_pwd) {
		if ($pane->[LEFT]->get_type eq $pane->[RIGHT]->get_type) {
			$pane->[LEFT]->refresh;
			$pane->[RIGHT]->set_model($pane->[LEFT]->get_model);
		} else {
			$pane->[LEFT]->refresh;
			$pane->[RIGHT]->refresh;
		}
	} else {
		$pane->[LEFT]->refresh;
		$pane->[RIGHT]->refresh;
	}

	return 1;
}

sub refresh_inactive_pane {
	if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
		if ($active_pane->get_type eq $inactive_pane->get_type) {
			$inactive_pane->set_model($active_pane->get_model);
		} else {
			$inactive_pane->refresh;
		}
	} else {
		$inactive_pane->refresh;
	}
}

sub go_home_cb {
	my $opt = $config->get_option('Mode');

	if ($opt == NORTON_COMMANDER_MODE) {
		$active_pane->open_path($ENV{HOME});
	} elsif ($opt == EXPLORER_MODE) {
		$pane->[RIGHT]->open_path($ENV{HOME});
	}
}

sub synchronize_cb {
	$inactive_pane->open_path($active_pane->get_pwd);
}

sub unselect_cb {
	Filer::SelectDialog->new(Filer::SelectDialog->UNSELECT);
}

sub select_cb {
	Filer::SelectDialog->new(Filer::SelectDialog->SELECT);
}

sub search_cb {
	new Filer::Search;
}

sub paste_cb {
	my $f = sub {
		my ($files,$target) = @_;
		my $do;

		if ($CLIPBOARD_ACTION == COPY) {
			$do = new Filer::Copy;
		} else {
			$do = new Filer::Move;
		}

		$do->set_total(&files_count_paste);
		$do->show;

		foreach (@{$files}) {
			return if (! -e $_);

			my $r = $do->action($_, $target);

			if ($CLIPBOARD_ACTION == COPY) {
				if ($r == File::DirWalk::FAILED) {
					Filer::Dialog->msgbox_error("Copying of $_ to " . $inactive_pane->get_pwd . " failed: $!");
					last;
				} elsif ($r == File::DirWalk::ABORTED) {
					Filer::Dialog->msgbox_info("Copying of $_ to " . $inactive_pane->get_pwd . " aborted!");
					last;
				}
			} else {
				if ($r == File::DirWalk::FAILED) {
					Filer::Dialog->msgbox_error("Moving of $_ to " . $inactive_pane->get_pwd . " failed: $!");
					last;
				} elsif ($r == File::DirWalk::ABORTED) {
					Filer::Dialog->msgbox_info("Moving of $_ to " . $inactive_pane->get_pwd . " aborted!");
					last;
				}
			}
		}

		$do->destroy;
	};

	my $files = [ split /\n/, &get_clipboard_contents ];

	# copy or cut files
	my $target = ($active_pane->get_type eq "TREE") ? $active_pane->get_updir : $active_pane->get_pwd;
	&{$f}($files, $target);

	# refresh panes.
	$active_pane->refresh;
	&refresh_inactive_pane;

	# reset clipboard
	if ($CLIPBOARD_ACTION == CUT) {
		&set_clipboard_contents("");
	}

	# reset Cut property
	$CLIPBOARD_ACTION = COPY; # reset Cut
}

sub cut_cb {
	&set_clipboard_contents(join "\n", @{$active_pane->get_items});

	Gtk2::Gdk::Atom->new('CLIPBOARD_CUT');

	$CLIPBOARD_ACTION = CUT; # Cut (Move) files on Paste
}

sub copy_cb {
	return if (($active_pane->count_items == 0) or (not defined $active_pane->get_item));

#	if ($config->get_option("Mode") == EXPLORER_MODE) {
		&set_clipboard_contents(join "\n", @{$active_pane->get_items});

		$CLIPBOARD_ACTION = COPY;
# 	} else {
# 		my $f = sub {
# 			my ($files,$target) = @_;
# 			my $copy = new Filer::Copy;
#
# 			$copy->set_total(&files_count);
# 			$copy->show;
#
# 			foreach (@{$files}) {
# 				my $r = $copy->copy($_, $target);
#
# 				if ($r == File::DirWalk::FAILED) {
# 					Filer::Dialog->msgbox_error("Copying of $_ to " . $inactive_pane->get_pwd . " failed: $!");
# 					last;
# 				} elsif ($r == File::DirWalk::ABORTED) {
# 					Filer::Dialog->msgbox_info("Copying of $_ to " . $inactive_pane->get_pwd . " aborted!");
# 					last;
# 				}
# 			}
#
# 			$copy->destroy;
#
# 			&refresh_inactive_pane;
# 		};
#
# 		if ($active_pane->count_items == 1) {
# 			if ($config->get_option("ConfirmCopy") == 1) {
# 				my ($dialog,$source_label,$dest_label,$source_entry,$dest_entry) = Filer::Dialog->source_target_dialog;
#
# 				$dialog->set_title("Copy");
# 				$source_label->set_markup("<b>Copy: </b>");
# 				$source_entry->set_text($active_pane->get_item);
# 				$dest_label->set_markup("<b>to: </b>");
# 				$dest_entry->set_text($inactive_pane->get_pwd);
#
# 				$dialog->show_all;
#
# 				if ($dialog->run eq 'ok') {
# 					&{$f}([$source_entry->get_text], $dest_entry->get_text);
# 				}
#
# 				$dialog->destroy;
# 			} else {
# 				&{$f}([$active_pane->get_item], $inactive_pane->get_pwd);
# 			}
# 		} else {
# 			if ($config->get_option("ConfirmCopy") == 1) {
# 				return if (Filer::Dialog->yesno_dialog(sprintf("Copy %s selected files to %s?", $active_pane->count_items, $inactive_pane->get_pwd)) eq 'no');
# 			}
#
# 			&{$f}($active_pane->get_items, $inactive_pane->get_pwd);
# 		}
# 	}
}

# sub move_cb {
# 	return if (($active_pane->count_items == 0) or (not defined $active_pane->get_item));
#
# 	my $f = sub {
# 		my ($files,$target) = @_;
# 		my $move = new Filer::Move;
#
# 		$move->set_total(&files_count);
# 		$move->show;
#
# 		foreach (@{$files}) {
# 			my $r = $move->move($_, $target);
#
# 			if ($r == File::DirWalk::FAILED) {
# 				Filer::Dialog->msgbox_error("Moving of $_ to " . $inactive_pane->get_pwd . " failed: $!");
# 				last;
# 			} elsif ($r == File::DirWalk::ABORTED) {
# 				Filer::Dialog->msgbox_info("Moving of $_ to " . $inactive_pane->get_pwd . " aborted!");
# 				last;
# 			}
# 		}
#
# 		$move->destroy;
#
# 		$active_pane->remove_selected;
# 		&refresh_inactive_pane;
# 	};
#
# 	if ($active_pane->count_items == 1) {
# 		if ($config->get_option("ConfirmMove") == 1) {
# 			my ($dialog,$source_label,$dest_label,$source_entry,$dest_entry) = Filer::Dialog->source_target_dialog;
#
# 			$dialog->set_title("Move");
# 			$source_label->set_markup("<b>Move: </b>");
# 			$source_entry->set_text($active_pane->get_item);
# 			$dest_label->set_markup("<b>to: </b>");
# 			$dest_entry->set_text($inactive_pane->get_pwd);
#
# 			$dialog->show_all;
#
# 			if ($dialog->run eq 'ok') {
# 				&{$f}([$source_entry->get_text], $dest_entry->get_text);
# 			}
#
# 			$dialog->destroy;
# 		} else {
# 			&{$f}([$active_pane->get_item], $inactive_pane->get_pwd);
# 		}
# 	} else {
# 		if ($config->get_option("ConfirmMove") == 1) {
# 			return if (Filer::Dialog->yesno_dialog(sprintf("Move %s selected files to %s?", $active_pane->count_items, $inactive_pane->get_pwd)) eq 'no');
# 		}
#
# 		&{$f}($active_pane->get_items, $inactive_pane->get_pwd);
# 	}
# }

sub rename_cb {
	my ($dialog,$hbox,$label,$entry);

	return if (($active_pane->count_items == 0) or (not defined $active_pane->get_item));

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
	$entry->set_text(File::Basename::basename($active_pane->get_item));
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $old_pwd = $active_pane->get_pwd;		
		my $old = $active_pane->get_item;
		my $new;
		
		if ($active_pane->get_type eq "TREE") {
			$new = abs_path(catfile(splitdir(dirname($old_pwd)), $entry->get_text));			
		} else {
			$new = abs_path(catfile(splitdir($old_pwd), $entry->get_text));			
		}
		
		if (rename($old,$new)) {
			$active_pane->set_item(new Filer::FileInfo($new)); # updates the selected item to the new name.
			&refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Rename failed: $!");
		}
	}

	$dialog->destroy;
}

sub delete_cb {
	return if (($active_pane->count_items == 0) or (not defined $active_pane->get_item));

	if ($config->get_option("ConfirmDelete") == 1) {
		if ($active_pane->count_items == 1) {
			my $f = $active_pane->get_fileinfo->[0]->get_basename; 
			$f =~ s/&/&amp;/g; # sick fix. meh. 

			if (-f $active_pane->get_item) {
				return if (Filer::Dialog->yesno_dialog("Delete file \"$f\"?") eq 'no');
			} elsif (-d $active_pane->get_item) {
				return if (Filer::Dialog->yesno_dialog("Delete directory \"$f\"?") eq 'no');
			}
		} else {
			return if (Filer::Dialog->yesno_dialog(sprintf("Delete %s selected files?", $active_pane->count_items)) eq 'no');
		}
	}

	my $delete = Filer::Delete->new;
	my $t = &files_count; 

	if (($t > 1) or (-d $active_pane->get_item)) {
		$delete->set_total($t);
		$delete->show;

		foreach (@{$active_pane->get_items}) {
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
		my $f = $active_pane->get_item; 
		
		if (! unlink($f)) {
			Filer::Dialog->msgbox_info(sprintf("Deleting of \"%s\" failed: $!", $f));
		}

		$active_pane->update_navigation_buttons($active_pane->get_pwd);
	}

	$active_pane->remove_selected;
	&refresh_inactive_pane;
}

sub mkdir_cb {
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("Make directory", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);
	$dialog->set_default_response('ok');

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox, 0,0,5);

	$label = new Gtk2::Label;
	$label->set_text($active_pane->get_pwd . "/");
	$hbox->pack_start($label, 0,0,2);

	$entry = new Gtk2::Entry;
	$entry->set_text("New Folder");
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $dir = catfile(splitdir($active_pane->get_pwd), $entry->get_text);

		if (mkdir($dir)) {
			$active_pane->refresh;
			&refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Make directory $dir failed: $!");
		}
	}

	$dialog->destroy;
}

sub link_cb {
	my ($dialog,$link_label,$target_label,$link_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	return if (! defined $active_pane->get_item);

	$dialog->set_title("Link");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$link_label->set_markup("<b>Link: </b>");
	$link_entry->set_text(catfile(splitdir($active_pane->get_pwd), basename($active_pane->get_item)));
	$link_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($active_pane->get_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $link = $link_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($link) eq File::Spec->curdir) {
			$link = catfile(splitdir($active_pane->get_pwd), $link);
		}

		if (link($target, $link)) {
			&refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create link! $!");
		}
	}

	$dialog->destroy;
}

sub symlink_cb {
	my ($dialog,$symlink_label,$target_label,$symlink_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	return if (! defined $active_pane->get_item);

	$dialog->set_title("Symlink");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$symlink_label->set_markup("<b>Symlink: </b>");
	$symlink_entry->set_text(catfile(splitdir($active_pane->get_pwd), basename($active_pane->get_item)));
	$symlink_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($active_pane->get_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $symlink = $symlink_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($symlink) eq File::Spec->curdir) {
			$symlink = catfile(splitdir($active_pane->get_pwd), $symlink);
		}

		if (symlink($target, $symlink)) {
			&refresh_inactive_pane;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create symlink! $!");
		}
	}

	$dialog->destroy;
}

sub files_count {
	my $c = 0;

	if (($active_pane->count_items == 1) and (! -d $active_pane->get_item)) {
		$c = 1;
	} else {
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

		my $dirwalk = new File::DirWalk;
		$dirwalk->onFile(sub {
			++$c;
			while (Gtk2->events_pending) { Gtk2->main_iteration }
			return File::DirWalk::SUCCESS;
		});

		foreach (@{$active_pane->get_items}) {
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

	foreach (split /\n/, &get_clipboard_contents) {
		if (-e $_) {
			$dirwalk->walk($_);
		}
	}

	Glib::Source->remove($id);

	$dialog->destroy;

	return $c;
}

sub get_clipboard_contents {
	my $clipboard = Gtk2::Clipboard->get_for_display($widgets->{main_window}->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
	my $contents = "";

	$clipboard->request_text(sub {
		my ($c,$t) = @_;
		return if (!$t);
	
		$contents = $t;
	});
	
	return $contents;
}

sub set_clipboard_contents {
	my ($contents) = @_;
	my $clipboard = Gtk2::Clipboard->get_for_display($widgets->{main_window}->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
	$clipboard->set_text($contents);
}

1;
