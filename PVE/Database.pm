package PVE::Database;

use warnings;
no warnings 'uninitialized';
use strict;
use POSIX;
use Data::Dumper;
use Digest::SHA;
use PVE::INotify;
use PVE::Exception qw(raise raise_param_exc);
use PVE::JSONSchema qw(register_standard_option get_standard_option);
use PVE::Cluster;
use PVE::ProcFSTools;
use PVE::Tools;
use File::Basename;
use File::Path;
use IO::File;
use Net::IP;
use PVE::Tools qw(run_command lock_file dir_glob_foreach);
use Encode;
use PVE::QemuServer;
use PVE::OpenVZ;
use PVE::API2::Network;
use PVE::Network;
use Time::Piece;
use Time::Seconds;
use PVE::SafeSyslog;

my $hostdb_conf_filename = "/etc/pve/local/host.db";
my $pvedb_conf_dir = "/etc/pve/database";
my $clusterdb_conf_filename = "$pvedb_conf_dir/cluster.db";

my $empty_vm_conf = {
	network => { bandwidth => 0, netlock => 0, rate => 0, exceededrate => 0, lastreset => 0, netin => 0, netout => 0, netin_last => 0, netout_last => 0, resetdate => 0},
};

my $empty_host_conf = {
	network => { limitinterface => ''},
};

sub new {
	my ($class) = @_;
	
	my $rpcenv = PVE::RPCEnvironment->get();
	my $self = bless { rpcenv => $rpcenv };

	return $self;
}

sub load_vmdb_conf {
    my ($vmid) = @_;

    my $vmdb_conf = {};

    my $dir = $pvedb_conf_dir;

    my $filename = "$dir/$vmid.db";
    if (my $fh = IO::File->new($filename, O_RDONLY)) {
		$vmdb_conf = parse_vmdb_config($filename, $fh);
    }

    return $vmdb_conf;
}

sub load_hostdb_conf {

	my $hostdb_conf = {};
	
	if (my $fh = IO::File->new($hostdb_conf_filename, O_RDONLY)) {
		$hostdb_conf = parse_hostdb_config($hostdb_conf_filename, $fh);
    }
	
	return $hostdb_conf;

}

sub parse_hostdb_config {
    my ($filename, $fh) = @_;

    return generic_db_config_parser($filename, $fh, $empty_host_conf);
}

sub parse_vmdb_config {
    my ($filename, $fh) = @_;

    return generic_db_config_parser($filename, $fh, $empty_vm_conf);
}

sub generic_db_config_parser {
    my ($filename, $fh, $empty_conf) = @_;

    my $section;

    my $res = $empty_conf;

    while (defined(my $line = <$fh>)) {
		next if $line =~ m/^#/;
		next if $line =~ m/^\s*$/;
		chomp $line;

		my $linenr = $fh->input_line_number();
		my $prefix = "$filename (line $linenr)";

		if ($line =~ m/^\[([A-Za-z0-9]+)\]$/i) {
			$section = $1;
			if(!$empty_conf->{$section}) {
				$section = '';
			} else {
				next;
			}
		}
		
		if ($empty_conf->{$section} && $line =~ m/^([a-z][a-z_]*\d*):\s*(\S+)\s*$/) {
			$res->{$section}{$1} = $2;
		} else {
			warn "$prefix: skip line - no or invalid section/var\n";
			next;
		}
	}

    return $res;
}

# helper function for API

sub copy_object_with_digest {
    my ($object) = @_;

    my $sha = Digest::SHA->new('sha1');

    my $res = {};
    foreach my $k (sort keys %$object) {
		my $object1 = $object->{$k};
		next if !defined($object1);
		if(ref($object1) eq 'HASH') {
			foreach my $k1 (sort keys %$object1) {
				
				$res->{$k}->{$k1} = $object->{$k}->{$k1};
				$sha->add("$k->$k1", ':', $object->{$k}->{$k1}, "\n");
			}
		} else {
			my $v = $object->{$k};
			next if !defined($v);
			$res->{$k} = $object->{$k};
			$sha->add("$k", ':', $v, "\n");
		}
    }

    my $digest = $sha->hexdigest;

    $res->{digest} = $digest;

    return wantarray ? ($res, $digest) : $res;
}

sub parse_object_to_raw {
	my ($object, $empty_conf) = @_;
	my $raw = '';
	
	foreach my $k (sort keys %$object) {
		my $object1 = $object->{$k};
		next if !defined($object1);
		next if ref($object1) ne 'HASH';
		next if !$empty_conf->{$k};
		$raw .= "[$k]\n";
		foreach my $k1 (sort keys %$object1) {
			$raw .= "$k1: $object->{$k}->{$k1}\n";
		}
	}
	return $raw;
}

sub save_db_conf {
	my ($filename, $raw) = @_;
			
	mkdir $pvedb_conf_dir;

    PVE::Tools::file_set_contents($filename, $raw);
}
sub save_vmdb_conf {
    my ($vmid, $conf) = @_;
	
	my $filename = "$pvedb_conf_dir/$vmid.db";
	my $raw = parse_object_to_raw($conf, $empty_vm_conf);
	save_db_conf($filename, $raw);

}

sub save_hostdb_conf {
    my ($conf) = @_;

	my $raw = parse_object_to_raw($conf, $empty_host_conf);
	save_db_conf($hostdb_conf_filename, $raw);

}

#sub remove_from_object 
#	my ($object, $section, @remove) = @_;
#	raise_param_exc({ delsection => "no such section '$section'" })  if !$empty_conf->{$section};
#	foreach my $opt (values @remove) {
#		delete($object->{$section}->{$opt});
#		delete($object->{$section}) if (!keys $object->{$section});
#	}
#	return $object;
#}

