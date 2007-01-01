package Filer::ListStore;

# use strict;
# use warnings;

use Glib;
use Gtk2;

use Filer::Constants qw(:filer :filepane_columns);

#
#  here we register our new type and its interfaces with the type system.
#  If you want to implement additional interfaces like GtkTreeSortable,
#  you will need to do it here.
#

use Glib::Object::Subclass
	Glib::Object::,
 	interfaces => [qw(Gtk2::TreeModel Gtk2::TreeSortable Gtk2::TreeDragDest Gtk2::TreeDragSource)],
#  	interfaces => [qw(Gtk2::TreeModel Gtk2::TreeDragDest Gtk2::TreeDragSource)],

# 	properties => [
# 		Glib::ParamSpec->boolean("show-hidden", "Show Hidden", "Show Hidden", $TRUE, [qw(readable writable)]),
# 	]
;

################################################################################
# Gtk2::TreeModel
################################################################################

#
# this is called everytime a new custom list object
# instance is created (we do that in custom_list_new).
# Initialise the list structure's fields here.
#

sub INIT_INSTANCE {
	my ($self) = @_;
	$self->{n_columns}    = 7;
	$self->{column_types} = [qw(Glib::Scalar Glib::Object Glib::String Glib::Int Glib::String Glib::String Glib::Int)];
	$self->{list}         = [];

	$self->{sort_column_id}  = $COL_NAME;
	$self->{sort_order}      = "ascending";

	$self->{stamp}        = sprintf '%d', rand (1<<31);
}

# sub GET_PROPERTY {
# 	my ($self,$pspec) = @_;
# 	return ($self->{prop}->{$pspec->get_name} || $pspec->get_default_value);
# }
# 
# sub SET_PROPERTY {
# 	my ($self,$pspec,$newval) = @_;
# 	$self->{prop}->{$pspec->get_name} = $newval;
# }

#
#  this is called just before a custom list is
#  destroyed. Free dynamically allocated memory here.
#

sub FINALIZE_INSTANCE {
	my ($self) = @_;

	# free all records and free all memory used by the list
	#warning IMPLEMENT
}

#
# tells the rest of the world whether our tree model has any special
# characteristics. In our case, we have a list model (instead of a tree).
# Note that unlike the C version of this custom model, our iters do NOT
# persist.
#

sub GET_FLAGS {
	return [qw(list-only)]
}

#
# tells the rest of the world how many data
# columns we export via the tree model interface
#

sub GET_N_COLUMNS {
	return shift->{n_columns};
}

#
# tells the rest of the world which type of
# data an exported model column contains
#

sub GET_COLUMN_TYPE {
	my ($self, $index) = @_;
	# and invalid index will send undef back to the calling XS layer,
	# which will croak.
	return $self->{column_types}[$index];
}

#
# converts a tree path (physical position) into a
# tree iter structure (the content of the iter
# fields will only be used internally by our model).
# We simply store a pointer to our CustomRecord
# structure that represents that row in the tree iter.
#

sub GET_ITER {
	my ($self,$path) = @_;

	die "no path" if (! $path);

	my @indices = $path->get_indices;
	my $n       = $indices[0];
	my $record  = $self->{list}->[$n];
	
	return undef if (! $record);

	return [ $self->{stamp}, $n, $record, undef ];
}

#
#  custom_list_get_path: converts a tree iter into a tree path (ie. the
#                        physical position of that row in the list).
#

sub GET_PATH {
	my ($self, $iter) = @_;
	die "no iter" unless $iter;

	my $pos  = $iter->[1];
	my $path = Gtk2::TreePath->new_from_indices($pos);

	return $path;
}

#
# custom_list_get_value: Returns a row's exported data columns
#                        (_get_value is what gtk_tree_model_get uses)
#

sub GET_VALUE {
	my ($self,$iter,$column) = @_;

	die "bad iter" unless $iter;

	return undef unless $column < @{$self->{column_types}};
	
	my $pos    = $iter->[1];
	my $record = $iter->[2];

	die "bad iter" if ($pos >= @{$self->{list}});

	if ($column == $COL_FILEINFO) { return $record; }
	if ($column == $COL_ICON) { return $record->get_mimetype_icon; }
	if ($column == $COL_NAME) { return $record->get_basename; }
	if ($column == $COL_SIZE) { return $record->get_raw_size; }
	if ($column == $COL_TYPE) { return $record->get_description; }
	if ($column == $COL_MODE) { return $record->get_mode; }
	if ($column == $COL_DATE) { return $record->get_raw_mtime; }
}

#
# iter_next: Takes an iter structure and sets it to point to the next row.
#

sub ITER_NEXT {
	my ($self,$iter) = @_;

	my $nextpos    = $iter->[1] + 1;
	my $nextrecord = $self->{list}->[$nextpos];

	return undef if (! $nextrecord);

	return [ $self->{stamp}, $nextpos, $nextrecord, undef ];
}

