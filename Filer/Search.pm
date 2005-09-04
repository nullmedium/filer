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
use Class::Std::Utils;

use strict;
use warnings;

my %filechooser_button;
my %file_pattern_entry;
my %grep_pattern_entry;
my %file_pattern;
my %grep_pattern;
my %follow_symlinks_checkbutton;
my %first_match_checkbutton;
my %searching_label;
my %search_stop;
my %treestore;
my %treeview;
my %parent_iter;
my %dirwalk;

sub new {
	my ($class,$filer) = @_;
	my $self = bless anon_scalar(), $class;
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

	$filechooser_button{ident $self} = new Gtk2::FileChooserButton("Search in ...", 'GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER');
	$filechooser_button{ident $self}->set_current_folder($filer->get_active_pane->get_item);
       	$table->attach($filechooser_button{ident $self}, 1, 2, 0, 1, [ "fill", "expand" ], [], 0, 0);
 
	$label = new Gtk2::Label("Filename: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

 	$file_pattern_entry{ident $self} = new Gtk2::Entry;
	$table->attach($file_pattern_entry{ident $self}, 1, 2, 1, 2, [ "fill", "expand" ], [], 0, 0);

	$label = new Gtk2::Label("Content: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 2, 3, [ "fill" ], [], 0, 0);

	$grep_pattern_entry{ident $self} = new Gtk2::Entry;
	$table->attach($grep_pattern_entry{ident $self}, 1, 2, 2, 3, [ "fill", "expand" ], [], 0, 0);

	$follow_symlinks_checkbutton{ident $self} = new Gtk2::CheckButton("Follow symlinks");
	$follow_symlinks_checkbutton{ident $self}->set_alignment(0.0,0.0);
	$table->attach($follow_symlinks_checkbutton{ident $self}, 0, 2, 3, 4, [ "fill" ], [], 0, 0);

	$first_match_checkbutton{ident $self} = new Gtk2::CheckButton("List only first line with given content string");
	$first_match_checkbutton{ident $self}->set_alignment(0.0,0.0);
	$table->attach($first_match_checkbutton{ident $self}, 0, 2, 4, 5, [ "fill" ], [], 0, 0);

	$hbox = new Gtk2::HButtonBox;
	$hbox->set_layout_default('end');
	$hbox->set_spacing(5);
	$table->attach($hbox, 0, 3, 5, 6, [ "fill", "expand" ], [], 0, 0);

	$button = Gtk2::Button->new_from_stock("gtk-find");
	$button->set_label("Search");
	$button->signal_connect("clicked", sub {
		$self->init_dirwalk;
		$self->start_search
	});
	$hbox->add($button);

	$button = Gtk2::Button->new_from_stock("gtk-stop");
	$button->signal_connect("clicked", sub {
		$search_stop{ident $self} = 1;
	});
	$hbox->add($button);

	$button = Gtk2::Button->new_from_stock("gtk-clear");
	$button->signal_connect("clicked", sub {
		$treestore{ident $self}->clear;
		$searching_label{ident $self}->set_markup("");
	});
	$hbox->add($button);

	$searching_label{ident $self} = new Gtk2::Label;
	$searching_label{ident $self}->set_use_markup(1);
	$searching_label{ident $self}->set_alignment(0.0,0.0);
	$dialog->vbox->pack_start($searching_label{ident $self},0,0,5);

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$dialog->vbox->pack_start($sw,1,1,0);

	$treestore{ident $self} = new Gtk2::TreeStore('Glib::String');
	$treeview{ident $self}  = Gtk2::TreeView->new_with_model($treestore{ident $self});
	$treeview{ident $self}->insert_column_with_attributes(0, "Search Results", new Gtk2::CellRendererText, text => 0);
	$sw->add($treeview{ident $self});

	$dialog->show_all;

	$dialog->run;
	$dialog->destroy;

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $filechooser_button{ident $self};
	delete $file_pattern_entry{ident $self};
	delete $grep_pattern_entry{ident $self};
	delete $file_pattern{ident $self};
	delete $grep_pattern{ident $self};
	delete $follow_symlinks_checkbutton{ident $self};
	delete $first_match_checkbutton{ident $self};
	delete $searching_label{ident $self};
	delete $search_stop{ident $self};
	delete $treestore{ident $self};
	delete $treeview{ident $self};
	delete $parent_iter{ident $self};
	delete $dirwalk{ident $self};
}

sub init_dirwalk {
	my ($self) = @_;

	$dirwalk{ident $self} = new File::DirWalk;

	$dirwalk{ident $self}->onBeginWalk(sub {
		if ($search_stop{ident $self} == 1) {
			return 0;
		}

		while (Gtk2->events_pending) { Gtk2->main_iteration; }
		return 1;
	});

	$dirwalk{ident $self}->onDirEnter(sub {
		my ($path) = @_;
		my $dirname_file = File::Basename::dirname($path);

 		$searching_label{ident $self}->set_markup("<b>Searching in:</b> $dirname_file");
		return 1;
	});

	my $f = sub {
		my ($file) = @_;
		my $dirname_file      = File::Basename::dirname($file);
		my $basename_file     = File::Basename::basename($file);
		my $file_pattern      = $file_pattern{ident $self};
		my $grep_pattern      = $grep_pattern{ident $self};

		if ($basename_file !~ /\A$file_pattern\Z/) {
			return 1;
		}

		if (not defined $grep_pattern) {
			if (not defined $parent_iter{ident $self}->{$dirname_file}) {
				$parent_iter{ident $self}->{$dirname_file} = 
					$treestore{ident $self}->insert_with_values(
						undef,
						-1,
						0, $dirname_file
					);
			}

			$treestore{ident $self}->insert_with_values(
				$parent_iter{ident $self}->{$dirname_file},
				0, $basename_file
			);
		} else {
			if (-T $file and -R $file) {
				my $hits = 0;

				open my $fh, $file || return 0;

				while (<$fh>) {

					if ($search_stop{ident $self} == 1) {
						return 0;
					}

					if (/$grep_pattern/) {
						++$hits;

						if (not defined $parent_iter{ident $self}->{$dirname_file}) {
							$parent_iter{ident $self}->{$dirname_file} = 
								$treestore{ident $self}->insert_with_values(
									undef,
									-1,
									0, $dirname_file
								);
						}

						$treestore{ident $self}->insert_with_values(
							$parent_iter{ident $self}->{$dirname_file},
							-1,
							0, "Line $.: $basename_file"
						);

						if ($first_match_checkbutton{ident $self}->get_active) {
							last;
						}

						if ($hits >= 500 or $. >= 10000)  {
							$treestore{ident $self}->insert_with_values(
								$parent_iter{ident $self}->{$dirname_file},
								-1,
								0, "..."
							);

							last;
						}
					}

					while (Gtk2->events_pending) { Gtk2->main_iteration; }
				}

				close $fh;
			}
		}

		return 1;
	};

	$dirwalk{ident $self}->onFile($f);

	if ($follow_symlinks_checkbutton{ident $self}->get_active) {
		$dirwalk{ident $self}->onLink($f);
	}
}

sub start_search {
	my ($self) = @_;

	my $path                   = $filechooser_button{ident $self}->get_filename;
	$file_pattern{ident $self} = $file_pattern_entry{ident $self}->get_text;
	$grep_pattern{ident $self} = $grep_pattern_entry{ident $self}->get_text;

	$file_pattern{ident $self} =~ s/\//\\\//g;
	$file_pattern{ident $self} =~ s/\./\\./g;
	$file_pattern{ident $self} =~ s/\*/\.*/g;
	$file_pattern{ident $self} =~ s/\?/\./g;

	if ($file_pattern{ident $self} eq "") {
		$file_pattern{ident $self} = "*";
	}

	if ($grep_pattern{ident $self} eq "") {
		delete $grep_pattern{ident $self};
	}

	$treestore{ident $self}->clear;
	$parent_iter{ident $self} = {};
	$search_stop{ident $self} = 0;

	$dirwalk{ident $self}->walk($path);

	$searching_label{ident $self}->set_markup("<b>Searching finished</b>");
	$treeview{ident $self}->expand_all;
}

1;
