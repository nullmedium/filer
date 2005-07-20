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

package Filer::FileAssociationDialog;

sub new {
	my ($class,$mime) = @_;
	my $self = bless {}, $class;
	$self->{mime} = $mime;

	my ($dialog,$bbox,$hbox,$vbox,$sw,$treeview,$selection);
	my ($cell,$col,$button);

	$self->{selected_type} = undef;
	$self->{selected_type_iter} = undef;
	$self->{selected_command} = undef;
	$self->{selected_command_iter} = undef;

	$dialog = new Gtk2::Dialog("File Association", undef, 'modal', 'gtk-close' => 'close');
	$dialog->set_size_request(600,400);
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,1,1,0);

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$hbox->pack_start($sw,1,1,0);

	$self->{types_model} = new Gtk2::TreeStore('Glib::Object','Glib::String','Glib::String');
	$treeview = Gtk2::TreeView->new_with_model($self->{types_model});
	$treeview->set_rules_hint(1);
	$treeview->set_headers_visible(0);

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => 0);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => 1);

	$treeview->append_column($col);

	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, text => 2);

	$treeview->append_column($col);

	$selection = $treeview->get_selection;
	$selection->signal_connect("changed", sub {
		my ($selection) = @_;
		$self->{selected_type_iter} = $selection->get_selected;
		$self->{selected_type} = undef;

		if (defined $self->{selected_type_iter}) {
			$self->{selected_type} = $self->{types_model}->get($self->{selected_type_iter}, 2);

			if (defined $self->{selected_type}) {
				$self->refresh_commands($self->{selected_type});
			}
		}
	});
	$sw->add($treeview);

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$hbox->pack_start($sw,1,1,0);

	$self->{commands_model} = new Gtk2::ListStore('Glib::String');

	$treeview = Gtk2::TreeView->new_with_model($self->{commands_model});
	$treeview->insert_column_with_attributes(0, "Application Preference Order", Gtk2::CellRendererText->new, text => 0);

	$selection = $treeview->get_selection;
	$selection->signal_connect("changed", sub {
		my ($selection) = @_;
		$self->{selected_command_iter} = $selection->get_selected;
		$self->{selected_command} = undef;
		
		if (defined $self->{selected_command_iter}) {
			$self->{selected_command} = $self->{commands_model}->get($self->{selected_command_iter}, 0);
		}
	});
	$sw->add($treeview);

	$bbox = new Gtk2::VButtonBox;
	$bbox->set_layout_default('start');
	$bbox->set_spacing_default(5);
	$hbox->pack_start($bbox,0,0,2);

	$button = Gtk2::Button->new_from_stock('gtk-add');
	$button->signal_connect("clicked", sub {
		my $fs = new Gtk2::FileChooserDialog("Select Command", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');

		if ($fs->run eq 'ok') {
			$self->{commands_model}->set($self->{commands_model}->append, 0, $fs->get_filename);
			$self->set_commands;
		}

		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-edit');
	$button->signal_connect("clicked", sub {
		return if (not defined $self->{selected_command_iter});

		my $fs = new Gtk2::FileChooserDialog("Select Command", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		$fs->set_filename($self->{selected_command});

		if ($fs->run eq 'ok') {
			$self->{commands_model}->set($self->{selected_command_iter}, 0, $fs->get_filename);
			$self->set_commands;
		}
		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		return if (not defined $self->{selected_command_iter});
		
		$self->{commands_model}->remove($self->{selected_command_iter});
		$self->set_commands;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-up');
	$button->signal_connect("clicked", sub {
		my $treepath = $self->{commands_model}->get_path($self->{selected_command_iter});

		if ($treepath->prev) {
			$self->{commands_model}->swap($self->{commands_model}->get_iter($treepath),$self->{selected_command_iter});
			$self->set_commands;
		}
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-down');
	$button->signal_connect("clicked", sub {
		my $treepath = $self->{commands_model}->get_path($self->{selected_command_iter});
		$treepath->next;
	
		my $b = $self->{commands_model}->get_iter($treepath);

		if ($b) {
			$self->{commands_model}->swap($self->{selected_command_iter},$b);
			$self->set_commands;
		}
	});
	$bbox->add($button);

	$bbox = new Gtk2::HButtonBox;
	$bbox->set_layout_default('start');
	$bbox->set_spacing_default(5);
	$dialog->vbox->pack_start($bbox, 0,1,0);

	$button = Gtk2::Button->new_from_stock('gtk-add');
	$button->signal_connect("clicked", sub {
		my ($dialog,$table,$combo,$label,$entry);

		$dialog = new Gtk2::Dialog("Add mimetype", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		$dialog->set_position('center');
		$dialog->set_modal(1);

		$table = new Gtk2::Table(2,2);
		$dialog->vbox->pack_start($table, 1,1,5);

		$label = new Gtk2::Label;
		$label->set_text("Group: ");
		$table->attach($label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

		$combo = Gtk2::ComboBox->new_text;
		foreach ($self->{mime}->get_mimetype_groups) { $combo->append_text($_) }
		$combo->set_active(0);
		$table->attach($combo, 1, 2, 0, 1, [ "fill" ], [], 0, 0);

		$label = new Gtk2::Label;
		$label->set_text("Type name: ");
		$table->attach($label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

		$entry = new Gtk2::Entry;
		$entry->set_text("");
		$table->attach($entry, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

		$dialog->show_all;

		if ($dialog->run eq 'ok' and defined $entry->get_text) {
			my $type = $combo->get_active_text . "/" . $entry->get_text;
			$self->{mime}->add_mimetype($type);
		}

		$dialog->destroy;
		$self->refresh_types;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		if (defined $self->{selected_type} and defined $self->{selected_type_iter}) {
			$self->{types_model}->remove($self->{selected_type_iter});		
			$self->{commands_model}->clear;
			$self->{mime}->delete_mimetype($self->{selected_type});
		}
	});
	$bbox->add($button);

	$button = Gtk2::Button->new("Set Icon");
	$button->signal_connect("clicked", sub {
		$self->set_icon_dialog($self->{selected_type});
		$self->refresh_types;
	});
	$bbox->add($button);

	$self->refresh_types;
	$dialog->show_all;
	$dialog->run;
	$dialog->destroy;

	return $self;
}

sub refresh_types {
	my ($self) = @_;
	my $groups = {};

	$self->{types_model}->clear;

	foreach ($self->{mime}->get_mimetype_groups) {
		$groups->{$_} = $self->{types_model}->append(undef);
		$self->{types_model}->set($groups->{$_}, 1, $_, 2, undef);
	}

	foreach (sort $self->{mime}->get_mimetypes) {
		next if ($_ eq 'default');

		if ($_ =~ /(.+)\/(.+)/) {
			my $group = $1;
			my $type = $2;
			$self->{types_model}->set($self->{types_model}->append($groups->{$group}), 0, Gtk2::Gdk::Pixbuf->new_from_file($self->{mime}->get_icon($_)), 1, $type, 2, "$group/$type");
		}
	}
}

sub refresh_commands {
	my ($self,$type) = @_;
	$self->{commands_model}->clear;

	foreach ($self->{mime}->get_commands($type)) {
		$self->{commands_model}->set($self->{commands_model}->append, 0, $_);
	}
}

sub set_commands {
	my ($self) = @_;
	my @commands = ();

	$self->{commands_model}->foreach(sub {
		my $cmd = $_[0]->get($_[2], 0);
		push @commands, $cmd;
		return 0;
	});

	$self->{mime}->set_commands($self->{selected_type},\@commands);
};

1;
