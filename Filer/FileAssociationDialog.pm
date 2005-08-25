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
use Class::Std::Utils;

use strict;
use warnings;

my %mime;
my %types_model;
my %types_treeview;
my %commands_model;
my %commands_treeview;

sub new {
	my ($class,$mime) = @_;
	my $self = bless anon_scalar(), $class;
	
	my ($dialog,$sw,$hbox,$col,$cell,$selection,$bbox,$button);

	$mime{ident $self} = $mime;

	$dialog = new Gtk2::Dialog(
		"File Association",
		undef,
		'modal',
		'gtk-close' => 'close'
	);

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

	$types_model{ident $self}    = new Gtk2::TreeStore(qw(Glib::Object Glib::String Glib::String));
	$types_treeview{ident $self} = Gtk2::TreeView->new_with_model($types_model{ident $self});
	$types_treeview{ident $self}->set_rules_hint(1);
	$types_treeview{ident $self}->set_headers_visible(0);

	# a column with a pixbuf renderer and a text renderer
	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererPixbuf->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, pixbuf => 0);

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 1);
	$col->add_attribute($cell, text => 1);

	$types_treeview{ident $self}->append_column($col);

	$col = Gtk2::TreeViewColumn->new;
	$col->set_title("Name");

	$cell = Gtk2::CellRendererText->new;
	$col->pack_start($cell, 0);
	$col->add_attribute($cell, text => 2);

	$types_treeview{ident $self}->append_column($col);

	$selection = $types_treeview{ident $self}->get_selection;
	$selection->signal_connect("changed", sub {
		my ($selection) = @_;
		my $type = $self->get_selected_type;
		$commands_model{ident $self}->clear;

		return if (! defined $type);

		$self->refresh_commands($type);
	});
	$sw->add($types_treeview{ident $self});

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$hbox->pack_start($sw,1,1,0);

	$commands_model{ident $self}    = new Gtk2::ListStore('Glib::String');
	$commands_treeview{ident $self} = Gtk2::TreeView->new_with_model($commands_model{ident $self});
	$commands_treeview{ident $self}->insert_column_with_attributes(0, "Application Preference Order", Gtk2::CellRendererText->new, text => 0);
	$sw->add($commands_treeview{ident $self});

	$bbox = new Gtk2::VButtonBox;
	$bbox->set_layout_default('start');
	$bbox->set_spacing_default(5);
	$hbox->pack_start($bbox,0,0,2);

	$button = Gtk2::Button->new_from_stock('gtk-add');
	$button->signal_connect("clicked", sub {
		my $fs = new Gtk2::FileChooserDialog(
			"Select Command",
			undef,
			'GTK_FILE_CHOOSER_ACTION_OPEN',
			'gtk-cancel' => 'cancel',
			'gtk-ok'     => 'ok'
		);

		if ($fs->run eq 'ok') {
			$commands_model{ident $self}->set($commands_model{ident $self}->append, 0, $fs->get_filename);
			$self->set_commands;
		}

		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-edit');
	$button->signal_connect("clicked", sub {
		my $fs = new Gtk2::FileChooserDialog(
			"Select Command",
			undef,
			'GTK_FILE_CHOOSER_ACTION_OPEN',
			'gtk-cancel' => 'cancel',
			'gtk-ok'     => 'ok'
		);

		my ($iter,$command) = $self->get_selected_command;
		$fs->set_filename($command);

		if ($fs->run eq 'ok') {
			$commands_model{ident $self}->set($iter, 0, $fs->get_filename);
			$self->set_commands;
		}
		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		my $iter = $commands_treeview{ident $self}->get_selection->get_selected;
		return if (! defined $iter);

		$commands_model{ident $self}->remove($iter);
		$self->set_commands;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-up');
	$button->signal_connect("clicked", sub {
		my $iter = $commands_treeview{ident $self}->get_selection->get_selected;
		return if (! defined $iter);

		my $treepath = $commands_model{ident $self}->get_path($iter);

		if ($treepath->prev) {
			$commands_model{ident $self}->swap($commands_model{ident $self}->get_iter($treepath),$iter);
			$self->set_commands;
		}
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-down');
	$button->signal_connect("clicked", sub {
		my $iter = $commands_treeview{ident $self}->get_selection->get_selected;
		return if (! defined $iter); 

		my $treepath = $commands_model{ident $self}->get_path($iter);
		$treepath->next;
	
		my $b = $commands_model{ident $self}->get_iter($treepath);

		if ($b) {
			$commands_model{ident $self}->swap($iter,$b);
			$self->set_commands;
		}
	});
	$bbox->add($button);

	$bbox = new Gtk2::HButtonBox;
	$bbox->set_layout_default('start');
	$bbox->set_spacing_default(5);
	$dialog->vbox->pack_start($bbox, 0,1,0);

	$button = Gtk2::Button->new_from_stock('gtk-add');
	$button->signal_connect("clicked", \&add_mimetype_dialog, $self);
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		my ($iter,$type) = $self->get_selected_type;
		return if (! defined $iter);

		$mime{ident $self}->delete_mimetype($type);
		$types_model{ident $self}->remove($iter);
		$commands_model{ident $self}->clear;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new("Set Icon");
	$button->signal_connect("clicked", sub {
		my $type = $self->get_selected_type;
		return if (! defined $type);

		$mime{ident $self}->set_icon_dialog($type);
		$self->refresh_types;
	});
	$bbox->add($button);

	$self->refresh_types;
	$dialog->show_all;
	$dialog->run;
	$dialog->destroy;

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $mime{ident $self};
	delete $types_model{ident $self};
	delete $types_treeview{ident $self};
	delete $commands_model{ident $self};
	delete $commands_treeview{ident $self};
}

sub add_mimetype_dialog {
	my $self = pop;
	my ($dialog,$table,$combo,$label,$entry);

	$dialog = new Gtk2::Dialog(
		"Add mimetype",
		undef,
		'modal',
		'gtk-cancel' => 'cancel',
		'gtk-ok'     => 'ok'
	);

	$dialog->set_position('center');
	$dialog->set_modal(1);

	$table = new Gtk2::Table(2,2);
	$dialog->vbox->pack_start($table, 1,1,5);

	$label = new Gtk2::Label;
	$label->set_text("Group: ");
	$table->attach($label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$combo = Gtk2::ComboBox->new_text;
	foreach ($mime{ident $self}->get_mimetype_groups) { $combo->append_text($_) }
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
		$mime{ident $self}->add_mimetype($type);
		$self->refresh_types;
	}

	$dialog->destroy;
}

sub get_selected_type {
	my ($self) = @_;
	my $iter   = $types_treeview{ident $self}->get_selection->get_selected;

	return undef if (! defined $iter);

	my $type = $types_model{ident $self}->get($iter,2);
	return (wantarray) ? ($iter,$type) : $type;
}

sub get_selected_command {
	my ($self) = @_;
	my $iter   = $commands_treeview{ident $self}->get_selection->get_selected;
	
	return undef if (! defined $iter);

	my $command = $commands_model{ident $self}->get($iter,0);
	return (wantarray) ? ($iter,$command) : $command;
}

sub refresh_types {
	my ($self) = @_;
	my $groups = {};

	$types_model{ident $self}->clear;

	foreach my $mimetype (sort $mime{ident $self}->get_mimetypes) {
		next if ($mimetype eq 'application/default');

		my ($group,$type) = split "/", $mimetype;
		
		$groups->{$group} ||= $types_model{ident $self}->insert_with_values(undef, -1,
			1, $group
		);

		my $icon   = $mime{ident $self}->get_icon($mimetype);
		my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($icon);

		$types_model{ident $self}->insert_with_values($groups->{$group}, -1,
			0, $pixbuf,
			1, $type,
			2, $mimetype
		);
	}
}

sub refresh_commands {
	my ($self,$type) = @_;
	$commands_model{ident $self}->clear;

	foreach ($mime{ident $self}->get_commands($type)) {
		$commands_model{ident $self}->insert_with_values(-1, 0, $_);
	}
}

sub set_commands {
	my ($self)   = @_;
	my $type     = $self->get_selected_type;
	my @commands = ();

	return if (! defined $type);

	$commands_model{ident $self}->foreach(sub {
		my ($model,$path,$iter) = @_;

		my $cmd = $model->get($iter, 0);
		push @commands, $cmd;
		return 0;
	});

	$mime{ident $self}->set_commands($type,\@commands);
};

1;
