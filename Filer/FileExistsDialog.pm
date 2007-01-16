package Filer::FileExistsDialog;
use base qw(Gtk2::Dialog);

use warnings;
use strict;
use Readonly;

use Filer::Constants qw(:bool); 

our $RENAME	   = 1;
our $OVERWRITE	   = 2;
our $OVERWRITE_ALL = 3;
our $SKIP	   = 4;
our $SKIP_ALL	   = 5;

sub new {
	my ($class,$file_src,$file_dest) = @_;

	my $self = $class->SUPER::new(
		"File Already Exists",
		undef,
		'modal',
		"Rename"        => $RENAME,
		"Overwrite"     => $OVERWRITE,
		"Skip"          => $SKIP,
		"Overwrite All" => $OVERWRITE_ALL,
		"Skip All"      => $SKIP_ALL,
		"gtk-cancel"    => 'cancel',
	);
	$self = bless $self, $class;

	$self->{fi_src}   = Filer::FileInfo->new($file_src);
	$self->{fi_dest}  = Filer::FileInfo->new($file_dest);
	
	($self->action_area->get_children)[5]->set_sensitive(0);

	$self->set_position('center');

	my $label = Gtk2::Label->new;
	$label->set_use_markup(1);
	$label->set_markup(
		"A similar " . (($self->{fi_dest}->is_dir) ? ("directory") : ("file")) . " named '$file_dest' already exists.\n" .
		"  size " . $self->{fi_dest}->get_size . "\n" .
		"  modified on " . $self->{fi_dest}->get_mtime . "\n" 	
	);
	$label->set_alignment(0.0,0.0);
	$self->vbox->pack_start($label, $TRUE, $TRUE, 5);

	$label = Gtk2::Label->new;
	$label->set_use_markup(1);
	$label->set_markup(
		"The source " . (($self->{fi_src}->is_dir) ? ("directory") : ("file"))  . " is '$file_src'\n" .
		"  size " . $self->{fi_dest}->get_size . "\n" .
		"  modified on " . $self->{fi_dest}->get_mtime . "\n" 	
	);
	$label->set_alignment(0.0,0.0);
	$self->vbox->pack_start($label, $TRUE, $TRUE, 5);

	my $hbox = Gtk2::HBox->new(0,0);
	$self->vbox->pack_start($hbox, $TRUE, $TRUE, 5);

	$self->{entry} = Gtk2::Entry->new;
	$self->{entry}->set_text($self->{fi_src}->get_basename);
	$self->{entry}->signal_connect(changed => sub {
		my $file = $self->get_suggested_filename;

		my @buttons = $self->action_area->get_children;
		my $button  = $buttons[5];
		
		if (-e $file) {
			$button->set_sensitive(0);
		} else {
			$button->set_sensitive(1);
		}
	});
	$hbox->pack_start($self->{entry}, $TRUE, $TRUE, 5);

	my $button = Gtk2::Button->new("Suggest New Name");
	$button->signal_connect(clicked => sub {
		my $str = Filer::Tools->suggest_filename_helper($file_dest);
		$self->{entry}->set_text(File::Basename::basename($str));
	});
	$hbox->pack_start($button, $TRUE, $TRUE, 5);

	$self->show_all;
	return $self;
}

sub get_suggested_filename {
	my ($self) = @_;
	return Filer::Tools->catpath($self->{fi_dest}->get_dirname, $self->{entry}->get_text);
}

1;
