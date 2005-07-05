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

our ($VERSION,$libpath,$widgets,$pane,$active_pane,$inactive_pane,$config,$stat_cache);

use strict;
use warnings;

use Storable;
use Gtk2;
use Gtk2::Gdk::Keysyms;

use Cwd;
use Fcntl;
use Memoize;
use File::BaseDir;
use File::Basename;
use File::MimeInfo::Magic;
use File::Temp;
use File::DirWalk;
use Stat::lsMode;

use Filer::Config;
use Filer::Bookmarks;
use Filer::Mime;
use Filer::Archive;
use Filer::Properties;
use Filer::Dialog;
use Filer::ProgressDialog;

use Filer::DND;
use Filer::FilePane;
use Filer::FileTreePane;

use Filer::FileCopy;
use Filer::Copy;
use Filer::Move;
use Filer::Delete;
use Filer::Search;

use constant NORTON_COMMANDER_MODE => 0;
use constant EXPLORER_MODE => 1;

use constant LEFT => 0;
use constant RIGHT => 1;

use constant SELECT => 0;
use constant UNSELECT => 1;

sub main_window {
	my ($window,$hbox,$button,$accel_group,$toolbar);

	my @menu_items	=
	(
	{ path => '/_File/Open Terminal',		accelerator => 'F2',		callback => \&open_terminal_cb, item_type => '<Item>'},
	{ path => '/_File/Open',			accelerator => 'F3',		callback => \&open_cb,		item_type => '<Item>'},
	{ path => '/_File/Open With',							callback => \&open_with_cb,	item_type => '<Item>'},
	{ path => '/_File/sep', 									 		item_type => '<Separator>'},
	{ path => '/_File/Quit',			accelerator => 'F10',		callback => \&quit_cb, 	 	item_type => '<Item>'},
	{ path => '/_Edit/_Copy',			accelerator => 'F5',		callback => \&copy_cb, 	 	item_type => '<Item>'},
#	{ path => '/_Edit/_Paste',			accelerator => '<control>V',	callback => \&paste_cb,	 	item_type => '<Item>'},
	{ path => '/_Edit/_Rename',							callback => \&rename_cb, 	item_type => '<Item>'},
	{ path => '/_Edit/_Move',			accelerator => 'F6',		callback => \&move_cb, 	 	item_type => '<Item>'},
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
	{ path => '/_Options/Move files to Trash when deleting',			callback => \&move_to_trash_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/Show Hidden Files',	accelerator => '<control>H',	callback => \&hidden_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/sep',											item_type => '<Separator>'},
	{ path => '/_Options/File Associations',					callback => \&file_ass_cb,	item_type => '<Item>'},
	{ path => '/_Help/About',							callback => \&about_cb,		item_type => '<Item>'},
	);

	$widgets->{main_window} = new Gtk2::Window('toplevel');
	$widgets->{main_window}->set_title("Filer $VERSION");

	my $size = $config->get_option("WindowSize");
	my ($w,$h) = split /:/, $size;		

	$widgets->{main_window}->resize($w,$h);

	$widgets->{main_window}->signal_connect("event", \&window_event_cb);
	$widgets->{main_window}->signal_connect("delete-event", \&quit_cb);
	$widgets->{main_window}->set_icon(Gtk2::Gdk::Pixbuf->new_from_file(Filer::Mime->new->get_icon('inode/directory')));

	$widgets->{vbox} = new Gtk2::VBox(0,0);
	$widgets->{main_window}->add($widgets->{vbox});

	$accel_group = new Gtk2::AccelGroup;
	$widgets->{main_window}->add_accel_group($accel_group);

	$widgets->{item_factory} = new Gtk2::ItemFactory("Gtk2::MenuBar", '<main>', $accel_group);
	$widgets->{item_factory}->create_items(undef, @menu_items);
	$widgets->{vbox}->pack_start($widgets->{item_factory}->get_widget('<main>'), 0, 0, 0);

	$toolbar = new Gtk2::Toolbar;
	$toolbar->set_style('GTK_TOOLBAR_BOTH_HORIZ');
	$toolbar->append_item('Open Terminal', 'Open Terminal', undef, undef, \&open_terminal_cb);

	$widgets->{home_button} = $toolbar->append_item('Home', 'Home', undef, undef, \&go_home_cb);
	$widgets->{sync_button} = $toolbar->append_item('Synchronize', 'Synchronize', undef, undef, \&synchronize_cb);

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

	$hbox = new Gtk2::HBox(1,0);
	$widgets->{vbox}->pack_start($hbox, 0, 0, 0);

	$button = new Gtk2::Button("Refresh");
	$button->signal_connect("clicked", \&refresh_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$button = new Gtk2::Button("Copy");
	$button->signal_connect("clicked", \&copy_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$widgets->{move_button} = new Gtk2::Button("Move");
	$widgets->{move_button}->signal_connect("clicked", \&move_cb);
	$hbox->pack_start($widgets->{move_button}, 1, 1, 0);

	$button = new Gtk2::Button("Rename");
	$button->signal_connect("clicked", \&rename_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$button = new Gtk2::Button("MkDir");
	$button->signal_connect("clicked", \&mkdir_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$button = new Gtk2::Button("Delete");
	$button->signal_connect("clicked", \&delete_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$widgets->{statusbar} = new Gtk2::Statusbar;
	$widgets->{vbox}->pack_start($widgets->{statusbar}, 0, 0, 0);

	my $bookmarks = $widgets->{item_factory}->get_item("/Bookmarks");
	$bookmarks->set_submenu(&get_bookmarks_menu());

	my $i1 = $widgets->{item_factory}->get_item("/Options/Mode/Norton Commander Style");
	my $i2 = $widgets->{item_factory}->get_item("/Options/Mode/MS Explorer Style");

	$i2->set_group($i1->get_group);

	if ($config->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$i1->set_active(1);
		$i2->set_active(0);

#		$widgets->{item_factory}->get_item("/Edit/Paste")->set("visible", 0);
	} elsif ($config->get_option('Mode') == EXPLORER_MODE) {
		$i1->set_active(0);
		$i2->set_active(1);

#		$widgets->{item_factory}->get_item("/Edit/Paste")->set("visible", 1);
	}

	$widgets->{list1}->open_path($config->get_option('PathLeft'));
	$widgets->{list2}->open_path((defined $ARGV[0] and -d $ARGV[0]) ? $ARGV[0] : $config->get_option('PathRight'));

	$widgets->{main_window}->show_all;

	$widgets->{sync_button}->hide;
	$widgets->{tree}->get_vbox->hide;
	$widgets->{list1}->get_vbox->hide;
	$widgets->{list2}->get_vbox->show;

	$pane->[LEFT] = undef;
	$pane->[RIGHT] = $widgets->{list2};

	&switch_mode;

	$widgets->{item_factory}->get_item("/Options/Show Hidden Files")->set_active($config->get_option('ShowHiddenFiles'));
	$widgets->{item_factory}->get_item("/Options/Move files to Trash when deleting")->set_active($config->get_option('MoveToTrash'));
	$widgets->{item_factory}->get_item("/Options/Ask confirmation for/Copying")->set_active($config->get_option('ConfirmCopy'));
	$widgets->{item_factory}->get_item("/Options/Ask confirmation for/Moving")->set_active($config->get_option('ConfirmMove'));
	$widgets->{item_factory}->get_item("/Options/Ask confirmation for/Deleting")->set_active($config->get_option('ConfirmDelete'));

	$pane->[RIGHT]->set_focus;
}

sub get_bookmarks_menu {
	my $menu = new Gtk2::Menu;
	my $menuitem;

	$menuitem = new Gtk2::MenuItem("Set Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $bookmarks = new Filer::Bookmarks;

		if ($active_pane->count_selected_items > 0) {
		
			foreach (@{$active_pane->get_selected_items}) {
				if (-d $_) {
					$bookmarks->set_bookmark($_);
				} else {
					$bookmarks->set_bookmark($active_pane->get_pwd);
				}
			}
		} else {
			$bookmarks->set_bookmark($active_pane->get_pwd);		
		}		

		my $menu = $widgets->{item_factory}->get_item("/Bookmarks");
		$menu->set_submenu(&get_bookmarks_menu());
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::MenuItem("Remove Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $bookmarks = new Filer::Bookmarks;

		if ($active_pane->count_selected_items > 0) {
		
			foreach (@{$active_pane->get_selected_items}) {
				if (-d $_) {
					$bookmarks->remove_bookmark($_);
				} else {
					$bookmarks->remove_bookmark($active_pane->get_pwd);
				}
			}
		} else {
			$bookmarks->remove_bookmark($active_pane->get_pwd);		
		}

		my $menu = $widgets->{item_factory}->get_item("/Bookmarks");
		$menu->set_submenu(&get_bookmarks_menu());
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::SeparatorMenuItem;
	$menuitem->show;
	$menu->add($menuitem);

	my $bookmarks = new Filer::Bookmarks;
	foreach ($bookmarks->get_bookmarks) {
		$menuitem = new Gtk2::MenuItem($_);
		$menuitem->signal_connect("activate", sub {
			my $p = ($config->get_option("Mode") == NORTON_COMMANDER_MODE) ? $active_pane : $pane->[RIGHT];
			$p->open_path($_[1]);
		},$_);
		$menuitem->show;
		$menu->add($menuitem);
	}

	return $menu;
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
	my $dialog = new Gtk2::Dialog("About", undef, 'modal', 'gtk-close' => 'close');
	$dialog->signal_connect(response => sub { $_[0]->destroy });
	$dialog->set_position('center');
	$dialog->set_modal(1);

	my $label = new Gtk2::Label;
	$label->set_use_markup(1);
	$label->set_markup("<b>Filer $VERSION</b>\n\nCopyright (C) 2004-2005\nby Jens Luedicke &lt;jens.luedicke\@gmail.com&gt;\n");
	$label->set_alignment(0.0,0.0);
	$dialog->vbox->pack_start($label, 1,1,5);

	$dialog->show_all;
	$dialog->run;
}

sub open_cb {
	if ($config->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$active_pane->open_file($active_pane->get_selected_item);
	} else {
		$pane->[RIGHT]->open_file($pane->[RIGHT]->get_selected_item);
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
		if (defined $ENV{'TERMCMD'}) {
			system("cd '$path' && $ENV{TERMCMD} & exit");
		} else {
			Filer::Dialog->msgbox_info("TERMCMD not defined!");
		}
	}
}

sub ncmc_cb {
	# check if item is checked
	$config->set_option('Mode', NORTON_COMMANDER_MODE) if ($_[2]->get_active);
	&switch_mode;
	return 1;
}

sub explorer_cb {
	# check if item is checked
	$config->set_option('Mode', EXPLORER_MODE) if ($_[2]->get_active);
	&switch_mode;
	return 1;
}

sub switch_mode {
	my $opt = $config->get_option('Mode');

	if ($opt == EXPLORER_MODE) {
		$widgets->{list2}->get_location_bar->reparent($widgets->{location_bar});

		$widgets->{sync_button}->set("visible", 0);
		$widgets->{tree}->get_vbox->set("visible", 1);
		$widgets->{list1}->get_vbox->set("visible", 0);

		$pane->[LEFT] = $widgets->{tree};

#		$widgets->{item_factory}->get_item("/Edit/Copy")->set_accel_path("<control>C");
#		$widgets->{item_factory}->get_item("/Edit/Paste")->set("visible", 1);
#		$widgets->{item_factory}->get_item("/Edit/Move")->set("visible", 0);
#		$widgets->{move_button}->set("visible", 0);

	} elsif ($opt == NORTON_COMMANDER_MODE) {
		$widgets->{list2}->get_location_bar->reparent($widgets->{list2}->get_location_bar_parent);

		$widgets->{sync_button}->set("visible", 1);
		$widgets->{tree}->get_vbox->set("visible", 0);
		$widgets->{list1}->get_vbox->set("visible", 1);

		$pane->[LEFT] = $widgets->{list1};

#		$widgets->{item_factory}->get_item("/Edit/Copy")->set_accel_path("F5");
#		$widgets->{item_factory}->get_item("/Edit/Paste")->set("visible", 0);
#		$widgets->{item_factory}->get_item("/Edit/Move")->set("visible", 1);
#		$widgets->{move_button}->set("visible", 1);
	}
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

sub go_home_cb {
	my $opt = $config->get_option('Mode');

	if ($opt == NORTON_COMMANDER_MODE) {
		$active_pane->open_path($ENV{HOME});
	} elsif ($opt == EXPLORER_MODE) {
		$pane->[RIGHT]->open_path($ENV{HOME});
	}
}

sub synchronize_cb {
	$inactive_pane->open_path($active_pane->get_pwd());
}

sub unselect_cb {
	&select_dialog(UNSELECT);
}

sub select_cb {
	&select_dialog(SELECT);
}

sub select_dialog {
	my ($type) = @_;
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("", undef, 'modal', 'gtk-ok' => 'ok');
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
		my $mypane = ($config->get_option("Mode") == NORTON_COMMANDER_MODE) ? $active_pane : $pane->[RIGHT];
		my $selection = $mypane->get_treeview->get_selection;
		my $str = $entry->get_text;
#		my $bx = (split //, $str)[0];

		$str =~ s/\//\\\//g;
		$str =~ s/\./\\./g;
		$str =~ s/\*/\.*/g;
		$str =~ s/\?/\./g;

		$mypane->get_treeview->get_model->foreach(sub {
			my $model = $_[0];
			my $iter = $_[2];
			my $item = $model->get($iter, 1);

			return 0 if ($item eq "..");

# 			if (-d $mypane->get_path($item)) {
# 				if ($bx eq '/') {
# 					$item = "/$item";
# 				} else {
# 					return 0;
# 				}
# 			}

			if ($item =~ /\A$str\Z/)  {
				if ($type == SELECT) {
					$selection->select_iter($iter);
				}

				if ($type == UNSELECT) {
					$selection->unselect_iter($iter);
				}
			}
		}, undef);
	}

	$dialog->destroy;
}

sub search_cb {
	new Filer::Search;
}

# sub paste_cb {
# 	my $f = sub {
# 		my ($files,$target) = @_;
# 		my $copy = new Filer::Copy;
# 
# 		$copy->set_total(&files_count_paste);
# 		$copy->show;
# 
# 		foreach (@{$files}) {
# 			return if (! -e $_);
# 
# 			my $r = $copy->copy($_, $target);
# 
# 			if ($r == File::DirWalk::FAILED) {
# 				Filer::Dialog->msgbox_error("Copying of $_ to " . $inactive_pane->get_pwd . " failed: $!");
# 				last;
# 			} elsif ($r == File::DirWalk::ABORTED) {
# 				Filer::Dialog->msgbox_info("Copying of $_ to " . $inactive_pane->get_pwd . " aborted!");
# 				last;
# 			}
# 		}
# 
# 		$copy->destroy;
# 		$inactive_pane->refresh;
# 	};
# 	
# 	my @files = ();
# 	my $clipboard = Gtk2::Clipboard->get_for_display($active_pane->get_treeview->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
# 
# 	$clipboard->request_text(sub { 
# 		my ($c,$t) = @_;
# 		@files = split /\n/, $t;
# 	});
# 
# 	&{$f}(\@files, $active_pane->get_pwd);
# 	$active_pane->refresh;
# }

sub copy_cb {
	return if (($active_pane->count_selected_items == 0) or (not defined $active_pane->get_selected_item));

# 	if ($config->get_option("Mode") == EXPLORER_MODE) {
# 
# 		my $clipboard = Gtk2::Clipboard->get_for_display($active_pane->get_treeview->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
# 		my $contents = join "\n", @{$active_pane->get_selected_items};
# 
# 		$clipboard->set_text($contents);
# 
# 	} else {
		my $f = sub {
			my ($files,$target) = @_;
			my $copy = new Filer::Copy;

			$copy->set_total(&files_count);
			$copy->show;

			foreach (@{$files}) {
				my $r = $copy->copy($_, $target);

				if ($r == File::DirWalk::FAILED) {
					Filer::Dialog->msgbox_error("Copying of $_ to " . $inactive_pane->get_pwd . " failed: $!");
					last;
				} elsif ($r == File::DirWalk::ABORTED) {
					Filer::Dialog->msgbox_info("Copying of $_ to " . $inactive_pane->get_pwd . " aborted!");
					last;
				}
			}

			$copy->destroy;

			if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
				if ($active_pane->get_type eq $inactive_pane->get_type) { 
					$active_pane->refresh;
					$inactive_pane->set_model($active_pane->get_model);
				} else {
					$inactive_pane->refresh;
				}
			} elsif ($active_pane->get_pwd ne $inactive_pane->get_pwd) {
				$inactive_pane->refresh;
			}
		};

		if ($active_pane->count_selected_items == 1) {
			if ($config->get_option("ConfirmCopy") == 1) {
				my ($dialog,$source_label,$dest_label,$source_entry,$dest_entry) = Filer::Dialog->source_target_dialog;

				$dialog->set_title("Copy");
				$source_label->set_markup("<b>Copy: </b>");
				$source_entry->set_text($active_pane->get_selected_item);
				$dest_label->set_markup("<b>to: </b>");
				$dest_entry->set_text($inactive_pane->get_pwd);

				$dialog->show_all;

				if ($dialog->run eq 'ok') {
					&{$f}([$source_entry->get_text], $dest_entry->get_text);
				}

				$dialog->destroy;
			} else {
				&{$f}([$active_pane->get_selected_item], $inactive_pane->get_pwd);
			}
		} else {
			if ($config->get_option("ConfirmCopy") == 1) {
				return if (Filer::Dialog->yesno_dialog(sprintf("Copy %s selected files to %s?", $active_pane->count_selected_items, $inactive_pane->get_pwd)) eq 'no');
			}

			&{$f}($active_pane->get_selected_items, $inactive_pane->get_pwd);
		}
#	}
}

sub move_cb {
	return if (($active_pane->count_selected_items == 0) or (not defined $active_pane->get_selected_item));

	my $f = sub {
		my ($files,$target) = @_;
		my $move = new Filer::Move;

		$move->set_total(&files_count);
		$move->show;

		foreach (@{$files}) {
			my $r = $move->move($_, $target);

			if ($r == File::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Moving of $_ to " . $inactive_pane->get_pwd . " failed: $!");
				last;
			} elsif ($r == File::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Moving of $_ to " . $inactive_pane->get_pwd . " aborted!");
				last;
			}
		}

		$move->destroy;

		if ($active_pane->get_pwd ne $inactive_pane->get_pwd) {
			$active_pane->refresh;
			$inactive_pane->refresh;
		}
	};

	if ($active_pane->count_selected_items == 1) {
		if ($config->get_option("ConfirmMove") == 1) {
			my ($dialog,$source_label,$dest_label,$source_entry,$dest_entry) = Filer::Dialog->source_target_dialog;

			$dialog->set_title("Move");
			$source_label->set_markup("<b>Move: </b>");
			$source_entry->set_text($active_pane->get_selected_item);
			$dest_label->set_markup("<b>to: </b>");
			$dest_entry->set_text($inactive_pane->get_pwd);

			$dialog->show_all;

			if ($dialog->run eq 'ok') {
				&{$f}([$source_entry->get_text], $dest_entry->get_text);
			}

			$dialog->destroy;
		} else {
			&{$f}([$active_pane->get_selected_item], $inactive_pane->get_pwd);
		}
	} else {
		if ($config->get_option("ConfirmMove") == 1) {
			return if (Filer::Dialog->yesno_dialog(sprintf("Move %s selected files to %s?", $active_pane->count_selected_items, $inactive_pane->get_pwd)) eq 'no');
		}

		&{$f}($active_pane->get_selected_items, $inactive_pane->get_pwd);
	}
}

sub rename_cb {
	my ($dialog,$hbox,$label,$entry);

	return if (($active_pane->count_selected_items == 0) or (not defined $active_pane->get_selected_item));

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
	$entry->set_text(File::Basename::basename($active_pane->get_selected_item));
	$entry->set_activates_default(1);
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $old_name = $active_pane->get_selected_item;
		my $new_name = $entry->get_text;

		if ((new Filer::Move)->move($old_name, $new_name) == File::DirWalk::SUCCESS) {

			my $model = $active_pane->get_treeview->get_model;
			my $iter = $active_pane->get_selected_iter;

			$model->set($iter, 1, $new_name);
			$model->set($iter, ($active_pane->get_type eq "TREE") ? 2 : 9, $active_pane->get_pwd . "/$new_name");
			$active_pane->set_selected_item($new_name);
		} else {
			Filer::Dialog->msgbox_error("Rename failed: $!");
		}
	}

	$dialog->destroy;
	
	if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
		if ($active_pane->get_type eq $inactive_pane->get_type) { 
			$inactive_pane->set_model($active_pane->get_model);
		} else {
			$inactive_pane->refresh;
		}
	}
}

sub delete_cb {
	return if (($active_pane->count_selected_items == 0) or (not defined $active_pane->get_selected_item));

	if ($config->get_option("ConfirmDelete") == 1) {
		if ($active_pane->count_selected_items == 1) {
			if (-f $active_pane->get_selected_item) {
				return if (Filer::Dialog->yesno_dialog(sprintf("Delete file \"%s\"?", basename($active_pane->get_selected_item))) eq 'no');
			} elsif (-d $active_pane->get_selected_item) {
				return if (Filer::Dialog->yesno_dialog(sprintf("Delete directory \"%s\"?", basename($active_pane->get_selected_item))) eq 'no');
			}		
		} else {
			return if (Filer::Dialog->yesno_dialog(sprintf("Delete %s selected files?", $active_pane->count_selected_items)) eq 'no');
		}
	}

	my $delete = Filer::Delete->new;
	$delete->set_total(&files_count);

	$delete->show;

	foreach (@{$active_pane->get_selected_items}) {
		my $r = $delete->delete($_);

		if ($r == File::DirWalk::FAILED) {
			Filer::Dialog->msgbox_info(($config->get_option("MoveToTrash") != 1) ? "Deleting of $_ failed: $!" : "Moving of $_ to Trash failed: $!");
			last;
		} elsif ($r == File::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info(($config->get_option("MoveToTrash") != 1) ? "Deleting of $_ aborted!" : "Moving of $_ to Trash aborted!");
			last;
		}
	}

	$delete->destroy;

	$active_pane->remove_selected;
	
	if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
		if ($active_pane->get_type eq $inactive_pane->get_type) { 
			$inactive_pane->set_model($active_pane->get_model);
		} else {
			$inactive_pane->refresh;
		}
	}
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
		my $dir = $active_pane->get_pwd . "/" . $entry->get_text;

		if (mkdir($dir)) {
			$active_pane->refresh;
		} else {
			Filer::Dialog->msgbox_error("Make directory $dir failed: $!");
		}
	}

	$dialog->destroy;
	
	if ($active_pane->get_type eq $inactive_pane->get_type) {
		if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
			$inactive_pane->set_model($active_pane->get_model);
		}
	}
}

sub link_cb {
	my ($dialog,$link_label,$target_label,$link_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	return if (! defined $active_pane->get_selected_item);
	
	$dialog->set_title("Link");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$link_label->set_markup("<b>Link: </b>");
	$link_entry->set_text($inactive_pane->get_pwd . "/" . basename($active_pane->get_selected_item));
	$link_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($active_pane->get_selected_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $link = $link_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($link) eq '.') {
			$link = $active_pane->get_pwd . "/$link";
		}

		if (link($target, $link)) {
			if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
				if ($active_pane->get_type eq $inactive_pane->get_type) { 
					$inactive_pane->set_model($active_pane->get_model);
				} else {
					$inactive_pane->refresh;
				}
			}
		} else {
			Filer::Dialog->msgbox_error("Couldn't create link! $!");
		}
	}

	$dialog->destroy;
}

