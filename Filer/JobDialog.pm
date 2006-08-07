package Filer::JobDialog;
use base qw(Gtk2::Dialog);

use strict;
use warnings;

use Filer::Constants;

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

	$self->{progress_label} = Gtk2::Label->new();
	$self->{progress_label}->set_alignment(0.0,0.0);
	$self->{progress_label}->set_ellipsize('PANGO_ELLIPSIZE_MIDDLE');
	$hbox->pack_start($self->{progress_label},1,1,0);

	$self->{progressbar} = new Gtk2::ProgressBar;
	$self->vbox->pack_start($self->{progressbar},0,1,0);

	my $button = $self->add_button('gtk-cancel' => 'cancel');
	$button->signal_connect("clicked", sub {
		$self->set_cancelled($TRUE);
		$self->destroy;
	});

	$self->set_cancelled($FALSE);
	
	return $self;
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
	return $self->{CANCELLED};
}

sub set_cancelled {
	my ($self,$cancel) = @_;
	$self->{CANCELLED} = $cancel;
}

sub update_progress_label {
	my ($self,$str) = @_;
	$self->{progress_label}->set_text($str);
	while (Gtk2->events_pending) { Gtk2->main_iteration; }
}

sub update_progressbar {
	my ($self,$fraction) = @_;

	$self->{progressbar}->set_text(sprintf("%.0f", ($fraction * 100)) . "%");
	$self->{progressbar}->set_fraction($fraction);

	while (Gtk2->events_pending) { Gtk2->main_iteration; }
}

1;
