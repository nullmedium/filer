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

package Filer::Mime;

# use strict;
# use warnings;

use Filer;
use Filer::Constants;
our @ISA = qw(Filer);

use constant ICON => 0;
use constant COMMANDS => 1;
use constant MIME => 2;

our ($default_mimetypes);

$default_mimetypes = {
	'default'					=> [ "$main::libpath/icons/default.png",			[] ],
	'application/ogg'				=> [ "$main::libpath/icons/mimetypes/audio.png",		[] ],
	'application/pdf'				=> [ "$main::libpath/icons/mimetypes/pdf.png",			[] ],
	'application/postscript'			=> [ "$main::libpath/icons/mimetypes/postscript.png",		[] ],
	'application/x-bzip-compressed-tar'		=> [ "$main::libpath/icons/mimetypes/bz2.png",			[] ],
	'application/x-compressed-tar'			=> [ "$main::libpath/icons/mimetypes/tgz.png",			[] ],
	'application/x-deb'				=> [ "$main::libpath/icons/mimetypes/deb.png",			[] ],
	'application/x-executable'			=> [ "$main::libpath/icons/exec.png",				[] ],
	'application/x-object'				=> [ "$main::libpath/icons/mimetypes/source_o.png",		[] ],
	'application/x-perl'				=> [ "$main::libpath/icons/mimetypes/source_pl.png",		[] ],
	'application/x-shellscript'			=> [ "$main::libpath/icons/mimetypes/shellscript.png",		[] ],
	'application/x-trash'				=> [ "$main::libpath/icons/mimetypes/trash.png",		[] ],
	'application/zip'				=> [ "$main::libpath/icons/mimetypes/zip.png",			[] ],
	'audio/mpeg'					=> [ "$main::libpath/icons/mimetypes/audio.png",		[] ],
	'audio/x-mp3'					=> [ "$main::libpath/icons/mimetypes/audio.png",		[] ],
	'audio/x-mpegurl'				=> [ "$main::libpath/icons/mimetypes/sound.png",		[] ],
	'audio/x-pn-realaudio'				=> [ "$main::libpath/icons/mimetypes/real_doc.png",		[] ],
	'audio/x-wav'					=> [ "$main::libpath/icons/mimetypes/sound.png",		[] ],
	'image/gif	'				=> [ "$main::libpath/icons/mimetypes/images.png",		[] ],
	'image/jpeg'					=> [ "$main::libpath/icons/mimetypes/images.png",		[] ],
	'image/png'					=> [ "$main::libpath/icons/mimetypes/images.png",		[] ],
	'image/svg+xml'					=> [ "$main::libpath/icons/mimetypes/vectorgfx.png",		[] ],
	'inode/blockdevice'				=> [ "$main::libpath/icons/blockdevice.png",			[] ],
	'inode/chardevice'				=> [ "$main::libpath/icons/chardevice.png",			[] ],
	'inode/directory'				=> [ "$main::libpath/icons/folder.png",				[] ],
	'inode/fifo'					=> [ "$main::libpath/icons/pipe.png",				[] ],
	'inode/socket'					=> [ "$main::libpath/icons/socket.png",				[] ],
	'inode/symlink'					=> [ "$main::libpath/icons/symlink.png",			[] ],
	'text/html'					=> [ "$main::libpath/icons/mimetypes/html.png",			[] ],
	'text/plain'					=> [ "$main::libpath/icons/mimetypes/wordprocessing.png",	[] ],
	'text/x-c++src'					=> [ "$main::libpath/icons/mimetypes/source_cpp.png",		[] ],
	'text/x-chdr'					=> [ "$main::libpath/icons/mimetypes/source_h.png",		[] ],
	'text/x-csrc'					=> [ "$main::libpath/icons/mimetypes/source_c.png",		[] ],
	'text/x-log'					=> [ "$main::libpath/icons/mimetypes/log.png",			[] ],
	'text/x-makefile'				=> [ "$main::libpath/icons/mimetypes/make.png",			[] ],
	'text/x-readme'					=> [ "$main::libpath/icons/mimetypes/readme.png",		[] ],
	'text/x-uri'					=> [ "$main::libpath/icons/mimetypes/html.png",			[] ],
	'text/xml'					=> [ "$main::libpath/icons/mimetypes/html.png",			[] ],
	'video/mpeg'					=> [ "$main::libpath/icons/mimetypes/video.png",		[] ],
	'video/quicktime'				=> [ "$main::libpath/icons/mimetypes/quicktime.png",		[] ],
	'video/x-ms-wmv'				=> [ "$main::libpath/icons/mimetypes/video.png",		[] ],
	'video/x-msvideo'				=> [ "$main::libpath/icons/mimetypes/video.png",		[] ],
};

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;
	$self->{cfg_home} = File::Spec->catfile((new File::BaseDir)->xdg_config_home, "/filer");
	$self->{mime_store} = File::Spec->catfile(File::Spec->splitdir($self->{cfg_home}), "mime");

	if (! -e $self->{mime_store}) {
		$self->store($default_mimetypes);
	}

	return $self;
}

