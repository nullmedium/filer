package Filer::DeleteJobDialog;
use base qw(Filer::JobDialog);

use strict;
use warnings;

sub new {
	my ($class) = @_;
	my $self    = $class->SUPER::new("Deleting ...","<b>Deleting:</b> ");

	return $self;
}

1;
