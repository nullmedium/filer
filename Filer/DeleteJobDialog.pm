package Filer::DeleteJobDialog;
use base qw(Filer::JobDialog);
use Class::Std::Utils;

use strict;
use warnings;

use Filer::Constants;

my %deleted_files;
my %total_files;
my %timeout;

sub new {
	my ($class) = @_;
	my $self    = $class->SUPER::new("Deleting ...","<b>Deleting:</b> ");

	$deleted_files{ident $self} = 0;
	$total_files{ident $self}   = 0;

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $deleted_files{ident $self};
	delete $total_files{ident $self};
}

sub show_job_dialog {
	my ($self) = @_;
	$self->show_all;

	$timeout{ident $self} = Glib::Timeout->add(100, sub {
		return 0 if ($self->cancelled);
		return 1 if ($self->total_files == 0);

		$self->update_progressbar($self->deleted_files/$self->total_files);
		return 1;
	});
}

sub destroy_job_dialog {
	my ($self) = @_;
	$self->destroy;
	Glib::Source->remove($timeout{ident $self});
}

sub total_files {
	my ($self) = @_;
	return $total_files{ident $self};
}

sub set_total_files {
	my ($self,$count) = @_;
	$total_files{ident $self} = $count;
}

sub deleted_files {
	my ($self) = @_;
	return $deleted_files{ident $self};
}

sub set_deleted_files {
	my ($self,$files) = @_;
	$deleted_files{ident $self} = $files;
}

1;
