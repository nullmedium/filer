use Test::Simple tests => 2;

use File::DirWalk;

ok( ref(File::DirWalk->new) eq 'File::DirWalk' ); # 1

$dw = new File::DirWalk;
$dw->onFile(sub { print $_[0], "\n"; });

ok( $dw->walk($ENV{'HOME'}) ); # 2
