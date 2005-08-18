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
use Class::Std::Utils;

use strict;
use warnings;

use YAML qw(LoadFile DumpFile Dump);

use Filer;
use Filer::Constants;

use enum qw(ICON COMMANDS);

my $default_mimetypes = {
	'application/default'			=> [ "$main::libpath/icons/default.png",			[] ],
	'application/ogg'			=> [ "$main::libpath/icons/mimetypes/audio.png",		[] ],
	'application/pdf'			=> [ "$main::libpath/icons/mimetypes/pdf.png",			[] ],
	'application/postscript'		=> [ "$main::libpath/icons/mimetypes/postscript.png",		[] ],
	'application/x-bzip-compressed-tar'	=> [ "$main::libpath/icons/mimetypes/bz2.png",			[] ],
	'application/x-compressed-tar'		=> [ "$main::libpath/icons/mimetypes/tgz.png",			[] ],
	'application/x-deb'			=> [ "$main::libpath/icons/mimetypes/deb.png",			[] ],
	'application/x-executable'		=> [ "$main::libpath/icons/exec.png",				[] ],
	'application/x-object'			=> [ "$main::libpath/icons/mimetypes/source_o.png",		[] ],
	'application/x-perl'			=> [ "$main::libpath/icons/mimetypes/source_pl.png",		[] ],
	'application/x-shellscript'		=> [ "$main::libpath/icons/mimetypes/shellscript.png",		[] ],
	'application/x-trash'			=> [ "$main::libpath/icons/mimetypes/trash.png",		[] ],
	'application/zip'			=> [ "$main::libpath/icons/mimetypes/zip.png",			[] ],
	'audio/mpeg'				=> [ "$main::libpath/icons/mimetypes/audio.png",		[] ],
	'audio/x-mp3'				=> [ "$main::libpath/icons/mimetypes/audio.png",		[] ],
	'audio/x-mpegurl'			=> [ "$main::libpath/icons/mimetypes/sound.png",		[] ],
	'audio/x-pn-realaudio'			=> [ "$main::libpath/icons/mimetypes/real_doc.png",		[] ],
	'audio/x-wav'				=> [ "$main::libpath/icons/mimetypes/sound.png",		[] ],
	'image/gif'				=> [ "$main::libpath/icons/mimetypes/images.png",		[] ],
	'image/jpeg'				=> [ "$main::libpath/icons/mimetypes/images.png",		[] ],
	'image/png'				=> [ "$main::libpath/icons/mimetypes/images.png",		[] ],
	'image/svg+xml'				=> [ "$main::libpath/icons/mimetypes/vectorgfx.png",		[] ],
	'inode/blockdevice'			=> [ "$main::libpath/icons/blockdevice.png",			[] ],
	'inode/chardevice'			=> [ "$main::libpath/icons/chardevice.png",			[] ],
	'inode/directory'			=> [ "$main::libpath/icons/folder.png",				[] ],
	'inode/fifo'				=> [ "$main::libpath/icons/pipe.png",				[] ],
	'inode/socket'				=> [ "$main::libpath/icons/socket.png",				[] ],
	'inode/symlink'				=> [ "$main::libpath/icons/symlink.png",			[] ],
	'text/html'				=> [ "$main::libpath/icons/mimetypes/html.png",			[] ],
	'text/plain'				=> [ "$main::libpath/icons/mimetypes/wordprocessing.png",	[] ],
	'text/x-c++src'				=> [ "$main::libpath/icons/mimetypes/source_cpp.png",		[] ],
	'text/x-chdr'				=> [ "$main::libpath/icons/mimetypes/source_h.png",		[] ],
	'text/x-csrc'				=> [ "$main::libpath/icons/mimetypes/source_c.png",		[] ],
	'text/x-log'				=> [ "$main::libpath/icons/mimetypes/log.png",			[] ],
	'text/x-makefile'			=> [ "$main::libpath/icons/mimetypes/make.png",			[] ],
	'text/x-readme'				=> [ "$main::libpath/icons/mimetypes/readme.png",		[] ],
	'text/x-uri'				=> [ "$main::libpath/icons/mimetypes/html.png",			[] ],
	'text/xml'				=> [ "$main::libpath/icons/mimetypes/html.png",			[] ],
	'video/mpeg'				=> [ "$main::libpath/icons/mimetypes/video.png",		[] ],
	'video/quicktime'			=> [ "$main::libpath/icons/mimetypes/quicktime.png",		[] ],
	'video/x-ms-wmv'			=> [ "$main::libpath/icons/mimetypes/video.png",		[] ],
	'video/x-msvideo'			=> [ "$main::libpath/icons/mimetypes/video.png",		[] ],
};

# attributes;
my %filer;
my %mime;
my %mime_file;

