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

package Filer::Search;

use strict;
use warnings;

sub new {
	my ($class,$filer) = @_;
	my $self = bless {}, $class;
	my ($dialog,$table,$label,$button,$hbox,$sw);

	$dialog = new Gtk2::Dialog("Search", undef, 'modal', 'gtk-close' => 'close');
	$dialog->set_size_request(600,400);
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$table = new Gtk2::Table(5,2);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

	$label = new Gtk2::Label("Search in: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$self->{filechooser_button} = new Gtk2::FileChooserButton("Search in ...", 'GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER');
	$self->{filechooser_button}->set_current_folder($filer->get_active_pane->get_item);
       	$table->attach($self->{filechooser_button}, 1, 2, 0, 1, [ "fill", "expand" ], [], 0, 0);
 
	$label = new Gtk2::Label("Filename: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

 	$self->{file_pattern_entry} = new Gtk2::Entry;
	$table->attach($self->{file_pattern_entry}, 1, 2, 1, 2, [ "fill", "expand" ], [], 0, 0);

	$label = new Gtk2::Label("Content: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 2, 3, [ "fill" ], [], 0, 0);

	$self->{grep_pattern_entry} = new Gtk2::Entry;
	$table->attach($self->{grep_pattern_entry}, 1, 2, 2, 3, [ "fill", "expand" ], [], 0, 0);

	$self->{follow_symlinks_checkbutton} = new Gtk2::CheckButton("Follow symlinks");
	$self->{follow_symlinks_checkbutton}->set_alignment(0.0,0.0);
	$table->attach($self->{follow_symlinks_checkbutton}, 0, 2, 3, 4, [ "fill" ], [], 0, 0);

	$self->{first_match_checkbutton} = new Gtk2::CheckButton("List only first line with given content string");
	$self->{first_match_checkbutton}->set_alignment(0.0,0.0);
	$table->attach($self->{first_match_checkbutton}, 0, 2, 4, 5, [ "fill" ], [], 0, 0);

	$hbox = new Gtk2::HButtonBox;
	$hbox->set_layout_default('end');
	$hbox->set_spacing(5);
	$table->attach($hbox, 0, 3, 5, 6, [ "fill", "expand" ], [], 0, 0);

	$button = Gtk2::Button->new_from_stock("gtk-find");
	$button->set_label("Search");
	$button->signal_connect("clicked", sub {
		$self->init_dirwalk();
		$self->start_search
	});
	$hbox->add($button);

	$button = Gtk2::Button->new_from_stock("gtk-stop");
	$button->signal_connect("clicked", sub {
		$self->{search_stop} = 1;
	});
	$hbox->add($button);

	$button = Gtk2::Button->new_from_stock("gtk-clear");
	$button->signal_connect("clicked", sub {
		$self->{treestore}->clear;
		$self->{searching_label}->set_markup("");
	});
	$hbox->add($button);

	$self->{searching_label} = new Gtk2::Label;
	$self->{searching_label}->set_use_markup(1);
	$self->{searching_label}->set_alignment(0.0,0.0);
	$dialog->vbox->pack_start($self->{searching_label},0,0,5);

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$dialog->vbox->pack_start($sw,1,1,0);

	$self->{treestore} = new Gtk2::TreeStore('Glib::String');
	$self->{treeview} = Gtk2::TreeView->new_with_model($self->{treestore});
	$self->{treeview}->insert_column_with_attributes(0, "Search Results", new Gtk2::CellRendererText, text => 0);
	$sw->add($self->{treeview});

	$dialog->show_all;

	$dialog->run;
	$dialog->destroy;

	return $self;
}

sub init_dirwalk {
	my ($self) = @_;

	$self->{dirwalk} = new File::DirWalk;

	$self->{dirwalk}->onBeginWalk(sub {
		if ($self->{search_stop} == 1) {
			return 0;
		}

		while (Gtk2->events_pending) { Gtk2->main_iteration; }
		return 1;
	});

	$self->{dirwalk}->onDirEnter(sub {
		my ($path) = @_;
		my $dirname_file = File::Basename::dirname($path);

 		$self->{searching_label}->set_markup("<b>Searching in:</b> $dirname_file");
		return 1;
	});

	my $f = sub {
		my ($file) = @_;
		my $dirname_file = File::Basename::dirname($file);
		my $basename_file = File::Basename::basename($file);
		my $file_name_pattern = $self->{file_name_pattern};
		my $grep_pattern = $self->{grep_pattern};

		if ($basename_file !~ /\A$file_name_pattern\Z/) {
			return 1;
		}

		if (not defined $grep_pattern) {
			if (not defined $self->{parent_iter}->{$dirname_file}) {
				$self->{parent_iter}->{$dirname_file} = $self->append_search_result(undef,$dirname_file);
			}

			$self->append_search_result($self->{parent_iter}->{$dirname_file}, $basename_file);
		} else {
			if (-T $file and -R $file) {
				my $hits = 0;

				open(FILE, "$file") || return 0;

				while (<FILE>) {

					if ($self->{search_stop} == 1) {
						return 0;
					}

					if (/$grep_pattern/) {
						++$hits;

						if (not defined $self->{parent_iter}->{$dirname_file}) {
							$self->{parent_iter}->{$dirname_file} = $self->append_search_result(undef,$dirname_file);
						}

						$self->append_search_result($self->{parent_iter}->{$dirname_file}, "Line $.: $basename_file");

						if ($self->{first_match_checkbutton}->get_active) {
							last;
						}

						if ($hits >= 500 or $. >= 10000)  {
							$self->append_search_result($self->{parent_iter}->{$dirname_file}, "...");
							last;
						}
					}

					while (Gtk2->events_pending) { Gtk2->main_iteration; }
				}

				close(FILE);
			}
		}

		return 1;
	};

	$self->{dirwalk}->onFile($f);

	if ($self->{follow_symlinks_checkbutton}->get_active) {
		$self->{dirwalk}->onLink($f);
	}
}

sub start_search {
	my ($self) = @_;

	my $path = $self->{filechooser_button}->get_filename;
	$self->{file_name_pattern} = $self->{file_pattern_entry}->get_text;
	$self->{grep_pattern} = $self->{grep_pattern_entry}->get_text;

	$self->{file_name_pattern} =~ s/\//\\\//g;
	$self->{file_name_pattern} =~ s/\./\\./g;
	$self->{file_name_pattern} =~ s/\*/\.*/g;
	$self->{file_name_pattern} =~ s/\?/\./g;

	if ($self->{file_name_pattern} eq "") {
		$self->{file_name_pattern} = "*";
	}

	if ($self->{grep_pattern} eq "") {
		delete $self->{grep_pattern};
	}

	$self->{treestore}->clear;
	$self->{parent_iter} = {};
	$self->{search_stop} = 0;

	$self->{dirwalk}->walk($path);

	$self->{searching_label}->set_markup("<b>Searching finished</b>");
	$self->{treeview}->expand_all;
}

sub append_search_result {
	my ($self,$parent_iter,$str) = @_;

	my $iter = $self->{treestore}->append($parent_iter);
	$self->{treestore}->set($iter, 0, $str);

	return $iter;
}

1;
