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

package Filer::Dialog;

use strict;
use warnings;

use Filer::Constants qw(:bool);

sub msgbox_info {
	my ($message) = pop;
	&msgbox('info', $message);
	return;
}

sub msgbox_error {
	my ($message) = pop;
	&msgbox('error', $message);
	return;
}

sub msgbox {
	my ($type,$message) = @_;

	my $dialog = Gtk2::MessageDialog->new(
		undef,
		'modal',
		$type,
		'close',
		$message
	);

	$dialog->set_position('center');

	if ($dialog->run eq 'close') {
		$dialog->destroy;
	}
}

sub yesno_dialog {
	my ($question) = pop;
	my ($dialog,$label);

	$dialog = Gtk2::Dialog->new(
		$question,
		undef,
		'modal',
		'gtk-no'  => 'no',
		'gtk-yes' => 'yes'
	);

	$dialog->set_position('center');

	$label = Gtk2::Label->new;
	$label->set_use_markup(1);
	$label->set_markup($question);
	$label->set_alignment(0.0,0.0);
	$dialog->vbox->pack_start($label, $TRUE, $TRUE, 5);

	$dialog->show_all;
	my $r = $dialog->run;
	$dialog->destroy;

	return $r;
}

sub open_with_dialog {
	my ($class,$fileinfo) = @_;

	my $dialog = Gtk2::Dialog->new(
		"Open With",
		undef,
		'modal',
		'gtk-close' => 'close',
		'gtk-ok'    => 'ok',
	);

	$dialog->set_has_separator(1);
	$dialog->set_position('center');

	my $table = Gtk2::Table->new(3,3);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table, $FALSE, $FALSE, 5);

	my $label1 = Gtk2::Label->new;
	$label1->set_justify('left');
	$label1->set_text("Type: ");
	$label1->set_alignment(0.0,0.0);
	$table->attach($label1, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	my $type_label = Gtk2::Label->new;
	$type_label->set_justify('left');
	$type_label->set_text($fileinfo->get_description);
	$type_label->set_alignment(0.0,0.0);
	$table->attach($type_label, 1, 3, 0, 1, [ "expand","fill" ], [], 0, 0);

	my $label2 = Gtk2::Label->new;
	$label2->set_justify('left');
	$label2->set_text("Command:");
	$label2->set_alignment(0.0,0.0);
	$table->attach($label2, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	my $command_entry = Gtk2::Entry->new;
	$command_entry->set_text($fileinfo->get_mimetype_handler);
	$table->attach($command_entry, 1, 2, 1, 2, [ "expand","fill" ], [], 0, 0);

	my $cmd_browse_button = Gtk2::Button->new;
	$cmd_browse_button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
	$cmd_browse_button->signal_connect("clicked", sub {
		my $fs = Gtk2::FileChooserDialog->new(
			"Select Command",
			undef,
			'GTK_FILE_CHOOSER_ACTION_OPEN',
			'gtk-cancel' => 'cancel',
			'gtk-ok'     => 'ok'
		);

		$fs->set_filename($command_entry->get_text);

		if ($fs->run eq 'ok') {
			$command_entry->set_text($fs->get_filename);
		}

		$fs->destroy;
	});
	$table->attach($cmd_browse_button, 2, 3, 1, 2, [ "fill" ], [], 0, 0);

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $command  = $command_entry->get_text;
		my $filepath = $fileinfo->get_path;
		
		$fileinfo->set_mimetype_handler($command);
		Filer::Tools->exec("$command '$filepath'");
	}

	$dialog->destroy;
}

1;
