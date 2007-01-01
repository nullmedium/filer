package Filer::MimeTypeHandler;

use Filer::Constants qw(:filer);

use YAML::Syck qw(LoadFile DumpFile);

sub new {
	my ($class) = @_;
	my $self = bless {}, $class;

	$self->{mimefile} = Filer::Tools->catpath($XDG_CONFIG_HOME, "filer", "mime-2.yml");

	return $self;
}

sub get_mimetype_handler {
	my ($self,$mimetype) = @_;

	if (-e $self->{mimefile}) {
		my $mime = LoadFile($self->{mimefile});
		return $mime->{$mimetype};	
	}

	return undef;
}

sub set_mimetype_handler {
	my ($self,$mimetype,$handler) = @_;

	my $mime = {};

	if (-e $self->{mimefile}) {
		$mime = LoadFile($self->{mimefile});
	}

	$mime->{$mimetype} = $handler;	

	DumpFile($self->{mimefile}, $mime);
}

sub add_mimetype_handler {
	my ($self,$mimetype,$handler) = @_;
	my $mime = {};

	if (-e $self->{mimefile}) {
		$mime = LoadFile($self->{mimefile});
	}

	push @{$mime->{$mimetype}}, $handler;	

	DumpFile($self->{mimefile}, $mime);

}

1;