sub store {
	my ($self,$mime) = @_;
	Storable::store($mime, $self->{mime_store});
}

sub get {
	my ($self) = @_;
	return Storable::retrieve($self->{mime_store});
}

sub get_mimetypes {
	my ($self) = @_;
	my $mime = $self->get;

	return keys %{$mime};
}

sub add_mimetype {
	my ($self,$type) = @_;
	my $mime = $self->get;

	$mime->{$type} = [ "$main::libpath/icons/default.png", []];

	$self->store($mime);
}

sub delete_mimetype {
	my ($self,$type) = @_;
	my $mime = $self->get;

	delete $mime->{$type};

	$self->store($mime);
}

sub get_icon {
	my ($self,$type) = @_;
	my $mime = $self->get;

	if (defined $mime->{$type}->[ICON]) {
		return $mime->{$type}->[ICON];
	} else {
		if (defined $default_mimetypes->{$type}->[ICON]) {
			return $default_mimetypes->{$type}->[ICON];
		} else {
			return $default_mimetypes->{default}->[ICON];
		}
	}
}

sub get_icons {
	my ($self) = @_;
	my %icons = map { $_ => Filer::Tools->intelligent_scale(Gtk2::Gdk::Pixbuf->new_from_file($self->get_icon($_)), 22) } $self->get_mimetypes;
	return \%icons;
}

sub set_icon {
	my ($self,$type,$icon) = @_;
	my $mime = $self->get;
	$mime->{$type}->[ICON] = $icon;
	$self->store($mime);
}

sub get_commands {
	my ($self,$type) = @_;
	return @{$self->get->{$type}->[COMMANDS]};
}

sub set_commands {
	my ($self,$type,$commands) = @_;
	my $mime = $self->get;
	$mime->{$type}->[COMMANDS] = $commands;
	$self->store($mime);
}

sub get_default_command {
	my ($self,$type) = @_;
	return ($self->get_commands($type))[0];
}

sub set_default_command {
	my ($self,$type,$command) = @_;
	my $mime = $self->get;
	$mime->{$type}->[COMMANDS]->[0] = $command;
	$self->store($mime);
}

