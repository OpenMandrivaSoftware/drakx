package network;

use diagnostics;
use strict;

#-######################################################################################
#- misc imports
#-######################################################################################
use Socket;

use common qw(:common :file :system :functional);
use detect_devices;
use run_program;
use any;
use log;

#-######################################################################################
#- Functions
#-######################################################################################
sub read_conf {
    my ($file) = @_;
    my %netc = getVarsFromSh($file);
    $netc{dnsServer} = delete $netc{NS0};
    \%netc;
}

sub read_resolv_conf {
    my ($file) = @_;
    my %netc;
    my @l;

    local *F;
    open F, $file or die "cannot open $file: $!";
    foreach (<F>) {
	push @l, $1 if (/^\s*nameserver\s+([^\s]+)/);
    }

    $netc{$_} = shift @l foreach qw(dnsServer dnsServer2 dnsServer3);
    \%netc;
}

sub read_interface_conf {
    my ($file) = @_;
    my %intf = getVarsFromSh($file) or die "cannot open file $file: $!";

    $intf{BOOTPROTO} ||= 'static';
    $intf{isPtp} = $intf{NETWORK} eq '255.255.255.255';
    $intf{isUp} = 1;
    \%intf;
}

sub up_it {
    my ($prefix, $intfs) = @_;
    $_->{isUp} and return foreach @$intfs;
    my $f = "/etc/resolv.conf"; symlink "$prefix/$f", $f;
    run_program::rooted($prefix, "/etc/rc.d/init.d/network", "start");
    $_->{isUp} = 1 foreach @$intfs;
}
sub down_it {
    my ($prefix, $intfs) = @_;
    run_program::rooted($prefix, "/etc/rc.d/init.d/network", "stop");
    $_->{isUp} = 1 foreach @$intfs;
}

sub write_conf {
    my ($file, $netc) = @_;

    add2hash($netc, {
		     NETWORKING => "yes",
		     FORWARD_IPV4 => "false",
		     HOSTNAME => "localhost.localdomain",
		     });
    add2hash($netc, { DOMAINNAME => $netc->{HOSTNAME} =~ /\.(.*)/ });

    setVarsInSh($file, $netc, qw(NETWORKING FORWARD_IPV4 HOSTNAME DOMAINNAME GATEWAY GATEWAYDEV NISDOMAIN));
}

sub write_resolv_conf {
    my ($file, $netc) = @_;

    #- We always write these, even if they were autoconfigured. Otherwise, the reverse name lookup in the install doesn't work.
    unless ($netc->{DOMAINNAME} || dnsServers($netc)) {
	unlink($file);
	log::l("neither domain name nor dns server are configured");
	return 0;
    }
    my @l = cat_($file);

    local *F;
    open F, "> $file" or die "cannot write $file: $!";
    print F "search $netc->{DOMAINNAME}\n" if $netc->{DOMAINNAME};
    print F "nameserver $_\n" foreach dnsServers($netc);
    print F "#$_" foreach @l;

    #-res_init();		# reinit the resolver so DNS changes take affect
    1;
}

sub write_interface_conf {
    my ($file, $intf) = @_;

    my @ip = split '\.', $intf->{IPADDR};
    my @mask = split '\.', $intf->{NETMASK};
    add2hash($intf, {
		     BROADCAST => join('.', mapn { int $_[0] | ~int $_[1] & 255 } \@ip, \@mask),
		     NETWORK   => join('.', mapn { int $_[0] &      $_[1]       } \@ip, \@mask),
		     ONBOOT => bool2yesno(!member($intf->{DEVICE}, map { $_->{device} } detect_devices::probeall())),
		    });
    setVarsInSh($file, $intf, qw(DEVICE BOOTPROTO IPADDR NETMASK NETWORK BROADCAST ONBOOT));
}

sub add2hosts {
    my ($file, $hostname, @ips) = @_;
    my %l;
    $l{$_} = $hostname foreach @ips;

    local *F;
    if (-e $file) {
	open F, $file or die "cannot open $file: $!";
	/\s*(\S+)(.*)/ and $l{$1} ||= $2 foreach <F>;
    }
    log::l("writing host information to $file");
    open F, ">$file" or die "cannot write $file: $!";
    while (my ($ip, $v) = each %l) {
	$ip or next;
	print F "$ip";
	if ($v =~ /^\s/) {
	    print F $v;
	} else {
	    print F "\t\t$v";
	    print F " $1" if $v =~ /(.*?)\./;
	}
	print F "\n";
    }
}

