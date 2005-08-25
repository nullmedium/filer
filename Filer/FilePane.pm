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
use Class::Std::Utils;

require Exporter;
our @ISA = qw(Exporter Filer::FilePaneInterface);

use strict;
use warnings;

use Readonly;
use Cwd qw(abs_path);
use File::Basename;

use Filer::Constants;
use Filer::DND;

# use Filer::ListStore;
# use Filer::ListStoreConstants;
use Filer::FilePaneInterface;

# attributes:
# all other attributes are imported by Filer::FilePaneInterface

my %overrides;
my %path_combo;
my %location_bar;
my %navigation_box;
my %navigation_buttons;
my %status;

Readonly my $SELECT   => 0;
Readonly my $UNSELECT => 1;

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless anon_scalar(), $class;

	$filer{ident $self}               = $filer;
	$side{ident $self}                = $side;
	$overrides{ident $self}           = {};
	$mouse_motion_select{ident $self} = $FALSE;

	$vbox{ident $self} = new Gtk2::VBox(0,0);

	$location_bar{ident $self} = new Gtk2::HBox(0,0);
	$vbox{ident $self}->pack_start($location_bar{ident $self}, 0, 1, 0);

	my $button1 = new Gtk2::Button("Up");
	$button1->signal_connect("clicked", sub {
		$self->open_path_helper($self->get_updir);
	});
	$location_bar{ident $self}->pack_start($button1, 0, 1, 0);

	$path_combo{ident $self} = Gtk2::ComboBoxEntry->new_text;
	$location_bar{ident $self}->pack_start($path_combo{ident $self}, 1, 1, 0);

	my $button2 = new Gtk2::Button("Go");
	$button2->signal_connect("clicked", sub {
		$self->open_file(new Filer::FileInfo($path_combo{ident $self}->get_active_text));
	});
	$location_bar{ident $self}->pack_start($button2, 0, 1, 0);

	$navigation_box{ident $self} = new Gtk2::HBox(0,0);
	$vbox{ident $self}->pack_start($navigation_box{ident $self}, 0, 1, 0);

 	$treemodel{ident $self} = new Gtk2::ListStore(qw(Glib::Scalar Glib::Object Glib::String Glib::String Glib::String Glib::String Glib::String));

