package PVE::Database;

use warnings;
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
use Time::Piece;
use Time::Seconds;

my $hostdb_conf_filename = "/etc/pve/local/host.db";
my $pvedb_conf_dir = "/etc/pve/database";
my $clusterdb_conf_filename = "$pvedb_conf_dir/cluster.db";

my $empty_conf = {
	network => {},
};

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

sub parse_vmdb_config {
    my ($filename, $fh) = @_;

    return generic_db_config_parser($filename, $fh, $empty_conf);
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
	my ($object) = @_;
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
	my $raw = parse_object_to_raw($conf);
	save_db_conf($filename, $raw);

}

sub remove_from_object {
	my ($object, $section, @remove) = @_;
	raise_param_exc({ delsection => "no such section '$section'" })  if !$empty_conf->{$section};
	foreach my $opt (values @remove) {
		delete($object->{$section}->{$opt});
		delete($object->{$section}) if (!keys $object->{$section});
	}
	return $object;
}

sub update_vm_network {
	my ($d, $vmid) = @_;
	#print "NETIN: $d->{netin}\n";
	#print "NETOUT: $d->{netout}\n";
	my $currenttime = localtime;
	my $currentdate = $currenttime->strftime("%d-%m-%Y");
	my $futuredate = $currenttime->add_months(1)->strftime("%d-%m-%Y");
	my $dbconf = load_vmdb_conf($vmid);
	
	if($dbconf->{network}->{resetdate} le $currentdate) {
		$dbconf->{network}->{lastreset} = $currentdate;
		$dbconf->{network}->{resetdate} = $futuredate;
		$dbconf->{network}->{netin} = 0;
		$dbconf->{network}->{netout} = 0;
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
	
	$dbconf->{network}->{netin_last} = $d->{netin};
	$dbconf->{network}->{netout_last} = $d->{netout};
	save_vmdb_conf($vmid, $dbconf);
}

1;
