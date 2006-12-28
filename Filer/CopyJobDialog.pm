package Filer::CopyJobDialog;
use base qw(Filer::CopyMoveJobDialogCommon);

use strict;
use warnings;

use Filer::Constants;

sub new {
	my ($class) = @_;
	my $self    = $class->SUPER::new("Copying ...","<b>Copying: \nto: </b>");

	return $self;
}

1;
