package my_gtk;

use diagnostics;
use strict;
use vars qw(@ISA %EXPORT_TAGS @EXPORT_OK $border);

@ISA = qw(Exporter);
%EXPORT_TAGS = (
    helpers => [ qw(create_okcancel createScrolledWindow create_menu create_notebook create_packtable create_hbox create_vbox create_adjustment create_box_with_title) ],
    wrappers => [ qw(gtksignal_connect gtkpack gtkpack_ gtkappend gtkadd gtkset_usize gtkset_justify gtkset_active gtkshow gtkdestroy gtkset_mousecursor gtkset_background) ],
    ask => [ qw(ask_warn ask_okcancel ask_yesorno ask_from_entry ask_from_list ask_file) ],
);
$EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ];
@EXPORT_OK = map { @$_ } values %EXPORT_TAGS;

use Gtk;
use c;
use common qw(:common :functional);

my $forgetTime = 1000; # in milli-seconds
$border = 5;

1;

################################################################################
# OO stuff
################################################################################
sub new {
    my ($type, $title, %opts) = @_;

    Gtk->init;
    my $o = bless { %opts }, $type;
    $o->_create_window($title);
    push @interactive::objects, $o unless $opts{no_interactive_objects};
    $o;
}
sub main($;$) {
    my ($o, $f) = @_;
    $o->show;

    do { 
	Gtk->main 
    } while ($o->{retval} && $f && !&$f());
    $o->destroy;
    $o->{retval}
}
sub show($) {
    my ($o) = @_;
    $o->{window}->show;
    $o->{rwindow}->show;
    $o->{rwindow}->grab_add if $my_gtk::grab || $o->{grab};
}
sub destroy($) { 
    my ($o) = @_;
    $o->{rwindow}->grab_remove if $my_gtk::grab || $o->{grab};
    $o->{rwindow}->destroy;
    flush();
}
sub DESTROY { goto &destroy }
sub sync($) {
    my ($o) = @_;
    show($o);

    my $h = Gtk->idle_add(sub { Gtk->main_quit; 1 });
    map { Gtk->main } (1..4);
    Gtk->idle_remove($h);
}
sub flush(;$) {
    Gtk->main_iteration while Gtk->events_pending;
}
sub bigsize($) { 
    $_[0]{rwindow}->set_usize(600,400); 
}


sub gtkshow($)         { $_[0]->show; $_[0] }                  
sub gtkdestroy($)      { $_[0] and $_[0]->destroy }            
sub gtkset_usize($$$)  { $_[0]->set_usize($_[1],$_[2]); $_[0] }
sub gtkset_justify($$) { $_[0]->set_justify($_[1]); $_[0] }    
sub gtkset_active($$)  { $_[0]->set_active($_[1]); $_[0] }     

sub gtksignal_connect($@) {
    my $w = shift;
    $w->signal_connect(@_);
    $w
}
sub gtkpack($@) {
    my $box = shift;
    foreach (@_) {
	my $l = $_; 
	ref $l or $l = new Gtk::Label($l);
	$box->pack_start($l, 1, 1, 0);
	$l->show;
    }
    $box
}
sub gtkpack_($@) {
    my $box = shift;
    for (my $i = 0; $i < @_; $i += 2) {
	my $l = $_[$i + 1]; 
	ref $l or $l = new Gtk::Label($l);
	$box->pack_start($l, $_[$i], 1, 0);
	$l->show;
    }
    $box
}
sub gtkappend($@) {
    my $w = shift;
    foreach (@_) { 
	my $l = $_; 
	ref $l or $l = new Gtk::Label($l);
	$w->append($l); 
	$l->show;
    }
    $w
}
sub gtkadd($@) {
    my $w = shift;
    foreach (@_) {
	my $l = $_; 
	ref $l or $l = new Gtk::Label($l);
	$w->add($l);
	$l->show;
    }
    $w
}

sub gtkroot {
    Gtk->init;
    Gtk::Gdk::Window->new_foreign(Gtk::Gdk->ROOT_WINDOW);
}

sub gtkcolor($$$) {
    my ($r, $g, $b) = @_;

    my $color = bless {}, 'Gtk::Gdk::Color';
    $color->red  ($r << 8);
    $color->green($g << 8);
    $color->blue ($b << 8);
    gtkroot()->get_colormap->color_alloc($color);
}

