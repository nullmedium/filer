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
	$dialog->vbox->pack_start($label, 1,1,5);

	$dialog->show_all;
	my $r = $dialog->run;
	$dialog->destroy;

	return $r;
}

# sub ask_command_dialog {
# 	my ($class,$title,$default) = @_;
# 	my ($dialog,$label,$entry,$button);
# 	my $text;
# 
# 	$dialog = Gtk2::Dialog->new(
# 		$title,
# 		undef,
# 		'modal',
# 		'gtk-cancel' => 'cancel',
# 		'gtk-ok'     => 'ok'
# 	);
# 
# 	$dialog->set_size_request(450,150);
# 	$dialog->set_has_separator(1);
# 	$dialog->set_position('center');
# 	$dialog->set_default_response('ok');
# 
# 	$label = Gtk2::Label->new;
# 	$label->set_use_markup(1);
# 	$label->set_markup($title);
# 	$label->set_alignment(0.0,0.0);
# 	$dialog->vbox->pack_start($label, 1,1,5);
# 
# 	my $hbox = Gtk2::HBox->new(0,0);
# 	$dialog->vbox->pack_start($hbox, 0,0,5);
# 
# 	$entry = Gtk2::Entry->new;
# 	$entry->set_text($default);
# 	$entry->set_activates_default(1);
# 	$hbox->pack_start($entry, 1,1,5);
# 
# 	$button = Gtk2::Button->new;
# 	$button->add(Gtk2::Image->new_from_stock('gtk-open', 'button'));
# 	$button->signal_connect("clicked", sub {
# 		my $fs = Gtk2::FileChooserDialog->new(
# 			"Select Command",
# 			undef,
# 			'GTK_FILE_CHOOSER_ACTION_OPEN',
# 			'gtk-cancel' => 'cancel',
# 			'gtk-ok'     => 'ok'
# 		);
# 
# 		$fs->set_filename($entry->get_text);
# 
# 		if ($fs->run eq 'ok') {
# 			$entry->set_text($fs->get_filename);
# 		}
# 
# 		$fs->destroy;
# 	});
# 	$hbox->pack_start($button, 0,0,0);
# 
# 	$dialog->show_all;
# 
# 	if ($dialog->run eq 'ok') {
# 		$text = $entry->get_text;
# 	} else {
# 		$text = $default;
# 	}
# 
# 	$dialog->destroy;
# 
# 	return $text;
# }

sub mixed_button_new {
	my ($self,$stock,$text) = @_;

	my $button = Gtk2::Button->new;
	my $align = Gtk2::Alignment->new(0.5, 0.5, 0.0, 0.0);
	$button->add($align);

	my $image = Gtk2::Image->new_from_stock($stock, 'button');
	my $label = Gtk2::Label->new_with_mnemonic($text);
	$label->set_mnemonic_widget($button);

	my $hbox = Gtk2::HBox->new(0, 2);
	$hbox->pack_start($image, 0, 0, 0);
	$hbox->pack_end($label, 0, 0, 0);

	$align->add($hbox);
	$align->show_all;

	return $button;
}

sub open_with_dialog {
	my ($class,$fileinfo) = @_;

	my $dialog = Gtk2::Dialog->new(
		"Open With",
		undef,
		'modal',
		'gtk-close' => 'close',
		'gtk-ok' => 'ok',
	);

	$dialog->set_has_separator(1);
	$dialog->set_position('center');

	my $table = Gtk2::Table->new(3,3);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

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
		my $command = $command_entry->get_text;
		$fileinfo->set_mimetype_handler($command);
	}

	$dialog->destroy;
}

1;