# 	$treefilter{ident $self} = Gtk2::TreeModelFilter->new($treemodel{ident $self});
# 	$treefilter{ident $self}->set_visible_func(sub {
# 		my ($model,$iter) = @_;
# 		my $show_hidden   = $filer{ident $self}->get_config->get_option('ShowHiddenFiles');
# 		my $name          = $model->get($iter, $COL_NAME);
# 		my $show          = ($name !~ /^\./ and !$show_hidden or $show_hidden);
# 
# 		return $show;
# 	});

	$treeview{ident $self} = new Gtk2::TreeView($treemodel{ident $self});
	$treeview{ident $self}->set_rules_hint(1);
	$treeview{ident $self}->set_enable_search(1);
	$treeview{ident $self}->signal_connect("grab-focus", sub { $self->treeview_grab_focus_cb(@_) });
	$treeview{ident $self}->signal_connect("key-press-event", sub { $self->treeview_event_cb(@_) });
	$treeview{ident $self}->signal_connect("button-press-event", sub { $self->treeview_event_cb(@_) });
	$treeview{ident $self}->signal_connect("button-release-event", sub { $self->treeview_event_cb(@_) });
	$treeview{ident $self}->signal_connect("motion-notify-event", sub { $self->treeview_event_cb(@_) });

	# Drag and Drop
	my $dnd = new Filer::DND($filer{ident $self},$self);
	$treeview{ident $self}->drag_dest_set('all', ['move','copy'], $dnd->target_table);
	$treeview{ident $self}->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $dnd->target_table);
	$treeview{ident $self}->signal_connect("drag_data_get", sub { $dnd->filepane_treeview_drag_data_get(@_) });
	$treeview{ident $self}->signal_connect("drag_data_received", sub { $dnd->filepane_treeview_drag_data_received(@_) });

	$treeselection{ident $self} = $treeview{ident $self}->get_selection;
	$treeselection{ident $self}->set_mode("multiple");

	my $scrolled_window = new Gtk2::ScrolledWindow;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$vbox{ident $self}->pack_start($scrolled_window, 1, 1, 0);
	$scrolled_window->add($treeview{ident $self});

	my $sorts = {
		$COL_NAME => sub {
			my ($a,$b) = @_;
			return ($a->get_basename cmp $b->get_basename);
		},

		$COL_SIZE => sub {
			my ($a,$b) = @_;
			return ($a->get_raw_size <=> $b->get_raw_size);
		}, 
	
		$COL_TYPE => sub {
			my ($a,$b) = @_;
			return ($a->get_mimetype cmp $b->get_mimetype);
		},

		$COL_MODE => sub {
			my ($a,$b) = @_;
			return ($a->get_raw_mode <=> $b->get_raw_mode);
		},

		$COL_DATE => sub {
			my ($a,$b) = @_;
			return ($a->get_raw_mtime <=> $b->get_raw_mtime);
		},
	};

	my $sort_func = sub {
		my ($model,$a,$b) = @_;
		my ($sort_column_id,$order) = $model->get_sort_column_id;

		my $fi1 = $model->get_fileinfo($a);
		my $fi2 = $model->get_fileinfo($b);

		if (($fi1->is_dir) and !($fi2->is_dir)) {
			return ($order eq "ascending") ? -1 : 1;

		} elsif (!($fi1->is_dir) and ($fi2->is_dir)) {
			return ($order eq "ascending") ? 1 : -1;
		}
		
		# if $sort_column_id == $COL_NAME:
		# $sorts->{$sort_column_id}->($fi1,$fi2) will _never_ return 0
		# note: there are no two equal filenames...
		return ($sorts->{$sort_column_id}->($fi1,$fi2) || $sorts->{$COL_NAME}->($fi1,$fi2));
	};

	# a column with a pixbuf renderer and a text renderer
	my $col = new Gtk2::TreeViewColumn;
	$col->set_sort_column_id($COL_NAME);
	$col->set_sort_indicator(1);
	$col->set_title("Name");
	$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');

	my $cell0 = new Gtk2::CellRendererPixbuf;
	$col->pack_start($cell0, 0);
	$col->add_attribute($cell0, pixbuf => $COL_ICON);

	my $cell1 = new Gtk2::CellRendererText;
	$col->pack_start($cell1, 1);
	$col->add_attribute($cell1, text => $COL_NAME);

	$treemodel{ident $self}->set_sort_func($COL_NAME, $sort_func);
	$treeview{ident $self}->append_column($col);

	my @cols = qw(Fileinfo Icon Name Size Type Mode Date);

	for (my $n = $COL_SIZE; $n <= $#cols; $n++) {
		my $cell = new Gtk2::CellRendererText;
		my $col = Gtk2::TreeViewColumn->new_with_attributes($cols[$n], $cell, text => $n);
		$col->set_sort_column_id($n);
		$col->set_sort_indicator(1);
		$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');
		$treemodel{ident $self}->set_sort_func($n, $sort_func);
		$treeview{ident $self}->append_column($col);
	}

	$treemodel{ident $self}->set_sort_column_id($COL_NAME,'ascending');

	$status{ident $self} = new Gtk2::Label;
	$status{ident $self}->set_alignment(0.0,0.5);
	$vbox{ident $self}->pack_start($status{ident $self}, 0, 1, 2);

	return $self;
}

# sub DESTROY {
# 	my ($self) = @_;
# 
# 	delete $filer{ident $self};
# 	delete $side{ident $self};
# 	delete $filepath{ident $self};
# 	delete $overrides{ident $self};
# 	delete $vbox{ident $self};
# 	delete $treeview{ident $self};
# 	delete $treemodel{ident $self};
# 	delete $treeselection{ident $self};
# 	delete $path_combo{ident $self};
# 	delete $location_bar{ident $self};
# 	delete $navigation_box{ident $self};
# 	delete $navigation_buttons{ident $self};
# 	delete $status{ident $self};
# 	delete $mouse_motion_select{ident $self};
# 	delete $mouse_motion_y_pos_old{ident $self};
# }

