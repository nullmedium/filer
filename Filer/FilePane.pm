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

package Filer::FilePane;
use base qw(Filer::FilePaneInterface);

use strict;
use warnings;

use Readonly;
use Cwd qw(abs_path);
use File::Basename;

use Class::Bind;

use Filer::Constants qw(:filer :filepane_columns);
use Filer::ListStore;

Readonly my $SELECT   => 0;
Readonly my $UNSELECT => 1;

sub new {
	my ($class,$side) = @_;
	my $self = $class->SUPER::new($side);
	$self = bless $self, $class;

	$self->{location_bar} = Gtk2::HBox->new(0,0);
	$self->{vbox}->pack_start($self->{location_bar}, $FALSE, $TRUE, 0);

	my $button1 = Gtk2::Button->new("Up");
	$button1->signal_connect("clicked", sub {
		$self->open_path($self->get_updir);
	});
	$self->{location_bar}->pack_start($button1, $FALSE, $TRUE, 0);

	$self->{path_combo} = Gtk2::ComboBoxEntry->new_text;
	$self->{location_bar}->pack_start($self->{path_combo}, $TRUE, $TRUE, 0);

	my $button2 = Gtk2::Button->new("Go");
	$button2->signal_connect("clicked", sub {
		$self->open_file(Filer::FileInfo->new($self->{path_combo}->get_active_text));
	});
	$self->{location_bar}->pack_start($button2, $FALSE, $TRUE, 0);

	$self->{navigation_box} = Gtk2::HBox->new(0,0);
	$self->{vbox}->pack_start($self->{navigation_box}, $FALSE, $TRUE, 0);

	$self->{treemodel} = Filer::ListStore->new;
	$self->{treeview}  = Gtk2::TreeView->new($self->{treemodel});
	$self->{treeview}->set_rules_hint($TRUE);
	$self->{treeview}->set_enable_search($TRUE);

	$self->{treeview}->signal_connect("grab-focus",           bind(\*Filer::FilePaneInterface::treeview_grab_focus_cb, $self));
	$self->{treeview}->signal_connect("key-press-event",      bind(\*Filer::FilePane::treeview_event_cb, $self, _1, _2, _3));
	$self->{treeview}->signal_connect("button-press-event",   bind(\*Filer::FilePane::treeview_event_cb, $self, _1, _2));

	# Drag and Drop
	$self->{treeview}->drag_dest_set('all', ['move','copy'], $self->target_table);
	$self->{treeview}->drag_source_set(['button1_mask','shift-mask'], ['move','copy'], $self->target_table);
	$self->{treeview}->signal_connect("drag_data_get",      bind(\*Filer::FilePaneInterface::drag_data_get,      $self, _1, _2, _3));
	$self->{treeview}->signal_connect("drag_data_received", bind(\*Filer::FilePaneInterface::drag_data_received, $self, _1, _2, _3));

	$self->{treeselection} = $self->{treeview}->get_selection;
	$self->{treeselection}->set_mode("multiple");

	my $scrolled_window = Gtk2::ScrolledWindow->new;
	$scrolled_window->set_policy('automatic','automatic');
	$scrolled_window->set_shadow_type('etched-in');
	$scrolled_window->add($self->{treeview});
	$self->{vbox}->pack_start($scrolled_window, $TRUE, $TRUE, 0);

	# a column with a pixbuf renderer and a text renderer
	my $col = Gtk2::TreeViewColumn->new;
	$col->set_sort_column_id($COL_NAME);
	$col->set_sort_indicator($TRUE);
	$col->set_title("Name");
	$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');

	my $cell0 = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell0, 0);
	$col->add_attribute($cell0, pixbuf => $COL_ICON);

	my $cell1 = Gtk2::CellRendererText->new;
	$col->pack_start($cell1, 1);
	$col->add_attribute($cell1, text => $COL_NAME);

	$self->{treeview}->append_column($col);

	my %cols = ();
	$cols{$COL_SIZE} = "Size";
# 	$cols{$COL_MODE} = "Mode";
	$cols{$COL_TYPE} = "Type";
	$cols{$COL_DATE} = "Date Modified";

	foreach (sort keys %cols) {
		my $cell;
		my $col;

		if ($_ == $COL_SIZE) {
			$cell = Filer::CellRendererSize->new;
			$cell->set(humanize => $TRUE);
			$col  = Gtk2::TreeViewColumn->new_with_attributes($cols{$_}, $cell, size => $_);
		} elsif ($_ == $COL_DATE) {
			$cell = Filer::CellRendererDate->new;
			$cell->set(dateformat => "%o %b %Y");
# 			$cell->set(dateformat => "%x");
			$col  = Gtk2::TreeViewColumn->new_with_attributes($cols{$_}, $cell, seconds => $_);
		} else {
			$cell = Gtk2::CellRendererText->new;
			$col  = Gtk2::TreeViewColumn->new_with_attributes($cols{$_}, $cell, text => $_);
		}

		$col->set_sort_column_id($_);
 		$col->set_sort_indicator($TRUE);
		$col->set_sizing('GTK_TREE_VIEW_COLUMN_AUTOSIZE');
		$self->{treeview}->append_column($col);
	}

	$self->{status} = Gtk2::Label->new;
	$self->{status}->set_alignment(0.0,0.5);
	$self->{vbox}->pack_start($self->{status}, $FALSE, $TRUE, 2);

	return $self;
}

