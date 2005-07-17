package Filer::Constants;

require Exporter; 
our @ISA = qw(Exporter);
our @EXPORT = qw(LEFT RIGHT NORTON_COMMANDER_MODE EXPLORER_MODE COPY CUT);

use constant LEFT => 0;
use constant RIGHT => 1;

use constant NORTON_COMMANDER_MODE => 0;
use constant EXPLORER_MODE => 1;

use constant COPY => 0;
use constant CUT => 1;

1;

