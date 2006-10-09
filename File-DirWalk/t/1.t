use Test::Simple tests => 6;

use File::Basename;
use File::DirWalk;

my $perl_path        = dirname($^X);
my $perl_interpreter = basename($^X);

ok( ref(File::DirWalk->new) eq 'File::DirWalk' ); # 1

$dw = new File::DirWalk;

$dw->onDirEnter(sub {
	my ($path) = @_;

	if ($path eq $perl_path) {
		return FAILED;
	}
		
	return SUCCESS;
});

ok( $dw->walk($perl_path) == FAILED ); # 2

$dw->onBeginWalk(sub {
	my ($path) = @_;
	if (dirname($path) eq $dw->currentDir) {
		return ABORTED;
	}

	return SUCCESS;
});

ok( $dw->walk($perl_path) == ABORTED ); # 3

$dw->onBeginWalk(sub {
	my ($path) = @_;
	if ($path eq $dw->currentPath) {
		return ABORTED;
	}

	return SUCCESS;
});

ok( $dw->walk($perl_path) == ABORTED ); # 4

$dw->onFile(sub {
	my ($path) = @_;

	if (basename($path) eq $perl_interpreter) {
		return ABORTED;
	}

	return SUCCESS;
});

ok( $dw->walk($perl_path) == ABORTED ); # 5

$dw->onFile(sub {
	my ($path) = @_;
	
	if (basename($path) eq "1.t") {
		return ABORTED;
	}

	return SUCCESS;
});

ok( $dw->walk($0) == ABORTED ); # 6

# $dw->setCustomResponse('FOOBAR', -20);
# ok( $dw->getCustomResponse('FOOBAR') == -20); # 7
# 
# $dw->onBeginWalk(sub {
# 	my ($path) = @_;
# 
# 	if ($path eq $ENV{'HOME'}) {
# 		return $dw->getCustomResponse('FOOBAR');
# 	}
# 
# 	return FAILED;	
# });
# 
# ok( $dw->walk($ENV{'HOME'}) == $dw->getCustomResponse('FOOBAR') ); # 8
# 
# $dw->setCustomResponse('WOMBAT', -42);
# ok( $dw->getCustomResponse('FOOBAR') != $dw->getCustomResponse('WOMBAT') ); # 9