#
# iter_children: Returns $TRUE or $FALSE depending on whether the row
#                specified by 'parent' has any children.  If it has
#                children, then 'iter' is set to point to the first
#                child.  Special case: if 'parent' is undef, then the
#                first top-level row should be returned if it exists.
#

sub ITER_CHILDREN {
	my ($self,$parent) = @_;

	# this is a list, nodes have no children
	return undef if $parent;

	# parent == NULL is a special case; we need to return the first top-level row

 	# No rows => no first row
	return undef if (@{$self->{list}} == 0);

	# Set iter to first item in list
	return [ $self->{stamp}, 0, $self->{list}->[0] ];
}

#
# iter_has_child: Returns $TRUE or $FALSE depending on whether
#                 the row specified by 'iter' has any children.
#                 We only have a list and thus no children.
#

sub ITER_HAS_CHILD {
	return $FALSE;
}

#
# iter_n_children: Returns the number of children the row specified by
#                  'iter' has. This is usually 0, as we only have a list
#                  and thus do not have any children to any rows.
#                  A special case is when 'iter' is undef, in which case
#                  we need to return the number of top-level nodes, ie.
#                  the number of rows in our list.
#

sub ITER_N_CHILDREN {
	my ($self,$iter) = @_;

	# special case: if iter == NULL, return number of top-level rows
	if (! $iter) {
		return @{$self->{list}};
	}

	return 0; # otherwise, this is easy again for a list
}

#
# iter_nth_child: If the row specified by 'parent' has any children,
#                 set 'iter' to the n-th child and return $TRUE if it
#                 exists, otherwise $FALSE.  A special case is when
#                 'parent' is NULL, in which case we need to set 'iter'
#                 to the n-th row if it exists.
#

sub ITER_NTH_CHILD {
	my ($self,$parent,$n) = @_;

	# a list has only top-level rows
	return undef if $parent;

	# special case: if parent == NULL, set iter to n-th top-level row
	return undef if ($n >= @{$self->{list}});

	my $record = $self->{list}->[$n];

	die "no record" if (! $record);

	return [ $self->{stamp}, $n, $record, undef ];
}

#
# iter_parent: Point 'iter' to the parent node of 'child'.  As we have a
#              a list and thus no children and no parents of children,
#              we can just return $FALSE.
#

sub ITER_PARENT {
	return $FALSE;
}

#
# ref_node and unref_node get called as the model manages the lifetimes
# of nodes in the model.  you normally don't need to do anything for these,
# but may want to if you plan to implement data caching.
#
# sub REF_NODE { warn "REF_NODE @_\n"; }
# sub UNREF_NODE { warn "UNREF_NODE @_\n"; }

#
# new:  This is what you use in your own code to create a
#       new custom list tree model for you to use.
#

# we inherit new from Glib::Object::Subclass

################################################################################
# Gtk2::TreeSortable methods:
################################################################################

sub sort_dir {
	my ($a,$b) = @_;

	my $a_is_dir = $a->is_dir;
	my $b_is_dir = $b->is_dir;

	if ($a_is_dir && !$b_is_dir) {
		return -1;
	} elsif (!$a_is_dir && $b_is_dir) {
		return 1;
	}
	
	return 0;
}

sub sort {
	my ($self) = @_; 
	
	my $sort_column = $self->{sort_column_id};
	my $sort_sign   = ($self->{sort_order} eq "ascending") ? 1 : -1;

	my @array = ();

	if ($sort_column == $COL_NAME) {
	 	@array =
			sort {
				sort_dir($a,$b)
				|| ($a->get_basename cmp $b->get_basename) * $sort_sign;
			}
 			@{$self->{list}};

	} elsif ($sort_column == $COL_SIZE) {
	 	@array =
			sort {
				sort_dir($a,$b) ||
				(($a->get_raw_size <=> $b->get_raw_size)
				|| ($a->get_basename cmp $b->get_basename)) * $sort_sign;
			}
 			@{$self->{list}};
	} elsif ($sort_column == $COL_TYPE) {
	 	@array =
			sort {
				sort_dir($a,$b)	||
				(($a->get_mimetype cmp $b->get_mimetype)
				|| ($a->get_basename cmp $b->get_basename)) * $sort_sign;
			}
 			@{$self->{list}};

	} elsif ($sort_column == $COL_MODE) {
	 	@array =
			sort {
				sort_dir($a,$b) ||
				(($a->get_raw_mode <=> $b->get_raw_mode)
				||  ($a->get_basename cmp $b->get_basename)) * $sort_sign;
			}
 			@{$self->{list}};

	} elsif ($sort_column == $COL_DATE) {
	 	@array =
			sort {
				sort_dir($a,$b) ||
				(($a->get_raw_mtime <=> $b->get_raw_mtime)
				||  ($a->get_basename cmp $b->get_basename)) * $sort_sign;
			}
 			@{$self->{list}};
	}

	$self->{list} = \@array;

# 	my $path = Gtk2::TreePath->new;
# 	$self->rows_reordered($path, undef, @new_order);
}