sub get_type {
	my ($self) = @_;
	return "LIST";
}

sub get_location_bar {
	my ($self) = @_;
	return $self->{location_bar};
}

sub get_navigation_box {
	my ($self) = @_;
	return $self->{navigation_box};
}

sub show_popup_menu {
	my ($self,$e) = @_;

 	my $item;
	my $uimanager = Filer->instance()->get_uimanager;
	my $ui_path   = '/ui/list-popupmenu';

	my $popup_menu = $uimanager->get_widget($ui_path);

	$uimanager->get_widget("$ui_path/PopupItems1/Open")->set_sensitive($TRUE);
	$uimanager->get_widget("$ui_path/PopupItems1/Open With")->set_sensitive($TRUE);
	$uimanager->get_widget("$ui_path/PopupItems1/Delete")->set_sensitive($TRUE);
	$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive($TRUE);
	$uimanager->get_widget("$ui_path/PopupItems1/Move")->set_sensitive($TRUE);
	$uimanager->get_widget("$ui_path/Properties")->set_sensitive($TRUE);

	my $bookmarks = Filer::Bookmarks->new;
	$uimanager->get_widget("$ui_path/Bookmarks")->set_submenu($bookmarks->generate_bookmarks_menu);

	if ($self->count_items == 1) {
		my $fi = $self->get_fileinfo_list->[0];

		if ($fi->is_dir) {
			$uimanager->get_widget("$ui_path/PopupItems1/Open With")->set_sensitive($FALSE);
		}
	} elsif ($self->count_items > 1) {
		$uimanager->get_widget("$ui_path/PopupItems1/Open")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/PopupItems1/Open With")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/Properties")->set_sensitive($FALSE);
	} else {
		$uimanager->get_widget("$ui_path/PopupItems1/Open")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/PopupItems1/Open With")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/PopupItems1/Delete")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/PopupItems1/Copy")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/PopupItems1/Move")->set_sensitive($FALSE);
		$uimanager->get_widget("$ui_path/Properties")->set_sensitive($FALSE);
	}

	$popup_menu->show_all;
	$popup_menu->popup(undef, undef, undef, undef, $e->button, $e->time);
}


sub treeview_event_cb {
	my ($self,$w,$e) = @_;

	if ($e->type eq "key-press") {
		if ($e->keyval == $Gtk2::Gdk::Keysyms{'BackSpace'}) {
			$self->open_path($self->get_updir);
			return 1;
		} elsif ($e->keyval == $Gtk2::Gdk::Keysyms{'Return'}) {

			$self->open_file($self->get_fileinfo_list->[0]);
			return 1;
		} elsif ($e->keyval == $Gtk2::Gdk::Keysyms{'Delete'}) {

			Filer->instance()->delete_cb;
			return 1;
		}
	}

	if ($e->type eq "button-press") { 
		if ($e->button == 3) {
			$self->set_focus;
			$self->show_popup_menu($e);
			return 1;
		}
	}
	
	if ($e->type eq "2button-press" and $e->button == 1) {
		my ($p) = $self->{treeview}->get_path_at_pos($e->x,$e->y);
		
		if (defined $p) {
			my $iter = $self->{treemodel}->get_iter($p);
			my $fi   = $self->get_fileinfo($iter);

			if (defined $fi) {
				$self->open_file($fi);
			}
		}

		return 1;
	}

	return 0;
}

sub get_pwd {
	my ($self) = @_;
	return $self->{filepath};
}

sub get_updir {
	my ($self) = @_;
	return abs_path(Filer::Tools->catpath($self->{filepath}, $UPDIR));
}

