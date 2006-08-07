package Filer::MoveJobDialog;
use base qw(Filer::CopyMoveJobDialogCommon Filer::JobDialog);

use strict;
use warnings;

use Filer::Constants;

sub new {
	my ($class) = @_;
	my $self    = $class->SUPER::new("Moving ...","<b>Moving: \nto: </b>");

	$self->set_total_bytes(0);
	$self->set_completed_bytes(0);

	return $self;
}

1;
