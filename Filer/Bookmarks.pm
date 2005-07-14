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

use Filer;
use Filer::Constants;
our @ISA = qw(Filer);

# use strict;
# use warnings;

sub new {
	my ($class,$side) = @_;
	my $self = bless {}, $class;
	$self->{cfg_home} = File::Spec->catfile((new File::BaseDir)->xdg_config_home, "/filer");
	$self->{bookmarks_store} = File::Spec->catfile(File::Spec->splitdir($self->{cfg_home}), "bookmarks");

	if (! -e $self->{bookmarks_store}) {
		my $bookmarks = {};
		$self->store($bookmarks);
	}

	return $self;
}

sub store {
	my ($self,$bookmarks) = @_;
	Storable::store($bookmarks, $self->{bookmarks_store});
}

sub get {
	my ($self) = @_;
	return Storable::retrieve($self->{bookmarks_store});
}

sub get_bookmarks {
	my ($self) = @_;
	return sort keys %{$self->get};
}

sub set_bookmark {
	my ($self,$path) = @_;
	return if (!$path); 

	my $bookmarks = $self->get;
	$bookmarks->{$path} = 1;

	$self->store($bookmarks);
}

sub remove_bookmark {
	my ($self,$path) = @_;
	return if (!$path); 

	my $bookmarks = $self->get;
	delete $bookmarks->{$path};	

	$self->store($bookmarks);
}

sub bookmarks_menu {
	my ($self) = @_;
	my $menu = new Gtk2::Menu;
	my $menuitem;

	$menuitem = new Gtk2::MenuItem("Set Bookmark");
	$menuitem->signal_connect("activate", sub {

		if ($active_pane->count_items > 0) {
			foreach (@{$active_pane->get_items}) {
				if (-d $_) {
					$self->set_bookmark($_);
				} else {
					$self->set_bookmark($active_pane->get_pwd);
				}
			}
		} else {
			$self->set_bookmark($active_pane->get_pwd);
		}

		my $menu = $widgets->{item_factory}->get_item("/Bookmarks");
		$menu->set_submenu($self->bookmarks_menu);
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::MenuItem("Remove Bookmark");
	$menuitem->signal_connect("activate", sub {
		if ($active_pane->count_items > 0) {
			foreach (@{$active_pane->get_items}) {
				if (-d $_) {
					$self->remove_bookmark($_);
				} else {
					$self->remove_bookmark($active_pane->get_pwd);
				}
			}
		} else {
			$self->remove_bookmark($active_pane->get_pwd);
		}

		my $menu = $widgets->{item_factory}->get_item("/Bookmarks");
		$menu->set_submenu($self->bookmarks_menu);
	});
	$menuitem->show;
	$menu->add($menuitem);

	$menuitem = new Gtk2::SeparatorMenuItem;
	$menuitem->show;
	$menu->add($menuitem);

	foreach ($self->get_bookmarks) {
		$menuitem = new Gtk2::MenuItem($_);
		$menuitem->signal_connect("activate", sub {
			my $p = ($config->get_option("Mode") == NORTON_COMMANDER_MODE) ? $active_pane : $pane->[RIGHT];
			$p->open_path_helper($_[1]);
		},$_);
		$menuitem->show;
		$menu->add($menuitem);
	}

	return $menu;
}

1;
