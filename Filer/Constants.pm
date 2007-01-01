package Filer::Constants;
use base qw(Exporter);

use Readonly;

my @filer = qw($LEFT $RIGHT $NORTON_COMMANDER_MODE $EXPLORER_MODE $TRUE $FALSE $UPDIR $TMPDIR $ROOTDIR $HOMEDIR $XDG_CONFIG_HOME);

my @filepane_columns = qw($COL_FILEINFO $COL_ICON $COL_NAME $COL_SIZE $COL_MODE $COL_TYPE $COL_DATE);

my @bool = qw($TRUE $FALSE);

my @mode_t = qw(
$S_IFMT  $S_IFSOCK $S_IFLNK $S_IFREG $S_IFBLK $S_IFDIR $S_IFCHR $S_IFIFO $S_ISUID $S_ISGID $S_ISVTX
$S_IRWXU $S_IRUSR $S_IWUSR $S_IXUSR
$S_IRWXG $S_IRGRP $S_IWGRP $S_IXGRP 
$S_IRWXO $S_IROTH $S_IWOTH $S_IXOTH 
);

my @stat = qw(
$STAT_DEV $STAT_INO $STAT_MODE $STAT_NLINK $STAT_UID $STAT_GID $STAT_RDEV $STAT_SIZE
$STAT_ATIME $STAT_MTIME $STAT_CTIME $STAT_BLKSIZE $STAT_BLOCKS
);

my @symbols = ();
push @symbols, @filer, @filepane_columns, @bool, @mode_t, @stat;

our @EXPORT_OK   = @symbols;
our %EXPORT_TAGS = (
	'filer'  => \@filer,
	'filepane_columns' => \@filepane_columns,
	'bool'   => \@bool,
	'mode_t' => \@mode_t,
	'stat'   => \@stat,
);

# filer constants:

Readonly $LEFT  => 0;
Readonly $RIGHT => 1;

Readonly $NORTON_COMMANDER_MODE => 0;
Readonly $EXPLORER_MODE         => 1;

Readonly $TRUE  => 1;
Readonly $FALSE => 0;

Readonly $UPDIR   => File::Spec->updir;
Readonly $TMPDIR  => File::Spec->tmpdir;
Readonly $ROOTDIR => File::Spec->rootdir;
Readonly $HOMEDIR => $ENV{'HOME'};

Readonly $XDG_CONFIG_HOME => File::BaseDir::xdg_config_home;

# filepane constants:

Readonly $COL_FILEINFO => 0;
Readonly $COL_ICON     => 1;
Readonly $COL_NAME     => 2;
Readonly $COL_SIZE     => 3;
Readonly $COL_TYPE     => 4;
Readonly $COL_MODE     => 5;
Readonly $COL_DATE     => 6;

# stat constants:

Readonly $S_IFMT   => 00170000;
Readonly $S_IFSOCK => 0140000;
Readonly $S_IFLNK  => 0120000;
Readonly $S_IFREG  => 0100000;
Readonly $S_IFBLK  => 0060000;
Readonly $S_IFDIR  => 0040000;
Readonly $S_IFCHR  => 0020000;
Readonly $S_IFIFO  => 0010000;
Readonly $S_ISUID  => 0004000;
Readonly $S_ISGID  => 0002000;
Readonly $S_ISVTX  => 0001000;

Readonly $S_IRWXU => 00700;
Readonly $S_IRUSR => 00400;
Readonly $S_IWUSR => 00200;
Readonly $S_IXUSR => 00100;

Readonly $S_IRWXG => 00070;
Readonly $S_IRGRP => 00040;
Readonly $S_IWGRP => 00020;
Readonly $S_IXGRP => 00010;

Readonly $S_IRWXO => 00007;
Readonly $S_IROTH => 00004;
Readonly $S_IWOTH => 00002;
Readonly $S_IXOTH => 00001;

Readonly $STAT_DEV     => 0;
Readonly $STAT_INO     => 1;
Readonly $STAT_MODE    => 2;
Readonly $STAT_NLINK   => 3;
Readonly $STAT_UID     => 4;
Readonly $STAT_GID     => 5;
Readonly $STAT_RDEV    => 6;
Readonly $STAT_SIZE    => 7;
Readonly $STAT_ATIME   => 8;
Readonly $STAT_MTIME   => 9;
Readonly $STAT_CTIME   => 10;
Readonly $STAT_BLKSIZE => 11;
Readonly $STAT_BLOCKS  => 12;

1;
