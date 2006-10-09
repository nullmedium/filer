package Filer::Monitor;

use warnings;
use strict;

use Sys::Gamin;

my %fm;
my %timeout;
my %filepath;
my %filepane;
my %block;

sub new {
	my ($class,$pane) = @_;
	my $self = bless {}, $class;

	$self->{filepane} = $pane;
	$self->{filepath} = $pane->get_pwd;

	$self->{fm} = Sys::Gamin->new;
	$self->{fm}->monitor($self->{filepath});

	return $self;
}

sub start_monitoring {
	my ($self) = @_;

	$self->{filepath} = $self->{filepane}->get_pwd;
	$self->{fm}->monitor($self->{filepath});

	$self->{timeout} = Glib::Timeout->add(750, sub {
		$self->check_filepath_changed;

		while ($self->{fm}->pending) {

			my $event = $self->{fm}->next_event;
			my $type  = $event->type;

			if (($type =~ /change|create|move|delete/)) {
			 	print "DEBUG $self $type ", $event->filename, "\n";
				$self->{filepane}->refresh;
			 }
		}

		return 1;
	});

}

sub stop_monitoring {
	my ($self) = @_;

	Glib::Source->remove($self->{timeout});
	$self->{fm}->cancel($self->{filepath});
}

sub check_filepath_changed {
	my ($self) = @_;

	return 0 if ($self->{filepath} eq $self->{filepane}->get_pwd);	

	if ($self->{fm}->monitored($self->{filepath})) {
		$self->{fm}->cancel($self->{filepath});
	}

	$self->{filepath} = $self->{filepane}->get_pwd;
	$self->{fm}->monitor($self->{filepath});
	
	return 1;
}

sub DESTROY {
	my ($self) = @_;
	
	print "DEBUG: $self DESTROY\n";

	Glib::Source->remove($self->{timeout});
}

1;
