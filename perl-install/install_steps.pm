package install_steps; # $Id$

use diagnostics;
use strict;
use vars qw(@filesToSaveForUpgrade @filesNewerToUseAfterUpgrade);

#-######################################################################################
#- misc imports
#-######################################################################################
use common;
use install_any qw(:all);
use partition_table;
use detect_devices;
use fs::type;
use modules;
use run_program;
use lang;
use keyboard;
use fsedit;
use loopback;
use do_pkgs;
use pkgs;
use any;
use log;

our @ISA = qw(do_pkgs);

@filesToSaveForUpgrade = qw(
/etc/ld.so.conf /etc/fstab /etc/hosts /etc/conf.modules /etc/modules.conf
);

@filesNewerToUseAfterUpgrade = qw(
/etc/profile
);

#-######################################################################################
#- OO Stuff
#-######################################################################################
sub new($$) {
    my ($type, $o) = @_;

    bless $o, ref($type) || $type;
    return $o;
}

sub charsetChanged {
    my ($_o) = @_;
}

#-######################################################################################
#- In/Out Steps Functions
#-######################################################################################
sub enteringStep {
    my ($_o, $step) = @_;
    log::l("starting step `$step'");
}
sub leavingStep {
    my ($o, $step) = @_;
    log::l("step `$step' finished");

    if (-d "$o->{prefix}/root/drakx") {
	eval { cp_af("/tmp/ddebug.log", "$o->{prefix}/root/drakx") };
	output(install_any::auto_inst_file(), install_any::g_auto_install(1));
    }

    foreach my $s (@{$o->{orderedSteps}}) {
	#- the reachability property must be recomputed each time to take
	#- into account failed step.
	next if $o->{steps}{$s}{done} && !$o->{steps}{$s}{redoable};

	my $reachable = 1;
	if (my $needs = $o->{steps}{$s}{needs}) {
	    my @l = ref($needs) ? @$needs : $needs;
	    $reachable = min(map { $o->{steps}{$_}{done} || 0 } @l);
	}
	$o->{steps}{$s}{reachable} = 1 if $reachable;
    }
    $o->{steps}{$step}{reachable} = $o->{steps}{$step}{redoable};

    while (my $f = shift @{$o->{steps}{$step}{toBeDone} || []}) {
	eval { &$f() };
	$o->ask_warn(N("Error"), [
N("An error occurred, but I don't know how to handle it nicely.
Continue at your own risk."), formatError($@) ]) if $@;
    }
}

sub errorInStep { 
    my ($_o, $err) = @_;
    print "error :(\n"; 
    print "$err\n\n";
    c::_exit(1);
}
sub kill_action {}

#-######################################################################################
#- Steps Functions
#-######################################################################################
#------------------------------------------------------------------------------
sub selectLanguage {
    my ($o) = @_;

    #- for auto_install compatibility with old $o->{lang}
    $o->{locale} = lang::system_locales_to_ourlocale($o->{lang}, $o->{lang}) if $o->{lang};
    $o->{locale}{langs} ||= { $o->{locale}{lang} => 1 };

    if (!exists $o->{locale}{country}) {
	my $h = lang::analyse_locale_name(lang::l2locale($o->{locale}{lang}));
	$o->{locale}{country} = $h->{country} if $h->{country};
	$o->{locale}{IM} = lang::get_default_im($o->{locale}{lang});
    }

    lang::set($o->{locale}, !$o->isa('interactive::gtk'));
    add2hash_($o->{locale}, { utf8 => lang::utf8_should_be_needed($o->{locale}) });

    log::l("selectLanguage: pack_langs: ", lang::pack_langs($o->{locale}{langs}), " utf8-flag: ", to_bool($o->{locale}{utf8}));

    #- for auto_install compatibility with old $o->{keyboard} containing directly $o->{keyboard}{KEYBOARD}
    $o->{keyboard} = { KEYBOARD => $o->{keyboard} } if $o->{keyboard} && !ref($o->{keyboard});

    if (!$o->{keyboard} || $o->{keyboard}{unsafe}) {
	$o->{keyboard} = keyboard::from_usb() || keyboard::lang2keyboard($o->{locale}{lang});
	$o->{keyboard}{unsafe} = 1;
	keyboard::setup($o->{keyboard});
    }

    $o->charsetChanged;

    addToBeDone {
	lang::write_langs($o->{locale}{langs});
    } 'formatPartitions';
    addToBeDone {
	lang::write($o->{locale});
    } 'installPackages';
}
#------------------------------------------------------------------------------
sub selectKeyboard {
    my ($o) = @_;
    $o->{keyboard}{KBCHARSET} = lang::l2charset($o->{locale}{lang});
    keyboard::setup($o->{keyboard});

    addToBeDone {
	keyboard::write($o->{keyboard});
    } 'installPackages' if !$o->{isUpgrade} || !$o->{keyboard}{unsafe};

    if ($o->{raw_X}) {
	require Xconfig::default;
	Xconfig::default::config_keyboard($o->{raw_X}, $o->{keyboard});
	$o->{raw_X}->write;
    }
}
#------------------------------------------------------------------------------
sub acceptLicense {}

#------------------------------------------------------------------------------
sub setupSCSI {
    my ($o) = @_;
    install_any::configure_pcmcia($o->{modules_conf}, $o->{pcmcia}) if $o->{pcmcia};
    modules::load(modules::category2modules('disk/cdrom'));
    modules::load_category($o->{modules_conf}, 'bus/firewire');
    modules::load_category($o->{modules_conf}, 'disk/ide|scsi|hardware_raid|firewire');

    install_any::getHds($o);
}

#------------------------------------------------------------------------------
sub selectInstallClass {
    my ($o) = @_;

    if ($o->{partitioning}{use_existing_root} || $o->{isUpgrade}) {
	# either one root is defined (and all is ok), or we take the first one we find
	my $p = fs::get::root_($o->{fstab}) || (first(install_any::find_root_parts($o->{fstab}, $o->{prefix})) || die)->{part};
	install_any::use_root_part($o->{all_hds}, $p);
    } 
}

#------------------------------------------------------------------------------
sub doPartitionDisksBefore {
    my ($o) = @_;
    eval { 
	eval { fs::umount("$o->{prefix}/sys") };
	eval { fs::umount("$o->{prefix}/proc/bus/usb") };
	eval { fs::umount("$o->{prefix}/proc") };
	eval {          fs::umount_all($o->{fstab}, $o->{prefix}) };
	eval { sleep 1; fs::umount_all($o->{fstab}, $o->{prefix}) } if $@; #- HACK
    } if $o->{fstab} && !$::testing;
}

#------------------------------------------------------------------------------
sub doPartitionDisksAfter {
    my ($o) = @_;

    if (!$::testing) {
	my $hds = $o->{all_hds}{hds};
	partition_table::write($_) foreach @$hds;
	$_->{rebootNeeded} and $o->rebootNeeded foreach @$hds;
    }

    fs::set_removable_mntpoints($o->{all_hds});
    fs::mount_options::set_all_default($o->{all_hds}, %$o, lang::fs_options($o->{locale}))
	if !$o->{isUpgrade};

    $o->{fstab} = [ fs::get::fstab($o->{all_hds}) ];
    fs::get::root_($o->{fstab}) or die "Oops, no root partition";

    if (arch() =~ /ppc/ && detect_devices::get_mac_generation() =~ /NewWorld/) {
	die "Need bootstrap partition to boot system!" if !(defined $partition_table::mac::bootstrap_part);
    }
    
    if (arch() =~ /ia64/ && !fs::get::has_mntpoint("/boot/efi", $o->{all_hds})) {
	die N("You must have a FAT partition mounted in /boot/efi");
    }

    if ($o->{partitioning}{use_existing_root} && !$::recovery) {
	#- ensure those partitions are mounted so that they are not proposed in choosePartitionsToFormat
	fs::mount_part($_, $o->{prefix}) foreach sort { $a->{mntpoint} cmp $b->{mntpoint} }
						 grep { $_->{mntpoint} && maybeFormatted($_) } @{$o->{fstab}};
    }

    cat_("/proc/mounts") =~ m|(\S+)\s+/tmp/nfsimage| &&
      !any { $_->{mntpoint} eq "/mnt/nfs" } @{$o->{all_hds}{nfss}} and
	push @{$o->{all_hds}{nfss}}, { fs_type => 'nfs', mntpoint => "/mnt/nfs", device => $1, options => "noauto,ro,nosuid,soft,rsize=8192,wsize=8192" };
}

#------------------------------------------------------------------------------
sub doPartitionDisks {
    my ($o) = @_;

    if ($o->{partitioning}{auto_allocate}) {
	catch_cdie { fsedit::auto_allocate($o->{all_hds}, $o->{partitions}) } sub { 1 };
    }
}

#------------------------------------------------------------------------------

sub ask_mntpoint_s {#-}}}
    my ($_o, $fstab) = @_;

    #- TODO: set the mntpoints

    my %m; foreach (@$fstab) {
	my $m = $_->{mntpoint};

	next if !$m || $m eq 'swap'; #- there may be a lot of swap.

	$m{$m} and die N("Duplicate mount point %s", $m);
	$m{$m} = 1;

	#- in case the type does not correspond, force it to ext3
	fs::type::set_fs_type($_, 'ext3') if $m =~ m|^/| && !isTrueFS($_) && !isOtherAvailableFS($_);
    }
    1;
}


sub rebootNeeded($) {
    my ($_o) = @_;
    log::l("Rebooting...");
    c::_exit(0);
}

sub choosePartitionsToFormat($$) {
    my ($_o, $fstab) = @_;

    foreach (@$fstab) {
	$_->{mntpoint} = "swap" if isSwap($_);
	$_->{mntpoint} or next;
	
	add2hash_($_, { toFormat => $_->{notFormatted} }) if $_->{fs_type}; #- eg: don't set toFormat for isRawRAID (0xfd)
        $_->{$::recovery ? 'toFormat' : 'toFormatUnsure'} ||= member($_->{mntpoint}, '/', '/usr');

	if (!$_->{toFormat}) {
	    my $fs_type = fs::type::fs_type_from_magic($_);
	    if (!$fs_type || $fs_type ne $_->{fs_type}) {
		log::l("setting toFormatUnsure for $_->{device} because <$_->{fs_type}> ne <$fs_type>");
		$_->{toFormatUnsure} = 1;
	    }
	}
    }
}

sub formatMountPartitions {
    my ($o) = @_;
    fs::formatMount_all($o->{all_hds}{raids}, $o->{fstab}, $o->{prefix});
}

#------------------------------------------------------------------------------
sub setPackages {
    my ($o, $rebuild_needed) = @_;

    install_any::setPackages($o, $rebuild_needed);
    pkgs::selectPackagesAlreadyInstalled($o->{packages}, $o->{prefix});
    $rebuild_needed and pkgs::selectPackagesToUpgrade($o->{packages}, $o->{prefix});
}

sub deselectFoundMedia {
    my (undef, $hdlists) = @_;
    @$hdlists;
}

sub selectSupplMedia { '' }
sub askSupplMirror { '' }

sub choosePackages {
    my ($o, $packages, $_compssUsers, $first_time) = @_;

    #- now for upgrade, package that must be upgraded are
    #- selected first, after is used the same scheme as install.

    #- make sure we kept some space left for available else the system may
    #- not be able to start (xfs at least).
    my $available = install_any::getAvailableSpace($o);
    my $availableCorrected = pkgs::invCorrectSize($available / sqr(1024)) * sqr(1024);
    log::l(sprintf "available size %s (corrected %s)", formatXiB($available), formatXiB($availableCorrected));

    add2hash_($o, { compssListLevel => 5 }) if !$::auto_install;

    #- avoid destroying user selection of packages but only
    #- for expert, as they may have done individual selection before.
    if ($first_time || !$::expert) {
	exists $o->{compssListLevel}
	  and pkgs::setSelectedFromCompssList($packages, $o->{rpmsrate_flags_chosen}, $o->{compssListLevel}, $availableCorrected);
    }
    $availableCorrected;
}

sub upgrading_redhat() {
    #- remove weird config files that bother Xconfig::* too much
    unlink "$::prefix/etc/X11/XF86Config";
    unlink "$::prefix/etc/X11/XF86Config-4";

    sub prefering_mdk {
	my ($lpkg, $rpkg_ver, $c) = @_;
	my $lpkg_ver = $lpkg->version . '-' . $lpkg->release;
	log::l($lpkg->name . ' ' . ': prefering ' . ($c == 1 ? "$lpkg_ver over $rpkg_ver" : "$rpkg_ver over $lpkg_ver"));
    }

    my $old_compare_pkg = \&URPM::Package::compare_pkg;
    undef *URPM::Package::compare_pkg;
    *URPM::Package::compare_pkg = sub {
	my ($lpkg, $rpkg) = @_;
	my $c = ($lpkg->release =~ /mdk$/ ? 1 : 0) - ($rpkg->release =~ /mdk$/ ? 1 : 0);
	if ($c) {
	    prefering_mdk($lpkg, $rpkg->version . '-' . $rpkg->release, $c);
	    $c;
	} else {
	    &$old_compare_pkg;
	}
    };

    my $old_compare = \&URPM::Package::compare;
    undef *URPM::Package::compare;
    *URPM::Package::compare = sub {
	my ($lpkg, $rpkg_ver) = @_;
	my $c = ($lpkg->release =~ /mdk$/ ? 1 : 0) - ($rpkg_ver =~ /mdk$/ ? 1 : 0);
	if ($c) {
	    prefering_mdk($lpkg, $rpkg_ver, $c);
	    return $c;
	}
	&$old_compare;
    };
}

sub beforeInstallPackages {
    my ($o) = @_;

    #- save these files in case of upgrade failure.
    if ($o->{isUpgrade}) {
	foreach (@filesToSaveForUpgrade) {
	    unlink "$o->{prefix}/$_.mdkgisave";
	    if (-e "$o->{prefix}/$_") {
		eval { cp_af("$o->{prefix}/$_", "$o->{prefix}/$_.mdkgisave") };
	    }
	}
	foreach (@filesNewerToUseAfterUpgrade) {
	    unlink "$o->{prefix}/$_.rpmnew";
	}
    }

    #- mainly for upgrading redhat packages, but it can help other
    my @should_not_be_dirs = qw(/usr/X11R6/lib/X11/xkb /usr/share/locale/zh_TW/LC_TIME /usr/include/GL);
    my @should_be_dirs = qw(/etc/X11/xkb);
    my @to_remove = (
		     (grep { !-l $_ && -d $_          } map { "$::prefix$_" } @should_not_be_dirs),
		     (grep { -l $_ || !-d $_ && -e $_ } map { "$::prefix$_" } @should_be_dirs),
		    );
    rm_rf(@to_remove);

    if ($o->{isUpgrade} eq 'redhat') {
	upgrading_redhat();
    }

    #- some packages need such files for proper installation.
    install_any::write_fstab($o);

    require network::network;
    network::network::add2hosts("$o->{prefix}/etc/hosts", "localhost", "127.0.0.1");

    log::l("setting excludedocs to $o->{excludedocs}");
    substInFile { s/%_excludedocs.*//; $_ .= "%_excludedocs yes\n" if eof && $o->{excludedocs} } "$o->{prefix}/etc/rpm/macros";

    #- add oem theme if the files exists.
    mkdir_p("$o->{prefix}/usr/share");
    install_any::getAndSaveFile("install/oem-theme.rpm", "$o->{prefix}/usr/share/oem-theme.rpm");
}

sub pkg_install {
    my ($o, @l) = @_;
    log::l("selecting packages " . join(" ", @l));
    require pkgs;
    if ($::testing) {
	log::l(qq(selecting package "$_")) foreach @l;
    } else {
	$o->{packages}{rpmdb} ||= pkgs::rpmDbOpen($o->{prefix});
	pkgs::selectPackage($o->{packages}, pkgs::packageByName($o->{packages}, $_) || die "$_ rpm not found") foreach @l;
    }
    my @toInstall = pkgs::packagesToInstall($o->{packages});
    if (@toInstall) {
	log::l("installing packages");
	$o->installPackages;
    } else {
	log::l("all packages selected are already installed, nothing to do")
    }
}

sub pkg_install_if_requires_satisfied {
    my ($o, @l) = @_;
    require pkgs;
    $o->{packages}{rpmdb} ||= pkgs::rpmDbOpen($o->{prefix});
    foreach (@l) {
	my %newSelection;
	my $pkg = pkgs::packageByName($o->{packages}, $_) || die "$_ rpm not found";
	pkgs::selectPackage($o->{packages}, $pkg, 0, \%newSelection);
	if (scalar(keys %newSelection) == 1) {
	    pkgs::selectPackage($o->{packages}, $pkg);
	} else {
	    log::l("pkg_install_if_requires_satisfied: not selecting $_ because of ", join(", ", keys %newSelection));
	}
    }
    $o->installPackages;
}

sub installPackages($$) { #- complete REWORK, TODO and TOCHECK!
    my ($o) = @_;
    my $packages = $o->{packages};

    if (%{$packages->{state}{ask_remove} || {}}) {
	log::l("removing : ", join ', ', keys %{$packages->{state}{ask_remove}});
	pkgs::remove($o->{prefix}, [ keys %{$packages->{state}{ask_remove}} ], $packages);
    }

    #- small transaction will be built based on this selection and depslist.
    my @toInstall = pkgs::packagesToInstall($packages);

    my $time = time();
    $ENV{DURING_INSTALL} = 1;
    pkgs::install($o->{prefix}, $o->{isUpgrade}, \@toInstall, $packages);

    any::writeandclean_ldsoconf($o->{prefix});
    delete $ENV{DURING_INSTALL};
    run_program::rooted_or_die($o->{prefix}, 'ldconfig');

    eval {
	run_program::rooted($o->{prefix}, 'gdk-pixbuf-query-loaders', '>', '/etc/gtk-2.0/gdk-pixbuf.loaders.' . (arch() =~ /64/ ? 'lib64' : 'lib'));
	run_program::rooted($o->{prefix}, 'gtk-query-immodules-2.0', '>', '/etc/gtk-2.0/gtk.immodules.' . (arch() =~ /64/ ? 'lib64' : 'lib'));
	run_program::rooted($o->{prefix}, 'pango-querymodules-' . (arch() =~ /64/ ? '64' : '32'), '>', '/etc/pango/' . (arch() =~ /i.86/ ? 'i386' : arch()) . '/pango.modules');
    };

    log::l("Install took: ", formatTimeRaw(time() - $time));
    install_any::log_sizes($o);
    scalar(@toInstall); #- return number of packages installed.
}

sub afterInstallPackages($) {
    my ($o) = @_;

    die N("Some important packages didn't get installed properly.
Either your cdrom drive or your cdrom is defective.
Check the cdrom on an installed computer using \"rpm -qpl media/main/*.rpm\"
") if any { m|read failed: Input/output error| } cat_("$o->{prefix}/root/drakx/install.log");

    if (arch() !~ /^sparc/) { #- TODO restore it as may be needed for sparc
	-x "$o->{prefix}/usr/bin/dumpkeys" or $::testing or die 
"Some important packages didn't get installed properly.

Please switch to console 2 (using ctrl-alt-f2)
and look at the log file /tmp/ddebug.log

Consoles 1,3,4,7 may also contain interesting information";
    }

    #-  why not? cuz weather is nice today :-) [pixel]
    common::sync(); common::sync();

    my $have_devfsd = do {
	my $p = pkgs::packageByName($o->{packages}, 'devfsd');
	$p && $p->flag_installed
    };
    require bootloader;
    bootloader::may_append($o->{bootloader}, devfs => $have_devfsd ? 'mount' : 'nomount');

    #- generate /etc/lvmtab needed for rc.sysinit
    run_program::rooted($o->{prefix}, 'lvm2', 'vgscan') if -e '/etc/lvmtab';

    #- configure PCMCIA services if needed.
    install_any::write_pcmcia($o->{pcmcia});

    #- for mandrake_firstime
    touch "$o->{prefix}/var/lock/TMP_1ST";

    any::config_dvd($o->{prefix}, $have_devfsd);
    any::config_mtools($o->{prefix});

    #- make sure wins is disabled in /etc/nsswitch.conf
    #- else if eth0 is not existing, glibc segfaults.
    substInFile { s/\s*wins// if /^\s*hosts\s*:/ } "$o->{prefix}/etc/nsswitch.conf";

    #- make sure some services have been enabled (or a catastrophic restart will occur).
    #- these are normally base package post install scripts or important services to start.
    run_program::rooted($o->{prefix}, "chkconfig", "--add", $_) foreach
			qw(random netfs network rawdevices sound kheader keytable syslog crond portmap);

    if ($o->{mouse}{device} =~ /ttyS/) {
	log::l("disabling gpm for serial mice (doesn't get along nicely with X)");
	run_program::rooted($o->{prefix}, "chkconfig", "--del", "gpm") 
    }

    #- install urpmi before as rpmdb will be opened, this will cause problem with update-menus.
    $o->install_urpmi;

    #- update menu scheme before calling update menus if desktop mode.
    if ($o->{meta_class} eq 'desktop') {
	run_program::rooted($o->{prefix}, "touch", "/etc/menu/do-not-create-menu-link");
	run_program::rooted($o->{prefix}, "touch", "/etc/menu/enable_simplified");
    } elsif (!$o->{isUpgrade}) {
	run_program::rooted($o->{prefix}, "touch", "/etc/menu/do-not-create-menu-link");
    }

    if ($o->{pcmcia}) {
	substInFile { s/.*(TaskBarShowAPMStatus).*/$1=1/ } "$o->{prefix}/usr/lib/X11/icewm/preferences";
	eval { cp_af("$o->{prefix}/usr/share/applnk/System/kapm.kdelnk",
		     "$o->{prefix}/etc/skel/Desktop/Autostart/kapm.kdelnk") };
    }

    if ($o->{brltty}) {
	output("$o->{prefix}/etc/brltty.conf", <<EOF);
braille-driver $o->{brltty}{driver}
braille-device $o->{brltty}{device}
text-table $o->{brltty}{table}
EOF
    }


    install_any::disable_user_view() if $o->{security} >= 3 || $o->{authentication}{NIS};
    run_program::rooted($o->{prefix}, "kdeDesktopCleanup");

    foreach (list_skels($o->{prefix}, '.kde/share/config/kfmrc')) {
	my $found;
	substInFile {
	    $found ||= /KFM Misc Defaults/;
	    $_ .= 
"[KFM Misc Defaults]
GridWidth=85
GridHeight=70
" if eof && !$found;
	} $_ 
    }

    #- move some file after an upgrade that may be seriously annoying.
    #- and rename saved files to .mdkgiorig.
    if ($o->{isUpgrade}) {
	my $pkg = pkgs::packageByName($o->{packages}, 'rpm');
	$pkg && ($pkg->flag_selected || $pkg->flag_installed) && $pkg->compare(">= 4.0") and pkgs::cleanOldRpmDb($o->{prefix});

	log::l("moving previous desktop files that have been updated to Trash of each user");
	install_any::kdemove_desktop_file($o->{prefix});

	foreach (@filesToSaveForUpgrade) {
	    renamef("$o->{prefix}/$_.mdkgisave", "$o->{prefix}/$_.mdkgiorig")
	      if -e "$o->{prefix}$_.mdkgisave";
	}

	foreach (@filesNewerToUseAfterUpgrade) {
	    if (-e "$o->{prefix}/$_.rpmnew" && -e "$o->{prefix}/$_") {
		renamef("$o->{prefix}/$_", "$o->{prefix}/$_.mdkgiorig");
		renamef("$o->{prefix}/$_.rpmnew", "$o->{prefix}/$_");
	    }
	}
    }

    any::fix_broken_alternatives($o->{isUpgrade} eq 'redhat');

    #- update theme directly from a package (simplest).
    if (-s "$o->{prefix}/usr/share/oem-theme.rpm") {
	run_program::rooted($o->{prefix}, "rpm", "-U", "/usr/share/oem-theme.rpm");
	unlink "/usr/share/oem-theme.rpm";
    }

    #- call update-menus at the end of package installation
    push @{$o->{waitpids}}, run_program::raw({ root => $o->{prefix}, detach => 1 }, "update-menus", "-n");

    if ($o->{updatemodules}) {
	$o->{updatemodules} = detect_devices::floppy() or die N("No floppy drive available");
	$o->updateModulesFromFloppy;
    }
}

sub install_urpmi {
    my ($o) = @_;

    my $pkg = pkgs::packageByName($o->{packages}, 'urpmi');
    if ($pkg && ($pkg->flag_selected || $pkg->flag_installed)) {
	install_any::install_urpmi($o->{prefix}, 
				   $o->{method},
				   $o->{packages},
				   $o->{packages}{mediums});
	pkgs::saveCompssUsers($o->{prefix}, $o->{packages}, $o->{compssUsers});
    }
}

sub updateModulesFromFloppy {
    my ($o) = @_;
    return if $::testing;

    fs::mount($o->{updatemodules}, "/floppy", "ext2", 0);
    foreach (glob_("$o->{prefix}/lib/modules/*")) {
	my ($kernelVersion) = m,lib/modules/(\S*),;
	log::l("examining updated modules for kernel $kernelVersion");
	if (-d "/floppy/$kernelVersion") {
	    my @src_files = glob_("/floppy/$kernelVersion/*");
	    my @dest_files = map { chomp_($_) } run_program::rooted_get_stdout($o->{prefix}, 'find', '/lib/modules');
	    foreach my $s (@src_files) {
		log::l("found updatable module $s");
		my ($sfile, $sext) = $s =~ m!([^/\.]*\.k?o)(?:\.gz|\.bz2)?$!;
		my $qsfile = quotemeta $sfile;
		my $qsext = quotemeta $sext;
		foreach my $target (@dest_files) {
		    $target =~ /$qsfile/ or next;
		    eval { cp_af($s, $target) };
		    if ($@) {
			log::l("updating module $target by $s failed: $@");
		    } else {
			log::l("updating module $target by $s");
		    }
		    if ($target !~ /$qsfile$qsext$/) {
			#- extension differ, first rename target file correctly,
			#- then uncompress source file, then compress it as expected.
			my ($basetarget, $text) = $target =~ /(.*?)(\.gz|\.bz2)$/;
			rename $target, "$basetarget$sext";
			$sext eq '.gz' and run_program::run("gzip", "-d", "$basetarget$sext");
			$sext eq '.bz2' and run_program::run("bzip2", "-d", "$basetarget$sext");
			$text eq '.gz' and run_program::run("gzip", $basetarget);
			$text eq '.bz2' and run_program::run("bzip2", $basetarget);
		    }
		}
	    }
	}
    }
    fs::umount("/floppy");
}

#------------------------------------------------------------------------------
sub selectMouse($) {
    my ($_o) = @_;
}

#------------------------------------------------------------------------------
sub configureNetwork {
    my ($o) = @_;
    require network::network;
    network::network::configureNetwork2($o, $o->{modules_conf}, $o->{prefix}, $o->{netc}, $o->{intf});
    if ($o->{method} =~ /ftp|http|nfs/) {
	$o->{netcnx}{type} = 'lan';
	$o->{netcnx}{$_} = $o->{netc}{$_} foreach qw(NET_DEVICE NET_INTERFACE);
    }
}

#------------------------------------------------------------------------------
sub installUpdates {
    my ($o) = @_;
    my $u = $o->{updates} or return; $u->{updates} or return;

    upNetwork($o);
    require crypto;
    crypto::getPackages($o->{prefix}, $o->{packages}, $u->{mirror}) and
	$o->pkg_install(@{$u->{packages} || []});

    #- re-install urpmi with update security medium.
    $o->install_urpmi;
}

sub summaryBefore {}

sub summary {
    my ($o) = @_;
    configureTimezone($o);
    configurePrinter($o) if $o->{printer};
}

sub summaryAfter {
    my ($_o) = @_;
}

#------------------------------------------------------------------------------
sub configureTimezone {
    my ($o) = @_;
    install_any::preConfigureTimezone($o);

    $o->pkg_install('ntp') if $o->{timezone}{ntp};

    require timezone;
    timezone::write($o->{timezone});
}

#------------------------------------------------------------------------------
sub configureServices {
    my ($o) = @_;
    if ($o->{services}) {
	require services;
	services::doit($o, $o->{services});
    }
}
#------------------------------------------------------------------------------
sub configurePrinter {
    my ($o) = @_;
    eval {
	$o->do_pkgs->install('foomatic-filters', 'foomatic-db-engine', 'foomatic-db', 'printer-utils', 'printer-testpages',
			     if_($o->do_pkgs->is_installed('gimp'), 'gimpprint'));
    };
    if ($@ =~ /rpm not found/) {
	log::l("ERROR: $@");
	if ($o->{printer}) {
	    require printer::printerdrake;
	    printer::printerdrake::final_cleanup($o->{printer});
	}
	return;
    }

    require printer::main;
    eval { add2hash($o->{printer} ||= {}, printer::main::getinfo($o->{prefix})) }; #- get existing configuration.

    require printer::printerdrake;
    printer::printerdrake::install_spooler($o->{printer}, $o->{security}, $o->do_pkgs);

    foreach (values %{$o->{printer}{configured} || {}}) {
	log::l("configuring printer queue " . $_->{queuedata}{queue} || $_->{QUEUE});
	#- when copy is so adul�e (sorry french taste :-)
	#- and when there are some configuration in one place and in another place...
	$o->{printer}{currentqueue} = {};
	printer::main::copy_printer_params($_->{queuedata}, $o->{printer}{currentqueue});
	printer::main::copy_printer_params($_, $o->{printer});
	#- setup all configured queues, which is not the case interactively where
	#- only the working queue is setup on configuration.
	printer::main::configure_queue($o->{printer});
    }
}

#------------------------------------------------------------------------------
sub setRootPassword {
    my ($o) = @_;
    $o->{superuser} ||= {};
    $o->{superuser}{name} = 'root';
    any::write_passwd_user($o->{superuser}, $o->{authentication}{md5});
    delete $o->{superuser}{name};
    install_any::set_authentication($o);
}

#------------------------------------------------------------------------------

sub addUser {
    my ($o) = @_;
    my $users = $o->{users} ||= [];

    if ($::prefix) {
	#- getpwnam, getgrnam, getgrid works
	symlinkf("$::prefix/etc/passwd", '/etc/passwd');
	symlinkf("$::prefix/etc/group", '/etc/group');
    }

    my (%uids, %gids); 
    foreach (glob_("$::prefix/home")) { my ($u, $g) = (stat($_))[4,5]; $uids{$u} = 1; $gids{$g} = 1 }

    foreach (@$users) {
	$_->{home} ||= "/home/$_->{name}";

	my $u = $_->{uid} || ($_->{oldu} = (stat("$::prefix$_->{home}"))[4]) || int getpwnam($_->{name});
	my $g = $_->{gid} || ($_->{oldg} = (stat("$::prefix$_->{home}"))[5]) || int getgrnam($_->{name});
	#- search for available uid above 501 else initscripts may fail to change language for KDE.
	if (!$u || getpwuid($u)) { for ($u = 501; getpwuid($u) || $uids{$u}; $u++) {} }
	if (!$g)                 { for ($g = 501; getgrgid($g) || $gids{$g}; $g++) {} }
	
	$_->{uid} = $u; $uids{$u} = 1;
	$_->{gid} = $g; $gids{$g} = 1;
    }

    any::write_passwd_user($_, $o->{authentication}{md5}) foreach @$users;

    append_to_file("$::prefix/etc/group",
		   map { "$_->{name}:x:$_->{gid}:\n" } grep { ! getgrgid($_->{gid}) } @$users);

    foreach my $u (@$users) {
	if (! -d "$::prefix$u->{home}") {
	    my $mode = $o->{security} < 2 ? 0755 : 0750;
	    eval { cp_af("$::prefix/etc/skel", "$::prefix$u->{home}") };
	    if ($@) {
		log::l("copying of skel failed: $@"); mkdir("$::prefix$u->{home}", $mode); 
	    } else {
		chmod $mode, "$::prefix$u->{home}";
	    }
	}
	require commands;
	eval { commands::chown_("-r", "$u->{uid}.$u->{gid}", "$::prefix$u->{home}") }
	    if $u->{uid} != $u->{oldu} || $u->{gid} != $u->{oldg};
    }
    #- since we wrote the password in /etc/passwd, we must convert to shadow
    run_program::rooted($::prefix, 'pwconv') if $o->{authentication}{shadow};

    any::addUsers($users);

    if ($o->{autologin}) {
	$o->{desktop} ||= first(any::sessions());
	$o->pkg_install("autologin") if !member($o->{desktop}, 'KDE', 'GNOME');
    }
    any::set_autologin($o->{autologin}, $o->{desktop});

    install_any::disable_user_view() if @$users == ();
}

#------------------------------------------------------------------------------
sub readBootloaderConfigBeforeInstall {
    my ($o) = @_;

    require bootloader;
    add2hash($o->{bootloader} ||= {}, bootloader::read($o->{fstab}));

    $o->{bootloader}{bootUnsafe} = 0 if $o->{bootloader}{boot}; #- when upgrading, don't ask where to install the bootloader (mbr vs boot partition)
}

sub setupBootloaderBefore {
    my ($o) = @_;

    require bootloader;

    #- remove previous ide-scsi lines
    bootloader::modify_append($o->{bootloader}, sub {
	my ($_simple, $dict) = @_;
	@$dict = grep { $_->[1] ne 'ide-scsi' } @$dict;
    });

    if ($o->{miscellaneous}{HDPARM}) {
	bootloader::set_append($o->{bootloader}, $_, 'autotune') foreach grep { /ide/ } all("/proc/ide");
    }
    if (cat_("/proc/cmdline") =~ /mem=nopentium/) {
	bootloader::set_append($o->{bootloader}, 'mem', 'nopentium');
    }
    if (cat_("/proc/cmdline") =~ /\b(pci)=(\S+)/) {
	bootloader::set_append($o->{bootloader}, $1, $2);
    }
    if (my ($acpi) = cat_("/proc/cmdline") =~ /\bacpi=(\w+)/) {
	if ($acpi eq 'ht') {
	    #- the user is using the default, which may not be the best
	    my $year = detect_devices::dmidecode()->{BIOS_Year};
	    if (detect_devices::isLaptop() && $year >= 2002) {
		log::l("forcing ACPI on a laptop with recent bios ($year)");
		$acpi = 'on';
	    }
	}
	bootloader::set_append($o->{bootloader}, acpi => $acpi);
    }
    if (cat_("/proc/cmdline") =~ /\bnoapic/) {
	bootloader::set_append($o->{bootloader}, 'noapic');
    }
    my ($MemTotal) = cat_("/proc/meminfo") =~ /^MemTotal:\s*(\d+)/m;
    if (my ($biggest_swap) = sort { $b->{size} <=> $a->{size} } grep { isSwap($_) } @{$o->{fstab}}) {
	log::l("MemTotal: $MemTotal < ", $biggest_swap->{size} / 2);
	bootloader::set_append($o->{bootloader}, resume => devices::make($biggest_swap->{device})) if $MemTotal < $biggest_swap->{size} / 2;
    }

    #- check for valid fb mode to enable a default boot with frame buffer.
    my $vga = $o->{allowFB} && (!detect_devices::matching_desc__regexp('3D Rage LT') &&
                                !detect_devices::matching_desc__regexp('Rage Mobility [PL]') &&
                                !detect_devices::matching_desc__regexp('i740') &&
                                !detect_devices::matching_desc__regexp('Matrox') &&
                                !detect_devices::matching_desc__regexp('Tseng.*ET6\d00') &&
                                !detect_devices::matching_desc__regexp('SiS.*SG86C2.5') &&
                                !detect_devices::matching_desc__regexp('SiS.*559[78]') &&
                                !detect_devices::matching_desc__regexp('SiS.*300') &&
                                !detect_devices::matching_desc__regexp('SiS.*540') &&
                                !detect_devices::matching_desc__regexp('SiS.*6C?326') &&
                                !detect_devices::matching_desc__regexp('SiS.*6C?236') &&
                                !detect_devices::matching_desc__regexp('Voodoo [35]|Voodoo Banshee') && #- 3d acceleration seems to bug in fb mode
                                !detect_devices::matching_desc__regexp('828[14][05].* CGC') #- i810 & i845 now have FB support during install but we disable it afterwards
                               );
    my $force_vga = $o->{allowFB} && (detect_devices::matching_desc__regexp('SiS.*630') || #- SiS 630 need frame buffer.
                                      detect_devices::matching_desc__regexp('GeForce.*Integrated') #- needed for fbdev driver (hack).
                                     );

    #- propose the default fb mode for kernel fb, if aurora or bootsplash is installed.
    my $need_fb = do {
        my $p = pkgs::packageByName($o->{packages}, 'bootsplash');
        $p && $p->flag_installed;
    };
    bootloader::suggest($o->{bootloader}, $o->{all_hds},
                        vga_fb => ($force_vga || $vga && $need_fb) && $o->{vga}, 
                        quiet => $o->{meta_class} ne 'server');

    $o->{bootloader}{keytable} ||= keyboard::keyboard2kmap($o->{keyboard});
}

sub setupBootloader {
    my ($o) = @_;

    any::install_acpi_pkgs($o->do_pkgs, $o->{bootloader});

    require bootloader;
    bootloader::install($o->{bootloader}, $o->{all_hds});
}

#------------------------------------------------------------------------------
sub configureXBefore {
    my ($o) = @_;

    #- keep this here if the package has to be updated.
    $o->pkg_install("xorg-x11");
}
sub configureX {
    my ($o) = @_;
    configureXBefore($o);

    require Xconfig::default;
    $o->{raw_X} = Xconfig::default::configure($o->{keyboard}, $o->{mouse});

    require Xconfig::main;
    Xconfig::main::configure_everything_auto_install($o->{raw_X}, $o->do_pkgs, $o->{X}, install_any::X_options_from_o($o));
    configureXAfter($o);
}
sub configureXAfter {
    my ($o) = @_;
    if ($o->{X}{bios_vga_mode}) {
	install_any::setupFB($o, $o->{X}{bios_vga_mode}) or do {
	    log::l("disabling automatic start-up of X11 if any as setup framebuffer failed");
	    Xconfig::various::runlevel(3); #- disable automatic start-up of X11 on error.
	};
    }
    if ($o->{X}{default_depth} >= 16 && $o->{X}{resolution_wanted} >= 1024) {
	log::l("setting large icon style for kde");
	install_any::kderc_largedisplay($o->{prefix});
    }
}

#------------------------------------------------------------------------------
sub miscellaneousBefore {
    my ($o) = @_;

    my %s = getVarsFromSh("$o->{prefix}/etc/sysconfig/system");
    $o->{miscellaneous}{HDPARM} = $s{HDPARM} if exists $s{HDPARM};
    require security::level;
    require security::various;
    $o->{security} ||= security::level::get() || ($o->{meta_class} =~ /server|firewall/ ? 3 : 2);
    $o->{security_user} ||= security::various::config_security_user($o->{prefix});
    $o->{libsafe} ||= security::various::config_libsafe($o->{prefix});

    log::l("security $o->{security}");

    add2hash_($o->{miscellaneous} ||= {}, { numlock => !detect_devices::isLaptop() });
}
sub miscellaneous {
    my ($_o) = @_;
    #- keep some given parameters
    #-TODO
}
sub miscellaneousAfter {
    my ($o) = @_;
    add2hash_ $o, { useSupermount => $o->{security} < 4 ? 'magicdev' : 0 };

    $ENV{SECURE_LEVEL} = $o->{security}; #- deprecated with chkconfig 1.3.4-2mdk, uses /etc/sysconfig/msec

    addToBeDone {
	setVarsInSh("$o->{prefix}/etc/sysconfig/system", { 
            CLASS => $::expert && 'expert' || 'beginner',
            SECURITY => $o->{security},
	    META_CLASS => $o->{meta_class} || 'PowerPack',
        });
	substInFile { s/KEYBOARD_AT_BOOT=.*/KEYBOARD_AT_BOOT=yes/ } "$o->{prefix}/etc/sysconfig/usb" if detect_devices::usbKeyboards();

    } 'installPackages';
}

#------------------------------------------------------------------------------
sub exitInstall { 
    my ($o) = @_;
    eval { 
	my $report = '/root/drakx/report.bug';
	unlink "$::prefix$report", "$::prefix$report.gz";
	output "$::prefix$report", install_any::report_bug($o->{prefix});
	run_program::rooted($::prefix, 'gzip', $report);
    };
    install_any::getAndSaveAutoInstallFloppies($o, 1);
    eval { output "$o->{prefix}/root/drakx/README", "This directory contains several installation-related files,
mostly log files (very useful if you ever report a bug!).

Beware that some Mandrakelinux tools rely on the contents of some
of these files... so remove any file from here at your own
risk!
" };
    #- wait for remainging processes.
    foreach (@{$o->{waitpids}}) {
	waitpid $_, 0;
	log::l("pid $_ returned $?");
    }
    install_any::unlockCdrom();
    install_any::log_sizes($o);
}

#------------------------------------------------------------------------------
sub hasNetwork {
    my ($o) = @_;
    $o->{netcnx}{type} && $o->{netc}{NETWORKING} ne 'no' and return 1;
    log::l("no network seems to be configured for internet ($o->{netcnx}{type},$o->{netc}{NETWORKING})");
    0;
}

#------------------------------------------------------------------------------
sub upNetwork {
    my ($o, $b_pppAvoided) = @_;

    #- do not destroy this file if prefix is '' or even '/' (could it happens ?).
    if (length($o->{prefix}) > 1) {
	symlinkf("$o->{prefix}/etc/$_", "/etc/$_") foreach qw(resolv.conf protocols services);
    }
    member($o->{method}, qw(ftp http nfs)) and return 1;
    $o->{modules_conf}->write;
    if (hasNetwork($o)) {
	if ($o->{netcnx}{type} =~ /adsl|lan|cable/) {
	    log::l("starting network ($o->{netcnx}{type})");
	    require network::netconnect;
	    network::netconnect::start_internet($o);
	    return 1;
	} elsif (!$b_pppAvoided) {
	    log::l("starting network (ppp: $o->{netcnx}{type})");
	    eval { modules::load(qw(serial ppp bsd_comp ppp_deflate)) };
	    run_program::rooted($o->{prefix}, "/etc/rc.d/init.d/syslog", "start");
	    require network::netconnect;
	    network::netconnect::start_internet($o);
	    return 1;
	} else {
	    log::l(qq(not starting network (b/c ppp avoided and type is "$o->{netcnx}{type})"));
	}
    }
    $::testing;
}

#------------------------------------------------------------------------------
sub downNetwork {
    my ($o, $costlyOnly) = @_;

    $o->{method} eq "ftp" || $o->{method} eq "http" || $o->{method} eq "nfs" and return 1;
    $o->{modules_conf}->write;
    if (hasNetwork($o)) {
	if (!$costlyOnly) {
	    require network::netconnect;
	    network::netconnect::stop_internet($o);
	    return 1;
	} elsif ($o->{netc}{type} !~ /adsl|lan|cable/) {
	    require network::netconnect;
	    network::netconnect::stop_internet($o);
	    run_program::rooted($o->{prefix}, "/etc/rc.d/init.d/syslog", "stop");
	    eval { modules::unload(qw(ppp_deflate bsd_comp ppp serial)) };
	    return 1;
	}
    }
    $::testing;
}

#------------------------------------------------------------------------------
sub cleanIfFailedUpgrade($) {
    my ($o) = @_;

    #- if an upgrade has failed, there should be .mdkgisave files around.
    if ($o->{isUpgrade}) {
	foreach (@filesToSaveForUpgrade) {
	    if (-e "$o->{prefix}/$_" && -e "$o->{prefix}/$_.mdkgisave") {
		rename "$o->{prefix}/$_", "$o->{prefix}/$_.mdkginew"; #- keep new files around in case !
		rename "$o->{prefix}/$_.mdkgisave", "$o->{prefix}/$_";
	    }
	}
    }
}


1;
