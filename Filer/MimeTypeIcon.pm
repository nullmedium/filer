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

package Filer::MimeTypeIcon;

use strict;
use warnings;

use Readonly;

sub new {
	my ($class,$mimetype) = @_;
	my $self = bless {}, $class;

	$self->{mimetype}  = $mimetype;	

	return $self;
}

sub get_pixbuf {
	my ($self) = @_;
	my $icon;
	my $pixbuf;

	my ($media,$subtype) = split "/", $self->{mimetype}; 

    if ($subtype eq "directory") {
        $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file("$main::libpath/icons/folder.png");
    } else {
        $pixbuf = Gtk2::Gdk::Pixbuf->new_from_file("$main::libpath/icons/default.png");
    }

	return $pixbuf;
}

1;
