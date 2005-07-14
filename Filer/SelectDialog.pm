package Filer::SelectDialog; 

use constant SELECT => 0;
use constant UNSELECT => 1;

use Filer;
use Filer::Constants;
use Filer::FilePane;

sub new {
	my ($class,$type) = @_;
	my $self = bless {}, $class;

	my ($dialog,$hbox,$label,$entry);

	$dialog = new Gtk2::Dialog("", undef, 'modal', 'gtk-cancel' => 'cancel', 'gtk-ok' => 'ok');
	$dialog->set_default_response('ok');
	$dialog->set_has_separator(1);
	$dialog->set_position('center');
	$dialog->set_modal(1);

	$hbox = new Gtk2::HBox(0,0);
	$dialog->vbox->pack_start($hbox,0,1,5);

	$label = new Gtk2::Label;
	$hbox->pack_start($label,0,0,0);

	$entry = new Gtk2::Entry;
	$entry->set_activates_default(1);
	$entry->set_text("*");
	$hbox->pack_start($entry,0,0,0);

	if ($type == SELECT) {
		$dialog->set_title("Select Files");
		$label->set_text("Select: ");
	} else {
		$dialog->set_title("Unselect Files");
		$label->set_text("Unselect: ");
	}

	$dialog->show_all;

	if ($dialog->run eq 'ok') {
		my $mypane = $active_pane;
		my $selection = $mypane->get_treeview->get_selection;
		my $str = $entry->get_text;
#		my $bx = (split //, $str)[0];

		$str =~ s/\//\\\//g;
		$str =~ s/\./\\./g;
		$str =~ s/\*/\.*/g;
		$str =~ s/\?/\./g;

		$mypane->get_treeview->get_model->foreach(sub {
			my $model = $_[0];
			my $iter = $_[2];
			my $item = $model->get($iter, Filer::FilePane->COL_NAME);

			return 0 if ($item eq "..");

# 			if (-d $mypane->get_path($item)) {
# 				if ($bx eq '/') {
# 					$item = "/$item";
# 				} else {
# 					return 0;
# 				}
# 			}

			if ($item =~ /\A$str\Z/)  {
				if ($type == SELECT) {
					$selection->select_iter($iter);
				}

				if ($type == UNSELECT) {
					$selection->unselect_iter($iter);
				}
			}
		});
	}

	$dialog->destroy;
}

1;

