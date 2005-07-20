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

use strict;
use warnings;

sub new {
	my ($class,$filer) = @_;
	my $self = bless {}, $class;

	$self->{filer} = $filer;
	$self->{bookmarks_store} = Filer::Tools->catpath((new File::BaseDir)->xdg_config_home, "filer", "bookmarks.cfg");
	$self->{bookmarks_store_old} = Filer::Tools->catpath((new File::BaseDir)->xdg_config_home, "filer", "bookmarks");

	if (-e $self->{bookmarks_store_old}) {
		my $stuff = Storable::retrieve($self->{bookmarks_store_old});
		$self->store(sort keys %{$stuff});
		unlink($self->{bookmarks_store_old});
	}

	return $self;
}

sub store {
	my ($self,@bookmarks) = @_;

	open(my $cfg, ">$self->{bookmarks_store}") || die "$self->{bookmarks_store}: $!\n\n";
	
	foreach (@bookmarks) {
		print $cfg "$_\n";
	}

	close($cfg);
}

sub get {
	my ($self) = @_;
	my @bookmarks = ();

	if (! -e $self->{bookmarks_store}) {
		return @bookmarks;
	}

	open(my $cfg, "$self->{bookmarks_store}") || die "$self->{bookmarks_store}: $!\n\n";
	
	while (<$cfg>) {
		chomp $_;
		push @bookmarks, $_;
	}

	close($cfg);

	return (@bookmarks);
}

sub get_bookmarks {
	my ($self) = @_;
	return sort $self->get;
}

sub set_bookmark {
	my ($self,$path) = @_;
	return if (!$path); 

	# 4.6. Extracting Unique Elements from a List
	my %seen = ();
	my @uniq = ();
	foreach my $item ($path,$self->get) {
		push (@uniq,$item) unless $seen{$item}++;
	}

	$self->store(@uniq);
}

sub remove_bookmark {
	my ($self,$path) = @_;
	return if (!$path); 

	# 4.6. Extracting Unique Elements from a List
	my %seen = ();
	my @uniq = ();
	foreach my $item ($self->get) {
		push (@uniq,$item) unless $seen{$item}++;
	}

	delete $seen{$path};

	$self->store(sort keys %seen);
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
