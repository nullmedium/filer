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
use File::Basename;
use File::MimeInfo::Magic;
use File::Temp;
use Stat::lsMode;

use Filer::Config;
use Filer::Bookmarks;
use Filer::Mime;
use Filer::Archive;
use Filer::Properties;
use Filer::Dialog;
use Filer::ProgressDialog;
use Filer::DirWalk;

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
	{ path => '/_Options/Show Hidden Files',	accelerator => '<control>H',	callback => \&hidden_cb,	item_type => '<CheckItem>'},
	{ path => '/_Options/sep',											item_type => '<Separator>'},
	{ path => '/_Options/File Associations',					callback => \&file_ass_cb,	item_type => '<Item>'},
	{ path => '/_Help',												item_type => '<LastBranch>'},
	{ path => '/_Help/About',							callback => \&about_cb,		item_type => '<Item>'},
	);

	$window = new Gtk2::Window('toplevel');
	$window->set_title("Filer $VERSION");
	$window->resize(800,600);
	$window->signal_connect("event", \&window_event_cb);
	$window->signal_connect("delete-event", \&quit_cb);
	$window->set_icon(Gtk2::Gdk::Pixbuf->new_from_file(Filer::Mime->new->get_icon('inode/directory')));

	$widgets->{vbox} = new Gtk2::VBox(0,0);
	$window->add($widgets->{vbox});

	$accel_group = new Gtk2::AccelGroup;
	$window->add_accel_group($accel_group);

	$widgets->{item_factory} = new Gtk2::ItemFactory("Gtk2::MenuBar", '<main>', $accel_group);
	$widgets->{item_factory}->create_items(undef, @menu_items);
	$widgets->{vbox}->pack_start($widgets->{item_factory}->get_widget('<main>'), 0, 0, 0);

	$toolbar = new Gtk2::Toolbar;
	$toolbar->set_style('text');
	$toolbar->append_item('Open Terminal', 'Open Terminal', undef, undef, \&open_terminal_cb);
	$widgets->{sync_button} = $toolbar->append_item('Synchronize', 'Synchronize', undef, undef, \&synchronize_cb);

	$widgets->{vbox}->pack_start($toolbar, 0, 0, 0);

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

	$hbox = new Gtk2::HBox(0,0);
	$widgets->{vbox}->pack_start($hbox, 0, 0, 0);

	$button = new Gtk2::Button("Refresh");
	$button->signal_connect("clicked", \&refresh_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$button = new Gtk2::Button("Copy");
	$button->signal_connect("clicked", \&copy_cb);
	$hbox->pack_start($button, 1, 1, 0);

	$button = new Gtk2::Button("Move");
	$button->signal_connect("clicked", \&move_cb);
	$hbox->pack_start($button, 1, 1, 0);

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
	} elsif ($config->get_option('Mode') == EXPLORER_MODE) {
		$i1->set_active(0);
		$i2->set_active(1);
	}

	$widgets->{list1}->open_path($config->get_option('PathLeft'));
	$widgets->{list2}->open_path((defined $ARGV[0] and -d $ARGV[0]) ? $ARGV[0] : $config->get_option('PathRight'));

	$window->show_all;

	$widgets->{sync_button}->hide;
	$widgets->{tree}->get_vbox->hide;
	$widgets->{list1}->get_vbox->hide;
	$widgets->{list2}->get_vbox->show;

	$pane->[LEFT] = undef;
	$pane->[RIGHT] = $widgets->{list2};

	&switch_mode;

	$widgets->{item_factory}->get_item("/Options/Show Hidden Files")->set_active($config->get_option('ShowHiddenFiles'));
}

