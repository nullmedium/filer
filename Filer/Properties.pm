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
	my ($file) = pop;
	my ($dialog,$table,$label,$checkbutton,$entry);
	my ($frame,$type_label,$icon_image,$icon_entry,$icon_browse_button);
	my ($button,$alignment,$hbox);
	my $expander;

	my $owner_combo;
	my $group_combo;

	my $mode = 0;
	my $properties_mode = 0;
	my $owner_mode = 0;
	my $group_mode = 0;
	my $other_mode = 0;

	my @stat;
	my $owner;
	my $group;
	my $multiple = 0;

	my $type = File::MimeInfo::mimetype($file);
	my $mime = new Filer::Mime(); 

	if ($main::active_pane->count_selected_items == 1) {
		@stat = stat($file);
		$owner = getpwuid($stat[4]);
		$group = getgrgid($stat[5]);
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

	# Filename and Size

	if (!$multiple) {
		$table = new Gtk2::Table(2,2);
		$table->set_homogeneous(0);
		$table->set_col_spacings(5);
		$table->set_row_spacings(1);
		$dialog->vbox->pack_start($table,1,1,5);

		$label = new Gtk2::Label("<b>Filename</b>");
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 0, 1, 0, 1, [ "fill" ], [ ], 0, 0);

		$label = new Gtk2::Label("<b>Size</b>");
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 0, 1, 1, 2, [ "fill" ], [ ], 0, 0);

		$label = new Gtk2::Label($file);
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$label->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
		$table->attach($label, 1, 2, 0, 1, [ "fill", "expand" ], [ ], 0, 0);

		$label = new Gtk2::Label(Filer::FilePane::calculate_size($stat[7]));
		$label->set_use_markup(1);
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 1, 2, 1, 2, [ "fill" ], [ ], 0, 0);

		# Icon

		my $expander = new Gtk2::Expander("<b>Mimetype Icon</b>");
		$expander->signal_connect("activate", \&expander_callback);
			$expander->set_expanded(1);
		$expander->set_use_markup(1);
		$dialog->vbox->pack_start($expander,0,0,5);

		$table = new Gtk2::Table(2,4);
		$table->set_homogeneous(0);
		$table->set_col_spacings(5);
		$table->set_row_spacings(1);
		$expander->add($table);

		$frame = new Gtk2::Frame;
		$frame->set_size_request(50, 50);
		$frame->set_shadow_type('out');
		$table->attach($frame, 0, 1, 0, 2, [], [], 0, 0);

		$icon_image = new Gtk2::Image;
		$icon_image->set_from_file($mime->get_icon($type));
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
				$icon_image->set_from_pixbuf(&main::intelligent_scale($pixbuf,100));
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

	$expander = new Gtk2::Expander("<b>Properties</b>");
	$expander->signal_connect("activate", \&expander_callback);
	$expander->set_expanded(1);
	$expander->set_use_markup(1);
	$dialog->vbox->pack_start($expander,0,0,5);

	$table = new Gtk2::Table(4,4);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$expander->add($table);
	
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
	$checkbutton->set_active(S_ISUID & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Set GID");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$properties_mode,2);
	});
	$checkbutton->set_active(S_ISGID & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 0, 1, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Sticky Bit");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$properties_mode,1);
	});
	$checkbutton->set_active(S_ISVTX & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 0, 1, 3, 4, [ "fill" ], [], 0, 0);

	# Owner

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$owner_mode,4);
	});
	$checkbutton->set_active(S_IRUSR & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$owner_mode,2);
	});
	$checkbutton->set_active(S_IWUSR & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 1, 2, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$owner_mode,1);
	});
	$checkbutton->set_active(S_IXUSR & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 1, 2, 3, 4, [ "fill" ], [], 0, 0);

	# Group

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$group_mode,4);
	});
	$checkbutton->set_active(S_IRGRP & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$group_mode,2);
	});
	$checkbutton->set_active(S_IWGRP & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 2, 3, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$group_mode,1);
	});
	$checkbutton->set_active(S_IXGRP & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 2, 3, 3, 4, [ "fill" ], [], 0, 0);

	# Other

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$other_mode,4);
	});
	$checkbutton->set_active(S_IROTH & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 3, 4, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$other_mode,2);
	});
	$checkbutton->set_active(S_IWOTH & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 3, 4, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		&{$mode_clicked}($w,\$other_mode,1);
	});
	$checkbutton->set_active(S_IXOTH & $stat[2]) if ($multiple == 0);
	$table->attach($checkbutton, 3, 4, 3, 4, [ "fill" ], [], 0, 0);

	$expander = new Gtk2::Expander("<b>Owner and Group</b>");
	$expander->signal_connect("activate", \&expander_callback);
	$expander->set_expanded(1);
	$expander->set_use_markup(1);
	$dialog->vbox->pack_start($expander,0,0,5);

	$table = new Gtk2::Table(2,2);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$expander->add($table);

	$label = new Gtk2::Label("<b>Owner: </b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$label = new Gtk2::Label("<b>Group: </b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$owner_combo = new Gtk2::Combo;
	$owner_combo->set_popdown_strings(@users);
	$owner_combo->entry->set_text($owner);
	$owner_combo->set_sensitive(0) if ($ENV{USER} ne 'root');
	$table->attach($owner_combo, 1, 2, 0, 1, [ "fill" ], [], 0, 0);

	$group_combo = new Gtk2::Combo;
	$group_combo->set_popdown_strings(@groups);
	$group_combo->entry->set_text($group);
	$table->attach($group_combo, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

	$dialog->show_all;

	my $r = $dialog->run;

	if ($r eq 'ok') {
		foreach (@{$main::active_pane->get_selected_items}) {
			my @stat = stat($_);

			if ($ENV{USER} eq getpwuid($stat[4])) {
				my $mode = ($properties_mode * 1000) + ($owner_mode * 100) +  ($group_mode * 10) + ($other_mode * 1);
				my $owner = $owner_combo->entry->get_text;
				my $group = $group_combo->entry->get_text;

				system("chmod $mode '$_'");
				system("chown $owner:$group '$_'");
			} else {
				Filer::Dialog->msgbox_error("Error! $_: Operation not permitted");
			}
		}
	}

	$dialog->destroy;
}

sub expander_callback {
	my ($e) = @_;
	my $w = $e->parent->parent;

	$w->queue_resize();
}

1;
