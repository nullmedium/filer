#     Copyright (C) 2004 Jens Luedicke <jens@irs-net.com>
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
use constant S_IFLNK =>  0120000;
use constant S_IFREG =>  0100000;
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
		if ($w->get_active) {
			${$mode_ref} += $x;
		} else {
			${$mode_ref} -= $x;
		}
	};

	$dialog = new Gtk2::Dialog("Set File Properties", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);
	
	$table = new Gtk2::Table(4,4);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

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

	$table = new Gtk2::Table(2,2);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

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

1;
