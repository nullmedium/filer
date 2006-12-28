package Filer::SourceTargetDialog;
use base qw(Filer::DefaultDialog);

use warnings;
use strict;

sub new {
	my ($class,$title) = @_;

	my $self = $class->SUPER::new(
		$title,
		undef,
		'modal',
		'gtk-cancel' => 'cancel',
		'gtk-ok'     => 'ok',
	);
	$self = bless $self, $class;

	$self->set_size_request(450,150);
	$self->set_position('center');

	my $table = new Gtk2::Table(2,2);
	$table->set_homogeneous(0);
	$table->set_col_spacings(5);
	$table->set_row_spacings(1);
	$self->vbox->pack_start($table,0,0,5);

	$self->{source_label} = new Gtk2::Label;
	$self->{source_label}->set_justify('left');
	$self->{source_label}->set_use_markup(1);
	$self->{source_label}->set_alignment(0.0,0.0);
	$table->attach($self->{source_label}, 0, 1, 0, 1, [ "fill" ], [], 0, 0);

	$self->{source_entry} = new Gtk2::Entry;
	$table->attach($self->{source_entry}, 1, 2, 0, 1, [ "expand","fill" ], [], 0, 0);

	$self->{target_label} = new Gtk2::Label;
	$self->{target_label}->set_justify('left');
	$self->{target_label}->set_use_markup(1);
	$self->{target_label}->set_alignment(0.0,0.0);
	$table->attach($self->{target_label}, 0, 1, 1, 2, [ "fill" ], [], 0, 0);

	$self->{target_entry} = new Gtk2::Entry;
	$table->attach($self->{target_entry}, 1, 2, 1, 2, [ "expand","fill" ], [], 0, 0);

	$self->show_all;

	return $self;
}

sub get_source_label {
	my ($self) = @_;
	return $self->{source_label};
}

sub get_source_entry {
	my ($self) = @_;
	return $self->{source_entry};
}

sub get_target_label {
	my ($self) = @_;
	return $self->{target_label};
}

sub get_target_entry {
	my ($self) = @_;
	return $self->{target_entry};
}

1;
