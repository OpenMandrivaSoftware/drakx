$kinds2all_modules = {
                       'usb' => [
                                  'usb-uhci',
                                  'usb-ohci',
                                  'ehci-hcd'
                                ],
                       'network' => [
                                      '3c501',
                                      '3c503',
                                      '3c505',
                                      '3c507',
                                      '3c509',
                                      '3c515',
                                      '3c90x',
                                      '82596',
                                      'abyss',
                                      'ac3200',
                                      'acenic',
                                      'aironet4500_card',
                                      'at1700',
                                      'atp',
                                      'com20020-pci',
                                      'cs89x0',
                                      'de600',
                                      'de620',
                                      'defxx',
                                      'depca',
                                      'dgrs',
                                      'dmfe',
                                      'e100',
                                      'e2100',
                                      'eepro',
                                      'eepro100',
                                      'eexpress',
                                      'epic100',
                                      'eth16i',
                                      'ewrk3',
                                      'hamachi',
                                      'hp',
                                      'hp-plus',
                                      'hp100',
                                      'ibmtr',
                                      'lance',
                                      'natsemi',
                                      'ne',
                                      'ne2k-pci',
                                      'ni5010',
                                      'ni52',
                                      'ni65',
                                      'nvnet',
                                      'olympic',
                                      'pcnet32',
                                      'plip',
                                      'rcpci',
                                      'sb1000',
                                      'sis900',
                                      'smc-ultra',
                                      'smc9194',
                                      'starfire',
                                      'tlan',
                                      'tmspci',
                                      'tulip',
                                      'via-rhine',
                                      'wd',
                                      'winbond-840',
                                      'forcedeth',
                                      'fealnx',
                                      '3c990',
                                      '3c990fx',
                                      'b44',
                                      'bcm4400',
                                      'skfp',
                                      'tc35815',
                                      'lanstreamer',
                                      'farsync',
                                      'sdladrv',
                                      'prism2_plx',
                                      'iph5526',
                                      '3c59x',
                                      '8139too',
                                      '8139cp',
                                      'sundance',
                                      'catc',
                                      'CDCEther',
                                      'kaweth',
                                      'pegasus',
                                      'rtl8150',
                                      'usbnet',
                                      'dl2k',
                                      'myri_sbus',
                                      'yellowfin',
                                      'ns83820',
                                      'r8169',
                                      'tg3',
                                      'e1000',
                                      'sk98lin',
                                      'bcm5820',
                                      'bcm5700'
                                    ],
                       'scsi' => [
                                   '3w-xxxx',
                                   'AM53C974',
                                   'BusLogic',
                                   'NCR53c406a',
                                   'a100u2w',
                                   'advansys',
                                   'aha152x',
                                   'aha1542',
                                   'aha1740',
                                   'atp870u',
                                   'dc395x_trm',
                                   'dtc',
                                   'g_NCR5380',
                                   'in2000',
                                   'initio',
                                   'pas16',
                                   'pci2220i',
                                   'psi240i',
                                   'fdomain',
                                   'qla1280',
                                   'qla2x00',
                                   'qlogicfas',
                                   'qlogicfc',
                                   'seagate',
                                   'wd7000',
                                   'sim710',
                                   'sym53c416',
                                   't128',
                                   'tmscsim',
                                   'u14-34f',
                                   'ultrastor',
                                   'eata',
                                   'eata_pio',
                                   'eata_dma',
                                   'mptscsih',
                                   'nsp32',
                                   'ata_piix',
                                   'sata_promise',
                                   'sata_svw',
                                   'sata_via',
                                   '53c7,8xx',
                                   'aic7xxx',
                                   'aic7xxx_old',
                                   'aic79xx',
                                   'pci2000',
                                   'qlogicisp',
                                   'sym53c8xx',
                                   'lpfcdd',
                                   'DAC960',
                                   'dpt_i2o',
                                   'megaraid',
                                   'aacraid',
                                   'cciss',
                                   'cpqarray',
                                   'gdth',
                                   'i2o_block',
                                   'cpqfc',
                                   'qla2200',
                                   'qla2300',
                                   'pdc-ultra',
                                   'ips',
                                   'ppa',
                                   'imm'
                                 ]
                     };
my @l = map { /^(\S+)\s*:/ ? $1 : () } `lspcidrake`;

my %kinds2modules = map { 
    $_ => [ intersection(\@l, $kinds2all_modules->{$_}) ];
} qw(usb scsi);

$kinds2modules{network} = [
  grep {
	  my $l = $_;
	  scalar grep { $_ eq $l } @{ $kinds2all_modules->{network} }
  } @l
];

if (my @scsi = @{$kinds2modules{scsi}}) {
    print "probeall scsi_hostadapter ", join(" ", @scsi), "\n";
}
if (my @usb = @{$kinds2modules{usb}}) {
    print "probeall usb-interface ", join(" ", @usb), "\n";
}
my $eth = 0;
foreach (@{$kinds2modules{network}}) {
    print "alias eth$eth $_\n";
    $eth++;
}

sub intersection { my (%l, @m); @l{@{shift @_}} = (); foreach (@_) { @m = grep { exists $l{$_} } @$_; %l = (); @l{@m} = () } keys %l }