sub gtkset_mousecursor($) {
    my ($type) = @_;
    gtkroot()->set_cursor(Gtk::Gdk::Cursor->new($type));
}

sub gtkset_background {
    my ($r, $g, $b) = @_;

    my $root = gtkroot();
    my $gc = Gtk::Gdk::GC->new($root);

    my $color = gtkcolor($r, $g, $b);
    $gc->set_foreground($color);
    $root->set_background($color);
    
    my ($h, $w) = $root->get_size;
    $root->draw_rectangle($gc, 1, 0, 0, $w, $h);
}



################################################################################
# createXXX functions

# these functions return a widget
################################################################################

sub create_okcancel($;$$) {
    my ($w, $ok, $cancel) = @_;

    gtkadd(create_hbox(),
	  gtksignal_connect($w->{ok} = new Gtk::Button($ok || _("Ok")), "clicked" => $w->{ok_clicked} || sub { $w->{retval} = 1; Gtk->main_quit }),
	  gtksignal_connect(new Gtk::Button($cancel || _("Cancel")), "clicked" => $w->{cancel_clicked} || sub { $w->{retval} = 0; Gtk->main_quit }),
	 );
}

sub create_box_with_title($@) {
    my $o = shift;

    @_ = map { ref $_ ? $_ : warp_text($_) } @_;
    $o->{box} = gtkpack_(new Gtk::VBox(0,0),
			 map({
			      my $w = ref $_ ? $_ : new Gtk::Label($_);
			      $w->set_name("Title");
			      0, $w;
			     } @_),
			 0, new Gtk::HSeparator,
		       )
}

sub createScrolledWindow($) {
    my $w = new Gtk::ScrolledWindow(undef, undef);
    $w->set_policy('automatic', 'automatic');
    member(ref $_[0], qw(Gtk::CList)) ?
      $w->add($_[0]) :
      $w->add_with_viewport($_[0]);
    $_[0]->show;
    $w
}

sub create_menu($@) {
    my $title = shift;
    my $w = new Gtk::MenuItem($title);
    $w->set_submenu(gtkshow(gtkappend(new Gtk::Menu, @_)));
    $w
}

sub create_notebook(@) {
    my $n = new Gtk::Notebook;
    while (@_) {
	my $title = shift;
	my $book = shift;

	my ($w1, $w2) = map { new Gtk::Label($_) } $title, $title;
	$book->{widget_title} = $w1;
	$n->append_page_menu($book, $w1, $w2);
	$book->show;
	$w1->show;
	$w2->show;
    }
    $n
}

sub create_adjustment($$$) {
    my ($val, $min, $max) = @_;
    new Gtk::Adjustment($val, $min, $max + 1, 1, ($max - $min + 1) / 10, 1);
}

sub create_packtable($@) {
    my $options = shift;
    my $w = new Gtk::Table(0, 0, $options->{homogeneous} || 0);
    map_index {
	my ($i) = @_;
	map_index {
	    my ($j) = @_;
	    if (defined $_) {
		ref $_ or $_ = new Gtk::Label($_);
		$w->attach_defaults($_, $j, $j + 1, $i, $i + 1);
		$_->show;
	    }
	} @$_;
    } @_;
    $w->set_col_spacings($options->{col_spacings} || 0);
    $w->set_row_spacings($options->{row_spacings} || 0);
    $w
}

sub create_hbox {
    my $w = new Gtk::HButtonBox;
    $w->set_layout(-spread);
    $w;
}
sub create_vbox {
    my $w = new Gtk::VButtonBox;
    $w->set_layout(-spread);
    $w;
}


