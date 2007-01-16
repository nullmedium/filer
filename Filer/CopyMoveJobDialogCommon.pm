package Filer::CopyMoveJobDialogCommon;
use base qw(Filer::JobDialog);

use strict;
use warnings;

use Filer::Constants qw(:bool);

sub new {
	my ($class,$title,$label) = @_;
	my $self    = $class->SUPER::new($title,$label);

	$self->{SKIP_ALL}      = $FALSE;
	$self->{OVERWRITE_ALL} = $FALSE;

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

sub overwrite_all {
	my ($self) = @_;
	return $self->{OVERWRITE_ALL};
}

sub set_overwrite_all {
	my ($self,$bool) = @_;
	$self->{OVERWRITE_ALL} = $bool;
}

sub show_file_exists_dialog {
	my ($self,$src,$dest) = @_;

	my $dialog = Filer::FileExistsDialog->new($src,$dest);
	my $r = $dialog->run;

	if ($r == $Filer::FileExistsDialog::RENAME) {

		my $my_dest = $dialog->get_suggested_filename;

		$dialog->destroy;
		return (File::DirWalk::SUCCESS,$my_dest);

	} elsif ($r == $Filer::FileExistsDialog::OVERWRITE) {

		# do nothing. 

		$dialog->destroy;
		return (File::DirWalk::SUCCESS,$dest);

	} elsif ($r == $Filer::FileExistsDialog::SKIP) {

		$dialog->destroy;
		return (File::DirWalk::SUCCESS,$dest);

	} elsif ($r == $Filer::FileExistsDialog::OVERWRITE_ALL) {

		# do nothing. 
		$self->set_overwrite_all($TRUE);

		$dialog->destroy;
		return (File::DirWalk::SUCCESS,$dest);

	} elsif ($r == $Filer::FileExistsDialog::SKIP_ALL) {

		# next time we encounter en existing file, return SUCCESS. 
		$self->set_skip_all($TRUE);

		$dialog->destroy;
		return (File::DirWalk::SUCCESS,$dest);

	} elsif ($r eq 'cancel') {

		$dialog->destroy;
		return (File::DirWalk::ABORTED,$dest);
	}
}

1;
