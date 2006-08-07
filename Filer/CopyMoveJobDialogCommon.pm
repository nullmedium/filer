package Filer::CopyMoveJobDialogCommon;
use base qw(Exporter);

our @EXPORT = qw(
show_job_dialog
destroy_job_dialog
total_bytes
set_total_bytes
completed_bytes
set_completed_bytes
update_written_bytes
);

use strict;
use warnings;

use Filer::Constants;

sub show_job_dialog {
	my ($self) = @_;
	$self->show_all;

	$self->{SKIP_ALL} = $FALSE;

# 	$self->{timeout} = Glib::Timeout->add(250, sub {
# 		return 0 if ($self->cancelled);
# 		return 1 if ($self->total_bytes == 0);
# 
# 		$self->update_progressbar($self->completed_bytes/$self->total_bytes);
# 		return 1;
# 	});
}

sub destroy_job_dialog {
	my ($self) = @_;
	$self->destroy;
# 	Glib::Source->remove($self->{timeout});
}

sub total_bytes {
	my ($self) = @_;
	return $self->{total_bytes};
}

sub set_total_bytes {
	my ($self,$bytes) = @_;
	$self->{total_bytes} = $bytes;
}

sub completed_bytes {
	my ($self) = @_;
	return $self->{completed_bytes};
}

sub set_completed_bytes {
	my ($self,$bytes) = @_;
	$self->{completed_bytes} = $bytes;
}

sub skip_all {
	my ($self) = @_;
	return $self->{SKIP_ALL};
}

sub set_skip_all {
	my ($self,$bool) = @_;
	$self->{SKIP_ALL} = $bool;
}

1;
