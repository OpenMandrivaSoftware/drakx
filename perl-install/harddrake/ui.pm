package harddrake::ui;

use strict;

use harddrake::data;
use common;
use interactive;
use Gtk;
#use MDK::Common;

my @menu_items = ( { path => _("/_File"), type => '<Branch>' },
			    { path => _("/_File")._("/_Quit"), accelerator => _("<control>Q"), callback => \&quit_global	},
			    { path => _("/_Help"),type => '<Branch>' },
			    { path => _("/_Help")._("/_Help..."), callback => \&help },
			    { path => _("/_Help")._("/_About..."), callback => \&about_harddrake },
			    );

my %fields = ( "bus" => _("Bus"),
			"driver" => _("Module"),
			"media_type" => _("Media class"),
			"description" => _("Description"),
			"bus_id" => _("Bus identification"),
			"bus_location" => _("Location on the bus"),
			"info" => "Hardware id",
			"device" => "Device file",
			"nbuttons" => "Number of buttons",
#			"MOUSETYPE" => "Type of mouse (gpm)",
#			"XMOUSETYPE" => "Type of mouse (X11)",
			"name" => "Name",
			);



my $in;

sub run {
    my ($class) = @_;
    $in = 'interactive'->vnew('su', 'default');
    $::isStandalone=1;
    Gtk->init;
    my $window = $class->new;
    $window->set_position('center');
    $window->show;
    Gtk->main;
    $window->destroy;
}

my $license ='Copyright (C) 1999-2002 MandrakeSoft by tvignaud@mandrakesoft.com

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
';


