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

use Filer::Constants;
use Filer::Stat qw(:mode_t);

sub set_properties_dialog {
	my ($filer)     = pop;
	my $active_pane = $filer->get_active_pane;

	my ($dialog,$table,$label,$checkbutton,$entry);
	my ($frame,$type_label,$icon_image,$icon_entry,$icon_browse_button);
	my ($button,$alignment,$hbox,$vbox);

	my $owner_combo;
	my $group_combo;

	my $properties_mode = 0;
	my $owner_mode      = 0;
	my $group_mode      = 0;
	my $other_mode      = 0;

	my $fileinfo;
	my $owner    = "";
	my $group    = "";
	my $multiple = 0;

	if ($active_pane->count_items == 1) {
		$fileinfo = $active_pane->get_fileinfo_list->[0];
		$owner = $fileinfo->get_uid;
		$group = $fileinfo->get_gid;
	} else {
		$multiple = 1;
	}

	my @users = ();
	my @groups = ();

	open (my $passwd_h, "/etc/passwd") || die "/etc/passwd: $!";
	while (<$passwd_h>) {
		chomp;
		my ($user) = split ":";
		push @users, $user;
	}
	close($passwd_h) || die "/etc/group: $!";

	open (my $group_h, "/etc/group") || die "/etc/group: $!";
	while (<$group_h>) {
		chomp;
		my ($group) = split ":";
		push @groups, $group;
	}
	close($group_h) || die "/etc/group: $!";

	my $mode_clicked = sub {
		my ($w,$mode_ref,$x) = @_;
		${$mode_ref} += ($w->get_active) ? $x : -$x;
	};

	$dialog = new Gtk2::Dialog(
		"Set File Properties",
		undef,
		'modal',
		'gtk-cancel' => 'cancel',
		'gtk-ok' => 'ok'
	);

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

		$label = new Gtk2::Label($fileinfo->get_size . " (" . $fileinfo->get_raw_size . " Bytes)");
		$label->set_alignment(0.0,0.0);
		$table->attach($label, 1, 2, 1, 2, [ "fill" ], [ ], 0, 0);
 	}

	# Permissions

	$frame = new Gtk2::Frame("<b>Permissions</b>");
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
		$mode_clicked->($w,\$properties_mode,4);
	});
	$checkbutton->set_active($S_ISUID & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Set GID");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$properties_mode,2);
	});
	$checkbutton->set_active($S_ISGID & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 0, 1, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Sticky Bit");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$properties_mode,1);
	});
	$checkbutton->set_active($S_ISVTX & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 0, 1, 3, 4, [ "fill" ], [], 0, 0);

	# Owner

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$owner_mode,4);
	});
	$checkbutton->set_active($S_IRUSR & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$owner_mode,2);
	});
	$checkbutton->set_active($S_IWUSR & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 1, 2, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$owner_mode,1);
	});
	$checkbutton->set_active($S_IXUSR & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 1, 2, 3, 4, [ "fill" ], [], 0, 0);

	# Group

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$group_mode,4);
	});
	$checkbutton->set_active($S_IRGRP & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$group_mode,2);
	});
	$checkbutton->set_active($S_IWGRP & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 2, 3, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$group_mode,1);
	});
	$checkbutton->set_active($S_IXGRP & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 2, 3, 3, 4, [ "fill" ], [], 0, 0);

	# Other

	$checkbutton = new Gtk2::CheckButton("Read");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$other_mode,4);
	});
	$checkbutton->set_active($S_IROTH & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 3, 4, 1, 2, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Write");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$other_mode,2);
	});
	$checkbutton->set_active($S_IWOTH & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 3, 4, 2, 3, [ "fill" ], [], 0, 0);

	$checkbutton = new Gtk2::CheckButton("Execute");
	$checkbutton->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$mode_clicked->($w,\$other_mode,1);
	});
	$checkbutton->set_active($S_IXOTH & $fileinfo->get_raw_mode && !$multiple);
	$table->attach($checkbutton, 3, 4, 3, 4, [ "fill" ], [], 0, 0);

	$frame = new Gtk2::Frame("<b>Owner and Group</b>");
	$frame->get_label_widget->set_use_markup(1);
	$frame->set_label_align(0.0,0.0);
	$frame->set_shadow_type('none');
	$dialog->vbox->pack_start($frame,0,0,0);

	$vbox = new Gtk2::VBox(0,0);
	$frame->add($vbox);

	$owner_combo = Gtk2::ComboBox->new_text;
	$owner_combo->set_popdown_strings(sort @users);
	$owner_combo->insert_text(0, $owner);
	$owner_combo->set_active(0);
	$owner_combo->set_sensitive(($ENV{USER} eq 'root') ? 1 : 0);
	$vbox->pack_start($owner_combo, 1, 1, 0);

	$group_combo = Gtk2::ComboBox->new_text;
	$group_combo->set_popdown_strings(sort @groups);
	$group_combo->insert_text(0, $group);
	$group_combo->set_active(0);
	$vbox->pack_start($group_combo, 1, 1, 0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my @files = @{$active_pane->get_item_list};
		my $mode  = oct(($properties_mode * 1000) + ($owner_mode * 100) +  ($group_mode * 10) + ($other_mode));
		my $uid   = getpwnam($owner_combo->get_active_text);
		my $gid   = getgrnam($group_combo->get_active_text);

		eval {
			package Filer::Properties;
			chown($uid, $gid, @files);
			chmod($mode, @files);
		};

		if ($@) {
			Filer::Dialog->msgbox_error("Error: $@: $!");
			last;
		}

		$filer->refresh_cb;
	}

	$dialog->destroy;
}

1;
