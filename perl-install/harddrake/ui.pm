#!/usr/bin/perl -w

package ui;

use harddrake::data;

use strict;
use lib qw(/usr/lib/libDrakX);

use standalone;
use c;
#use detect_devices;
use common;

use interactive;
use Gtk;
#use MDK::Common;

my $in;

my @pid_launched;
my @menu_items = ( { path => _("/_File"), type => '<Branch>' },
			    { path => _("/_File")._("/_Save report"), accelerator => _("<control>Q"), callback => \&quit_global },
			    { path => _("/_File")._("/_Quit"), accelerator => _("<control>Q"), callback => \&quit_global	},
#			    { path => _("/_Settings"),type => '<Branch>' },
#			    { path => _("/_Settings")._("/_Preferences") , callback => \&nop}, # FIXME
			    { path => _("/_Help"),type => '<Branch>' },
			    { path => _("/_Help")._("/_About..."), callback => \&about_harddrake }
			    );

my $xpm_dir = "/usr/share/pixmaps/harddrake2/";


my %fields = ( "bus" => _("Bus"),
			"driver" => _("Module"),
			"media_type" => _("Media Type"),
			"description" => _("Description"),
			"bus_id" => _("Bus identification"),
			"bus_location" => _("Location on the bus")
			);



sub run {
    my ($class) = @_;
    $in = 'interactive'->vnew('su', 'default');
    Gtk->init;
    my $window = $class->new;
    $window->show;
    Gtk->main;
    $window->destroy;
    return $window;
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
	   $widget2, $module_cfg_button, $vscrollbar);

    if ("@ARGV" =~ /--help|-h/) {
	   print 'Harddrake 2
',$license;
	   exit;
    }

    my_gtk::add_icon_path('/usr/share/pixmaps/harddrake2/');
    $main_win = new Gtk::Window;
    $main_win->set_title(_("Harddrake2 version " . $data::version));
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
    $widget->pack1( $tree, 0, 0);
    $widget->add1( $tree );
    $tree->show;

    $vbox = new Gtk::VBox;
    $vbox->show;
    $widget->pack2( $vbox, 1, 0);
    $widget->add2( $vbox );

    $widget2 = new Gtk::Frame;
    $widget2->set_label( _("Informations"));
    $vbox->add($widget2);
    $widget2->show;

    
    $widget = new Gtk::HBox;
    $widget2->add($widget);
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

    
    foreach (keys %fields) {
	   $reverse_fields{$fields{$_}} = $_;
    }

    $statusbar = new Gtk::Statusbar;
    $main_vbox->add($statusbar);
    $statusbar->show;
    $main_vbox->set_child_packing($statusbar, 0, 0, 0, 'start' );

    $wait = $in->wait_message(_("Please wait"), _("Detection in progress"));

    my $root = new_with_label Gtk::TreeItem("Detected hardware" );
    $tree->append( $root );
    $root->show();

#    $subtree= new Gtk::Tree;
#    $tree->set_subtree( $subtree );
#    $subtree->show();
#    $hbox->add($vbox);
#    $hbox->set_child_packing($vbox, 1, 1, 0, 'start' );
    
    foreach (@data::tree){
	   my ($Ident, $title, $icon, $configurator, $detector) = @$_;
	   next if (ref($detector) ne "CODE");
	   my @devices = &$detector;
	   next if (!listlength(@devices)); # Skip class without any devices
#		  foreach my $ii (keys %_) { print "@@@ $ii ========> %_{$ii}\n"; };
#		  not new_with_label Gtk::TreeItem($item) because of icon
	   my ($subitem, $subsubtree) = (new Gtk::TreeItem, new Gtk::Tree);
	   $tree->append( $subitem );
	   $subitem->signal_connect(select  => sub {
		  $text->backward_delete($text->get_point);
		  $config_button->hide;
		  $module_cfg_button->hide;
	   }, , "" );
	   my $gicon = new Gtk::Pixmap(my_gtk::gtkcreate_png($icon));

	   my ($hbox, $label) = (new Gtk::HBox(0,0) ,new Gtk::Label($title));
	   $hbox->pack_start($gicon,0, 0, 5);
	   $hbox->pack_start($label,0, 0, 5);
	   $gicon->show;
	   $label->show;
	   $hbox->show;
	   $subitem->add($hbox);

	   $subitem->show();
	   $subitem->set_subtree($subsubtree);
	   $subitem->expand unless ($title =~ /Unknown/ );

	   foreach (@devices) {
		  my $i= (defined($_->{device})? $_->{device}:
				(defined($_->{description})?$_->{description}:$title));
		  my $widget = new Gtk::TreeItem($i);
		  if ($_->{bus} eq "PCI") {
			 my $i=$_;
			 $_->{bus_id} = join ':', map { sprintf("%lx", $i->{$_}) } qw(vendor id subvendor subid);
			 $_->{bus_location} = join ':', map { sprintf("%lx", $i->{$_}) } qw(pci_bus pci_device pci_function);
			 foreach (qw(vendor id subvendor subid pci_bus pci_device pci_function)) { 
				delete $i->{$_}
			 }
		  }
		  $widget->show;
		  $subsubtree->append($widget);
		  $widget->expand;
		  $widget->set_user_data( $_ );
		  $widget->signal_handlers_destroy();
		  $widget->signal_connect(select => sub {
			 $_ = $widget->get_user_data;
			 $text->hide;
			 $text->backward_delete($text->get_point);
			 # split description into manufacturer/description
			 foreach my $i (sort map { ($fields{$_})?$fields{$_} : $_ } keys %$_) {
				$text->insert("","","", "\n$i : ". $_->{($reverse_fields{$i})?$reverse_fields{$i}:$i}."\n" );
				$module_cfg_button->signal_connect(clicked => sub
											{
											    print "TOTO\n";
											}) if ($i eq "Module" && $reverse_fields{$i});
			 };
			 
			 $config_button->signal_connect(clicked => sub {
				if (my $pid = fork) {
				    POSIX::wait();
				  } else {
					 exec($configurator) or die "$configurator missing\n";
				  }
			 })  if (-x $configurator);
			 $text->show;
			 $config_button->show;
		  } );
	   }
    }
    undef $wait;
    
    $main_win->signal_connect ( delete_event => \&quit_global );
    
    return $main_win;    # Return the constructed UI
}


sub about_harddrake {
    $in->ask_yesorno(_("About Harddrake"), 
				 join ("", _("This is HardDrake, a Mandrake hardware configuration tool.\nVersion:"), " $data::version\n", 
					  _("Author:")," Thierry Vignaud <tvignaud\@mandrakesoft.com> \n\n" ,
					  $license),
				 [ _("Ok") ], "Ok");

}

sub quit_global {
#    no strict;
    foreach(@pid_launched) {
	   kill 'TERM', $_ if (defined $_);
    }
    Gtk->exit(0);
}



1;

__END__