sub _create_window($$) {
    my ($o, $title) = @_;
    my $w = new Gtk::Window;
    my $f = new Gtk::Frame(undef);
    $w->set_name("Title");

    if ($::isStandalone || $o->{no_border}) {
	gtkadd($w, $f);
    } else {
	my $t = new Gtk::Table(0, 0, 0);

	my $new = sub {
	    my $w = new Gtk::DrawingArea;
	    $w->set_usize($border, $border);
	    $w->set_events(['exposure_mask']);
	    $w->signal_connect_after(expose_event => 
		sub { $w->window->draw_rectangle($w->style->black_gc, 1, 0, 0, @{$w->allocation}[2,3]); 1 }
	    );
	    $w;
	};

	 $t->attach(&$new(), 0, 1, 0, 3, [],              , ["expand","fill"], 0, 0);
	 $t->attach(&$new(), 1, 2, 0, 1, ["expand","fill"], [],                0, 0);
	 $t->attach($f,      1, 2, 1, 2, ["expand","fill"], ["expand","fill"], 0, 0);
	 $t->attach(&$new(), 1, 2, 2, 3, ["expand","fill"], [],                0, 0);
	 $t->attach(&$new(), 2, 3, 0, 3, [],                ["expand","fill"], 0, 0);

	gtkadd($w, $t);
    }

    $w->set_title($title);
    $w->signal_connect("expose_event" => sub { c::XSetInputFocus($w->window->XWINDOW) }) if $my_gtk::force_focus || $o->{force_focus};
    $w->signal_connect("delete_event" => sub { $o->{retval} = undef; Gtk->main_quit });
    $w->set_uposition(@{$my_gtk::force_position || $o->{force_position}}) if $my_gtk::force_position || $o->{force_position};

    $w->signal_connect(size_allocate => sub {
	my ($wi, $he) = @{$_[1]}[2,3]; 
	my ($X, $Y, $Wi, $He) = @{$my_gtk::force_center || $o->{force_center}};
        $w->set_uposition(max(0, $X + ($Wi - $wi) / 2), max(0, $Y + ($He - $he) / 2));
    }) if ($my_gtk::force_center || $o->{force_center}) && !($my_gtk::force_position || $o->{force_position}) ;

    $o->{window} = $f;
    $o->{rwindow} = $w;
}




################################################################################
# ask_XXX

# just give a title and some args, and it will return the value given by the user
################################################################################

sub ask_warn       { my $w = my_gtk->new(shift @_); $w->_ask_warn(@_); main($w); }
sub ask_yesorno    { my $w = my_gtk->new(shift @_); $w->_ask_okcancel(@_, _("Yes"), _("No")); main($w); }
sub ask_okcancel   { my $w = my_gtk->new(shift @_); $w->_ask_okcancel(@_, _("Is it ok?"), _("Ok"), _("Cancel")); main($w); }
sub ask_from_entry { my $w = my_gtk->new(shift @_); $w->_ask_from_entry(@_); main($w); }
sub ask_from_list  { my $w = my_gtk->new(shift @_); $w->_ask_from_list(@_); main($w); }
sub ask_file       { my $w = my_gtk->new(''); $w->_ask_file(@_); main($w); }

sub _ask_from_entry($$@) {
    my ($o, @msgs) = @_;
    my $entry = new Gtk::Entry;
    my $f = sub { $o->{retval} = $entry->get_text; Gtk->main_quit };
    $o->{ok_clicked} = $f;
    $o->{cancel_clicked} = sub { $o->{retval} = undef; Gtk->main_quit };

    gtkadd($o->{window},
	  gtkpack($o->create_box_with_title(@msgs),
		 gtksignal_connect($entry, 'activate' => $f),
		 ($o->{hide_buttons} ? () : create_okcancel($o))),
	  );
    $entry->grab_focus();
}

sub _ask_from_list($$$$) {
    my ($o, $messages, $l, $def) = @_;
    my $list = new Gtk::CList(1);
    my ($first_time, $starting_word) = (1, '');
    my (@widgets, $timeout, $curr);

    my $leave = sub { $o->{retval} = $l->[$curr]; Gtk->main_quit };
    my $select = sub { 
	$list->focus_row($_[0]); 
	$list->select_row($_[0], 0);
	$list->moveto($_[0], 0, 0.5, 0);
    };

    $list->signal_connect(button_release_event => $leave);
    $list->signal_connect(select_row => sub {
	my ($w, $row, undef, $e) = @_;
	$curr = $row;
    });
    $list->signal_connect(key_press_event => sub {
        my ($w, $e) = @_;
	my $c = chr $e->{keyval};

	Gtk->timeout_remove($timeout) if $timeout; $timeout = '';
	
	if ($e->{keyval} >= 0x100) {
	    &$leave if $c eq "\r" || $c eq "\x8d";
	    $starting_word = '';
	} else {
	    &$leave if $c eq ' ';

	    $curr++ if $starting_word eq '' || $starting_word eq $c;
	    $starting_word .= $c unless $starting_word eq $c;
	
	    my $j; for ($j = 0; $j < @$l; $j++) {
		 $l->[($j + $curr) % @$l] =~ /^$starting_word/i and last;
	    }
	    $j == @$l ?
	      $starting_word = '' :
	      &$select(($j + $curr) % @$l);
	
	    $w->{timeout} = $timeout = Gtk->timeout_add($forgetTime, sub { $timeout = $starting_word = ''; 0 } );
	}
	1;
    });
    $list->set_selection_mode('browse');

    gtkadd($o->{window}, 
	   gtkpack($o->create_box_with_title(@$messages), 
		   @$l > 15 ? gtkset_usize(createScrolledWindow($list), 200, 280) : $list));

    $o->sync; # otherwise the moveto is not done
    map_index {
	$list->append($_);
	&$select($::i) if $def && $_ eq $def; 
    } @$l;

    $list->grab_focus;
}

