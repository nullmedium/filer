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

package Filer::Bookmarks;

use strict;
use warnings;

use Filer;
use Filer::Constants;

sub new {
	my ($class,$filer) = @_;
	my $self = bless {}, $class;

	$self->{filer}     = $filer;
	$self->{config}    = $filer->get_config;
	$self->{bookmarks} = $self->{config}->get_option("Bookmarks");

	$self->{ui}             = $self->{filer}->get_uimanager;
	$self->{bookmarks_menu} = $self->{ui}->get_widget("/ui/menubar/bookmarks-menu");

	return $self;
}

sub get_bookmarks {
	my ($self) = @_;

	if (defined $self->{bookmarks}) {
		return sort @{$self->{bookmarks}};
	} else {
		return ();
	}
}

sub set_bookmark {
	my ($self,$path) = @_;

	undef my %seen;
	push @{$self->{bookmarks}}, $path;
	@seen{@{$self->{bookmarks}}} = 1;

	$self->{bookmarks} = [keys %seen];

	$self->{config}->set_option("Bookmarks", $self->{bookmarks});
}

sub remove_bookmark {
	my ($self,$path) = @_;

	undef my %seen;
	@seen{@{$self->{bookmarks}}} = 1;

	delete $seen{$path};

	$self->{bookmarks} = [keys %seen];

	$self->{config}->set_option("Bookmarks", $self->{bookmarks});
}

sub generate_bookmarks_menu {
	my ($self)         = @_;
	my $bookmarks_menu = Gtk2::Menu->new;
	my $menuitem;

	$menuitem = Gtk2::MenuItem->new("Set Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $pane = $self->{filer}->get_active_pane;

		if ($pane->count_items > 0) {
			foreach (@{$pane->get_fileinfo_list}) {
				if ($_->is_dir) {
					$self->set_bookmark($_->get_path);
				} else {
					$self->set_bookmark($pane->get_pwd);
				}
			}
		} else {
			$self->set_bookmark($pane->get_pwd);
		}

		$self->{bookmarks_menu}->set_submenu($self->generate_bookmarks_menu);
	});
	$menuitem->show;
	$bookmarks_menu->add($menuitem);

	$menuitem = Gtk2::MenuItem->new("Remove Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $pane = $self->{filer}->get_active_pane;

		if ($pane->count_items > 0) {
			foreach (@{$pane->get_fileinfo_list}) {
				if ($_->is_dir) {
					$self->remove_bookmark($_->get_path);
				} else {
					$self->remove_bookmark($pane->get_pwd);
				}
			}
		} else {
			$self->remove_bookmark($pane->get_pwd);
		}

		$self->{bookmarks_menu}->set_submenu($self->generate_bookmarks_menu);
	});
	$menuitem->show;
	$bookmarks_menu->add($menuitem);

	$menuitem = Gtk2::SeparatorMenuItem->new;
	$menuitem->show;
	$bookmarks_menu->add($menuitem);

	foreach ($self->get_bookmarks) {
		$menuitem = Gtk2::MenuItem->new($_);
		$menuitem->signal_connect("activate", sub {
			my $path = pop @_;

			if (-e $path && -d $path) {
				my $mode = $self->{config}->get_option('Mode');
				my $pane;

				if ($mode == $EXPLORER_MODE) {
					$pane = $self->{filer}->get_right_pane;		
				} else {
					$pane = $self->{filer}->get_active_pane;
				}

				$pane->open_path($path);
			} else {
				Filer::Dialog->msgbox_error("Path '$path' doesn't exist!");
			}
		},$_);

		$menuitem->show;
		$bookmarks_menu->add($menuitem);
	}

	return $bookmarks_menu;
}

1;
