#     Copyright (C) 2004-2010 Jens Luedicke <jens.luedicke@gmail.com>
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

package Filer::PropertiesDialog;
use base qw(Gtk2::Dialog);

use strict;
use warnings;

use Filer::Constants qw(:bool :mode_t);

sub new {
	my $class = shift;
	
	my $self = $class->SUPER::new(
		"Set File Properties",
		undef,
		'modal',
		'gtk-cancel' => 'cancel',
		'gtk-ok'     => 'ok'
	);
	$self = bless $self, $class;

	$self->{active_pane} = Filer::instance()->get_active_pane;

	my ($table,$frame,$label,$button,$vbox);

	$self->set_has_separator(1);
	$self->set_position('center');
	$self->vbox->set_spacing(10);

	# Filename and Size

	$table = new Gtk2::Table(2,2);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(5);
	$self->vbox->pack_start($table, $TRUE, $TRUE, 5);

	$label = new Gtk2::Label("<b>Filename</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 0, 1, [ "fill" ], [ ], 0, 0);

	$label = new Gtk2::Label("<b>Size</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 1, 2, [ "fill" ], [ ], 0, 0);

	$label = new Gtk2::Label("<b>Mimetype:</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 2, 3, [ "fill" ], [ ], 0, 0);

	$label = new Gtk2::Label("<b>Open with:</b>");
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$table->attach($label, 0, 1, 3, 4, [ "fill" ], [ ], 0, 0);

	$self->{path_label} = new Gtk2::Label;
	$self->{path_label}->set_alignment(0.0,0.0);
	$self->{path_label}->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
	$table->attach($self->{path_label}, 1, 2, 0, 1, [ "fill", "expand" ], [ ], 0, 0);

	$self->{size_label} = new Gtk2::Label;
	$self->{size_label}->set_alignment(0.0,0.0);
	$table->attach($self->{size_label}, 1, 2, 1, 2, [ "fill" ], [ ], 0, 0);

	$self->{mimetype_label} = new Gtk2::Label;
	$self->{mimetype_label}->set_alignment(0.0,0.0);
	$table->attach($self->{mimetype_label}, 1, 2, 2, 3, [ "fill" ], [ ], 0, 0);

	$self->{openw_label} = new Gtk2::Label;
	$self->{openw_label}->set_alignment(0.0,0.0);
	$table->attach($self->{openw_label}, 1, 2, 3, 4, [ "fill" ], [ ], 0, 0);

	$self->{openw_button} = new Gtk2::Button("Change");
	$self->{openw_button}->signal_connect(clicked => sub {
		Filer::Dialog->show_open_with_dialog($self->{fileinfo});
		$self->init;
	});
	$table->attach($self->{openw_button}, 2, 3, 3, 4, [ "fill" ], [ ], 0, 0);

	# Permissions

	$frame = new Gtk2::Frame("<b>Permissions</b>");
	$frame->get_label_widget->set_use_markup(1);
	$frame->set_label_align(0.0,0.0);
	$frame->set_shadow_type('none');
	$self->vbox->pack_start($frame, $FALSE, $FALSE, 0);

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

	$self->{uid_cb} = new Gtk2::CheckButton("Set UID");
	$self->{uid_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{properties_mode},4);
	});
	$table->attach($self->{uid_cb}, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$self->{gid_cb} = new Gtk2::CheckButton("Set GID");
	$self->{gid_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{properties_mode},2);
	});
	$table->attach($self->{gid_cb}, 0, 1, 2, 3, [ "fill" ], [], 0, 0);

	$self->{sbi_cb} = new Gtk2::CheckButton("Sticky Bit");
	$self->{sbi_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{properties_mode},1);
	});
	$table->attach($self->{sbi_cb}, 0, 1, 3, 4, [ "fill" ], [], 0, 0);

	# Owner

	$self->{own_r_cb} = new Gtk2::CheckButton("Read");
	$self->{own_r_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{owner_mode},4);
	});
	$table->attach($self->{own_r_cb}, 1, 2, 1, 2, [ "fill" ], [], 0, 0);

	$self->{own_w_cb} = new Gtk2::CheckButton("Write");
	$self->{own_w_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{owner_mode},2);
	});
	$table->attach($self->{own_w_cb}, 1, 2, 2, 3, [ "fill" ], [], 0, 0);

	$self->{own_x_cb} = new Gtk2::CheckButton("Execute");
	$self->{own_x_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{owner_mode},1);
	});
	$table->attach($self->{own_x_cb}, 1, 2, 3, 4, [ "fill" ], [], 0, 0);

	# Group

	$self->{grp_r_cb} = new Gtk2::CheckButton("Read");
	$self->{grp_r_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{group_mode},4);
	});
	$table->attach($self->{grp_r_cb}, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$self->{grp_w_cb} = new Gtk2::CheckButton("Write");
	$self->{grp_w_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{group_mode},2);
	});
	$table->attach($self->{grp_w_cb}, 2, 3, 2, 3, [ "fill" ], [], 0, 0);

	$self->{grp_x_cb} = new Gtk2::CheckButton("Execute");
	$self->{grp_x_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{group_mode},1);
	});
	$table->attach($self->{grp_x_cb}, 2, 3, 3, 4, [ "fill" ], [], 0, 0);

	# Other

	$self->{oth_r_cb} = new Gtk2::CheckButton("Read");
	$self->{oth_r_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{other_mode},4);
	});
	$table->attach($self->{oth_r_cb}, 3, 4, 1, 2, [ "fill" ], [], 0, 0);

	$self->{oth_w_cb} = new Gtk2::CheckButton("Write");
	$self->{oth_w_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{other_mode},2);
	});
	$table->attach($self->{oth_w_cb}, 3, 4, 2, 3, [ "fill" ], [], 0, 0);

	$self->{oth_x_cb} = new Gtk2::CheckButton("Execute");
	$self->{oth_x_cb}->signal_connect("clicked", sub {
		my ($w,$e) = @_;
		$self->mode_change($w,\$self->{other_mode},1);
	});
	$table->attach($self->{oth_x_cb}, 3, 4, 3, 4, [ "fill" ], [], 0, 0);

	$frame = new Gtk2::Frame("<b>Owner and Group</b>");
	$frame->get_label_widget->set_use_markup(1);
	$frame->set_label_align(0.0,0.0);
	$frame->set_shadow_type('none');
	$self->vbox->pack_start($frame, $FALSE, $FALSE, 0);

	$vbox = new Gtk2::VBox(0,0);
	$frame->add($vbox);

	$self->{owner_combo} = Gtk2::ComboBox->new_text;
	$vbox->pack_start($self->{owner_combo}, $TRUE, $TRUE, 0);

	$self->{group_combo} = Gtk2::ComboBox->new_text;
	$vbox->pack_start($self->{group_combo}, $TRUE, $TRUE, 0);

	$self->show_all;
	$self->init;

	if ($self->run eq 'ok') {
		$self->ok;
	}

	$self->destroy;
}