sub get_bookmarks_menu {
	my $menu = new Gtk2::Menu;
	my $menuitem;

	$menuitem = new Gtk2::MenuItem("Set Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $bookmarks = new Filer::Bookmarks;
		$bookmarks->set_bookmark($active_pane->get_selected_item);

		my $menu = $widgets->{item_factory}->get_item("/Bookmarks");
		$menu->set_submenu(&get_bookmarks_menu());
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::MenuItem("Remove Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $bookmarks = new Filer::Bookmarks;
		$bookmarks->remove_bookmark($active_pane->get_selected_item);

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
	if ($config->get_option('Mode') == NORTON_COMMANDER_MODE) {
		$config->set_option('PathLeft', $pane->[LEFT]->get_pwd);
	}

	$config->set_option('PathRight', $pane->[RIGHT]->get_pwd);

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

	$widgets->{sync_button}->set("visible", ($opt == NORTON_COMMANDER_MODE) ? 1 : 0);
	$widgets->{tree}->get_vbox->set("visible", ($opt == EXPLORER_MODE) ? 1 : 0);
	$widgets->{list1}->get_vbox->set("visible", ($opt == NORTON_COMMANDER_MODE) ? 1 : 0);

	$pane->[LEFT] = ($opt == NORTON_COMMANDER_MODE) ? $widgets->{list1} : $widgets->{tree};
}

sub hidden_cb {
	$config->set_option('ShowHiddenFiles', ($_[2]->get_active) ? 1 : 0);
	$pane->[LEFT]->refresh;
	$pane->[RIGHT]->refresh;
	return 1;
}

sub file_ass_cb {
	Filer::Mime->file_association_dialog;
}

sub refresh_cb {
	$pane->[LEFT]->refresh;
	$pane->[RIGHT]->refresh;
	return 1;
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
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,0,1,5);

	$label = new Gtk2::Label;
	$hbox->pack_start($label,0,0,0);

	$entry = new Gtk2::Entry;
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

sub copy_cb {
	return if ($active_pane->count_selected_items == 0);

	if ($active_pane->count_selected_items == 1) {
		my ($dialog,$source_label,$dest_label,$source_entry,$dest_entry) = Filer::Dialog->source_target_dialog;

		$dialog->set_title("Copy");
		$source_label->set_markup("<b>Copy: </b>");
		$source_entry->set_text($active_pane->get_selected_item);
		$dest_label->set_markup("<b>to: </b>");
		$dest_entry->set_text($inactive_pane->get_pwd);

		$dialog->show_all;

		if ($dialog->run eq 'ok') {
			my $source = $source_entry->get_text;
			my $dest = $dest_entry->get_text;
			$dialog->destroy;

			return if ($source eq $dest);

			my $copy = Filer::Copy->new;
			$copy->set_total(&files_count);
			$copy->show;
			
			my $r = $copy->copy($source, $dest);

			if ($r == Filer::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Copying of $source to $dest failed!");
			} elsif ($r == Filer::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Copying of $source to $dest aborted!");
			}

			$copy->destroy;

			&refresh_cb;
		}

		$dialog->destroy;
	} else {
		return if (Filer::Dialog->yesno_dialog("Copy selected files to " . $inactive_pane->get_pwd . "?") eq 'no');

		my $copy = Filer::Copy->new;
		$copy->set_total(&files_count);
		$copy->show;

		foreach (@{$active_pane->get_selected_items}) {
			last if ($_ eq $inactive_pane->get_pwd);

			my $r = $copy->copy($_, $inactive_pane->get_pwd);

			if ($r == Filer::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Copying of $_ to " . $inactive_pane->get_pwd . " failed!");
				last;
			} elsif ($r == Filer::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Copying of $_ to " . $inactive_pane->get_pwd . " aborted!");
				last;
			}
		}

		$copy->destroy;
		$inactive_pane->refresh;
	}
}

sub move_cb {
	return if ($active_pane->count_selected_items == 0);

	if ($active_pane->count_selected_items == 1) {
		my ($dialog,$source_label,$dest_label,$source_entry,$dest_entry) = Filer::Dialog->source_target_dialog;

		$dialog->set_title("Move");
		$source_label->set_markup("<b>Move: </b>");
		$source_entry->set_text($active_pane->get_selected_item);
		$dest_label->set_markup("<b>to: </b>");
		$dest_entry->set_text($inactive_pane->get_pwd);

		$dialog->show_all;

		if ($dialog->run eq 'ok') {
			my $source = $source_entry->get_text;
			my $dest = $dest_entry->get_text;
			$dialog->destroy;

			return if ($source eq $dest);

			my $move = Filer::Move->new;
			$move->set_total(&files_count);
			$move->show;

			my $r = $move->move($source, $dest);

			if ($r == Filer::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Moving of $source to $dest failed!");
			} elsif ($r == Filer::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Moving of $source to $dest aborted!");
			}

			$move->destroy;

			$active_pane->remove_selected;
			$inactive_pane->refresh;
		}

		$dialog->destroy;
	} else {
		return if (Filer::Dialog->yesno_dialog("Move selected files to " . $inactive_pane->get_pwd . "?") eq 'no');

		my $move = Filer::Move->new;
		$move->set_total(&files_count);
		$move->show;

		foreach (@{$active_pane->get_selected_items}) {
			last if ($_ eq $inactive_pane->get_pwd);

			my $r = $move->move($_, $inactive_pane->get_pwd);

			if ($r == Filer::DirWalk::FAILED) {
				Filer::Dialog->msgbox_error("Moving of $_ to " . $inactive_pane->get_pwd . " failed!");
				last;
			} elsif ($r == Filer::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Moving of $_ to " . $inactive_pane->get_pwd . " aborted!");
				last;
			}
		}

		$move->destroy;

		$active_pane->remove_selected;
		$inactive_pane->refresh;
	}
}

sub rename_cb {
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("Rename", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,0,0,5);

	$label = new Gtk2::Label;
	$label->set_text("Rename: ");
	$hbox->pack_start($label, 0,0,2);

	$entry = new Gtk2::Entry;
	$entry->set_text(File::Basename::basename($active_pane->get_selected_item));
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $old_name = $active_pane->get_selected_item;
		my $new_name = File::Basename::dirname($old_name) . "/" . $entry->get_text;

		if (rename($old_name, $new_name)) {
			my $model = $active_pane->get_treeview->get_model;
			my $iter = $active_pane->get_selected_iter;

			$model->set($iter, 1, $entry->get_text);
			$model->set($iter, ($active_pane->get_type eq "TREE") ? 2 : 9, $new_name);
			$active_pane->set_selected_item($new_name);
		} else {
			Filer::Dialog->msgbox_error("Rename failed: $!");
		}
	}

	$dialog->destroy;
}

sub delete_cb {
	return if (($active_pane->count_selected_items == 0)
		 or (Filer::Dialog->yesno_dialog("Delete selected files?") eq 'no'));

	my $delete = Filer::Delete->new;
	$delete->set_total(&files_count);
	$delete->show;

	foreach (@{$active_pane->get_selected_items}) {
		my $r = $delete->delete($_);

		if ($r == Filer::DirWalk::FAILED) {
			Filer::Dialog->msgbox_info("Deleting of $_ failed!");
			last;
		} elsif ($r == Filer::DirWalk::ABORTED) {
			Filer::Dialog->msgbox_info("Deleting of $_ aborted!");
			last;
		}
	}

	$delete->destroy;
	$active_pane->remove_selected;
}

sub mkdir_cb {
	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("Make directory", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox, 0,0,5);

	$label = new Gtk2::Label;
	$label->set_text($active_pane->get_pwd . "/");
	$hbox->pack_start($label, 0,0,2);

	$entry = new Gtk2::Entry;
	$entry->set_text("New Folder");
	$hbox->pack_start($entry, 1,1,0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $dir = $label->get_text . $entry->get_text;

		if (mkdir($dir)) {
			$active_pane->refresh;
		} else {
			Filer::Dialog->msgbox_error("Make directory $dir failed: $!");
		}
	}

	$dialog->destroy;
}

sub link_cb {
	my ($dialog,$link_label,$target_label,$link_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	$dialog->set_title("Link");
	$dialog->set_size_request(450,150);
	$link_label->set_markup("<b>Link: </b>");
	$link_entry->set_text($inactive_pane->get_pwd . "/" . basename($active_pane->get_selected_item));
	$target_label->set_markup("<b>to: </b>");
	$target_entry->set_text($active_pane->get_selected_item);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $link = $link_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($link) eq '.') {
			$link = $active_pane->get_pwd . "/$link";
		}

		if (link($target, $link)) {
			$inactive_pane->refresh;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create link! $!");
		}
	}

	$dialog->destroy;
}