# The interface/gateway needs to be configured before this will work!
sub guessHostname {
    my ($prefix, $netc, $intf) = @_;

    $intf->{isUp} && dnsServers($netc) or return 0;
    $netc->{HOSTNAME} && $netc->{DOMAINNAME} and return 1;

    write_resolv_conf("$prefix/etc/resolv.conf", $netc);

    my $name = gethostbyaddr(Socket::inet_aton($intf->{IPADDR}), AF_INET) or log::l("reverse name lookup failed"), return 0;

    log::l("reverse name lookup worked");

    add2hash($netc, { HOSTNAME => $name });
    1;
}

sub addDefaultRoute {
    my ($netc) = @_;
    c::addDefaultRoute($netc->{GATEWAY}) if $netc->{GATEWAY};
}

sub sethostname {
    my ($netc) = @_;
    syscall_('sethostname', $netc->{HOSTNAME}, length $netc->{HOSTNAME}) or log::l("sethostname failed: $!");
}

sub resolv($) {
    my ($name) = @_;
    is_ip($name) and return $name;
    my $a = join(".", unpack "C4", (gethostbyname $name)[4]);
    #-log::l("resolved $name in $a");
    $a;
}

sub dnsServers {
    my ($netc) = @_;
    grep { $_ } map { $netc->{$_} } qw(dnsServer dnsServer2 dnsServer3);
}

sub findIntf {
    my ($intf, $device) = @_;
    my ($l) = grep { $_->{DEVICE} eq $device } @$intf;
    push @$intf, $l = { DEVICE => $device } unless $l;
    $l;
}
#PAD \s* a la fin
my $ip_regexp = qr/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
sub is_ip {
    my ($ip) = @_;
    return 0 unless $ip =~ $ip_regexp;
    my @fields = ($1, $2, $3, $4);
    foreach (@fields) {
	return 0 if $_ < 0 || $_ > 255;
    }
    return 1;
}

sub netmask {
    my ($ip) = @_;
    return "255.255.255.0" unless is_ip($ip);
    $ip =~ $ip_regexp;
    if ($1 >= 1 && $1 < 127) {
	return "255.0.0.0";    #-1.0.0.0 to 127.0.0.0
    } elsif ($1  >= 128 && $1 <= 191 ){
	return "255.255.0.0";  #-128.0.0.0 to 191.255.0.0
    } elsif ($1 >= 192 && $1 <= 223) {
	return "255.255.255.0";
    } else {
	return "255.255.255.255"; #-experimental classes
    }
}

sub masked_ip {
    my ($ip) = @_;
    return "" unless is_ip($ip);
    my @mask = netmask($ip) =~ $ip_regexp;
    my @ip   = $ip          =~ $ip_regexp;
    for (my $i = 0; $i < @ip; $i++) {
	$ip[$i] &= int $mask[$i];
    }
    join(".", @ip);
}

sub dns {
    my ($ip) = @_;
    my $mask = masked_ip($ip);
    my @masked = masked_ip($ip) =~ $ip_regexp;
    $masked[3]  = 2;
    join (".", @masked);

}
sub gateway {
    my ($ip) = @_;
    my @masked = masked_ip($ip) =~ $ip_regexp;
    $masked[3]  = 1;
    join (".", @masked);

}

