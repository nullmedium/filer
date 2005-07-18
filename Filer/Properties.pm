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

package Filer::Properties;

use Filer::Constants;

use strict;
use warnings;

use constant S_IFMT  => 00170000;
use constant S_IFSOCK => 0140000;
use constant S_IFLNK => 0120000;
use constant S_IFREG => 0100000;
use constant S_IFBLK => 0060000;
use constant S_IFDIR => 0040000;
use constant S_IFCHR => 0020000;
use constant S_IFIFO => 0010000;
use constant S_ISUID => 0004000;
use constant S_ISGID => 0002000;
use constant S_ISVTX => 0001000;

use constant S_IRWXU => 00700;
use constant S_IRUSR => 00400;
use constant S_IWUSR => 00200;
use constant S_IXUSR => 00100;

use constant S_IRWXG => 00070;
use constant S_IRGRP => 00040;
use constant S_IWGRP => 00020;
use constant S_IXGRP => 00010;

use constant S_IRWXO => 00007;
use constant S_IROTH => 00004;
use constant S_IWOTH => 00002;
use constant S_IXOTH => 00001;

sub set_properties_dialog {
	my ($filer) = pop;
	my ($dialog,$table,$label,$checkbutton,$entry);
	my ($frame,$type_label,$icon_image,$icon_entry,$icon_browse_button);
	my ($button,$alignment,$hbox,$vbox);

	my $owner_combo;
	my $group_combo;

	my $mode = 0;
	my $properties_mode = 0;
	my $owner_mode = 0;
	my $group_mode = 0;
	my $other_mode = 0;

	my @stat = ();
	my $owner = "";
	my $group = "";
	my $multiple = 0;
	
	my $fileinfo;
	my $mime = new Filer::Mime($filer); 
	my $type;

	if ($filer->{active_pane}->count_items == 1) {
		$fileinfo = $filer->{active_pane}->get_fileinfo->[0];
		@stat = @{$fileinfo->get_stat};
		$owner = $fileinfo->get_uid;
		$group = $fileinfo->get_gid;
		$type = $fileinfo->get_mimetype;
	} else {
		$multiple = 1;
	}

	my @users = sort split /\n/, `cat /etc/passwd | cut -f 1 -d :`;
	my @groups = sort split /\n/, `cat /etc/group | cut -f 1 -d :`;

	my $mode_clicked = sub {
		my ($w,$mode_ref,$x) = @_;
		${$mode_ref} += ($w->get_active) ? $x : -$x;
	};

	$dialog = new Gtk2::Dialog("Set File Properties", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->vbox->set_spacing(10);

	if (!$multiple) {
		# Filename and Size

		$table = new Gtk2::Table(2,2);
		$table->set_homogeneous(0);
		$table->set_col_spacings(5);
		$table->set_row_spacings(5);
		$dialog->vbox->pack_start($table,1,1,5);

		$label = new Gtk2::Label("<b>Filename</b>");
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 0, 1, 0, 1, [ "fill" ], [ ], 0, 0);

		$label = new Gtk2::Label("<b>Size</b>");
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 0, 1, 1, 2, [ "fill" ], [ ], 0, 0);

		$label = new Gtk2::Label($fileinfo->get_path);
		$label->set_alignment(0.0,0.0);
		$label->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
		$table->attach($label, 1, 2, 0, 1, [ "fill", "expand" ], [ ], 0, 0);

		$label = new Gtk2::Label($fileinfo->get_size);
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 1, 2, 1, 2, [ "fill" ], [ ], 0, 0);

		# Icon

		$frame = new Gtk2::Frame("<b>Mimetype Icon</b>");
		$frame->get_label_widget->set_use_markup(1); 
		$frame->set_label_align(0.0,0.0);
		$frame->set_shadow_type('none');
		$dialog->vbox->pack_start($frame,0,0,0);

		$table = new Gtk2::Table(2,4);
		$table->set_homogeneous(0);
		$table->set_col_spacings(5);
		$table->set_row_spacings(1);
		$frame->add($table);

		$frame = new Gtk2::Frame;
		$frame->set_size_request(50, 50);
		$frame->set_shadow_type('out');
		$table->attach($frame, 0, 1, 0, 2, [], [], 0, 0);

		$icon_image = new Gtk2::Image;
		$icon_image->set_from_pixbuf(Filer::Tools->intelligent_scale(Gtk2::Gdk::Pixbuf->new_from_file($mime->get_icon($type)),50));
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
		$icon_entry->set_text($mime->get_icon($type));
		$table->attach($icon_entry, 2, 3, 1, 2, [ "expand","fill" ], [], 0, 0);

		$icon_browse_button = new Gtk2::Button;
		$icon_browse_button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
		$icon_browse_button->signal_connect("clicked", sub {
			my $fs = Filer::Dialog->preview_file_selection;
			$fs->set_filename($mime->get_icon($type));

			if ($fs->run eq 'ok') {
				my $mimeicon = $fs->get_filename;
				my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($mimeicon) || return;

				$icon_entry->set_text($mimeicon);
				$icon_image->set_from_pixbuf(Filer::Tools->intelligent_scale($pixbuf,50));
				$mime->set_icon($type, $mimeicon);
			}

			$fs->destroy;
		});
		$table->attach($icon_browse_button, 3, 4, 1, 2, [ "fill" ], [], 0, 0);
	} else {
		$label = new Gtk2::Label("<b>Set permissions for multiple files</b>");
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$dialog->vbox->pack_start($label,0,0,5);
	}

	# Properties

	$frame = new Gtk2::Frame("<b>Properties</b>");
	$frame->get_label_widget->set_use_markup(1); 
	$frame->set_label_align(0.0,0.0);
	$frame->set_shadow_type('none');
	$dialog->vbox->pack_start($frame,0,0,0);

	$table = new Gtk2::Table(4,4);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$frame->add($table);
	
	$label = new Gtk2::Label("<b>Owner</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 1, 2, 0, 1, [ "fill" ], [], 0, 0);

	$label = new Gtk2::Label("<b>Group</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 2, 3, 0, 1, [ "fill" ], [], 0, 0);

	$label = new Gtk2::Label("<b>Other</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 3, 4, 0, 1, [ "fill" ], [], 0, 0);

	# Properties

	$checkbutton = new Gtk2::CheckButton("Set UID");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$properties_mode,4);
	});
	$checkbutton->set_active(S_ISUID & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Set GID");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$properties_mode,2);
	});
	$checkbutton->set_active(S_ISGID & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 0, 1, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Sticky Bit");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$properties_mode,1);
	});
	$checkbutton->set_active(S_ISVTX & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 0, 1, 3, 4, [ "fill" ], [], 0, 0);

	# Owner

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$owner_mode,4);
	});
	$checkbutton->set_active(S_IRUSR & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$owner_mode,2);
	});
	$checkbutton->set_active(S_IWUSR & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 1, 2, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$owner_mode,1);
	});
	$checkbutton->set_active(S_IXUSR & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 1, 2, 3, 4, [ "fill" ], [], 0, 0);

	# Group

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$group_mode,4);
	});
	$checkbutton->set_active(S_IRGRP & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$group_mode,2);
	});
	$checkbutton->set_active(S_IWGRP & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 2, 3, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$group_mode,1);
	});
	$checkbutton->set_active(S_IXGRP & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 2, 3, 3, 4, [ "fill" ], [], 0, 0);

	# Other

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$other_mode,4);
	});
	$checkbutton->set_active(S_IROTH & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 3, 4, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$other_mode,2);
	});
	$checkbutton->set_active(S_IWOTH & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 3, 4, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$other_mode,1);
	});
	$checkbutton->set_active(S_IXOTH & $stat[2]) if (!$multiple);
	$table->attach($checkbutton, 3, 4, 3, 4, [ "fill" ], [], 0, 0);

	$frame = new Gtk2::Frame("<b>Owner and Group</b>");
	$frame->get_label_widget->set_use_markup(1); 
	$frame->set_label_align(0.0,0.0);
	$frame->set_shadow_type('none');
	$dialog->vbox->pack_start($frame,0,0,0);

	$vbox = new Gtk2::VBox(0,0);
	$frame->add($vbox);

	my ($pos,$i);
	$pos = 0; $i = 0;

	$owner_combo = Gtk2::ComboBox->new_text;
	foreach (@users) { $owner_combo->append_text($_); $pos = $i if ($_ eq $owner); $i++;}
	$owner_combo->set_active($pos);
	$owner_combo->set_sensitive(0) if ($ENV{USER} ne 'root');
	$vbox->pack_start($owner_combo, 1, 1, 0);

	$pos = 0; $i = 0;
	$group_combo = Gtk2::ComboBox->new_text;
	foreach (@groups) { $group_combo->append_text($_); $pos = $i if ($_ eq $group); $i++; }
	$group_combo->set_active($pos);
	$vbox->pack_start($group_combo, 1, 1, 0);

	$dialog->show_all;
	my $r = $dialog->run;

	if ($r eq 'ok') {
		my @files = map { $_->get_path; } @{$filer->{active_pane}->get_fileinfo};
		my $mode = oct(($properties_mode * 1000) + ($owner_mode * 100) +  ($group_mode * 10) + ($other_mode));

		my $uid = getpwnam($owner_combo->get_active_text);
		my $gid = getgrnam($group_combo->get_active_text);

		chmod($mode, @files) || return Filer::Dialog->msgbox_error("Error: $!");
		chown($uid, $gid, @files) || return Filer::Dialog->msgbox_error("Error: $!");

		$filer->refresh_cb;
	}

	$dialog->destroy;
}

1;
