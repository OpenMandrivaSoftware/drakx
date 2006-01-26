package install_gtk; # $Id$

use diagnostics;
use strict;

use ugtk2;
use mygtk2;
use common;
use lang;
use devices;

#-#####################################################################################
#-INTERN CONSTANT
#-#####################################################################################

#- if we're running for the doc team, we want screenshots with
#- a good B&W contrast: we'll override values of our theme
my $theme_overriding_for_doc = q(style "galaxy-default"
{
    base[SELECTED]    = "#E0E0FF"
    base[ACTIVE]      = "#E0E0FF"
    base[PRELIGHT]    = "#E0E0FF"
    bg[SELECTED]      = "#E0E0FF"
    bg[ACTIVE]        = "#E0E0FF"
    bg[PRELIGHT]      = "#E0E0FF"
    text[ACTIVE]      = "#000000"
    text[PRELIGHT]    = "#000000"
    text[SELECTED]    = "#000000"
    fg[SELECTED]      = "#000000"
}

style "white-on-blue"
{
  base[NORMAL] = { 0.93, 0.93, 0.93 }
  bg[NORMAL] = { 0.93, 0.93, 0.93 }
    
  text[NORMAL] = "#000000"
  fg[NORMAL] = "#000000"
}

style "background"
{
  bg[NORMAL] = { 0.93, 0.93, 0.93 }
}

style "background-logo"
{
  bg[NORMAL] = { 0.70, 0.70, 0.70 }
}
widget "*logo*" style "background-logo"

);

#------------------------------------------------------------------------------
sub load_rc {
    my ($o, $name) = @_;

    my $f = $name;
    -r $name or $f = find { -r $_ } map { "$_/themes-$name.rc" } ("share", $ENV{SHARE_PATH}, dirname(__FILE__));
    if ($f) {
	Gtk2::Rc->parse_string($o->{doc} ? $theme_overriding_for_doc : scalar cat_($f));
   }

    if ($::move) {
        #- override selection color since we will not do inverse-video on the text when it's images
	Gtk2::Rc->parse_string(q(
style "galaxy-default"
{
    base[ACTIVE]      = "#CECECE"
    base[SELECTED]    = "#CECECE"
    text[ACTIVE]      = "#000000"
    text[PRELIGHT]    = "#000000"
    text[SELECTED]    = "#000000"
}
));
    }
}

#------------------------------------------------------------------------------
sub load_font {
    my ($o) = @_;

    if (lang::text_direction_rtl()) {
	Gtk2::Widget->set_default_direction('rtl'); 
	my ($x, $y) = $::WizardWindow->get_position;
	my ($width) = $::WizardWindow->get_size;
	$::WizardWindow->move($::rootwidth - $width - $x, $y);
    }

    Gtk2::Rc->parse_string(q(
style "default-font" 
{
   font_name = ") . lang::l2pango_font($o->{locale}{lang}) . q("
}
widget "*" style "default-font"

));
}

#------------------------------------------------------------------------------
sub default_theme {
    my ($o) = @_;
    $::move ? '' :
    $o->{simple_themes} || $o->{vga16} ? 'blue' : 'galaxy';
}

sub install_theme {
    my ($o) = @_;

    load_rc($o, $o->{theme} ||= default_theme($o));
    load_font($o);

    if (!$::move) {
	my $win = gtknew('Window', widget_name => 'background');
	$win->realize;
	mygtk2::set_root_window_background_with_gc($win->style->bg_gc('normal'));
    }
}

#------------------------------------------------------------------------------
my %steps;
sub create_steps_window {
    my ($o) = @_;

    return if $::stepswidth == 0;

    $o->{steps_window} and $o->{steps_window}->destroy;

    $steps{$_} ||= gtknew('Pixbuf', file => "steps_$_") foreach qw(on off done);
    my $category = sub { 
	gtknew('HBox', children_tight => [ 
	    gtknew('Label', text_markup => '<b><u>' . $_[0] . '</u></b>', widget_name => 'Step-categories')
	]);
    };

    my @l = $category->(N("System installation"));
    foreach (grep { !eval $o->{steps}{$_}{hidden} } @{$o->{orderedSteps}}) {
	if ($_ eq 'setRootPassword') {
	    push @l, '', $category->(N("System configuration"));
	}
	my $img = gtknew('Image', file => 'steps_off.png');
	$steps{steps}{$_}{img} = $img;
	$steps{steps}{$_}{raw_text} = translate($o->{steps}{$_}{text});
	push @l, gtknew('HBox', spacing => 7, children_tight => [ '', '', $img, $steps{steps}{$_}{text} = gtknew('Label', text => $steps{steps}{$_}{raw_text}) ]);
    }

    my $offset = 20;
    $o->{steps_window} =
      gtknew('Window', width => ($::stepswidth - $offset), widget_name => 'Steps',
	     position => [ lang::text_direction_rtl() ? $::rootwidth - $::stepswidth : $offset, 150 ],
	     child => gtknew('VBox', spacing => 6, children_tight => \@l));
    $o->{steps_window}->show;
}