sub _ask_warn($@) {
    my ($o, @msgs) = @_;
    gtkadd($o->{window},
	  gtkpack($o->create_box_with_title(@msgs),
		 gtksignal_connect(my $w = new Gtk::Button(_("Ok")), "clicked" => sub { Gtk->main_quit }),
		 ),
	  );
    $w->grab_focus();
}

sub _ask_okcancel($@) {
    my ($o, @msgs) = @_;
    my ($ok, $cancel) = splice @msgs, -2;

    gtkadd($o->{window},
	   gtkpack(create_box_with_title($o, @msgs),
		   create_okcancel($o, $ok, $cancel),
		 )
	 );
    $o->{ok}->grab_focus();
}


sub _ask_file($$) {
    my ($o, $title) = @_;
    my $f = $o->{rwindow} = new Gtk::FileSelection $title;
    $f->ok_button->signal_connect(clicked => sub { $o->{retval} = $f->get_filename ; Gtk->main_quit });
    $f->cancel_button->signal_connect(clicked => sub { Gtk->main_quit });
    $f->hide_fileop_buttons;
}

################################################################################
# rubbish
################################################################################

#sub label_align($$) {
#    my $w = shift;
#    local $_ = shift;
#    $w->set_alignment(!/W/i, !/N/i);
#    $w
#}

#-sub _ask_from_list($$$$) {
#-    my ($o, $messages, $l, $def) = @_;
#-    my $list = new Gtk::List();
#-    my ($first_time, $starting_word) = (1, '');
#-    my (@widgets, $timeout);
#-    $list->signal_connect(select_child => sub {
#-	  $o->{retval} = $l->[$list->child_position($_[1])];
#-	  Gtk->main_quit;
#-    });
#-    map_index {
#-	  my ($i) = @_;
#-	  $def = $i if $_ eq $def;
#-	  my $w = new Gtk::ListItem($_);
#-	  my $id = $w->signal_connect(key_press_event => sub {
#-	       my ($w, $e) = @_;
#-	       my $c = chr $e->{keyval};
#-	  
#-	       Gtk->timeout_remove($timeout) if $timeout; $timeout = '';
#-	  
#-	       if ($e->{keyval} >= 0x100) {
#-		     if ($c eq "\r" || $c eq "\x8d") {
#-			 $list->select_item($i);
#-		     }
#-		     $starting_word = '';
#-	       } else {
#-		     my $curr = $i + bool($starting_word eq '' || $starting_word eq $c);
#-		     $starting_word .= $c unless $starting_word eq $c;
#-	  
#-		     my $j; for ($j = 0; $j < @$l; $j++) {
#-			 $l->[($j + $curr) % @$l] =~ /^$starting_word/i and last;
#-		     }
#-		     $j == @$l ?
#-		       $starting_word = '' :
#-		       $widgets[($j + $curr) % @$l]->grab_focus;
#-	  
#-		     $w->{timeout} = $timeout = Gtk->timeout_add($forgetTime, sub { $timeout = $starting_word = ''; 0 } );
#-	       }
#-	       1;
#-	  });
#-	  push @widgets, $w;
#-    } @$l;
#-    gtkadd($list, @widgets);
#-    my $scroll_win = do {
#-	  if (@$l > 15) {
#-	      my $win = createScrolledWindow($list);
#-	      gtkset_usize($win, 200, 280);
#-	      $list->set_focus_vadjustment($win->get_vadjustment);
#-	      $list->set_focus_hadjustment($win->get_hadjustment);
#-	      $win;
#-	  } else {
#-	      $list;
#-	  }
#-    };
#-    gtkadd($o->{window}, 
#-	     gtkpack($o->create_box_with_title(@$messages), 
#-		     $scroll_win));
#-    $widgets[$def]->grab_focus;
#-
#-}
