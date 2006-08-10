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

package Filer::MimeTypeIcon;

use strict;
use warnings;

use Readonly;

my %fdo_icons = 
(
	"inode/directory"          => "folder",
	"text/html"	           => "text-html",
	"application/x-executable" => "application-x-executable",
);

my %inode_icons = 
(
	"inode/directory"   => "gnome-fs-directory",
	"inode/blockdevice" => "gnome-fs-blockdev",
	"inode/chardevice"  => "gnome-fs-chardev",
	"inode/fifo"        => "gnome-fs-fifo",
	"inode/socket"      => "gnome-fs-socket",
);

my %media_icons = (
	application => "gnome-mime-application",
	audio       => "gnome-mime-audio",
	image       => "gnome-mime-image",
	text        => "gnome-mime-text",
	video       => "gnome-mime-video",
);

sub new {
	my ($class,$mimetype) = @_;
	my $self = bless {}, $class;

	$self->{mimetype}   = $mimetype;	
	$self->{desaturate} = 0;
	$self->{icontheme}  = Gtk2::IconTheme->get_default;

	return $self;
}

sub lookup_icon {
	my ($self) = @_;

	my ($media,$subtype) = split /\//, $self->{mimetype}; 
	my $icon = undef;

	if ($self->{icontheme}->has_icon("gnome-mime-$media-$subtype")) {

		$icon = "gnome-mime-$media-$subtype";

	} else {

		if ($self->{icontheme}->has_icon("gnome-mime-$media")) {

			$icon = "gnome-mime-$media";

		} else {

			if (defined $inode_icons{$self->{mimetype}} && $self->{icontheme}->has_icon($inode_icons{$self->{mimetype}})) {

				$icon = $inode_icons{$self->{mimetype}};

			} else {

				if ($self->{icontheme}->has_icon("gnome-mime-application-octet-stream")) {
					$icon = "gnome-mime-application-octet-stream";
				} else {
					$icon = undef;
				}
			}
		}
	}

	return $icon;
}

sub get_icon {
	my ($self) = @_;
	my $icon;
	my $pixbuf;

	$icon   = $self->lookup_icon;

	if ($icon) {
		$pixbuf = $self->{icontheme}->load_icon($icon, 16, 'no-svg');
	} else {
		my $widget = Gtk2::Invisible->new;
		$widget->realize;
		$pixbuf = $widget->render_icon('gtk-missing-image', 'small-toolbar');
	}

	return $pixbuf;
}

1;
