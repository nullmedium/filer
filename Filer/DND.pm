#     Copyright (C) 2004-2005 Jens Luedicke <jens.luedicke@gmail.com>
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

package Filer::FilePaneDND;
use Class::Std::Utils;

use strict;
use warnings;

use Readonly; 

use Filer::Constants;

Readonly my $TARGET_URI_LIST => 0;

my %filer;
my %config;
my %filepane;

sub new {
	my ($class,$filer,$filepane) = @_;
	my $self = bless anon_scalar(), $class;

	$filer{ident $self}    = $filer;
	$config{ident $self}   = $filer{ident $self}->get_config;
	$filepane{ident $self} = $filepane;

	return $self;
}

sub DESTROY {
	my $self = shift;

	delete $filer{ident $self};
	delete $config{ident $self};
	delete $filepane{ident $self};
}

sub target_table {
	{'target' => "text/uri-list", 'flags' => [], 'info' => $TARGET_URI_LIST};
}

sub drag_begin {
	my $self = shift;
	my ($widget,$context) = @_;

	$context->status('move',);
}

sub drag_data_get {
	my $self = shift;
	my ($widget,$context,$data,$info,$time) = @_;

	if ($info == $TARGET_URI_LIST) {
		if ($filepane{ident $self}->count_items > 0) {
			my $d = join "\r\n", @{$filepane{ident $self}->get_uri_list};
			$data->set($data->target, 8, $d);
		}
	}

	return 1;
}

sub drag_data_received {
	my $self = shift;
	my ($widget,$context,$x,$y,$data,$info,$time) = @_;

	if (($data->length >= 0) && ($data->format == 8)) {
		my $action      = $context->action;
		my $active_pane = $filer{ident $self}->get_active_pane;
		my ($p)         = $widget->get_dest_row_at_pos($x,$y);
		my $path;

		my @items       = map {	URI->new($_)->path; } split(/\r\n/, $data->data);
		my $items_count = scalar @items;

		if (defined $p) {
			$path = $filepane{ident $self}->get_path_by_treepath($p);
# 		} else {
# 			$path = $filepane{ident $self}->get_pwd;
# 		}
# 
#  		if (! -d $path) {
# 			$path = $filepane{ident $self}->get_pwd;
		}
t
#		return if ($path eq $active_pane->get_pwd);

		if (($config{ident $self}->get_option("ConfirmCopy") == $TRUE)
		 or ($config{ident $self}->get_option("ConfirmMove") == $TRUE)) {
			my $do = ($action eq "copy") ? "Copy" : "Move";

			if ($items_count == 1) {
				my $f = $items[0];
				$f =~ s/&/&amp;/g; # sick fix. meh.
				$f = File::Basename::basename($f);

				return if (Filer::Dialog->yesno_dialog("$do \"$f\" to $path?") eq 'no');
			} else {
				return if (Filer::Dialog->yesno_dialog("$do $items_count files to $path?") eq 'no');
			}
		}
		
		if ($action eq "copy") {
			my $copy = new Filer::Copy;
			$copy->copy(\@items,$path);

		} elsif ($action eq "move") {
			my $move = new Filer::Move;
			$move->move(\@items,$path);
		}

#		$filer{ident $self}->refresh_cb;
	}

	$context->finish (0, 0, $time);
}

sub drag_motion {
	my $self = shift;
	my ($widget,$context,$x,$y,$time,$data) = @_;
	my $action = $context->action;

	my ($p) = $widget->get_dest_row_at_pos($x,$y);
	my $path;

	if (defined $p) {
		$path = $filepane{ident $self}->get_path_by_treepath($p);

		if (-d $path) {
			$context->status('move',$time);
			return $TRUE;
		} else {
			$context->status([],$time);
			return $FALSE;
		}
	}

	return $FALSE;
}

1;