sub update_navigation_buttons {
	my ($self)  = @_;
	my $path    = $ROOTDIR;
	my $button  = undef;

	foreach my $path (sort { length($b) <=> length($a) } keys %{$self->{navigation_buttons}}) {
		# check if the current path button $path isn't a parentdir of $filepath
		last if (($self->{filepath} =~ /^$path/) and (-e $path));

		# destroy path button
		$self->{navigation_buttons}->{$path}->destroy;
		delete $self->{navigation_buttons}->{$path};
	}

	foreach (File::Spec->splitdir($self->{filepath})) {
		$path = Filer::Tools->catpath($path, $_);

		if (not defined $self->{navigation_buttons}->{$path}) {
			my $name = basename($path);
			
			$button = Gtk2::RadioButton->new_with_label($self->{navigation_buttons}->{$ROOTDIR}, $name);
			$button->set(draw_indicator => 0); # i'm evil

			$button->signal_connect(toggled => sub {
				my ($widget,$path) = @_;

		 		my $label = $widget->get_child;
				my $pc    = $label->get_pango_context;
				my $fd    = $pc->get_font_description;

				if ($widget->get_active) {
					$fd->set_weight('PANGO_WEIGHT_BOLD');
					$self->show_directory_contents($path);
				} else {
					$fd->set_weight('PANGO_WEIGHT_NORMAL');
				}

				$label->modify_font($fd);
			}, $path);

			$self->{navigation_box}->pack_start($button, $FALSE, $FALSE, 0);
			$self->{navigation_buttons}->{$path} = $button;
			$self->{navigation_buttons}->{$path}->show;
		}
	}

	# set last button active. current directory.
	$self->{navigation_buttons}->{$self->{filepath}}->set(active => 1);
}

sub open_file {
	my ($self,$fileinfo) = @_;

	return 0 if (not defined $fileinfo);

	my $filepath = abs_path($fileinfo->get_path);

	return 0 if ((not defined $filepath) or (not -R $filepath));

	if ($fileinfo->is_dir) {
		$self->open_path($filepath);

	} elsif ($fileinfo->is_executable) {

		Filer::Tools->exec($filepath);

	} else {
		my $handler = $fileinfo->get_mimetype_handler;

		if ($handler) {
			Filer::Tools->exec("$handler '$filepath'");
		} else {
			$self->open_file_with($fileinfo);
		}
	}
}

sub open_file_with {
	my ($self,$fileinfo) = @_;

	return 0 if (not defined $fileinfo);

	Filer::Dialog->show_open_with_dialog($fileinfo);		
}

sub open_path {
	my ($self,$filepath) = @_;

	$self->show_directory_contents($filepath);

	if (defined $self->{navigation_buttons}->{$filepath}) {
		$self->{navigation_buttons}->{$filepath}->set(active => 1);
	} else {
		$self->update_navigation_buttons;
	}
}

sub show_directory_contents {
	my ($self,$filepath) = @_;

	$self->{filepath}  = $filepath;
	$self->{directory} = Filer::Directory->new($filepath);

 	$self->{treemodel}->clear;

 	my $dir_contents = $self->{directory}->all;
	
	foreach my $fi (@{$dir_contents}) {
		if (($self->{ShowHiddenFiles} == $FALSE) && $fi->is_hidden) {
			next;
		}

		$self->{treemodel}->append_fileinfo($fi);
	}

	$self->{path_combo}->insert_text(0, $self->{filepath});
	$self->{path_combo}->set_active(0);

	my $status = sprintf("%d directories and %d files: %s", $self->{directory}->dirs_count, $self->{directory}->files_count, $self->{directory}->total_size);
	$self->{status}->set_text($status);
}

sub refresh {
	my ($self) = @_;
	$self->show_directory_contents($self->{filepath});
	$self->update_navigation_buttons;
}

sub show_file_selection_dialog {
	my ($self) = @_;
	$self->_show_file_selection_dialog($SELECT);
}

sub show_file_unselection_dialog {
	my ($self) = @_;
	$self->_show_file_selection_dialog($UNSELECT);
}

sub _show_file_selection_dialog {
	my ($self,$type) = @_;

	my $dialog = Filer::DefaultDialog->new;

	my $hbox = Gtk2::HBox->new(0,0);
	$dialog->vbox->pack_start($hbox, $FALSE, $TRUE, 5);

	my $label = Gtk2::Label->new;
	$hbox->pack_start($label, $FALSE, $FALSE, 0);

	my $entry = Gtk2::Entry->new;
	$entry->set_activates_default($TRUE);
	$entry->set_text("*");
	$hbox->pack_start($entry, $TRUE, $TRUE, 0);

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

		$self->{treemodel}->foreach(sub {
			my ($model,$iter,$fileinfo) = @_;
			
			if ($fileinfo->get_basename =~ /\A$str\Z/)  {
				if ($type == $SELECT) {
					$self->{treeselection}->select_iter($iter);
				}

				if ($type == $UNSELECT) {
					$self->{treeselection}->unselect_iter($iter);
				}
			}
			
			return 1;
		});
	}

	$dialog->destroy;
}

1;
