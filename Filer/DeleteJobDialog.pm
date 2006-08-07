package Filer::DeleteJobDialog;
use base qw(Filer::JobDialog);

use strict;
use warnings;

use Filer::Constants;

sub new {
	my ($class) = @_;
	my $self    = $class->SUPER::new("Deleting ...","<b>Deleting:</b> ");

	$self->{deleted_files} = 0;
	$self->{total_files}   = 0;

	return $self;
}

sub show_job_dialog {
	my ($self) = @_;
	$self->show_all;

# 	$self->{timeout} = Glib::Timeout->add(200, sub {
# 		return 0 if ($self->cancelled);
# 		return 1 if ($self->total_files == 0);
# 
# 		$self->update_progressbar($self->deleted_files/$self->total_files);
# 		return 1;
# 	});
}

sub destroy_job_dialog {
	my ($self) = @_;
	$self->destroy;
# 	Glib::Source->remove($self->{timeout});
}

sub total_files {
	my ($self) = @_;
	return $self->{total_files};
}

sub set_total_files {
	my ($self,$count) = @_;
	$self->{total_files} = $count;
}

sub deleted_files {
	my ($self) = @_;
	return $self->{deleted_files};
}

sub set_deleted_files {
	my ($self,$files) = @_;
	$self->{deleted_files} = $files;
}

1;
