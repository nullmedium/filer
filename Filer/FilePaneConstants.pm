package Filer::FilePaneConstants;
use base qw(Exporter);

use Readonly;

our @EXPORT = qw(
$COL_FILEINFO
$COL_ICON
$COL_NAME
$COL_SIZE
$COL_MODE
$COL_TYPE
$COL_DATE
);

# constants:

Readonly $COL_FILEINFO => 0;
Readonly $COL_ICON     => 1;
Readonly $COL_NAME     => 2;
Readonly $COL_SIZE     => 3;
Readonly $COL_MODE     => 4;
Readonly $COL_TYPE     => 5;
Readonly $COL_DATE     => 6;

1;
