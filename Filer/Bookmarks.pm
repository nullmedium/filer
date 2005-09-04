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
use Class::Std::Utils;

use strict;
use warnings;

use Filer;
use Filer::Constants;

my %filer;
my %bookmarks;

sub new {
	my ($class,$filer) = @_;
	my $self = bless anon_scalar(), $class;

	$filer{ident $self}     = $filer;
	$bookmarks{ident $self} = $filer->get_config->get_option("Bookmarks");

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $filer{ident $self};
	delete $bookmarks{ident $self};
}

sub get_bookmarks {
	my ($self) = @_;

	if (defined $bookmarks{ident $self}) {
		return sort @{$bookmarks{ident $self}};
	} else {
		return ();
	}
}

sub set_bookmark {
	my ($self,$path) = @_;

	undef my %seen;
	push @{$bookmarks{ident $self}}, $path;
	@seen{@{$bookmarks{ident $self}}} = 1;

	$bookmarks{ident $self} = [keys %seen];

	$filer{ident $self}->get_config->set_option("Bookmarks", $bookmarks{ident $self});
}

sub remove_bookmark {
	my ($self,$path) = @_;

	undef my %seen;
	@seen{@{$bookmarks{ident $self}}} = 1;

	delete $seen{$path};

	$bookmarks{ident $self} = [keys %seen];

	$filer{ident $self}->get_config->set_option("Bookmarks", $bookmarks{ident $self});
}

sub generate_bookmarks_menu {
	my ($self)         = @_;
	my $bookmarks_menu = new Gtk2::Menu;
	my $menuitem;

	$menuitem = new Gtk2::MenuItem("Set Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $pane = $filer{ident $self}->get_active_pane;

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

		$filer{ident $self}->get_widget("uimanager")->get_widget("/ui/menubar/bookmarks-menu")->set_submenu($self->generate_bookmarks_menu);
	});
	$menuitem->show;
	$bookmarks_menu->add($menuitem);

	$menuitem = new Gtk2::MenuItem("Remove Bookmark");
	$menuitem->signal_connect("activate", sub {
		my $pane = $filer{ident $self}->get_active_pane;

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

		$filer{ident $self}->get_widget("uimanager")->get_widget("/ui/menubar/bookmarks-menu")->set_submenu($self->generate_bookmarks_menu);
	});
	$menuitem->show;
	$bookmarks_menu->add($menuitem);

	$menuitem = new Gtk2::SeparatorMenuItem;
	$menuitem->show;
	$bookmarks_menu->add($menuitem);

	foreach ($self->get_bookmarks) {
		$menuitem = new Gtk2::MenuItem($_);
		$menuitem->signal_connect("activate", sub {
			$filer{ident $self}->get_active_pane->open_path_helper(pop @_);
		},$_);

		$menuitem->show;
		$bookmarks_menu->add($menuitem);
	}

	return $bookmarks_menu;
}

1;
