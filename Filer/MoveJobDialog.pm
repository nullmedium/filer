package Filer::MoveJobDialog;
use base qw(Filer::CopyMoveJobDialogCommon);

use strict;
use warnings;

sub new {
	my ($class) = @_;
	my $self    = $class->SUPER::new("Moving ...","<b>Moving: \nto: </b>");

	return $self;
}

1;