sub configureNetwork {
    my ($prefix, $netc, $in, $pcmcia, $intf, $first_time) = @_;
    local $_;
    any::setup_thiskind($in, 'net', !$::expert, 1, $pcmcia);
    my @l = detect_devices::getNet() or die _("no network card found");

    my $last; foreach ($::beginner ? $l[0] : @l) {
	my $intf2 = findIntf($intf ||= [], $_);
	add2hash($intf2, $last);
	add2hash($intf2, { NETMASK => '255.255.255.0' });
	configureNetworkIntf($in, $intf2) or last;

	$netc ||= {};
	delete $netc->{dnsServer};
	delete $netc->{GATEWAY};
	$last = $intf2;
    }
    #-	  {
    #-	      my $wait = $o->wait_message(_("Hostname"), _("Determining host name and domain..."));
    #-	      network::guessHostname($o->{prefix}, $o->{netc}, $o->{intf});
    #-	  }
    if ($last->{BOOTPROTO} =~ /^(dhcp|bootp)$/) {
	$in->ask_from_entries_ref(_("Configuring network"),
_("Please enter your host name if you know it.
Some DHCP servers require the hostname to work.
Your host name should be a fully-qualified host name,
such as ``mybox.mylab.myco.com''."),
				  [_("Host name:")], [ \$netc->{HOSTNAME} ]);
    } else {
	configureNetworkNet($in, $netc, $last ||= {}, @l);
    }
    miscellaneousNetwork($in);
}

sub miscellaneousNetwork {
    my ($in, $clicked) = @_;
    my $u = $::o->{miscellaneous} ||= {};
    $::isStandalone or $in->set_help('configureNetworkProxy');
    !$::beginner || $clicked and $in->ask_from_entries_ref('',
       _("Proxies configuration"),
       [ _("HTTP proxy"),
         _("FTP proxy"),
       ],
       [ \$u->{http_proxy},
         \$u->{ftp_proxy},
       ],
       complete => sub {
	   $u->{http_proxy} =~ m,^($|http://), or $in->ask_warn('', _("Proxy should be http://...")), return 1,3;
	   $u->{ftp_proxy} =~ m,^($|ftp://), or $in->ask_warn('', _("Proxy should be ftp://...")), return 1,4;
	   0;
       }
    ) || return;
}

sub configureNetworkNet {
    my ($in, $netc, $intf, @devices) = @_;

    $netc->{dnsServer} ||= dns($intf->{IPADDR});
    $netc->{GATEWAY}   ||= gateway($intf->{IPADDR});

    $in->ask_from_entries_ref(_("Configuring network"),
_("Please enter your host name.
Your host name should be a fully-qualified host name,
such as ``mybox.mylab.myco.com''.
You may also enter the IP address of the gateway if you have one"),
			     [_("Host name:"), _("DNS server:"), _("Gateway:"), $::expert ? _("Gateway device:") : ()],
			     [(map { \$netc->{$_} } qw(HOSTNAME dnsServer GATEWAY)),
			      {val => \$netc->{GATEWAYDEV}, list => \@devices}]
			    );
}


sub configureNetwork2 {
    my ($in, $prefix, $netc, $intf) = @_;
    my $etc = "$prefix/etc";

    write_conf("$etc/sysconfig/network", $netc);
    write_resolv_conf("$etc/resolv.conf", $netc);
    write_interface_conf("$etc/sysconfig/network-scripts/ifcfg-$_->{DEVICE}", $_) foreach @{$intf};
    add2hosts("$etc/hosts", $netc->{HOSTNAME}, map { $_->{IPADDR} } @{$intf});
    sethostname($netc) unless $::testing;
    addDefaultRoute($netc) unless $::testing;

    $in->pkg_install("dhcpcd") if grep { $_->{BOOTPROTO} =~ /^(dhcp)$/ } @{$intf};
    # Handle also pump (this is still in initscripts no?)
    $in->pkg_install("pump") if grep { $_->{BOOTPROTO} =~ /^(pump|bootp)$/ } @{$intf};
    #-res_init();		#- reinit the resolver so DNS changes take affect

    any::miscellaneousNetwork($in, $prefix);
}


sub configureNetworkIntf {
    my ($in, $intf) = @_;
    my $pump = $intf->{BOOTPROTO} =~ /^(dhcp|bootp)$/;
    delete $intf->{NETWORK};
    delete $intf->{BROADCAST};
    my @fields = qw(IPADDR NETMASK);
    $::isStandalone or $in->set_help('configureNetworkIP');
    $in->ask_from_entries_ref(_("Configuring network device %s", $intf->{DEVICE}),
($::isStandalone ? '' : _("Configuring network device %s", $intf->{DEVICE}) . "\n\n") .
_("Please enter the IP configuration for this machine.
Each item should be entered as an IP address in dotted-decimal
notation (for example, 1.2.3.4)."),
			     [ _("IP address:"), _("Netmask:"), _("Automatic IP") ],
			     [ \$intf->{IPADDR}, \$intf->{NETMASK}, { val => \$pump, type => "bool", text => _("(bootp/dhcp)") } ],
			     complete => sub {
				 $intf->{BOOTPROTO} = $pump ? "dhcp" : "static";
				 return 0 if $pump;
				 for (my $i = 0; $i < @fields; $i++) {
				     unless (is_ip($intf->{$fields[$i]})) {
					 $in->ask_warn('', _("IP address should be in format 1.2.3.4"));
					 return (1,$i);
				     }
				     return 0;
				 }
			     },
			     focus_out => sub {
				 $intf->{NETMASK} ||= netmask($intf->{IPADDR}) unless $_[0]
			     }
			    );
}


#-######################################################################################
#- Wonderful perl :(
#-######################################################################################
1;
