package Filer::Constants;
use base qw(Exporter);

use Readonly;

our @EXPORT = qw($LEFT $RIGHT $NORTON_COMMANDER_MODE $EXPLORER_MODE $TRUE $FALSE $UPDIR $TMPDIR $ROOTDIR $HOMEDIR $XDG_CONFIG_HOME);

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

1;