sub init {
	my ($self) = @_;

	$self->{fileinfo}    = $self->{active_pane}->get_fileinfo_list->[0];
	$self->{owner} = $self->{fileinfo}->get_uid;
	$self->{group} = $self->{fileinfo}->get_gid;

	my @users = ();
	my @groups = ();

	open (my $passwd_h, "/etc/passwd") || die "/etc/passwd: $!";
	while (<$passwd_h>) {
		chomp;
		next if (!$_);
		my ($user) = split ":";
		push @users, $user;
	}
	close($passwd_h) || die "/etc/group: $!";

	open (my $group_h, "/etc/group") || die "/etc/group: $!";
	while (<$group_h>) {
		chomp;
		next if (!$_);
		my ($group) = split ":";
		push @groups, $group;
	}
	close($group_h) || die "/etc/group: $!";
	
	my $mode = $self->{fileinfo}->get_raw_mode;

	$self->{uid_cb}->set_active($S_ISUID & $mode);
	$self->{gid_cb}->set_active($S_ISGID & $mode);
	$self->{sbi_cb}->set_active($S_ISVTX & $mode);

	$self->{own_r_cb}->set_active($S_IRUSR & $mode);
	$self->{own_w_cb}->set_active($S_IWUSR & $mode);
	$self->{own_x_cb}->set_active($S_IXUSR & $mode);

	$self->{grp_r_cb}->set_active($S_IRGRP & $mode);
	$self->{grp_w_cb}->set_active($S_IWGRP & $mode);
	$self->{grp_x_cb}->set_active($S_IXGRP & $mode);

	$self->{oth_r_cb}->set_active($S_IROTH & $mode);
	$self->{oth_w_cb}->set_active($S_IWOTH & $mode);
	$self->{oth_x_cb}->set_active($S_IXOTH & $mode);

	if ($self->{fileinfo}->is_dir) {
		$self->{own_x_cb}->set_label("Search");
		$self->{grp_x_cb}->set_label("Search");
		$self->{oth_x_cb}->set_label("Search");
	}

	$self->{owner_combo}->insert_text(0, $self->{owner});
	$self->{owner_combo}->append_text($_) for (sort @users);
	$self->{owner_combo}->set_sensitive(($ENV{USER} eq 'root') ? 1 : 0);
	$self->{owner_combo}->set_active(0);

	$self->{group_combo}->append_text($_) for (sort @groups);
	$self->{group_combo}->insert_text(0, $self->{group});
	$self->{group_combo}->set_active(0);

	$self->{path_label}->set_text($self->{fileinfo}->get_path);
	$self->{mimetype_label}->set_text($self->{fileinfo}->get_mimetype);

	if ($self->{fileinfo}->is_dir) {
		$self->deep_count;

		$self->{openw_label}->hide;
		$self->{openw_button}->hide;
	} else {
		$self->{size_label}->set_text($self->{fileinfo}->get_size . " (" . $self->{fileinfo}->get_raw_size . " Bytes)");

		$self->{openw_label}->set_text($self->{fileinfo}->get_mimetype_handler);
	}
}

sub ok {
	my ($self) = @_;

	my @files = @{$self->{active_pane}->get_item_list};
	my $mode  = oct(($self->{properties_mode} * 1000) + ($self->{owner_mode} * 100) + ($self->{group_mode} * 10) + ($self->{other_mode}));
	my $uid   = getpwnam($self->{owner_combo}->get_active_text);
	my $gid   = getgrnam($self->{group_combo}->get_active_text);

	eval {
		package Filer::Properties;
		chown($uid, $gid, @files);
		chmod($mode, @files);
	};

	if ($@) {
		Filer::Dialog->show_error_message("Error: $@: $!");
	}
}

sub mode_change {
	my ($self,$w,$mode_ref,$x) = @_;
	${$mode_ref} += ($w->get_active) ? $x : -$x;
}

sub deep_count {
	my ($self) = @_;

	my $dirwalk = new File::DirWalk;
	my $count_files;
	my $count_size;

	$dirwalk->onFile(sub {
		my ($file) = @_;

		++$count_files;
		$count_size += -s $file;

		$self->{size_label}->set_text("$count_files files (" . Filer::Tools->humanize_size($count_size) . ")");

		return 1;
	});

	$dirwalk->walk($self->{fileinfo}->get_path);
}

1;
