package Filer::FilePaneInterface;
use base qw(Exporter);
use Filer::FilePaneConstants;

our @EXPORT = qw(
$COL_FILEINFO
$COL_ICON
$COL_NAME
$COL_SIZE
$COL_MODE
$COL_TYPE
$COL_DATE
);

# API methods shared between Filer::FilePane and Filer::FileTreePane

sub new {
	my ($class,$filer,$side) = @_;
	my $self = bless {}, $class;

	$self->{vbox} = Gtk2::VBox->new(0,0);
	$self->{filer} = $filer;
	$self->{side}  = $side;
	
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

# sub get_treemodel {
# 	my ($self) = @_;
# 	return $self->{treeview}->get_model;
# }

# sub get_treefilter_model {
# 	my ($self) = @_;
# 	return $self->{treefilter}->get_model;
# }

# sub get_model_data {
# 	my ($self) = @_;
# 	return $self->{treemodel}->get_data;
# }

sub set_focus {
	my ($self) = @_;
	$self->{treeview}->grab_focus;
}

sub treeview_grab_focus_cb {
	my ($self) = @_;

	$self->{filer}->change_active_pane($self->{side});

	return 1;
}

# sub get_iter {
# 	my ($self) = @_;
# 	return $self->get_iter_list->[0];
# }

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

# sub get_item {
# 	my ($self) = @_;
# 	return $self->get_item_list->[0];
# }

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

# sub get_path_by_position {
# 	my ($self,$x,$y) = @_;
# 	
# }

sub count_items {
	my ($self) = @_;
	return $self->{treeselection}->count_selected_rows;
}

sub refresh {
	my ($self) = @_;
	print "DEBUG $self refresh\n";
	$self->open_path($self->{filepath});
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
# 	$self->{treefilter}->refilter;
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
