package Filer::DefaultDialog;
use base qw(Gtk2::Dialog);

sub new {
	my ($class,$title) = @_;

	my $self = $class->SUPER::new(
		$title,
		undef,
		'modal',
		'gtk-cancel' => 'cancel',
		'gtk-ok'     => 'ok'
	);

	$self = bless $self, $class;
	
	$self->set_size_request(450,150);
	$self->set_position('center');
	$self->set_default_response('ok');

	return $self;
}

1;
