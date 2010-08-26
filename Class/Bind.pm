#     Copyright (C) 2010 Jens Luedicke <jens.luedicke@gmail.com>
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program; if not, write to the Free Software
#     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package Class::Bind;
use base qw(Exporter);

use Class::Bind::Arg;

our $DEBUG = 0;

my @symbols = qw(bind _1 _2 _3 _4 _5 _6 _7 _8 _9 _10);
our @EXPORT = @symbols;

sub _1 { return Class::Bind::Arg->new(1); }
sub _2 { return Class::Bind::Arg->new(2); }
sub _3 { return Class::Bind::Arg->new(3); }
sub _4 { return Class::Bind::Arg->new(4); }
sub _5 { return Class::Bind::Arg->new(5); }
sub _6 { return Class::Bind::Arg->new(6); }
sub _7 { return Class::Bind::Arg->new(7); }
sub _8 { return Class::Bind::Arg->new(8); }
sub _9 { return Class::Bind::Arg->new(9); }
sub _10 { return Class::Bind::Arg->new(10); }

sub bind {
    my ($func, @args) = @_;

    my $functor = sub {
        my (@arguments) = @_;
        my @oldargs = @args; # do not modify @args

        foreach my $arg (@oldargs) {
            if (ref($arg) eq "Class::Bind::Arg") {

                for my $i (1..10) {
                    if ($arg->num() == $i) {
                        if ($DEBUG) {
                            print "replacing placeholder _$i => $arguments[$i-1]\n";
                        }

                        $arg = $arguments[$i-1];
                        last;
                    }
                }
            }
        }

        &{*$func}(@oldargs);
    };

    return $functor;
}

1;
