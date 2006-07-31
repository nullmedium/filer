package Filer::JobDialog;
use base qw(Gtk2::Dialog);
use Class::Std::Utils;

use strict;
use warnings;

use Filer::Constants;

my %CANCELLED;
my %progress_label;	
my %progressbar;	

sub new {
	my ($class,$title,$label_text) = @_;

	my $self = $class->SUPER::new($title, undef, 'modal');
	$self    = bless $self, $class;

	$self->set_has_separator(1);
	$self->set_size_request(450,150);
	$self->set_position('center');
	$self->set_modal(1);

	my $hbox = Gtk2::HBox->new(0,0);
	$self->vbox->pack_start($hbox,0,0,5);

	my $label = Gtk2::Label->new($label_text);
	$label->set_justify('left');
	$label->set_use_markup(1);
	$label->set_alignment(0.0,0.0);
	$hbox->pack_start($label,0,0,0);

	$progress_label{ident $self} = Gtk2::Label->new();
	$progress_label{ident $self}->set_alignment(0.0,0.0);
	$progress_label{ident $self}->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
	$hbox->pack_start($progress_label{ident $self},1,1,0);

	$progressbar{ident $self} = new Gtk2::ProgressBar;
	$self->vbox->pack_start($progressbar{ident $self},0,1,0);

	my $button = $self->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->set_cancelled($TRUE);
		$self->destroy;
	});

	$self->set_cancelled($FALSE);
	
	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $CANCELLED{ident $self};
	delete $progress_label{ident $self};	
	delete $progressbar{ident $self};	
}

sub show_job_dialog {
	my ($self) = @_;
	$self->show_all;
}

sub destroy_job_dialog {
	my ($self) = @_;
	$self->destroy;
}

sub cancelled {
	my ($self) = @_;
	return $CANCELLED{ident $self};
}

sub set_cancelled {
	my ($self,$cancel) = @_;
	$CANCELLED{ident $self} = $cancel;
}

sub update_progress_label {
	my ($self,$str) = @_;
	$progress_label{ident $self}->set_text($str);
	while (Gtk2->events_pending) { Gtk2->main_iteration; }
}

sub update_progressbar {
	my ($self,$fraction) = @_;

	$progressbar{ident $self}->set_text(sprintf("%.0f", ($fraction * 100)) . "%");
	$progressbar{ident $self}->set_fraction($fraction);

	while (Gtk2->events_pending) { Gtk2->main_iteration; }
}

1;
