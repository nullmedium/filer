#     Copyright (C) 2004-2006 Jens Luedicke <jens.luedicke@gmail.com>
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

package Filer::FilePaneInterface;
use base qw(Filer::FilePaneDND);
use Filer::Constants qw(:filepane_columns);

# API methods shared between Filer::FilePane and Filer::FileTreePane

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless {}, $class;

	$self->{vbox} = Gtk2::VBox->new(0,0);
	$self->{filer} = $filer;
	$self->{side}  = $side;

	$self->{ShowHiddenFiles} = $filer->get_config->get_option("ShowHiddenFiles");
	
	$self->{directory} = "";
	
	return $self;
}

sub get_side {
	my ($self) = @_;
	return $self->{side};
}

sub get_vbox {
	my ($self) = @_;
	return $self->{vbox};
}

sub get_treeview {
	my ($self) = @_;
	return $self->{treeview};
}

sub set_focus {
	my ($self) = @_;
	$self->{treeview}->grab_focus;
}

sub treeview_grab_focus_cb {
	my ($self) = @_;
	$self->{filer}->change_active_pane($self->{side});
	return 1;
}

sub get_iter_list {
	my ($self) = @_;
	my @sel    = $self->{treeselection}->get_selected_rows;
	my @iters  = map { $self->{treemodel}->get_iter($_) } @sel;
	return \@iters;
}

sub get_fileinfo {
	my ($self,$iter) = @_;
	return $self->{treemodel}->get($iter, $COL_FILEINFO);
}

sub get_fileinfo_list {
	my ($self) = @_;
	my @iters  = @{$self->get_iter_list};
	my @fi     = map { $self->get_fileinfo($_) } @iters;

	return \@fi;
}

sub get_item_list {
	my ($self) = @_;
	my @fi     = @{$self->get_fileinfo_list};
	my @items  = map { $_->get_path } @fi;

	return \@items;
}

sub get_uri_list {
	my ($self) = @_;
	my @fi   = @{$self->get_fileinfo_list};
	my @uris = map { $_->get_uri } @fi;

	return \@uris;
}

sub get_path_by_treepath {
	my ($self,$p) = @_;
	my $iter      = $self->{treemodel}->get_iter($p);
	my $fi        = $self->get_fileinfo($iter);
	my $path      = $fi->get_path;

	return $path;
}

sub count_items {
	my ($self) = @_;
	return $self->{treeselection}->count_selected_rows;
}

# sub remove_selected {
# 	my ($self) = @_;
# 
# 	while (1) {
# 		my @sel  = $self->{treeselection}->get_selected_rows;
# 		my $path = pop @sel;
# 
# 		last if (! defined $path);
# 
# 		my $iter = $self->{treemodel}->get_iter($path);
# 		my $fi   = $self->get_fileinfo($iter);
# 
# 		if (! $fi->exist) {
# 			$self->{treemodel}->remove($iter);
# 		}
# 	}
# }

sub set_show_hidden {
	my ($self,$bool) = @_;
	$self->{ShowHiddenFiles} = $bool;
	$self->refresh;
}

################################################################################

package Gtk2::TreeStore;

sub insert_with_values {
	my ($self,$parent_iter,$pos,%cols) = @_;

	my $iter = $self->insert($parent_iter, $pos);
	$self->set($iter, %cols);

	return $iter;
}

1;