sub new {
    my ($statusbar, $accel_group, $menu, $main_win, $widget, $config_button,
	   $menubar, $main_vbox, $vbox, $tree, $text, %reverse_fields, $wait,
	   $frame, $module_cfg_button, $vscrollbar,$pid,$mod_signal_id,
	   $tool_signal_id, $sig_id);

    if ("@ARGV" =~ /--help|-h/) {
	   print "Harddrake 2\n", $license, "\nUsage: harddrake [-h|--help]\n";
	   exit;
    }

    my_gtk::add_icon_path('/usr/share/pixmaps/harddrake2/');
    $main_win = new Gtk::Window;
    $main_win->set_title(_("Harddrake2 version ") . $harddrake::data::version);
    $main_win->set_default_size(760, 350); # 760 should be ok for most wm in 800x600
    $main_win->set_policy(0, 1, 0 );
    $main_win->realize;

    $main_vbox = new Gtk::VBox(0, 0 );
    $main_win->add($main_vbox);
    $main_vbox->show;

    $accel_group = new Gtk::AccelGroup;
    $widget = new Gtk::ItemFactory( 'Gtk::MenuBar', '<main>', $accel_group );
    $widget->create_items( @menu_items );
    $main_win->add_accel_group( $accel_group ); #$accel_group->attach($main_win);
    $menubar = $widget->get_widget( '<main>' );

    $main_vbox->add($menubar);
    $main_vbox->set_child_packing($menubar, 0, 0, 0, 'start' );
    $menubar->show;

    $tree = new Gtk::Tree;
    $tree->set_selection_mode('single' );
    $tree->set_view_mode('line' );
    $tree->set_view_lines(1);

    $widget = new Gtk::HPaned;
    $main_vbox->add($widget);
    $main_vbox->set_child_packing($widget, 1, 1, 0, 'start' );
    $widget->show;

    $frame = new Gtk::Frame;
    $frame->set_label( _("Detected hardware"));
    $frame->add($tree);

    $widget->pack1( $frame, 0, 0);
    $widget->add1( $frame  );
    $tree->show;
    $frame->show;

    $vbox = new Gtk::VBox;
    $vbox->show;
    $widget->pack2( $vbox, 1, 0);
    $widget->add2( $vbox );

    $frame = new Gtk::Frame;
    $frame->set_label( _("Informations"));
    $vbox->add($frame);
    $frame->show;

    
    $widget = new Gtk::HBox;
    $frame->add($widget);
    $widget->show;
    $text = new Gtk::Text;
    $widget->add($text);
    $text->realize;
    $text->show;

    $vscrollbar = new Gtk::VScrollbar( $text->vadj );
    $widget->pack_start( $vscrollbar, 0, 0, 0 );
    $vscrollbar->show();

    $config_button = new Gtk::Button(_("Run config tool"));
    $vbox->add($config_button);
    $vbox->set_child_packing($config_button, 0, 0, 0, 'start' );
    $config_button->realize;
#    $config_button->show;

    $module_cfg_button = new Gtk::Button(_("Configure module"));
    $vbox->add($module_cfg_button);
    $vbox->set_child_packing($module_cfg_button, 0, 0, 0, 'start' );
    $module_cfg_button->realize;

    %reverse_fields = reverse %fields;

    $statusbar = new Gtk::Statusbar;
    $main_vbox->add($statusbar);
    $statusbar->show;
    $main_vbox->set_child_packing($statusbar, 0, 0, 0, 'start' );

    $wait = $in->wait_message(_("Please wait"), _("Detection in progress"));

    my $root = new Gtk::TreeItem( );
    $tree->append( $root );
    $root->show();

    my $main_subtree= new Gtk::Tree;
    $root->set_subtree( $main_subtree );
    $main_subtree->show();
    
    foreach (@harddrake::data::tree){
	   my ($Ident, $title, $icon, $configurator, $detector) = @$_;
	   next if (ref($detector) ne "CODE"); #skip class witouth detector
	   my @devices = &$detector;
	   next if (!listlength(@devices)); # Skip empty class (no devices)
	   my ($hw_class_item, $hw_class_tree) = (new Gtk::TreeItem, new Gtk::Tree);
	   $main_subtree->append( $hw_class_item );
	   $hw_class_item->signal_connect(select  => sub {
		  $text->backward_delete($text->get_point); # erase all previous text
		  $config_button->hide;
		  $module_cfg_button->hide;
	   }, , "" );
	   my $gicon = new Gtk::Pixmap(my_gtk::gtkcreate_png($icon));
	   
	   my ($hbox, $label) = (new Gtk::HBox(0,0) ,new Gtk::Label($title));
	   $hbox->pack_start($gicon,0, 0, 5);
	   $hbox->pack_start($label,0, 0, 5);
	   $hw_class_item->add($hbox);
	   foreach ($gicon, $label, $hbox, $hw_class_item) { $_->show() };
	   $hw_class_item->set_subtree($hw_class_tree);
	   $hw_class_item->expand unless ($title =~ /Unknown/ );

	   $SIG{CHLD} = sub { undef $pid; $statusbar->pop($sig_id) };

	   foreach (@devices) {
		  if ($_->{media_type} eq 'SERIAL_USB') {
			 use Data::Dumper;
			 print "Data = ", Dumper($_),"\n";
		  }
		  if (exists $_->{bus} && $_->{bus} eq "PCI") {
			 my $i=$_;
			 $_->{bus_id} = join ':', map { if_($i->{$_} ne "65535",  sprintf("%lx", $i->{$_})) } qw(vendor id subvendor subid);
			 $_->{bus_location} = join ':', map { sprintf("%lx", $i->{$_} ) } qw(pci_bus pci_device pci_function);
		  }
		  # split description into manufacturer/description
		  ($_->{Vendor},$_->{description})=split(/\|/,$_->{description}) if exists $_->{description};
		  # EIDE detection incoherency:
		  if (exists $_->{bus} && $_->{bus} eq 'ide') {
			 $_->{channel} = _($_->{channel} ? "secondary" : "primary");
			delete $_->{info};
		  } elsif ((exists $_->{id}) && ($_->{bus} ne 'PCI')) {
			 # SCSI detection incoherency:
			 my $i=$_;
			 $_->{bus_location} =  join ':', map { sprintf("%lx", $i->{$_} ) } qw(bus id);
		  }
		  foreach my $i (qw(vendor id subvendor subid pci_bus pci_device pci_function MOUSETYPE XMOUSETYPE unsafe)) { 
			 delete $_->{$i};
		  }
		  my $hw_item = new Gtk::TreeItem(defined($_->{device})? $_->{device}:
				(defined($_->{description})?$_->{description}:$title));
		  $_->{device}='/dev/'.$_->{device} if exists $_->{device};
		  $hw_class_tree->append($hw_item);
		  $hw_item->expand;
		  $hw_item->show;
		  my $data=$_;
		  $hw_item->signal_handlers_destroy();
		  $hw_item->signal_connect(select => sub {
			 $_ = $data;
			 $text->hide;
			 $text->backward_delete($text->get_point);
			 foreach my $i (sort map { ($fields{$_})?$fields{$_} : $_ } keys %$_) {
				$text->insert("","","", "\n$i : ". $_->{($reverse_fields{$i})?$reverse_fields{$i}:$i}."\n" );
				
				$module_cfg_button->signal_disconnect($tool_signal_id) if($mod_signal_id);
				$mod_signal_id=$module_cfg_button->signal_connect(clicked => sub
							{
							    require modparm;
							}) if ($i eq "Module" && $reverse_fields{$i});
			 };
			 $config_button->signal_disconnect($tool_signal_id) if($tool_signal_id);
			 if (-x $configurator) {
				$tool_signal_id=$config_button->signal_connect(clicked => sub {
				    if (defined $pid) {return}
				    if ($pid = fork()) {
					   my $id = $statusbar->get_context_id("id");
					   $sig_id=$statusbar->push($id, _("Running \"%s\" ...", $configurator));
				    } else {
					   exec($configurator) or die "$configurator missing\n";
				    }
				}) ;
				$config_button->show;
			 } else {$config_button->hide }
			 $text->show;
		  } );
	   }
    }
#    undef $wait;
    
    $main_win->signal_connect ( delete_event => \&quit_global );
    
    return $main_win;    # Return the constructed UI
}


sub about_harddrake {
    $in->ask_warn(_("About Harddrake"), 
				 join ("", _("This is HardDrake, a Mandrake hardware configuration tool.\nVersion:"), " $harddrake::data::version\n", 
					  _("Author:")," Thierry Vignaud <tvignaud\@mandrakesoft.com> \n\n" ,
					  formatAlaTeX($license)));

}

sub help {
    $in->ask_warn(_("Harddrake help"), 
				 _("Description of the fields:

Bus: this is the physical bus on which the device is plugged (eg: PCI, USB, ...)

Bus identification: 
- pci devices : this list the vendor, device, subvendor and subdevice PCI ids

Description: this field describe the device

Location on the bus: 
- pci devices: this gives the PCI slot, device and function of this card
- eide devices: the device is either a slave or a master device
- scsi devices: the scsi bus and the scsi device ids

Media class: class of hardware device

Module: the module of the GNU/Linux kernel that handle that device

Vendor: the vendor name of the device
"));

}


sub quit_global {
    Gtk->exit(0);
}


__END__
