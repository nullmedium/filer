#!/usr/bin/perl

#     Copyright (C) 2004-2010 Jens Luedicke <jens.luedicke@gmail.com>
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

# $Devel::Trace::TRACE = 0;

BEGIN {
	use Cwd qw(abs_path);

	$libpath = $0;
	$libpath =~ s!/[^/]+$!!;
	$libpath =~ s!/bin$!/lib/filer!;
	die "Can't find required files in $libpath" unless -e $libpath;

	$libpath = abs_path($libpath);
}

# use strict;
use warnings;

use lib "$libpath";
use Filer;

Glib->install_exception_handler(sub {
	Filer::Dialog->show_error_message($_[0]);
	return 1;
});

my $filer = new Filer;
$filer->init_config;
$filer->init_main_window;

Gtk2->main;