# sub refilter {
# 	my ($self) = @_;
# 	$treefilter{ident $self}->refilter;
# }

sub get_type {
	my ($self) = @_;
	return "LIST";
}

sub get_location_bar {
	my ($self) = @_;
	return $location_bar{ident $self};
}

sub get_navigation_box {
	my ($self) = @_;
	return $navigation_box{ident $self};
}

sub show_popup_menu {
	my ($self,$e) = @_;

 	my $item;
	my $uimanager  = $filer{ident $self}->get_widgets->{uimanager};
	my $ui_path    = '/ui/list-popupmenu';

	my $popup_menu = $uimanager->get_widget($ui_path);
	$popup_menu->show_all;

	$uimanager->get_widget("$ui_path/Open")->show;
	$uimanager->get_widget("$ui_path/Open")->set_sensitive(1);
	$uimanager->get_widget("$ui_path/PopupItems1/Rename")->set_sensitive(1);
	$uimanager->get_widget("$ui_path/PopupItems1/Delete")->set_sensitive(1);
	$uimanager->get_widget("$ui_path/PopupItems1/Cut")->set_sensitive(1);
	$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive(1);
#	$uimanager->get_widget("$ui_path/PopupItems1/Paste")->set_sensitive(0);
	$uimanager->get_widget("$ui_path/PopupItems1/Paste")->set_sensitive(1);
	$uimanager->get_widget("$ui_path/archive-menu")->set_sensitive(1);
	$uimanager->get_widget("$ui_path/Properties")->set_sensitive(1);

	my $bookmarks = new Filer::Bookmarks($filer{ident $self});
	$uimanager->get_widget("$ui_path/Bookmarks")->set_submenu($bookmarks->generate_bookmarks_menu);

	my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

	if (defined $p) {
		if (! $treeselection{ident $self}->path_is_selected($p)) {
			$treeselection{ident $self}->unselect_all;
			$treeselection{ident $self}->select_path($p);
		}

		if ($self->count_items == 1) {
			my $fi = $self->get_fileinfo->[0];
			my $type = $fi->get_mimetype;

			# Customize archive submenu
			if (Filer::Archive->is_supported_archive($type)) {
				$uimanager->get_widget("$ui_path/archive-menu/Extract")->set_sensitive(1);
			} else {
				$uimanager->get_widget("$ui_path/archive-menu/Extract")->set_sensitive(0);
			}

			# add and create Open submenu
			my $commands_menu = new Gtk2::Menu;
			$item = $uimanager->get_widget("$ui_path/Open");
			$item->set_submenu($commands_menu);

			foreach ($filer{ident $self}->get_mime->get_commands($type)) {
				$item = new Gtk2::MenuItem(basename($_));
				$item->signal_connect("activate", sub {
					my @c = split /(!\\)\s+/, pop @_;
					Filer::Tools->start_program(@c,$self->get_item);
				}, $_);
				$commands_menu->add($item);
			}

			$item = new Gtk2::MenuItem("Other ...");
			$item->signal_connect("activate", sub { $self->open_file_with });
			$commands_menu->add($item);

			$commands_menu->show_all;
		} else {
			$uimanager->get_widget("$ui_path/Open")->set_sensitive(0);
			$uimanager->get_widget("$ui_path/PopupItems1/Rename")->set_sensitive(0);
			$uimanager->get_widget("$ui_path/Properties")->set_sensitive(0);
		}
	} else {
		$uimanager->get_widget("$ui_path/Open")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/PopupItems1/Rename")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/PopupItems1/Delete")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/PopupItems1/Cut")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/archive-menu")->set_sensitive(0);
		$uimanager->get_widget("$ui_path/Properties")->set_sensitive(0);
	}

	$popup_menu->show_all;
	$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
}

