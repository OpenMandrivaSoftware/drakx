package Xconfig::xfreeX; # $Id$

use diagnostics;
use strict;

use MDK::Common;
use Xconfig::parse;
use log;


sub empty_config {
    my ($class) = @_;
    my $raw_X = Xconfig::parse::read_XF86Config_from_string(our $default_header);
    bless $raw_X, $class;
}

sub read {
    my ($class, $file) = @_;
    $file ||= ($::prefix || '') . (bless {}, $class)->config_file;
    my $raw_X = Xconfig::parse::read_XF86Config($file);
    bless $raw_X, $class;
}
sub write {
    my ($raw_X, $file) = @_;
    $file ||= ($::prefix || '') . $raw_X->config_file;
    Xconfig::parse::write_XF86Config($raw_X, $file);
}


my @keyboard_fields = qw(XkbLayout XkbModel XkbDisable);
sub get_keyboard {
    my ($raw_X) = @_;
    my $raw_kbd = $raw_X->get_keyboard_section;
    raw_export_section($raw_kbd, @keyboard_fields);
}
sub set_keyboard {
    my ($raw_X, $kbd) = @_;
    my $raw_kbd = eval { $raw_X->get_keyboard_section } || $raw_X->new_keyboard_section;
    raw_import_section($raw_kbd, $kbd);
    $raw_X->set_Option('keyboard', $raw_kbd, keys %$kbd);
}

#- example: { Protocol => 'IMPS/2', Device => '/dev/psaux', Emulate3Buttons => undef, Emulate3Timeout => 50, ZAxisMapping => [ '4 5', '6 7' ] }
my @mouse_fields = qw(Protocol Device ZAxisMapping Emulate3Buttons Emulate3Timeout); #-);
sub get_mice {
    my ($raw_X) = @_;
    my @raw_mice = $raw_X->get_mouse_sections;
    map { raw_export_section($_, @mouse_fields) } @raw_mice;
}
sub set_mice {
    my ($raw_X, @mice) = @_;
    my @raw_mice = $raw_X->new_mouse_sections(int @mice);
    mapn { 
	my ($raw_mouse, $mouse) = @_;
	raw_import_section($raw_mouse, $mouse);
	$raw_X->set_Option('mouse', $raw_mouse, keys %$mouse);
    } \@raw_mice, \@mice;
}


#-##############################################################################
#- helpers
#-##############################################################################
sub raw_export_section_name {
    my ($section, $name) = @_;
    my $h = $section->{$name} or return;

    my @l = map { if_(!$_->{commented}, $_->{val}) } deref_array($h) or return;    
    $name => (ref($h) eq 'ARRAY' ? \@l : $l[0]);
}

sub raw_export_section {
    my ($section, @fields) = @_;
    my %h = map { raw_export_section_name($section, $_) } @fields;
    \%h;
}

sub raw_import_section {
    my ($section, $h) = @_;
    foreach (keys %$h) {
	my @l = map { { val => $_ } } deref_array($h->{$_});
	$section->{$_} = (ref($h->{$_}) eq 'ARRAY' ? \@l : $l[0]);
    }
}

sub add_Section {
    my ($raw_X, $Section, $h) = @_;
    my @suggested_ordering = qw(Files ServerFlags Keyboard Pointer XInput InputDevice Module DRI Monitor Device Screen ServerLayout);
    my %order = map_index { { lc($_) => $::i } } @suggested_ordering;
    my $e = { name => $Section, l => $h };
    my $added;
    @$raw_X = map { 
	if ($order{lc $_->{name}} > $order{lc $Section} && !$added) {
	    $added = 1;
	    ($e, $_);
	} else { $_ }
    } @$raw_X;
    push @$raw_X, $e if !$added;
    $h;
}
sub remove_Section {
    my ($raw_X, $Section, $when) = @_;
    @$raw_X = grep { $_->{name} ne $Section || ($when && $when->($_->{l})) } @$raw_X;
    $raw_X;
}
sub get_Sections {
    my ($raw_X, $Section, $when) = @_;
    map { if_($_->{name} eq $Section && (!$when || $when->($_->{l})), $_->{l}) } @$raw_X;
}
sub get_Section {
    my ($raw_X, $Section, $when) = @_;
    my @l = get_Sections($raw_X, $Section, $when);
    @l > 1 and log::l("Xconfig: found more than one Section $Section");
    $l[0];
}


our $default_header = <<'END';
# File generated by XFdrake.

# **********************************************************************
# Refer to the XF86Config man page for details about the format of
# this file.
# **********************************************************************

Section "Files"
    # Multiple FontPath entries are allowed (they are concatenated together)
    # By default, Mandrake 6.0 and later now use a font server independent of
    # the X server to render fonts.
    FontPath "unix/:-1"
EndSection

Section "ServerFlags"
    #DontZap # disable <Crtl><Alt><BS> (server abort)
    #DontZoom # disable <Crtl><Alt><KP_+>/<KP_-> (resolution switching)
    AllowMouseOpenFail # allows the server to start up even if the mouse doesn't work
EndSection
END


1;

