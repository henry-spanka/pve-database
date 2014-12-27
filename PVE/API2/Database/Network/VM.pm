package PVE::API2::Database::Network::VM;

use strict;
use warnings;
use PVE::JSONSchema qw(get_standard_option);
use PVE::Cluster;
use PVE::Database;

use Data::Dumper; # fixme: remove

use base qw(PVE::RESTHandler);

my $network_properties = {
    netin => {
		description => "Current netin cycle",
		type => 'integer',
		optional => 1,
    },
    netout => {
		description => "Current netout cycle",
		type => 'integer',
		optional => 1,
    },
    resetdate => {
		description => "Next reset date for traffic stats.",
		type => 'integer',
		optional => 1,
		minimum => 20141206,
    },
    bandwidth => {
		description => "Monthly maximum bandwidth",
		type => 'integer',
		optional => 1,
    },
};

my $add_network_properties = sub {
    my ($properties) = @_;

    foreach my $k (keys %$network_properties) {
	$properties->{$k} = $network_properties->{$k};
    }
    
    return $properties;
};

__PACKAGE__->register_method ({
	name => 'get_network',
	path => '',
	method => 'GET',
	description => "get network database section",
	permissions => {
		check => ['perm', '/vms/{vmid}', [ 'VM.Audit' ]],
	},
	parameters => {
		additionalProperties => 0,
		properties => {
			node => get_standard_option('pve-node'),
			vmid => get_standard_option('pve-vmid'),	
		},	
	},
	returns => { type => 'object',
				properties => {
					digest => {
						type => 'string',
						description => 'SHA1 digest of database file. This can be used to prevent concurrent modifications.',
					}
				}
	},
	code => sub {
		my ($param) = @_;
		
		my $dbconf = PVE::Database::load_vmdb_conf($param->{vmid});
		my ($conf, undef) = PVE::Database::copy_object_with_digest($dbconf->{network});
		return $conf;
	}
});
	
__PACKAGE__->register_method ({
    name => 'set_network',
    path => '',
    method => 'POST',
    description => "set and update network section database variables",
	protected => 1,
	permissions => {
		check => ['perm', '/vms/{vmid}', [ 'VM.Audit' ]],
	},
    parameters => {
    	additionalProperties => 0,
		properties => &$add_network_properties({
			node => get_standard_option('pve-node'),
			vmid => get_standard_option('pve-vmid'),
			digest => get_standard_option('pve-config-digest'),
		}),
   },
    returns => { type => 'null' },

    code => sub {
		my ($param) = @_;

		my $dbconf = PVE::Database::load_vmdb_conf($param->{vmid});
		my (undef, $digest) = PVE::Database::copy_object_with_digest($dbconf);
		PVE::Tools::assert_if_modified($digest, $param->{digest});

	    foreach my $k (keys %$network_properties) {
			next if !defined($param->{$k});
			$dbconf->{network}->{$k} = $param->{$k}; 
	    }
		
		PVE::Database::save_vmdb_conf($param->{vmid}, $dbconf);
		return undef;

	}
});
1;