sub treeview_event_cb {
	my ($self,$w,$e) = @_;

	if ($e->type eq "key-press") {
		if ($e->keyval == $Gtk2::Gdk::Keysyms{'BackSpace'}) {
			$self->open_path_helper($self->get_updir);
			return 1;
		} elsif ($e->keyval == $Gtk2::Gdk::Keysyms{'Delete'}) {

			$filer{ident $self}->delete_cb;
			return 1;

		} elsif ($e->keyval == $Gtk2::Gdk::Keysyms{'Return'}) {

			$self->open_file($self->get_fileinfo->[0]);
			return 1;
		}
	}

	if ($e->type eq "button-press") { 
		if ($e->button == 2) {
			$mouse_motion_select{ident $self}    = 1;
			$mouse_motion_y_pos_old{ident $self} = $e->y;

			my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

			if (defined $p) {
 				$treeselection{ident $self}->unselect_all;
				$treeselection{ident $self}->select_path($p);
			}

			$self->set_focus;
			return 1;
		} elsif ($e->button == 3) {

			$self->set_focus;
			$self->show_popup_menu($e);
			return 1;
		}
	}
	
	if ($e->type eq "2button-press" and $e->button == 1) {
		my ($p) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);
		
		if (defined $p) {
			my $iter = $treemodel{ident $self}->get_iter($p);
			my $fi   = $treemodel{ident $self}->get_fileinfo($iter);

			if (defined $fi) {
				$self->open_file($fi);
			}
		}

		return 1;
	}

	if ($e->type eq "button-release" and $e->button == 2) {
#		$self->set_focus;
		$mouse_motion_select{ident $self} = 0;
		return 1;
	}

	if (($e->type eq "motion-notify") and ($mouse_motion_select{ident $self} == 1)) {
		my ($p_old) = $treeview{ident $self}->get_path_at_pos($e->x,$mouse_motion_y_pos_old{ident $self});
		my ($p_new) = $treeview{ident $self}->get_path_at_pos($e->x,$e->y);

		if (defined $p_old and defined $p_new) {
			$treeselection{ident $self}->unselect_all;
			$treeselection{ident $self}->select_range($p_old,$p_new);
		}

#		$self->set_focus;
		return 1;
	}

	return 0;
}

sub set_model {
	my ($self,$model) = @_;

	$treemodel{ident $self}->clear;

	$model->foreach(sub {
		my ($model,$path,$iter) = @_;

		my %cols = map { $_ => $model->get($iter, $_) } (0 .. 6);
		$treemodel{ident $self}->insert_with_values(-1, %cols);

		return 0;
	});
}

sub get_pwd {
	my ($self) = @_;
	return $filepath{ident $self};
}

sub get_updir {
	my ($self) = @_;
	return abs_path(Filer::Tools->catpath($filepath{ident $self}, $UPDIR));
}

sub set_item {
	my ($self,$fi) = @_;

	my $basename = $fi->get_basename;
	my $size     = $fi->get_size;
	my $mode     = $fi->get_mode;
	my $type     = $fi->get_mimetype;
	my $time     = $fi->get_mtime;

	$treemodel{ident $self}->set($self->get_iter,
		$COL_FILEINFO, $fi,
		$COL_NAME,     $basename,
		$COL_SIZE,     $size,
		$COL_MODE,     $mode,
		$COL_TYPE,     $type,
		$COL_DATE,     $time,
	);
}

sub update_navigation_buttons {
	my ($self)  = @_;
	my $rootdir = File::Spec->rootdir;
	my $path    = $rootdir;
	my $button  = undef;

	foreach my $path (sort { length($b) <=> length($a) } keys %{$navigation_buttons{ident $self}}) {
		# check if the current path button $path isn't a parentdir of $filepath
		last if ($filepath{ident $self} =~ /^$path/);

		# destroy path button
		$navigation_buttons{ident $self}->{$path}->destroy;
		delete $navigation_buttons{ident $self}->{$path};
	}

	foreach (File::Spec->splitdir($filepath{ident $self})) {
		$path = Filer::Tools->catpath($path, $_);

		if (not defined $navigation_buttons{ident $self}->{$path}) {
			$button = new Gtk2::RadioButton($navigation_buttons{ident $self}->{$rootdir}, basename($path) || $rootdir);
			$button->set(draw_indicator => 0); # i'm evil

			$button->signal_connect(toggled => sub {
				my ($widget,$path) = @_;

		 		my $label = $widget->get_child;
				my $pc    = $label->get_pango_context;
				my $fd    = $pc->get_font_description;

				if ($widget->get_active) {
					$fd->set_weight('PANGO_WEIGHT_BOLD');

					# avoid an endless loop/recursion.
					if ($path ne $filepath{ident $self}) {
						$self->open_path($path);
					}
				} else {
					$fd->set_weight('PANGO_WEIGHT_NORMAL');
				}

				$label->modify_font($fd);
			}, $path);

			$navigation_box{ident $self}->pack_start($button,0,0,0);
			$navigation_buttons{ident $self}->{$path} = $button;
			$navigation_buttons{ident $self}->{$path}->show;
		}
	}

	# set last button active. current directory.
	$navigation_buttons{ident $self}->{$filepath{ident $self}}->set(active => 1);
}

