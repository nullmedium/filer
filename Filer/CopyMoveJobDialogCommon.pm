package Filer::CopyMoveJobDialogCommon;
use base qw(Exporter);
use Class::Std::Utils;

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

my %total_bytes;
my %completed_bytes;
my %timeout;

sub show_job_dialog {
	my ($self) = @_;
	$self->show_all;

	$timeout{ident $self} = Glib::Timeout->add(100, sub {
		return 0 if ($self->cancelled);
		return 1 if ($self->total_bytes == 0);

		$self->update_progressbar($self->completed_bytes/$self->total_bytes);
		return 1;
	});
}

sub destroy_job_dialog {
	my ($self) = @_;
	$self->destroy;
	Glib::Source->remove($timeout{ident $self});

	delete $timeout{ident $self};
	delete $total_bytes{ident $self};
	delete $completed_bytes{ident $self};
}

sub total_bytes {
	my ($self) = @_;
	return $total_bytes{ident $self};
}

sub set_total_bytes {
	my ($self,$bytes) = @_;
	$total_bytes{ident $self} = $bytes;
}

sub completed_bytes {
	my ($self) = @_;
	return $completed_bytes{ident $self};
}

sub set_completed_bytes {
	my ($self,$bytes) = @_;
	$completed_bytes{ident $self} = $bytes;
}

sub update_written_bytes {
	my ($self,$bytes) = @_;
	$completed_bytes{ident $self} += $bytes;
}

1;
