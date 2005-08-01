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

	$self->{filer} = $filer;

	return $self;
}

sub get_bookmarks {
	my ($self) = @_;
	my $bookmarks = $self->{filer}->{config}->get_option("Bookmarks");
	
	if (defined $bookmarks) {
		return sort @{$bookmarks};
	} else {
		return ();
	}
}

sub set_bookmark {
	my ($self,$path) = @_;
	my $bookmarks = $self->{filer}->{config}->get_option("Bookmarks");
	my @b = @{$bookmarks};
	push @b, $path;
		
	undef my %seen;
	@seen{@b} = @b;

	$self->{filer}->{config}->set_option("Bookmarks", [keys %seen]);
}

sub remove_bookmark {
	my ($self,$path) = @_;
	my $bookmarks = $self->{filer}->{config}->get_option("Bookmarks");
	my @b = @{$bookmarks};

	undef my %seen;
	@seen{@b} = @b;

	delete $seen{$path};

	$self->{filer}->{config}->set_option("Bookmarks", [keys %seen]);
}

sub bookmarks_menu {
	my ($self) = @_;
	my $menu = new Gtk2::Menu;
	my $menuitem;

	$menuitem = new Gtk2::MenuItem("Set Bookmark");
	$menuitem->signal_connect("activate", sub {

		if ($self->{filer}->{active_pane}->count_items > 0) {
			foreach (@{$self->{filer}->{active_pane}->get_items}) {
				if (-d $_) {
					$self->set_bookmark($_);
				} else {
					$self->set_bookmark($self->{filer}->{active_pane}->get_pwd);
				}
			}
		} else {
			$self->set_bookmark($self->{filer}->{active_pane}->get_pwd);
		}

	  	$self->{filer}->{widgets}->{uimanager}->get_widget("/ui/menubar/bookmarks-menu")->set_submenu($self->bookmarks_menu);
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::MenuItem("Remove Bookmark");
	$menuitem->signal_connect("activate", sub {
		if ($self->{filer}->{active_pane}->count_items > 0) {
			foreach (@{$self->{filer}->{active_pane}->get_items}) {
				if (-d $_) {
					$self->remove_bookmark($_);
				} else {
					$self->remove_bookmark($self->{filer}->{active_pane}->get_pwd);
				}
			}
		} else {
			$self->remove_bookmark($self->{filer}->{active_pane}->get_pwd);
		}

	  	$self->{filer}->{widgets}->{uimanager}->get_widget("/ui/menubar/bookmarks-menu")->set_submenu($self->bookmarks_menu);
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::SeparatorMenuItem;
	$menuitem->show;
	$menu->add($menuitem);

	foreach ($self->get_bookmarks) {
		$menuitem = new Gtk2::MenuItem($_);
		$menuitem->signal_connect("activate", sub {
			my $p = ($self->{filer}->{config}->get_option("Mode") == NORTON_COMMANDER_MODE) ? $self->{filer}->{active_pane} : $self->{filer}->{pane}->[RIGHT];
			$p->open_path_helper($_[1]);
		},$_);
		$menuitem->show;
		$menu->add($menuitem);
	}

	return $menu;
}

1;