sub GET_SORT_COLUMN_ID {
	my ($self) = @_;
	return ($TRUE, $self->{sort_column_id}, $self->{sort_order});
}

sub SET_SORT_COLUMN_ID {
	my ($self,$id,$order) = @_;

	$self->{sort_column_id} = $id;
	$self->{sort_order}     = $order;

	$self->sort;
	$self->sort_column_changed;
}

sub SET_SORT_FUNC {
	my ($self,$id,$func,$data) = @_;
	warn "Filer::ListStore has builtin sorting!\n";
}

sub SET_DEFAULT_SORT_FUNC {
	my ($self,$func,$data) = @_;
	warn "Filer::ListStore has builtin sorting!\n";
}

sub HAS_DEFAULT_SORT_FUNC {
	my ($list) = @_;
	return $FALSE;
}

################################################################################
# Gtk2::TreeDragDest
################################################################################

sub drag_data_received {
#	my ($self,$dest,$selection_data) = @_;
}

sub row_drop_possible {
#	my ($self,$dest_path,$selection_data) = @_;
}

################################################################################
# Gtk2::TreeDragSource
################################################################################

sub drag_data_delete {
}

################################################################################
# methods:
################################################################################

#
# set: It's always nice to be able to update the data stored in a data
#      structure.  So, here's a method to let you do that.  We emit the
#      'row-changed' signal to notify all who care that we've updated
#      something.
#

# sub set {
# 	my ($self,$treeiter,%vals) = @_;
# 
# 	# Convert the Gtk2::TreeIter to a more useable array reference.
# 	# Note that the model's stamp must be passed in as an argument.
# 	# This is so we can avoid trying to extract the guts of an iter
# 	# that we did not create in the first place.
# 	my $iter = $treeiter->to_arrayref($self->{stamp});
# 	
# 	$self->row_changed($self->get_path($treeiter), $treeiter);
# }

sub append_fileinfo {
	my ($self,$fi) = @_;

	# inform the tree view and other interested objects
	# (e.g. tree row references) that we have inserted
	# a new row, and where it was inserted

	push @{$self->{list}}, $fi;

	my $pos  = @{$self->{list}} - 1;
	my $path = Gtk2::TreePath->new_from_indices($pos);
	$self->row_inserted($path, $self->get_iter($path));

	$self->sort;
}

sub clear {
	my ($self) = @_;

	my $last = (@{$self->{list}} - 1);
	$self->{list} = [];
	
	for (my $i = $last; $i >= 0; $i--) {
		my $path = Gtk2::TreePath->new_from_indices($i);
		$self->row_deleted($path);
	}
	
	return 1;
}

sub set_show_hidden {
	my ($self,$show_hidden) = @_;

# 	if ($self->{show_hidden} || $show_hidden) {
# 		return;
# 	}
# 
# 	$self->{show_hidden} = $show_hidden;
# 
# 	if (! $show_hidden) {
# 
# 		for (my $i = 0; $i < @{$self->{list}}; $i++) {
# 			my $fi = $self->{list}->[$i];
# 		
# 			my @delete = ();
# 
# 			if ($fi->is_hidden) {
# 				my $path    = Gtk2::TreePath->new_from_indices($i);
# 				my @indices = $path->get_indices;
# 				my $pos     = $indices[0];
# 
# # 				splice @{$self->{list}}, $pos, 1;
# 				push @delete, $pos;
# 				$self->row_deleted($path);
# 				
# 				push @{$self->{hidden}}, $fi;
# 			}
# 		}
# 
# 		foreach (@delete) {
# 			splice @{$self->{list}}, $_, 1;
# 		}
# 	} else {
# 		for (my $i = 0; $i < @{$self->{hidden}}; $i++) {
# 			my $fi = $self->{hidden}->[$i];
# 
# 			my $path    = Gtk2::TreePath->new_from_indices($i);
# 			my @indices = $path->get_indices;
# 			my $pos     = $indices[0];
# 
# 			$self->row_inserted($path, $self->get_iter($path));
# 
# 			push @{$self->{list}}, $fi;			
# 		}
# 	}
}

sub foreach {
	my ($self,$func,$data) = @_;

	my $len = @{$self->{list}};
	
	for (my $i = 0; $i < $len; $i++) {
		my $path = Gtk2::TreePath->new_from_indices($i);
		my $iter = $self->get_iter($path);
		my $fi   = $self->get($iter, $COL_FILEINFO);
		
		last if (!$func->($self,$iter,$fi));
	}
}

sub remove {
	my ($self,$iter) = @_;

	my $path    = $self->get_path($iter);
	my @indices = $path->get_indices;
	my $pos     = $indices[0];

 	splice @{$self->{list}}, $pos, 1;
	$self->row_deleted($path);
}

1;
