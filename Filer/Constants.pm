package Filer::Constants;

require Exporter; 
our @ISA = qw(Exporter);
our @EXPORT = qw(LEFT RIGHT NORTON_COMMANDER_MODE EXPLORER_MODE TRUE FALSE UPDIR TMPDIR);

use constant LEFT => 0;
use constant RIGHT => 1;

use constant NORTON_COMMANDER_MODE => 0;
use constant EXPLORER_MODE => 1;

use constant TRUE => 1;
use constant FALSE => 0;

use constant UPDIR => File::Spec->updir;
use constant TMPDIR => File::Spec->tmpdir;

1;
