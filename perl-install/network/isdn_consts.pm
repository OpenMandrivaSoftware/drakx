package network::isdn; # $Id$

@isdndata =
  (
   { description => "Teles 16.0 (ISA)",               #1 irq, mem, io
    driver => 'hisax',
    type => '1',
    irq => '5',
    mem => '0xd000',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Teles  8.0 (ISA)", #2 irq, mem
    driver => 'hisax',
    type => '2',
    irq => '9',
    mem => '0xd800',
    card => 'isa',
   },
   { description => "Teles 16.3 (ISA non PnP)", #3 irq, io
    driver => 'hisax',
    type => '3',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Teles 16.3c (ISA PnP)", #14 irq, io
    driver => 'hisax',
    type => '14',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Creatix/Teles (ISA PnP)",	#4 irq, io0 (ISAC), io1 (HSCX)
    driver => 'hisax',
    type => '4',
    irq => '5',
    io0 => '0x0000',
    io1 => '0x0000',
    card => 'isa',
   },
   { description => "Teles generic (PCI)", #21 no parameter
    driver => 'hisax',
    type => '21',
    card => 'pci',
   },
   { description => "Teles 16.3 (PCMCIA)",	#8 irq, io
    driver => 'hisax',
    type => '8',
    irq => '',
    io => '0x',
    card => 'isa',
   },
   { description => "Teles S0Box", #25 irq, io (of the used lpt port)
    driver => 'hisax',
    type => '25',
    irq => '7',
    io => '0x378',
    card => 'isa',
   },
   { description => "ELSA PCC/PCF cards (ISA)", #6 io or nothing for autodetect (the io is required only if you have n>1 ELSA card)
    driver => 'hisax',
    type => '6',
    io => "",
    card => 'isa',
   },
   { description => "ELSA Quickstep 1000 (ISA)", #7 irq, io  (from isapnp setup)
    driver => 'hisax',
    type => '7',
    irq => '5',
    io => '0x300',
    card => 'isa',
   },
   { description => "ELSA Quickstep 1000 (PCI)", #18 no parameter
    driver => 'hisax',
    type => '18',
    card => 'pci',
   },
   { description => "ELSA Quickstep 3000 (PCI)", #18 no parameter
    driver => 'hisax',
    type => '18',
    card => 'pci',
   },
   { description => "ELSA generic (PCMCIA)", #10 irq, io  (set with card manager)
    driver => 'hisax',
    type => '10',
    irq => '',
    io => '0x',
    card => 'isa',
   },
   { description => "ELSA MicroLink (PCMCIA)", #10 irq, io  (set with card manager)
    driver => 'elsa_cs',
    card => 'isa',
   },
   { description => "ITK ix1-micro Rev.2 (ISA)", #9 irq, io
    driver => 'hisax',
    type => '9',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Eicon.Diehl Diva (ISA PnP)", #11 irq, io
    driver => 'hisax',
    type => '11',
    irq => '9',
    io => '0x180',
    card => 'isa',
   },
   { description => "Eicon.Diehl Diva 20 (PCI)", #11 no parameter
    driver => 'hisax',
    type => '11',
    card => 'pci',
   },
   { description => "Eicon.Diehl Diva 20PRO (PCI)", #11 no parameter
    driver => 'hisax',
    type => '11',
    card => 'pci',
   },
   { description => "Eicon.Diehl Diva 20_U (PCI)", #11 no parameter
    driver => 'hisax',
    type => '11',
    card => 'pci',
   },
   { description => "Eicon.Diehl Diva 20PRO_U (PCI)", #11 no parameter
    driver => 'hisax',
    type => '11',
    card => 'pci',
   },
   { description => "ASUS COM ISDNLink (ISA)", #12 irq, io  (from isapnp setup)
    driver => 'hisax',
    type => '12',
    irq => '5',
    io => '0x200',
    card => 'isa',
   },
   { description => "ASUS COM ISDNLink (PCI)",
    driver => 'hisax',
    type => '35',
    card => 'pci',
   },
   { description => "DynaLink (PCI)",
    driver => 'hisax',
    type => '12',
    card => 'pci',
   },
   { description => "DynaLink IS64PH, ASUSCOM (PCI)", #36
    driver => 'hisax',
    type => '36',
    card => 'pci',
   },
   { description => "HFC-2BS0 based cards (ISA)", #13 irq, io
    driver => 'hisax',
    type => '13',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "HFC 2BDS0 (PCI)", #35 none
    driver => 'hisax',
    type => '35',
    card => 'pci',
   },
   { description => "HFC 2BDS0 S+, SP (PCMCIA)", #37 irq,io (pcmcia must be set with cardmgr)
    driver => 'hisax',
    type => '37',
    card => 'isa',
   },
   { description => "Sedlbauer Speed Card (ISA)", #15 irq, io
    driver => 'hisax',
    type => '15',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Sedlbauer PC/104 (ISA)", #15 irq, io
    driver => 'hisax',
    type => '15',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Sedlbauer Speed Card (PCI)", #15 no parameter
    driver => 'hisax',
    type => '15',
    card => 'pci',
   },
   { description => "Sedlbauer Speed Star (PCMCIA)", #22 irq, io (set with card manager)
    driver => 'sedlbauer_cs',
    card => 'isa',
   },
   { description => "Sedlbauer Speed Fax+ (ISA Pnp)", #28 irq, io (from isapnp setup)
    driver => 'hisax',
    type => '28',
    irq => '9',
    io => '0xd80',
    card => 'isa',
    firmware => '/usr/lib/isdn/ISAR.BIN',
   },
   { description => "Sedlbauer Speed Fax+ (PCI)", #28 no parameter
    driver => 'hisax',
    type => '28',
    card => 'pci',
    firmware => '/usr/lib/isdn/ISAR.BIN',
   },
   { description => "USR Sportster internal (ISA)", #16 irq, io
    driver => 'hisax',
    type => '16',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "MIC card (ISA)",	#17 irq, io
    driver => 'hisax',
    type => '17',
    irq => '9',
    io => '0xd80',
    card => 'isa',
   },
   { description => "Compaq ISDN S0 card (ISA)", #19 irq, io0, io1, io (from isapnp setup io=IO2)
    driver => 'hisax',
    type => '19',
    irq => '5',
    io => '0x0000',
    io0 => '0x0000',
    io1 => '0x0000',
    card => 'isa',
   },
   { description => "NETjet card (PCI)", #20 no parameter
    driver => 'hisax',
    type => '20',
    card => 'pci',
   },
   { description => "Dr. Neuhaus Niccy (ISA PnP)", #24 irq, io0, io1 (from isapnp setup)
    driver => 'hisax',
    type => '24',
    irq => '5',
    io0 => '0x0000',
    io1 => '0x0000',
    card => 'isa',
   },
   { description => "Dr. Neuhaus Niccy (PCI)", ##24 no parameter
    driver => 'hisax',
    type => '24',
    card => 'pci',
   },
   { description => "AVM A1 (Fritz) (ISA non PnP)", #5 irq, io
    driver => 'hisax',
    type => '5',
    irq => '10',
    io => '0x300',
    card => 'isa',
   },
   { description => "AVM (ISA Pnp)", #27 irq, io  (from isapnp setup)
    driver => 'hisax',
    type => '27',
    irq => '5',
    io => '0x300',
    card => 'isa',
   },
   { description => "AVM A1 (Fritz) (PCMCIA)", #26 irq, io (set with card manager)
    driver => 'hisax',
    type => '26',
    irq => '',
    card => 'isa',
   },
   { description => "AVM PCI (Fritz!) (PCI)", #27 no parameter
    driver => 'hisax',
    type => '27',
    card => 'pci',
   },
   { description => "AVM B1 (PCI)",
    driver => 'b1pci',
    card => 'pci',
   },
   { description => "Siemens I-Surf 1.0 (ISA Pnp)", #29 irq, io, memory (from isapnp setup)   
    driver => 'hisax',
    type => '29',
    irq => '9',
    io => '0xd80',
    mem => '0xd000',
    card => 'isa',
   },
   { description => "ACER P10 (ISA Pnp)",	#30 irq, io (from isapnp setup)   
    driver => 'hisax',
    type => '30',
    irq => '5',
    io => '0x300',
    card => 'isa',
   },
   { description => "HST Saphir (ISA Pnp)", #31 irq, io
    driver => 'hisax',
    type => '31',
    irq => '5',
    io => '0x300',
    card => 'isa',
   },
   { description => "Telekom A4T (PCI)", #32 none
    driver => 'hisax',
    type => '32',
    card => 'pci',
   },
   { description => "Scitel Quadro (PCI)", #33 subcontroller (4*S0, subctrl 1...4)
    driver => 'hisax',
    type => '33',
    card => 'pci',
   },
   { description => "Gazel ISDN cards (ISA)", #34 irq,io
    driver => 'hisax',
    type => '34',
    irq => '5',
    io => '0x300',
    card => 'isa',
   },
   { description => "Gazel ISDN cards (PCI)", #34 none
    driver => 'hisax',
    type => '34',
    card => 'pci',
   },
   { description => "W6692 and Winbond based cards (PCI)", #36 none
    driver => 'hisax',
    type => '36',
    card => 'pci',
   },
  );

1;
