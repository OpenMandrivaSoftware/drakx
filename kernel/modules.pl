use strict;


BEGIN {
    #- for testing purpose
    (my $f = __FILE__) =~ s|/[^/]*$||;
    push @INC, $f;
}

use MDK::Common;
use list_modules;


my @skip_big_modules_on_stage1 = (
qw(
olympic
sk98lin acenic
3c90x
ns83820
aironet4500_card aironet4500_core com20020-pci hamachi starfire winbond-840

dc395x_trm
BusLogic seagate fdomain g_NCR5380
)
);

my @skip_modules_on_stage1 = (
  qw(sktr tmspci ibmtr abyss), # alt token ring
  qw(old_tulip rtl8139),
  if_(arch() =~ /alpha|ppc/, qw(sb1000)),
  "apa1480_cb",
  "imm",
  "ppa",
  "plip",
  qw(3w-xxxx pci2220i qla2x00 i2o_block),
  qw(eata_pio eata_dma),
  'AM53C974', # deprecated by tmscsim
  qw(ac3200 at1700 atp ni5010 ni52 ni65),  #- unused from Jeff
  "u14-34f", #- duplicate from ultrastor.o
);

my %images = (
    network => 'fs/network network/main|raw bus/pcmcia',
    cdrom   => 'fs/cdrom disk/cdrom|scsi|raw',
    hd      => 'fs/local fs/loopback disk/scsi|hardware_raid|raw',
    usb     => 'fs/network|cdrom bus/usb network/usb|raw disk/cdrom|usb|raw',
    pcmcia  => 'fs/network|cdrom disk/cdrom|pcmcia|raw bus/pcmcia network/pcmcia|raw',
    other   => 'network/main disk/scsi|hardware_raid ONLY_BIG fs/network network/raw fs/cdrom disk/cdrom|raw',
    all     => 'fs/network|cdrom|loopback|local bus/pcmcia|usb network/main|pcmcia|usb|raw disk/cdrom|scsi|hardware_raid|pcmcia|usb|raw',
);

my $verbose = "@ARGV" =~ /-v/;
images() if "@ARGV" =~ /images/;
check() if "@ARGV" =~ /check/;
pci_modules4stage1($1) if "@ARGV" =~ /pci_modules4stage1:(.*)/;

sub images {
    load_dependencies('modules.dep');

    while (my ($image, $l) = each %images) {
	my @modules;
	foreach (split(' ', $l)) { 
	    if (/ONLY_BIG/) {
		@modules = intersection(\@modules, \@skip_big_modules_on_stage1);
		next;
	    }
	    push @modules, category2modules($_);
	}

	@modules = difference2(\@modules, \@skip_modules_on_stage1);
	if ($image !~ /other|all/) {
	    @modules = difference2(\@modules, \@skip_big_modules_on_stage1)
	}
	@modules = map { dependencies_closure($_) } @modules;
	printf qq(%s_modules="%s"\n), $image, join(" ", map { "$_.o" } sort @modules);
    }
}

sub pci_modules4stage1 {
    print "$_\n" foreach difference2([ category2modules($_[0]) ], \@skip_modules_on_stage1);
}

sub check {
    my $error;
    my %listed;
    my %big_modules_categories;
    while (my ($t1, $l) = each %list_modules::l) {
	while (my ($t2, $l) = each %$l) {
	    ref $l or die "bad $l in $t1/$t2";
	    foreach (@$l) {
		$listed{$_} = 1; 
		push @{$big_modules_categories{$t1}{$t2}}, $_ if member($_, @skip_modules_on_stage1);
	    }
	}
    }

    # remove accepted categories for other.img
    delete $big_modules_categories{disk}{hardware_raid};
    delete $big_modules_categories{disk}{scsi};
    delete $big_modules_categories{network}{main};

    if (map { %$_ } values %big_modules_categories) {
	my @l = map { "$_/" . join('|', sort keys %{$big_modules_categories{$_}}) } sort keys %big_modules_categories;
	print STDERR "WEIRD CATEGORIES USED FOR other.img: ", join(" ", @l), "\n";
	if ($verbose) {
	    while (my ($t1, $t2s) = each %big_modules_categories) {
		print "$t1/$_ used for other.img: ", join(" ", @{$t2s->{$_}}), "\n" foreach keys %$t2s;
	    }
	}
	$error = 1;
    }

    my %deprecated_modules = %listed;
    my $not_listed = sub {
	my ($msg, $verbose, @l) = @_;
	my %not_listed;
	foreach (@l) {
	    my ($mod) = m|([^/]*)\.o(\.gz)?$| or next;
	    delete $deprecated_modules{$mod};
	    next if $listed{$mod};
	    s|.*?mdk(BOOT)?/||;
	    s|kernel/||; s|drivers/||; s|3rdparty/||;
	    $_ = dirname $_;
	    $_ = dirname $_ if $mod eq basename($_);
	    push @{$not_listed{$_}}, $mod;
	}
	if ($verbose) {
	    print "$msg $_: ", join(" ", @{$not_listed{$_}}), "\n" foreach sort keys %not_listed;
	}
    };
    $not_listed->('NOT LISTED', 1, `cd all.kernels/2.4* ; find -name "*.o" -o -name "*.o.gz"`);
    $not_listed->('not listed', $verbose, `rpm -qpl /RPMS/kernel-2.4*`);
    print "bad/old modules : ", join(" ", sort keys %deprecated_modules), "\n" if %deprecated_modules;

    exit $error;
}
