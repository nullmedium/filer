#     Copyright (C) 2006 Jens Luedicke <jens.luedicke@gmail.com>
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

package Filer::CellRendererSize;

use warnings;
use strict;

use Gtk2;

use Glib::Object::Subclass
	"Gtk2::CellRenderer",
	properties => [
		Glib::ParamSpec->int("size", "Size", "Size in bytes", 0, 2147483647, 2147483647, [qw(readable writable)]),
		Glib::ParamSpec->boolean("humanize", "Humanize", "Humanize size?", 1, [qw(readable writable)]),
	]
;

use constant x_padding => 1;
use constant y_padding => 1;

sub INIT_INSTANCE {
	my ($cell) = @_;
}

sub humanize_size {
	my ($cell) = shift;

	my $size     = $cell->get('size');
	my $humanize = $cell->get('humanize');

	if ($humanize) {
		return
		($size >= 1073741824) ? sprintf("%.2f GB", $size/1073741824) :
		($size >= 1048576)    ? sprintf("%.2f MB", $size/1048576)    :
		($size >= 1024)       ? sprintf("%.2f kB", $size/1024)       : $size;
	} else {
		return $size;
	}
}

sub calc_size {
	my ($cell,$layout) = @_;
	my ($width,$height) = $layout->get_pixel_size();

	return (0,0, $width + x_padding * 2, $height + y_padding * 2);
}

sub GET_SIZE {
	my ($cell,$widget,$cell_area) = @_;

	my $layout = $cell->get_layout($widget);
	$layout->set_text($cell->humanize_size());

	return $cell->calc_size($layout);
}

sub get_layout {
	my ($cell,$widget) = @_;
	return $widget->create_pango_layout("");
}

sub RENDER {
	my ($cell,$window,$widget,$background_area,$cell_area,$expose_area,$flags) = @_;
	my $state;

	if ($flags & 'selected') {
		$state = $widget->has_focus() ? 'selected' : 'active';
	} else {
		$state = ($widget->state() eq 'insensitive') ? 'insensitive' : 'normal';
	}

	my $layout = $cell->get_layout($widget);
	$layout->set_text($cell->humanize_size());

	my ($x_offset,$y_offset,$width,$height) = $cell->calc_size($layout);

	$widget->get_style->paint_layout(
		$window,
		$state,
		1,
		$cell_area,
		$widget,
		"cellrenderertext",
		$cell_area->x() + $x_offset + x_padding,
		$cell_area->y() + $y_offset + y_padding,
		$layout
	);
}

1;