sub update_steps_position {
    my ($o) = @_;
    return if !$steps{steps};
    my $last_step;
    foreach (@{$o->{orderedSteps}}) {
	exists $steps{steps}{$_} or next;
	if ($o->{steps}{$_}{entered} && !$o->{steps}{$_}{done}) {
	    $steps{steps}{$_}{img}->set_from_pixbuf($steps{on});
	    $steps{steps}{$_}{text}->set_markup('<b><i>' . $steps{steps}{$_}{raw_text} . '</i></b>');
	    if ($last_step) {
             $steps{steps}{$last_step}{img}->set_from_pixbuf($steps{done});
             $steps{steps}{$last_step}{text}->set_markup('<b>' . $steps{steps}{$last_step}{raw_text} . '</b>');
         }
	    return;
	}
	$last_step = $_;
    }
    mygtk2::flush(); #- for auto_installs which never go through the Gtk2 main loop
}

#------------------------------------------------------------------------------
sub create_logo_window {
    my ($o) = @_;

    return if $::logowidth == 0 || $::move;

    mygtk2::may_destroy($o->{logo_window});

    my $file = $o->{meta_class} eq 'firewall' ? "logo-mandriva-Firewall.png" : "logo-mandriva.png";

    $o->{logo_window} =
      gtknew('Window', 
	     width => $::logowidth, height => $::logoheight, 
	     widget_name => 'logo',
	     child => gtknew('Image', file => $file),
	 );
    $o->{logo_window}->show;
}

#------------------------------------------------------------------------------
sub init_gtk {
    my ($o) = @_;

    symlink("/tmp/stage2/etc/$_", "/etc/$_") foreach qw(gtk-2.0 pango fonts);

    if ($o->{vga16}) {
        #- inactivate antialias in VGA16 because it makes fonts look worse
        output('/tmp/fonts.conf',
q(<fontconfig>
<include>/etc/fonts/fonts.conf</include>
<match target="font"><edit name="antialias"><bool>false</bool></edit></match>
</fontconfig>
));
        $ENV{FONTCONFIG_FILE} = '/tmp/fonts.conf';
    }

    Gtk2->init;
    Gtk2->set_locale;
}

#------------------------------------------------------------------------------
sub init_sizes() {
    ($::rootwidth,  $::rootheight)    = (Gtk2::Gdk->screen_width, Gtk2::Gdk->screen_height);
    $::stepswidth = $::rootwidth <= 640 ? 0 : 200 if !$::move;
    ($::logowidth, $::logoheight) = $::rootwidth <= 640 ? (0, 0) : (800, 75);
    ($::windowwidth, $::windowheight) = ($::rootwidth - $::stepswidth, $::rootheight - $::helpheight - $::logoheight);
    ($::real_windowwidth, $::real_windowheight) = (576, 418);
    $::move and $::windowwidth -= 100;
}

sub handle_unsafe_mouse {
    my ($o, $window) = @_;

    $o->{mouse}{unsafe} or return;

    $window->add_events('pointer-motion-mask');
    my $signal; $signal = $window->signal_connect(motion_notify_event => sub {
	delete $o->{mouse}{unsafe};
	log::l("unsetting unsafe mouse");
	$window->signal_handler_disconnect($signal);
    });
}

sub special_shortcuts {
    my (undef, $event) = @_;
    my $d = ${{ $Gtk2::Gdk::Keysyms{F2} => 'screenshot', $Gtk2::Gdk::Keysyms{Home} => 'restart' }}{$event->keyval};
    if ($d eq 'screenshot') {
	install_any::take_screenshot($::o);
    } elsif ($d eq 'restart' && member('control-mask', @{$event->state}) && member('mod1-mask', @{$event->state})) {
	log::l("restarting install");
	ugtk2->exit(0x35);
    }
    0;
}

#------------------------------------------------------------------------------
sub createXconf {
    my ($file, $mouse_type, $mouse_dev, $_wacom_dev, $Driver) = @_;

    symlinkf(devices::make($mouse_dev), "/dev/mouse") if $mouse_dev ne 'none';

    #- needed for imlib to start on 8-bit depth visual.
    symlink("/tmp/stage2/etc/imrc", "/etc/imrc");
    symlink("/tmp/stage2/etc/im_palette.pal", "/etc/im_palette.pal");

    #- remove "error opening security policy file" warning
    symlink("/tmp/stage2/etc/X11", "/etc/X11");

if ($Driver) {
     output($file, sprintf(<<'END', ($::globetrotter ? "" : 'Option "XkbDisable"'), $mouse_type, $Driver, $Driver eq 'fbdev' ? '"default"' : '"800x600" "640x480"'));
Section "Files"
   FontPath   "/usr/X11R6/lib/X11/fonts:unscaled"
EndSection

Section "InputDevice"
    Identifier "Keyboard"
    Driver "keyboard"
    %s
    Option "XkbModel" "pc105"
    Option "XkbLayout" ""
EndSection

Section "InputDevice"
    Identifier "Mouse"
    Driver "mouse"
    Option "Protocol" "%s"
    Option "Device" "/dev/mouse"
    Option "ZAxisMapping" "4 5"
EndSection

Section "Monitor"
    Identifier "monitor"
    HorizSync 31.5-35.5
    VertRefresh 50-70
EndSection

Section "Device"
    Identifier  "device"
    Driver      "%s"
EndSection

Section "Screen"
    Identifier "screen"
    Device "device"
    Monitor "monitor"
    DefaultColorDepth 16
    Subsection "Display"
        Depth 16
        Modes %s
    EndSubsection
EndSection

Section "ServerLayout"
    Identifier "layout"
    Screen "screen"
    InputDevice "Mouse" "CorePointer"
    InputDevice "Keyboard" "CoreKeyboard"
EndSection

END
 }
}

1;
