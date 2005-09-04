package Filer::FilePaneInterface;
use base qw(Exporter);
use Class::Std::Utils;
use Filer::FilePaneConstants;

our @EXPORT = qw(
$COL_FILEINFO
$COL_ICON
$COL_NAME
$COL_SIZE
$COL_MODE
$COL_TYPE
$COL_DATE
%filer
%filepath
%side
%vbox
%treeview
%treemodel
%treeselection
%treefilter
%mouse_motion_select
%mouse_motion_y_pos_old
);

# attributes

%filer                  = {};
%filepath               = {};
%side                   = {};
%vbox                   = {};
%treeview               = {};
%treemodel              = {};
%treeselection          = {};
%treefilter             = {};
%mouse_motion_select    = {};
%mouse_motion_y_pos_old = {};

# API methods shared between Filer::FilePane and Filer::FileTreePane

sub get_side {
	my ($self) = @_;
	return $side{ident $self};
}

sub get_vbox {
	my ($self) = @_;
	return $vbox{ident $self};
}

sub get_treeview {
	my ($self) = @_;
	return $treeview{ident $self};
}

sub get_model {
	my ($self) = @_;
	return $treemodel{ident $self};
}

sub set_focus {
	my ($self) = @_;
	$treeview{ident $self}->grab_focus;
}

sub treeview_grab_focus_cb {
	my ($self) = @_;

	$filer{ident $self}->set_active_pane($self);
	$filer{ident $self}->set_inactive_pane($filer{ident $self}->get_pane(! $side{ident $self}));

	return 1;
}



sub get_iter {
	my ($self) = @_;
	return $self->get_iter_list->[0];
}

sub get_iter_list {
	my ($self) = @_;
	my @sel    = $treeselection{ident $self}->get_selected_rows;
	my @iters  = map { $treemodel{ident $self}->get_iter($_) } @sel;
	return \@iters;
}

sub get_fileinfo_list {
	my ($self) = @_;
	my @iters  = @{$self->get_iter_list};
	my @fi     = map { $treemodel{ident $self}->get_fileinfo($_) } @iters;

	return \@fi;
}

sub get_item {
	my ($self) = @_;
	return $self->get_item_list->[0];
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
	my $iter      = $treemodel{ident $self}->get_iter($p);
	my $fi        = $treemodel{ident $self}->get_fileinfo($iter);
	my $path      = $fi->get_path;

	return $path;
}

sub count_items {
	my ($self) = @_;
	return $treeselection{ident $self}->count_selected_rows;
}

sub refresh {
	my ($self) = @_;
	$self->open_path($filepath{ident $self});
}

sub remove_selected {
	my ($self) = @_;

	while (1) {
		my @sel  = $treeselection{ident $self}->get_selected_rows;
		my $path = pop @sel;

		last if (! defined $path);

		my $iter = $treemodel{ident $self}->get_iter($path);
		my $fi   = $treemodel{ident $self}->get_fileinfo($iter);

		if (! $fi->exist) {
			$treemodel{ident $self}->remove($iter);
		}
	}
}

#
# Pollute the namespaces with handy util methods
#

################################################################################

package Gtk2::TreeModel;

sub get_fileinfo {
	my ($self,$iter) = @_;
#  	my ($package, $filename, $line) = caller;
#
# 	print "get_fileinfo: called by: $package, $filename, $line\n";

	return $self->get($iter, 0);
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
