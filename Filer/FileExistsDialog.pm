package Filer::FileExistsDialog;
use base qw(Gtk2::Dialog);

use warnings;
use strict;

our $RENAME    = 1;
our $OVERWRITE = 2;
our $SKIP      = 3;
our $SKIP_ALL  = 4;

sub new {
	my ($class,$file_src,$file_dest) = @_;

	my $self = $class->SUPER::new(
		"File Already Exists",
		undef,
		'modal',
		"Skip"        => $SKIP,
		"Skip All"    => $SKIP_ALL,
		"Rename"      => $RENAME,
		"Overwrite"   => $OVERWRITE,
		"gtk-cancel"  => 'cancel',
	);
	$self = bless $self, $class;

	$self->{fi_src}   = Filer::FileInfo->new($file_src);
	$self->{fi_dest}  = Filer::FileInfo->new($file_dest);
	
	($self->action_area->get_children)[2]->set_sensitive(0);

	$self->set_position('center');

	my $label = Gtk2::Label->new;
	$label->set_use_markup(1);
	$label->set_markup(
		"A similar file named '$file_dest' already exists.\n" .
		"  size " . $self->{fi_dest}->get_size . "\n" .
		"  modified on " . $self->{fi_dest}->get_mtime . "\n" 	
	);
	$label->set_alignment(0.0,0.0);
	$self->vbox->pack_start($label, 1,1,5);

	$label = Gtk2::Label->new;
	$label->set_use_markup(1);
	$label->set_markup(
		"The source file is '$file_src'\n" .
		"  size " . $self->{fi_dest}->get_size . "\n" .
		"  modified on " . $self->{fi_dest}->get_mtime . "\n" 	
	);
	$label->set_alignment(0.0,0.0);
	$self->vbox->pack_start($label, 1,1,5);

	my $hbox = Gtk2::HBox->new(0,0);
	$self->vbox->pack_start($hbox, 1,1,5);

	$self->{entry} = Gtk2::Entry->new;
	$self->{entry}->set_text($self->{fi_src}->get_basename);
	$self->{entry}->signal_connect(changed => sub {
		my $file = $self->get_suggested_filename;

		my @buttons = $self->action_area->get_children;
		my $button  = $buttons[2];
		
		if (-e $file) {
			$button->set_sensitive(0);
		} else {
			$button->set_sensitive(1);
		}
	});
	$hbox->pack_start($self->{entry}, 1,1,5);

	my $button = Gtk2::Button->new("Suggest New Name");
	$button->signal_connect(clicked => sub {
		my $str = Filer::Tools->suggest_filename_helper($file_dest);
		$self->{entry}->set_text(File::Basename::basename($str));
	});
	$hbox->pack_start($button, 1,1,5);

	$self->show_all;
	return $self;
}

sub get_suggested_filename {
	my ($self) = @_;

	return Filer::Tools->catpath($self->{fi_dest}->get_dirname, $self->{entry}->get_text);
}

1;
