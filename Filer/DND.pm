package Filer::DND;

use strict;
use warnings;

use constant TARGET_URI_LIST	=> 0;

sub target_table {
	return ({'target' => "text/uri-list", 'flags' => [], 'info' => TARGET_URI_LIST});
}

sub drag_data_get_cb {
	my ($widget,$context,$data,$info,$time,$self) = @_;

	if ($info == TARGET_URI_LIST) {
		if ($self->count_selected_items > 0) {
			my $d = join "\r\n", @{$self->get_selected_items};
			$data->set($data->target, 8, $d);
		}
	}
}

sub drag_data_received_cb {
	my ($widget,$context,$x,$y,$data,$info,$time,$self) = @_;

	if (($data->length >= 0) && ($data->format == 8)) {
		my ($p,$d) = $widget->get_dest_row_at_pos($x,$y);
		my $action = $context->action;
		my $path;
		my $do;

		if (defined $p) {
			$path = $self->get_path_by_treepath($p);
	
			if (! -d $path) {
				return;
			}
		} else {
			$path = $self->get_pwd;
		}

		if ($action eq "copy") {
			return if (Filer::Dialog->yesno_dialog("Copy selected files to $path?") eq 'no');
			$do = Filer::Copy->new;
		} elsif ($action eq "move") {
			return if (Filer::Dialog->yesno_dialog("Move selected files to $path?") eq 'no');
			$do = Filer::Move->new;
		}

		$do->set_total(&main::files_count);
		$do->show;

		for (split /\r\n/, $data->data) {
			last if ($_ eq $path);

			my $r = $do->action($_, $path);

			if ($r == Filer::DirWalk::FAILED) {
				Filer::Dialog->msgbox_info("Copying of $_ to $path failed!");
				last;
			} elsif ($r == Filer::DirWalk::ABORTED) {
				Filer::Dialog->msgbox_info("Moving of $_ to $path aborted!");
				last;
			}
		}

		$do->destroy;

		if ($action eq "move") {
			$main::active_pane->remove_selected;
		}

		$main::inactive_pane->refresh;

		$context->finish (1, 0, $time);
		return;
	}

 	$context->finish (0, 0, $time);
}

1;
