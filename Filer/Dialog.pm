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

	my $dialog = new Gtk2::MessageDialog(undef, 'modal', $type, 'close', $message);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	if ($dialog->run eq 'close') {
		$dialog->destroy;
	}
}

sub yesno_dialog {
	my ($question) = pop;
	my ($dialog,$label);

	$dialog = new Gtk2::Dialog($question, undef, 'modal', 'gtk-no' => 'no', 'gtk-yes' => 'yes');
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$label = new Gtk2::Label;
	$label->set_use_markup(1);
	$label->set_markup($question);
	$label->set_alignment(0.0,0.0);
	$dialog->vbox->pack_start($label, 1,1,5);

	$dialog->show_all;
	my $r = $dialog->run;
	$dialog->destroy;

	return $r;
}

# sub input_dialog {
# 	my ($str) = pop;
# 	my ($dialog,$label);
#
# 	$dialog = new Gtk2::Dialog($question, undef, 'modal', 'gtk-no' => 'no', 'gtk-yes' => 'yes');
# 	$dialog->set_has_separator(1);
# 	$dialog->set_position('center');
# 	$dialog->set_modal(1);
#
# 	$label = new Gtk2::Label;
# 	$label->set_use_markup(1);
# 	$label->set_markup($question);
# 	$label->set_alignment(0.0,0.0);
# 	$dialog->vbox->pack_start($label, 1,1,5);
#
# 	$dialog->show_all;
# 	my $r = $dialog->run;
# 	$dialog->destroy;
# }

sub source_target_dialog {
	my ($dialog,$table,$source_label,$target_label,$source_entry,$target_entry);

	$dialog = new Gtk2::Dialog("", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_size_request(450,150);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$table = new Gtk2::Table(2,2);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$dialog->vbox->pack_start($table,0,0,5);

	$source_label = new Gtk2::Label;
	$source_label->set_justify('left');
	$source_label->set_use_markup(1);
	$source_label->set_alignment(0.0,0.0);
	$table->attach($source_label, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$source_entry = new Gtk2::Entry;
	$table->attach($source_entry, 1, 2, 0, 1, [ "expand","fill" ], [], 0, 0);

	$target_label = new Gtk2::Label;
	$target_label->set_justify('left');
	$target_label->set_use_markup(1);
	$target_label->set_alignment(0.0,0.0);
	$table->attach($target_label, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$target_entry = new Gtk2::Entry;
	$table->attach($target_entry, 1, 2, 1, 2, [ "expand","fill" ], [], 0, 0);

	return ($dialog,$source_label,$target_label,$source_entry,$target_entry);
}

sub preview_file_selection {
	my $frame = new Gtk2::Frame("Preview");
	my $preview = new Gtk2::Image;
	$frame->add($preview);
	$frame->show_all;

	my $dialog = new Gtk2::FileChooserDialog("Select Icon", undef, 'GTK_FILE_CHOOSER_ACTION_OPEN', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_use_preview_label(0);
	$dialog->set_preview_widget($frame);
	$dialog->set_preview_widget_active(1);

	my $filter = new Gtk2::FileFilter;
	$filter->add_pixbuf_formats;
	$dialog->set_filter($filter);

	$dialog->signal_connect("update-preview", sub {
		my ($w,$preview) = @_;
		my $filename = $w->get_preview_filename;

		return if ((not defined $filename) or (-d $filename));

		my $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($filename);
		$preview->set_from_pixbuf(&main::intelligent_scale($pixbuf,100));
	}, $preview);

	return $dialog;
}

sub mixed_button_new {
	my ($stock,$text) = @_;
	my ($button,$label,$image,$align,$hbox);

	$button = new Gtk2::Button;
	$label = Gtk2::Label->new_with_mnemonic($text);
	$label->set_mnemonic_widget($button);

	$image = Gtk2::Image->new_from_stock($stock, 'button');
	$hbox = new Gtk2::HBox(0, 2);

	$align = new Gtk2::Alignment(0.5, 0.5, 0.0, 0.0);

	$hbox->pack_start($image, 0, 0, 0);
	$hbox->pack_end($label, 0, 0, 0);

	$button->add($align);
	$align->add($hbox);
	$align->show_all;

	return $button;
}
1;