sub set_icon_dialog {
	my ($self,$type) = @_;
	my ($dialog,$table,$frame,$label,$type_label,$icon_image,$icon_entry,$icon_browse_button);
	my ($button,$alignment,$hbox);

	$dialog = new Gtk2::Dialog("Set Icon", undef, 'modal', 'gtk-close' => 'close');
	$dialog->set_has_separator(1);
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$table = new Gtk2::Table(2,4);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

	$frame = new Gtk2::Frame;
	$frame->set_size_request(50, 50);
	$frame->set_shadow_type('out');
	$table->attach($frame, 0, 1, 0, 2, [], [], 0, 0);

	$icon_image = new Gtk2::Image;
	$icon_image->set_from_pixbuf(&Filer::intelligent_scale(Gtk2::Gdk::Pixbuf->new_from_file($self->get_icon($type)),50));
	$icon_image->set_alignment(0.50,0.50);
	$frame->add($icon_image);

	$label = new Gtk2::Label;
	$label->set_justify('left');
	$label->set_text("Type: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 1, 2, 0, 1, [ "fill" ], [], 0, 0);

	$type_label = new Gtk2::Label;
	$type_label->set_justify('right');
	$type_label->set_text($type);
	$type_label->set_alignment(0.0,0.0);
	$table->attach($type_label, 2, 4, 0, 1, [ "expand","fill" ], [], 0, 0);

	$label = new Gtk2::Label;
	$label->set_justify('left');
	$label->set_text("Icon:");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

	$icon_entry = new Gtk2::Entry;
	$icon_entry->set_text($self->get_icon($type));
	$table->attach($icon_entry, 2, 3, 1, 2, [ "expand","fill" ], [], 0, 0);

	$icon_browse_button = new Gtk2::Button;
	$icon_browse_button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
	$icon_browse_button->signal_connect("clicked", sub {
		my $fs = Filer::Dialog->preview_file_selection;
		$fs->set_filename($self->get_icon($type));

		if ($fs->run eq 'ok') {
			my $mimeicon = $fs->get_filename;
			$icon_entry->set_text($mimeicon);
			$icon_image->set_from_pixbuf(&Filer::intelligent_scale(Gtk2::Gdk::Pixbuf->new_from_file($mimeicon),50));
		}

		$fs->destroy;
	});
	$table->attach($icon_browse_button, 3, 4, 1, 2, [ "fill" ], [], 0, 0);

	$dialog->show_all;

	if ($dialog->run eq 'close') {
		$self->set_icon($type, $icon_entry->get_text);
	}

	$dialog->destroy;
}

sub file_association_dialog {
	my ($dialog,$bbox,$hbox,$vbox,$sw,$treeview);
	my ($types_model,$commands_model,$selection);
	my ($cell,$col,$button);

	my $mime = new Filer::Mime;
	my $type = "";
	my $command = undef;
	my $command_iter = undef;

	my $refresh_types = sub {
		$types_model->clear;

		foreach (sort $mime->get_mimetypes) {
			next if ($_ eq 'default');
			$types_model->set($types_model->append, 0, Gtk2::Gdk::Pixbuf->new_from_file($mime->get_icon($_)), 1, $_);
		}
	};

	my $refresh_commands = sub {
		my ($type) = @_;
		$commands_model->clear;

		foreach ($mime->get_commands($type)) {
			$commands_model->set($commands_model->append, 0, $_);
		}
	};

	my $set_commands = sub {
		my @commands = ();

		$commands_model->foreach(sub {
			push @commands, $_[0]->get($_[2], 0);
			return 0;
		});

		$mime->set_commands($type,\@commands);
	};

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

	$types_model = new Gtk2::ListStore('Glib::Object','Glib::String');
	$treeview = Gtk2::TreeView->new_with_model($types_model);
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

	$selection = $treeview->get_selection;
	$selection->signal_connect("changed", sub {
		my ($selection) = @_;
		my $iter = $selection->get;
		if (defined $iter) {
			$type = $types_model->get($iter, 1);
			&{$refresh_commands}($type);
		}
			
	});
	$sw->add($treeview);

	$sw = new Gtk2::ScrolledWindow;
	$sw->set_policy('automatic','automatic');
	$sw->set_shadow_type('etched-in');
	$hbox->pack_start($sw,1,1,0);

	$commands_model = new Gtk2::ListStore('Glib::String');

	$treeview = Gtk2::TreeView->new_with_model($commands_model);
	$treeview->insert_column_with_attributes(0, "Application Preference Order", Gtk2::CellRendererText->new, text => 0);

	$selection = $treeview->get_selection;
	$selection->signal_connect("changed", sub {
		my ($selection) = @_;
		$command_iter = $selection->get;
		$command = undef;
		
		if (defined $command_iter) {
			$command = $commands_model->get($command_iter, 0);
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
			$commands_model->set($commands_model->append, 0, $fs->get_filename);
			&{$set_commands};
		}

		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-edit');
	$button->signal_connect("clicked", sub {
		return if (not defined $command_iter);

		my $fs = new Gtk2::FileChooserDialog("Select Command", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		$fs->set_filename($command);

		if ($fs->run eq 'ok') {
			$commands_model->set($command_iter, 0, $fs->get_filename);
			&{$set_commands};
		}
		$fs->destroy;
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		return if (not defined $command_iter);
		
		$commands_model->remove($command_iter);
		&{$set_commands};
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-up');
	$button->signal_connect("clicked", sub {
		my $treepath = $commands_model->get_path($command_iter);

		if ($treepath->prev) {
			$commands_model->swap($commands_model->get_iter($treepath),$command_iter);
			&{$set_commands};
		}
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-go-down');
	$button->signal_connect("clicked", sub {
		my $treepath = $commands_model->get_path($command_iter);
		$treepath->next;
	
		my $b = $commands_model->get_iter($treepath);

		if ($b) {
			$commands_model->swap($command_iter,$b);
			&{$set_commands};
		}
	});
	$bbox->add($button);

	$bbox = new Gtk2::HButtonBox;
	$bbox->set_layout_default('start');
	$bbox->set_spacing_default(5);
	$dialog->vbox->pack_start($bbox, 0,1,0);

	$button = Gtk2::Button->new_from_stock('gtk-add');
	$button->signal_connect("clicked", sub {
		my ($dialog,$hbox,$label,$entry);

		$dialog = new Gtk2::Dialog("Add mimetype", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		$dialog->set_position('center');
		$dialog->set_modal(1);

		$hbox = new Gtk2::HBox(0,0);
		$dialog->vbox->pack_start($hbox, 1,1,5);

		$label = new Gtk2::Label;
		$label->set_text("Mimetype: ");
		$hbox->pack_start($label, 1,1,2);

		$entry = new Gtk2::Entry;
		$entry->set_text("");
		$hbox->pack_start($entry, 1,1,0);

		$dialog->show_all;

		if ($dialog->run eq 'ok') {
			$mime->add_mimetype($entry->get_text);
		}

		$dialog->destroy;
		&{$refresh_types};
	});
	$bbox->add($button);

	$button = Gtk2::Button->new_from_stock('gtk-remove');
	$button->signal_connect("clicked", sub {
		$mime->delete_mimetype($type);
		&{$refresh_types};
	});
	$bbox->add($button);

	$button = Gtk2::Button->new("Set Icon");
	$button->signal_connect("clicked", sub {
		$mime->set_icon_dialog($type);
		&{$refresh_types};
	});
	$bbox->add($button);

	&{$refresh_types};

	$dialog->show_all;

	$dialog->run;
	$dialog->destroy;
}

sub run_dialog {
	my ($self,$fileinfo) = @_;
	my $type = $fileinfo->get_mimetype;
	my ($dialog,$table,$label,$button,$type_label,$cmd_browse_button,$remember_checkbutton,$run_terminal_checkbutton,$command_combo);

	$dialog = new Gtk2::Dialog("Open With", undef, 'modal', 'gtk-close' => 'close');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$table = new Gtk2::Table(3,3);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

	$label = new Gtk2::Label;
	$label->set_justify('left');
	$label->set_text("Type: ");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$type_label = new Gtk2::Label;
	$type_label->set_justify('left');
	$type_label->set_text($type);
	$type_label->set_alignment(0.0,0.0);
	$table->attach($type_label, 1, 3, 0, 1, [ "expand","fill" ], [], 0, 0);

	$label = new Gtk2::Label;
	$label->set_justify('left');
	$label->set_text("Command:");
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$command_combo = Gtk2::ComboBoxEntry->new_text;
	foreach ($self->get_commands($type)) { $command_combo->append_text($_) }
 	$table->attach($command_combo, 1, 2, 1, 2, [ "expand","fill" ], [], 0, 0);

	$cmd_browse_button = new Gtk2::Button;
	$cmd_browse_button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
	$cmd_browse_button->signal_connect("clicked", sub {
		my $fs = new Gtk2::FileChooserDialog("Select Command", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
		$fs->set_filename($command_combo->get_child->get_text);

		if ($fs->run eq 'ok') {
			$command_combo->get_child->set_text($fs->get_filename);
		}

		$fs->destroy;
	});
	$table->attach($cmd_browse_button, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$remember_checkbutton = new Gtk2::CheckButton("Remember application association for this type of file (sets default)");
	$dialog->vbox->pack_start($remember_checkbutton, 0,1,0);

	$run_terminal_checkbutton = new Gtk2::CheckButton("Run in Terminal");
	$dialog->vbox->pack_start($run_terminal_checkbutton, 0,1,0);

	$button = Filer::Dialog::mixed_button_new('gtk-ok',"_Run");
	$dialog->add_action_widget($button, 'ok');

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $command = $command_combo->get_active_text;
		my $file = $fileinfo->get_path_latin1;

		if ($remember_checkbutton->get_active) {
			$self->set_default_command($type, $command);
		}

		if ($run_terminal_checkbutton->get_active) {
			my $term = $config->get_option("Terminal");
			$command = "$term -x $command";
		}
		
		system("$command '$file' & exit");
	}

	$dialog->destroy;
}

1;
