# Copyright (c) 2005 Jens Luedicke <jensl@cpan.org>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package File::DirWalk;
use base qw(Exporter);
use Class::Std::Utils;

our $VERSION = '0.3';
our @EXPORT = qw(FAILED SUCCESS ABORTED PRUNE);

use strict;
use warnings;

use Readonly;

use File::Basename;
use File::Spec;

use constant SUCCESS 	=> 1;
use constant FAILED 	=> 0;
use constant ABORTED 	=> -1;
use constant PRUNE 	=> -10;

my %onBeginWalk;
my %onLink;
my %onFile;
my %onDirEnter;
my %onDirLeave;

sub new {
	my ($class) = @_;
	my $self = bless anon_scalar(), $class;

	$onBeginWalk{ident $self} = sub { SUCCESS };
	$onLink{ident $self}      = sub { SUCCESS };
	$onFile{ident $self}      = sub { SUCCESS };
	$onDirEnter{ident $self}  = sub { SUCCESS };
	$onDirLeave{ident $self}  = sub { SUCCESS };

	return $self;
}

sub DESTROY {
	my ($self) = @_;

	delete $onBeginWalk{ident $self};
	delete $onLink{ident $self};     
	delete $onFile{ident $self};     
	delete $onDirEnter{ident $self};
	delete $onDirLeave{ident $self};
}

sub onBeginWalk {
	my ($self,$func) = @_;
	$onBeginWalk{ident $self} = $func;
}

sub onLink {
	my ($self,$func) = @_;
	$onLink{ident $self} = $func;
}

sub onFile {
	my ($self,$func) = @_;
	$onFile{ident $self} = $func;
}

sub onDirEnter {
	my ($self,$func) = @_;
	$onDirEnter{ident $self} = $func;
}

sub onDirLeave {
	my ($self,$func) = @_;
	$onDirLeave{ident $self} = $func;
}

sub walk {
	my ($self,$path) = @_;

	if ((my $r = $onBeginWalk{ident $self}->($path)) != SUCCESS) {
		return $r;
	}

	if (-l $path) {

		if ((my $r = $onLink{ident $self}->($path)) != SUCCESS) {
			return $r;
		}

	} elsif (-d $path) {

		if ((my $r = $onDirEnter{ident $self}->($path)) != SUCCESS) {
			return $r;
		}

		opendir my $dirh, $path || return FAILED;
		my @dir_contents = readdir $dirh;
		@dir_contents = File::Spec->no_upwards(@dir_contents);

		foreach my $f (@dir_contents) {
			# be portable.
			my @dirs = File::Spec->splitdir($path);
			my $path = File::Spec->catfile(@dirs, $f);

			my $r = $self->walk($path);

			if ($r == PRUNE) {
				last;
			} elsif ($r != SUCCESS) {
				return $r;
			}
		}

		closedir $dirh;

		if ((my $r = $onDirLeave{ident $self}->($path)) != SUCCESS) {
			return $r;
		}
	} else {
		if ((my $r = $onFile{ident $self}->($path)) != SUCCESS) {
			return $r;
		}
	}

	return SUCCESS;
}

1;

=head1 NAME

File::DirWalk - walk through a directory tree and run own code

=head1 SYNOPSIS

Walk through your homedir and print out all filenames:

	use File::DirWalk;

	my $dw = new File::DirWalk; $dw->onFile(sub {
		my ($file) = @_;
		print "$file\n";

		return File::DirWalk::SUCCESS;
	});

	$dw->walk($ENV{'HOME'});

=head1 DESCRIPTION

This module can be used to walk through a directory tree and run own functions
on files, directories and symlinks.

=head1 METHODS

=over 4

=item C<new()>

Create a new File::DirWalk object

=item C<onBeginWalk(\&func)>

Specify a function to be be run on beginning of a walk. It is called each time
the C<walk> method is called. The directory-name is passed to the given
function. Function must return true.

=item C<onLink(\&func)>

Specify a function to be run on symlinks. The symlink-filename is passed to the
given function. Function must return true.

=item C<onFile(\&func)>

Specify a function to be run on regular files. The filename is passed to the
given function when called. Function must return true.

=item C<onDirEnter(\&func)>

Specify a function to be run before entering a directory. The directory-name is
passed to the given function when called. Function must return true.

=item C<onDirLeave(\&func)>

Specify a function to be run on leaving directory. The directory-name is passed
to the given function when called. Function must return true.

=item C<onForEach(\&func)>

Specify a function to be run on each file/directory within another directory.
The name is passed to the function when called. Function must return true.

=item C<walk($path)>

Begin the walk through the given directory tree. This method returns if the walk
is finished or if one of the callbacks doesn't return true.

=back

All callback-methods expect a function reference as their argument. The
directory- or filename  is passed to the function as the argument when called.
The function must return true, otherwise the recursive walk is aborted and
C<walk> returns. You don't need to define a callback if you don't need to.

The module provides the following constants: SUCCESS, FAILED and ABORTED (1, 0
and -1) which you can use within your callback code.

=head1 BUGS

Please mail the author if you encounter any bugs.

=head1 AUTHOR

Jens Luedicke E<lt>jensl@cpan.orgE<gt> web: L<http://perldude.de/>

=head1 CHANGES

Version 0.2: platform portability fixes and more documentation

Version 0.1: first CPAN release

=head1 HISTORY

I wrote DirWalk.pm module for use within my 'Filer' file manager as a directory
traversing backend and I thought it might be useful for others. It is my first
CPAN module.

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2005 Jens Luedicke. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