sub new {
	my ($class,$filer) = @_;
	my $self = bless anon_scalar(), $class;
	$filer{ident $self} = $filer;
	$mime_file{ident $self} = Filer::Tools->catpath(File::BaseDir->new->xdg_config_home, "filer", "mime.yml");

	if (! -e $mime_file{ident $self}) {
		$mime{ident $self} = $default_mimetypes;
	} else {
		$mime{ident $self} = LoadFile($mime_file{ident $self});
	}

	foreach (keys %{$mime{ident $self}}) {
		if (! -e $mime{ident $self}->{$_}->[ICON]) {
			if (-e $default_mimetypes->{$_}->[ICON]) {
				$mime{ident $self}->{$_}->[ICON] = $default_mimetypes->{$_}->[ICON];
			} else {
				$mime{ident $self}->{$_}->[ICON] = $default_mimetypes->{'application/default'}->[ICON];
			}
		}
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	DumpFile($mime_file{ident $self}, $mime{ident $self});

	delete $filer{ident $self};
	delete $mime{ident $self};
	delete $mime_file{ident $self};
}

sub get_mimetypes {
	my ($self) = @_;
	return keys %{$mime{ident $self}};
}

sub get_mimetype_groups {
	my ($self) = @_;
	my %groups = ();

	foreach ($self->get_mimetypes) {
		my ($group) = split "/", $_;
		$groups{$group}++;
	}

	return sort keys %groups;
}

sub add_mimetype {
	my ($self,$type) = @_;
	$mime{ident $self}->{$type} = [ $mime{ident $self}->{'application/default'}->[ICON], [] ];
}

sub delete_mimetype {
	my ($self,$type) = @_;
	delete $mime{ident $self}->{$type};
}

sub get_icon {
	my ($self,$type) = @_;
	return $mime{ident $self}->{$type}->[ICON];
}

sub get_icons {
	my ($self) = @_;
	my %icons = map { $_ => $self->get_icon($_) } $self->get_mimetypes;
	return \%icons;
}

sub set_icon {
	my ($self,$type,$icon) = @_;
	$mime{ident $self}->{$type}->[ICON] = $icon;
}

sub get_commands {
	my ($self,$type) = @_;
	return @{$mime{ident $self}->{$type}->[COMMANDS]};
}

sub set_commands {
	my ($self,$type,$commands) = @_;
	$mime{ident $self}->{$type}->[COMMANDS] = $commands;
}

sub get_default_command {
	my ($self,$type) = @_;

	if (wantarray) {
		return split /\s+/, $mime{ident $self}->{$type}->[COMMANDS]->[0];
	} else {
		return $mime{ident $self}->{$type}->[COMMANDS]->[0];
	}
}

sub set_default_command {
	my ($self,$type,$command) = @_;
	$mime{ident $self}->{$type}->[COMMANDS]->[0] = $command;
}

sub set_icon_dialog {
	my ($self,$type) = @_;
	my ($dialog,$table,$frame,$label,$type_label,$icon_image,$icon_entry,$icon_browse_button);
	my ($button,$alignment,$hbox);

	$dialog = new Gtk2::Dialog(
		"Set Icon",
		undef,
		'modal',
		'gtk-close' => 'close'
	);

	$dialog->set_has_separator(1);
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');

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
	$icon_image->set_from_pixbuf(Filer::Tools->intelligent_scale(Gtk2::Gdk::Pixbuf->new_from_file($self->get_icon($type)),50));
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

	$frame = new Gtk2::Frame("Preview");
	my $preview = new Gtk2::Image;
	$frame->add($preview);
	$frame->show_all;

	my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($self->get_icon($type));
	$preview->set_from_pixbuf(Filer::Tools->intelligent_scale($pixbuf,100));

	$icon_browse_button = Gtk2::FileChooserButton->new("Select Icon", 'GTK_FILE_CHOOSER_ACTION_OPEN');
	$icon_browse_button->set_use_preview_label(0);
	$icon_browse_button->set_preview_widget($frame);
	$icon_browse_button->set_preview_widget_active(1);

	my $filter = new Gtk2::FileFilter;
	$filter->add_pixbuf_formats;
	$icon_browse_button->set_filter($filter);

	$icon_browse_button->signal_connect("update-preview", sub {
		my ($w,$preview) = @_;
		my $filename = $w->get_preview_filename;

		return if (-d $filename);

		my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($filename);
		$preview->set_from_pixbuf(Filer::Tools->intelligent_scale($pixbuf,100));
		$icon_image->set_from_pixbuf($pixbuf);
	}, $preview);

	$icon_browse_button->set_filename($self->get_icon($type));
 	$table->attach($icon_browse_button, 2, 3, 1, 2, [ "expand","fill" ], [], 0, 0);

	$dialog->show_all;

	if ($dialog->run eq 'close') {
		$self->set_icon($type, $icon_browse_button->get_filename);
	}

	$dialog->destroy;
}

sub file_association_dialog {
	my ($self) = @_;
	new Filer::FileAssociationDialog($self);
}

sub run_dialog {
	my ($self,$fileinfo) = @_;
	my $type = $fileinfo->get_mimetype;
	my ($dialog,$table,$label,$button,$type_label,$cmd_browse_button,$remember_checkbutton,$run_terminal_checkbutton,$command_combo);

	$dialog = new Gtk2::Dialog(
		"Open With",
		undef,
		'modal',
		'gtk-close' => 'close'
	);

	$dialog->set_has_separator(1);
	$dialog->set_position('center');

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
	$command_combo->set_active(0);
	$table->attach($command_combo, 1, 2, 1, 2, [ "expand","fill" ], [], 0, 0);

	$cmd_browse_button = new Gtk2::Button;
	$cmd_browse_button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
	$cmd_browse_button->signal_connect("clicked", sub {
		my $fs = new Gtk2::FileChooserDialog(
			"Select Command",
			undef,
			'GTK_FILE_CHOOSER_ACTION_OPEN',
			'gtk-cancel' => 'cancel',
			'gtk-ok' => 'ok'
		);

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
		my $file = $fileinfo->get_path;

		if ($remember_checkbutton->get_active) {
			$self->set_default_command($type,$command);
		}

		if (! $run_terminal_checkbutton->get_active) {
			my @c = split /\s+/, $command;
			Filer::Tools->start_program(@c, $file);
		} else {
			my $term = $filer{ident $self}->get_config->get_option("Terminal");
			my @t = split /\s+/, $term;
			my @c = split /\s+/, $command;
			Filer::Tools->start_program(@t, "-x", @c, $file);
		}
	}

	$dialog->destroy;
}

1;