sub open_file {
	my ($self,$fileinfo) = @_;

	return 0 if (not defined $fileinfo);

	my $filepath = abs_path($fileinfo->get_path);

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if ($fileinfo->is_dir) {
		$self->open_path_helper($filepath);

	} elsif ($fileinfo->is_executable) {
		Filer::Tools->start_program($filepath);

	} else {
		my $type    = $fileinfo->get_mimetype;
		my @command = $filer{ident $self}->get_mime->get_default_command($type);

		if (@command) {
			Filer::Tools->start_program(@command,$filepath);
		} else {
			if (defined Filer::Archive->is_supported_archive($type)) {
				$self->extract_archive_temporary($filepath);
			} else {
				$filer{ident $self}->get_mime->run_dialog($fileinfo);
			}
		}
	}
}

sub open_file_with {
	my ($self) = @_;

	return 0 if (! defined $self->get_iter);

	$filer{ident $self}->get_mime->run_dialog($self->get_fileinfo->[0]);
}

sub open_path_helper {
	my ($self,$filepath) = @_;

	if (defined $navigation_buttons{ident $self}->{$filepath}) {
		$navigation_buttons{ident $self}->{$filepath}->set(active => 1);
	} else {
		$self->open_path($filepath);
		$self->update_navigation_buttons;
	}
}

sub open_path {
	my ($self,$filepath) = @_;

	my ($t0,$t1,$elapsed);
 	use Time::HiRes qw(gettimeofday tv_interval);
 	$t0 = [gettimeofday];

	if (defined $overrides{ident $self}->{$filepath}) {
		$filepath = $overrides{ident $self}->{$filepath};
		delete $overrides{ident $self}->{$filepath};
	}

	my $show_hidden  = $filer{ident $self}->get_config->get_option('ShowHiddenFiles');
	my $mimeicons    = $filer{ident $self}->get_mimeicons;
	my $default_icon = $mimeicons->{'application/default'};

	opendir (my $dirh, $filepath) 
		or return Filer::Dialog->msgbox_error("$filepath: $!");

	my @dir_contents =
		map { Filer::FileInfo->new(Filer::Tools->catpath($filepath, $_)); }
		grep { (!/^\.{1,2}\Z(?!\n)/s) and (!/^\./ and !$show_hidden or $show_hidden) } 
#		grep { (!/^\.{1,2}\Z(?!\n)/s) }
		readdir($dirh);
	closedir($dirh);

	$filepath{ident $self} = $filepath;

	my $total_size  = 0;
	my $dirs_count  = 0;
	my $files_count = 0;

	$treemodel{ident $self}->clear;

	foreach my $fi (@dir_contents) {
		my $type     = $fi->get_mimetype;
		my $icon     = $mimeicons->{$type};
		my $basename = $fi->get_basename;
		my $size     = $fi->get_size;
		my $mode     = $fi->get_mode;
		my $time     = $fi->get_mtime;

# 		use Filer::Scalar;
# 		tie my $basename, "Filer::Scalar";
# 
# 		$basename = \$fi->get_basename;

		$treemodel{ident $self}->insert_with_values(-1,
			$COL_FILEINFO, $fi,
			$COL_ICON,     $icon || $default_icon,
			$COL_NAME,     $basename,
			$COL_SIZE,     $size,
			$COL_MODE,     $mode,
			$COL_TYPE,     $type,
			$COL_DATE,     $time,
		);

#  		my $type     = $fi->get_mimetype;
#  		my $icon     = $mimeicons->{$type};
# 
# 		$treemodel{ident $self}->append_fileinfo($icon, $fi);

		if ($fi->is_dir) {
			$dirs_count++;
		} else {
			$files_count++;
		}

		$total_size += $fi->get_raw_size;
	}

	$path_combo{ident $self}->insert_text(0, $filepath{ident $self});
	$path_combo{ident $self}->set_active(0);
	$status{ident $self}->set_text("$dirs_count directories and $files_count files: " . Filer::Tools->calculate_size($total_size));

	$t1 = [gettimeofday];
	$elapsed = tv_interval($t0,$t1);
	print "time to load $filepath: $elapsed\n";
}