sub stop_ct {
	my ($vmid) = @_;
		PVE::Tools::run_command(['vzctl', '--skiplock', 'stop', $vmid, '--fast']);
}

sub stop_vm {
	my ($vmid) = @_;
	
	my $storecfg = PVE::Storage::config();
		PVE::QemuServer::vm_stop($storecfg, $vmid, 1, 0,
					 0, 0, undef, 0, undef);
}

sub Tc_SetHostRules {
	my ($nic) = @_;
	
	return if !$nic;

	my $TcHostDeleteRules = ["qdisc del dev ${nic} root",
						  'qdisc del dev venet0 root'
						 ];
	my $TcHostAddRules = ["qdisc add dev ${nic} root handle 1:  cbq avpkt 1000 bandwidth 1000mbit",
					   'qdisc add dev venet0 root handle 1: cbq avpkt 1000 bandwidth 1000mbit'
					  ];
					  
	foreach my $tclimitdelcommand (@$TcHostDeleteRules) {
		PVE::Tools::run_command("/sbin/tc $tclimitdelcommand");
	}
	
	foreach my $tclimitaddcommand (@$TcHostAddRules) {
		PVE::Tools::run_command("/sbin/tc $tclimitaddcommand");
	}
	

}

sub Tc_SetContainerRules {
	my ($rate, $nic, $classid, @ipaddresses) = @_;
	
	$rate = int($rate * 8); # Calculate mb/s to mbit/s

	return if (!$rate || !$nic || !$classid || !@ipaddresses);

	my $TcContainerAddRules = ["class add dev venet0 parent 1: classid 1:$classid cbq rate ${rate}mbit allot 1500 prio 5 bounded isolated",
						   "qdisc add dev venet0 parent 1:$classid sfq perturb 10",
						   "class add dev $nic parent 1: classid 1:$classid cbq rate ${rate}mbit allot 1500 prio 5 bounded isolated",
						   "qdisc add dev $nic parent 1:$classid sfq perturb 10"
						  ];
	foreach my $tclimitCTcommand (@$TcContainerAddRules) {
		PVE::Tools::run_command("/sbin/tc $tclimitCTcommand");
	}

	foreach my $ip_address (@ipaddresses) {
		my $ipversion = Net::IP::ip_get_version($ip_address);

		my $ipprotocol = 'ip', my $iptype = 'ip', my $prio = 1;
		$ipprotocol = 'ipv6', $iptype = 'ip6', $prio = 2 if ($ipversion eq 6);
		next if ($ipversion ne 4 && $ipversion ne 6);

		my $TcContainerAddRulesIPs = ["filter add dev ${nic} protocol ${ipprotocol} parent 1:0 prio ${prio} u32 match ${iptype} src ${ip_address} flowid 1:${classid}",
									  "filter add dev venet0 protocol ${ipprotocol} parent 1:0 prio ${prio} u32 match ${iptype} dst ${ip_address} flowid 1:${classid}"
									  ];
								  
		foreach my $tclimitCTIPscommand (@$TcContainerAddRulesIPs) {
			PVE::Tools::run_command("/sbin/tc $tclimitCTIPscommand");
		}
	}
}

sub Tc_SetQemuRules {
	my ($rate, $tap) = @_;

	PVE::Network::tap_rate_limit($tap, $rate);
}

sub getInterfaces {
	my $nodename = PVE::INotify::nodename();
	chomp $nodename;
	my $interfaces = PVE::API2::Network->index({node => $nodename, 'type' => 'eth'});
	
	return $interfaces;
}

sub checkInterface {
	my ($iface) = @_;
	my $interfaces = getInterfaces();
	
	foreach my $interface (@$interfaces) {
		return 1 if $iface eq $interface->{iface};
	}
	return 0;
}

sub update_vm_network {
	my ($self, $d, $vmid, $dbconf) = @_;

	my $currenttime = localtime;
	my $currentdate = $currenttime->strftime("%Y%m%d");
	my $futuredate = $currenttime->add_months(1)->strftime("%Y%m%d");
	
	if($dbconf->{network}->{resetdate} le $currentdate) {
		$dbconf->{network}->{lastreset} = $currentdate;
		$dbconf->{network}->{resetdate} = $futuredate;
		$dbconf->{network}->{netin} = 0;
		$dbconf->{network}->{netout} = 0;
	}
	
	if($dbconf->{network}->{bandwidth} >= ($dbconf->{network}->{netin} + $dbconf->{network}->{netout}) ) {
		$dbconf->{network}->{netlock} = 0;
	}
	
	if($dbconf->{network}->{netin_last} > $d->{netin}) {
		$dbconf->{network}->{netin_last} = $dbconf->{network}->{netin} += $d->{netin};
	} else {
		$dbconf->{network}->{netin} += ($d->{netin} - $dbconf->{network}->{netin_last});
	}
	
	if($dbconf->{network}->{netout_last} > $d->{netout}) {
		$dbconf->{network}->{netout_last} = $dbconf->{network}->{netin} += $d->{netin};
	} else {
		$dbconf->{network}->{netout} += ($d->{netout} - $dbconf->{network}->{netout_last});	
	}

	if( ( ($dbconf->{network}->{netin} + $dbconf->{network}->{netout}) > $dbconf->{network}->{bandwidth} ) && $dbconf->{network}->{bandwidth} && $dbconf->{network}->{netlock} ne 1) {
		$dbconf->{network}->{netlock} = 1;
	}
	
	$dbconf->{network}->{netin_last} = $d->{netin};
	$dbconf->{network}->{netout_last} = $d->{netout};
	
	save_vmdb_conf($vmid, $dbconf);

	return $dbconf;
}

1;
