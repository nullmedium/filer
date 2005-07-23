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
	$self->{types_treeview} = Gtk2::TreeView->new_with_model($self->{types_model});
	$self->{types_treeview}->set_rules_hint(1);
	$self->{types_treeview}->set_headers_visible(0);

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => 0);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => 1);

	$self->{types_treeview}->append_column($col);

	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, text => 2);

	$self->{types_treeview}->append_column($col);

	$selection = $self->{types_treeview}->get_selection;
	$selection->signal_connect("changed", sub {
		my ($selection) = @_;
		my $type = $self->get_selected_type;
		$self->{commands_model}->clear;

		if (defined $type) {
			$self->refresh_commands($type);
		}

		return 1;
	});
	$sw->add($self->{types_treeview});

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$hbox->pack_start($sw,1,1,0);

	$self->{commands_model} = new Gtk2::ListStore('Glib::String');
	$self->{commands_treeview} = Gtk2::TreeView->new_with_model($self->{commands_model});
	$self->{commands_treeview}->insert_column_with_attributes(0, "Application Preference Order", Gtk2::CellRendererText->new, text => 0);
	$sw->add($self->{commands_treeview});

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
		my $fs = new Gtk2::FileChooserDialog("Select Command", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		my ($iter,$command) = $self->get_selected_command;
		$fs->set_filename($command);

		if ($fs->run eq 'ok') {
			$self->{commands_model}->set($iter, 0, $fs->get_filename);
			$self->set_commands;
		}
		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		my $iter = $self->{commands_treeview}->get_selection->get_selected;
		
		if (defined $iter) {
			$self->{commands_model}->remove($iter);
			$self->set_commands;
		}
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-up');
	$button->signal_connect("clicked", sub {
		my $iter = $self->{commands_treeview}->get_selection->get_selected;
		
		if (defined $iter) {
			my $treepath = $self->{commands_model}->get_path($iter);

			if ($treepath->prev) {
				$self->{commands_model}->swap($self->{commands_model}->get_iter($treepath),$iter);
				$self->set_commands;
			}
		}
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-down');
	$button->signal_connect("clicked", sub {
		my $iter = $self->{commands_treeview}->get_selection->get_selected;

		if (defined $iter) {
			my $treepath = $self->{commands_model}->get_path($iter);
			$treepath->next;
	
			my $b = $self->{commands_model}->get_iter($treepath);

			if ($b) {
				$self->{commands_model}->swap($iter,$b);
				$self->set_commands;
			}
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
		my ($iter,$type) = $self->get_selected_type;

		if (defined $type) {
			$self->{mime}->delete_mimetype($type);
			$self->{types_model}->remove($iter);
			$self->{commands_model}->clear;
		}
		return 1;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new("Set Icon");
	$button->signal_connect("clicked", sub {
		my $type = $self->get_selected_type;

		if (defined $type) {
			$self->{mime}->set_icon_dialog($type);
			$self->refresh_types;
		}
	});
	$bbox->add($button);

	$self->refresh_types;
	$dialog->show_all;
	$dialog->run;
	$dialog->destroy;

	return $self;
}

sub get_selected_type {
	my ($self) = @_;
	my $iter = $self->{types_treeview}->get_selection->get_selected;

	if (defined $iter) {
		my $type = $self->{types_model}->get($iter,2);

		if (wantarray) {
			return ($iter,$type);		
		} else {
			return $type;
		}
	} else {
		return undef;
	}
}

sub get_selected_command {
	my ($self) = @_;
	my $iter = $self->{commands_treeview}->get_selection->get_selected;
	
	if (defined $iter) {
		my $command = $self->{commands_model}->get($iter,0);

		if (wantarray) {
			return ($iter,$command);
		} else {
			return $command;
		}
	} else {
		return undef;
	}
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

	my $type = $self->get_selected_type;
	if (defined $type) {
		$self->{mime}->set_commands($type,\@commands);
	}
};

1;