sub symlink_cb {
	my ($dialog,$symlink_label,$target_label,$symlink_entry,$target_entry) = Filer::Dialog->source_target_dialog;

	$dialog->set_title("Symlink");
	$dialog->set_size_request(450,150);
	$symlink_label->set_markup("<b>Symlink: </b>");
	$symlink_entry->set_text($inactive_pane->get_pwd . "/" . basename($active_pane->get_selected_item));
	$target_label->set_markup("<b>to: </b>");
	$target_entry->set_text($active_pane->get_selected_item);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $symlink = $symlink_entry->get_text;
		my $target = $target_entry->get_text;

		if (dirname($symlink) eq '.') {
			$symlink = $active_pane->get_pwd . "/$symlink";
		}

		if (symlink($target, $symlink)) {
			$inactive_pane->refresh;
		} else {
			Filer::Dialog->msgbox_error("Couldn't create symlink! $!");
		}
	}

	$dialog->destroy;
}

sub files_count {
	my $c = 0;
	my $dirwalk = new Filer::DirWalk;
	$dirwalk->onFile(sub {
		++$c;
		while (Gtk2->events_pending) { Gtk2->main_iteration }
		return Filer::DirWalk::SUCCESS;
	});

	foreach (@{$active_pane->get_selected_items}) {
		$dirwalk->walk($_);
	}

	return $c;
}

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