sub symlink_cb {
	my ($dialog,$symlink_label,$target_label,$symlink_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	return if (! defined $active_pane->get_selected_item);

	$dialog->set_title("Symlink");
	$dialog->set_size_request(450,150);
	$dialog->set_default_response('ok');

	$symlink_label->set_markup("<b>Symlink: </b>");
	$symlink_entry->set_text($inactive_pane->get_pwd . "/" . basename($active_pane->get_selected_item));
	$symlink_entry->set_activates_default(1);

	$target_label->set_markup("<b>linked object: </b>");
	$target_entry->set_text($active_pane->get_selected_item);
	$target_entry->set_activates_default(1);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $symlink = $symlink_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($symlink) eq '.') {
			$symlink = $active_pane->get_pwd . "/$symlink";
		}

		if (symlink($target, $symlink)) {
		
			if ($active_pane->get_pwd eq $inactive_pane->get_pwd) {
				if ($active_pane->get_type eq $inactive_pane->get_type) { 
					$inactive_pane->set_model($active_pane->get_model);
				} else {
					$inactive_pane->refresh;
				}
			}
			
		} else {
			Filer::Dialog->msgbox_error("Couldn't create symlink! $!");
		}
	}

	$dialog->destroy;
}

sub files_count {
	my $c = 0;

	if (($active_pane->count_selected_items == 1) and (! -d $active_pane->get_selected_item)) {
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

		foreach (@{$active_pane->get_selected_items}) {
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

# sub files_count_paste {
# 	my $c = 0;
# 	my $dirwalk = new File::DirWalk;
# 
# 	my $dialog = new Filer::ProgressDialog;
# 	$dialog->dialog->set_title("Please wait ...");
# 	$dialog->label1->set_markup("<b>Please wait ...</b>");
# 
# 	my $progressbar = $dialog->add_progressbar;
# 
# 	$dialog->show;
# 
# 	my $id = Glib::Timeout->add(50, sub {
# 		$progressbar->pulse;
# 		while (Gtk2->events_pending) { Gtk2->main_iteration }
# 		return 1;
# 	});
# 
# 	$dirwalk->onFile(sub {
# 		++$c;
# 		while (Gtk2->events_pending) { Gtk2->main_iteration }
# 		return File::DirWalk::SUCCESS;
# 	});
# 
# 	my @files = ();
# 	my $clipboard = Gtk2::Clipboard->get_for_display($active_pane->get_treeview->get_display, Gtk2::Gdk::Atom->new('CLIPBOARD'));
# 		
# 	$clipboard->request_text(sub { 
# 		my ($c,$t) = @_;
# 		@files = split /\n/, $t;
# 	});
# 
# 	foreach (@files) {
# 		if (-e $_) {
# 			$dirwalk->walk($_);
# 		}
# 	}
# 
# 	Glib::Source->remove($id);
# 
# 	$dialog->destroy;
# 
# 	return $c;
# }

sub intelligent_scale {
	my ($pixbuf,$scale) = @_;
	my $scaled;
	my $w;
	my $h;

	my $ow = $pixbuf->get_width;
	my $oh = $pixbuf->get_height;

	if ($ow <= $scale and $oh <= $scale) {
		$scaled = $pixbuf;
	} else {
		if ($ow > $oh) {
			$w = $scale;
			$h = $scale * ($oh/$ow);
        	} else {
			$h = $scale;
			$w = $scale * ($ow/$ow);
		}

		$scaled = $pixbuf->scale_simple($w, $h, 'GDK_INTERP_BILINEAR');
	}

	return $scaled;
}

1;