sub select_dialog {
	my ($self,$type) = @_;

	my $dialog = new Gtk2::Dialog("", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_default_response('ok');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	my $hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,0,1,5);

	my $label = new Gtk2::Label;
	$hbox->pack_start($label,0,0,0);

	my $entry = new Gtk2::Entry;
	$entry->set_activates_default(1);
	$entry->set_text("*");
	$hbox->pack_start($entry,0,0,0);

	if ($type == $SELECT) {
		$dialog->set_title("Select Files");
		$label->set_text("Select: ");
	} else {
		$dialog->set_title("Unselect Files");
		$label->set_text("Unselect: ");
	}

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $str = $entry->get_text;

		$str =~ s/\//\\\//g;
		$str =~ s/\./\\./g;
		$str =~ s/\*/\.*/g;
		$str =~ s/\?/\./g;

		$treemodel{ident $self}->foreach(sub {
			my ($model,$path,$iter) = @_;
			my $item  = $model->get($iter, $COL_NAME);

			if ($item =~ /\A$str\Z/)  {
				if ($type == $SELECT) {
					$treeselection{ident $self}->select_iter($iter);
				}

				if ($type == $UNSELECT) {
					$treeselection{ident $self}->unselect_iter($iter);
				}
			}
		});
	}

	$dialog->destroy;
}

sub create_tar_gz_archive {
	my ($self) = @_;

	$self->archive_helper(sub {
		my $archive = new Filer::Archive;
		return $archive->create_tar_gz_archive($filepath{ident $self}, $self->get_items);
	});
}

sub create_tar_bz2_archive {
	my ($self) = @_;

	$self->archive_helper(sub {
		my $archive = new Filer::Archive;
		return $archive->create_tar_bz2_archive($filepath{ident $self}, $self->get_items);
	});
}

sub extract_archive {
	my ($self) = @_;

	$self->archive_helper(sub {
		my $archive = new Filer::Archive;
		return $archive->extract_archive($filepath{ident $self}, $self->get_items);
	});
}

sub extract_archive_temporary {
	my ($self,$file) = @_;

	$self->archive_helper(sub {
		my $dir = $self->get_temp_archive_dir;
		my $archive = new Filer::Archive;
		return $archive->extract_archive($dir, [ $file ]);
	});
}

sub archive_helper {
	my ($self,$func) = @_;

	$vbox{ident $self}->set_sensitive(0);
	my $dir = $func->();
	$vbox{ident $self}->set_sensitive(1);

	$self->open_path($dir);
}

sub get_temp_archive_dir {
	my ($self) = @_;
	my $dir = File::Temp::tempdir(CLEANUP => 1);
	my $tmp = File::Spec->tmpdir;

	$overrides{ident $self}->{$tmp} = $filepath{ident $self};

	return $dir;
}

# package Gtk2::ListStore;
# 
# sub get_value {
# 	my ($self,$iter,$column) = @_;
# 	
# }
# 
# sub get {
# 	my ($self,$iter,$column) = @_;
# 	my $val = $self->get_value($iter,$column);
# 
# 	print "get: returning $val\n";
# 
# 	return $val;
# }

1;
