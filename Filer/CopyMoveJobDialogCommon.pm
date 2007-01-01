package Filer::CopyMoveJobDialogCommon;
use base qw(Filer::JobDialog);

use strict;
use warnings;

use Filer::Constants qw(:bool);

sub new {
	my ($class,$title,$label) = @_;
	my $self    = $class->SUPER::new($title,$label);

	$self->{SKIP_ALL} = $FALSE;

	return $self;
}

sub skip_all {
	my ($self) = @_;
	return $self->{SKIP_ALL};
}

sub set_skip_all {
	my ($self,$bool) = @_;
	$self->{SKIP_ALL} = $bool;
}

1;
