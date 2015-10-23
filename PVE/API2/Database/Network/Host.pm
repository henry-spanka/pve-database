package PVE::API2::Database::Network::Host;

use strict;
use warnings;
use PVE::JSONSchema qw(get_standard_option);
use PVE::Cluster;
use PVE::Database;

use Data::Dumper; # fixme: remove

use base qw(PVE::RESTHandler);

my $network_properties = {
    limitinterface => {
		description => "Interface through that OpenVZ traffic is routed (mostly eth[0,1...])",
		type => 'string',
		optional => 1,
    },
    maxspeed => {
		description => "Maximum speed for all CTs together",
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
	proxyto => 'node',
	permissions => {
		check => ['perm', '/nodes/{node}', [ 'Sys.Audit' ]],
	},
	parameters => {
		additionalProperties => 0,
		properties => {
			node => get_standard_option('pve-node'),
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
		
		my $dbconf = PVE::Database::load_hostdb_conf();
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
	proxyto => 'node',
	permissions => {
		check => ['perm', '/nodes/{node}', [ 'Sys.Audit' ]],
	},
    parameters => {
    	additionalProperties => 0,
		properties => &$add_network_properties({
			node => get_standard_option('pve-node'),
			digest => get_standard_option('pve-config-digest'),
		}),
   },
    returns => { type => 'null' },

    code => sub {
		my ($param) = @_;

		my $dbconf = PVE::Database::load_hostdb_conf();
		my (undef, $digest) = PVE::Database::copy_object_with_digest($dbconf);
		PVE::Tools::assert_if_modified($digest, $param->{digest});

	    foreach my $k (keys %$network_properties) {
			next if !defined($param->{$k});
			die "Invalid interface $param->{$k}" if $k eq 'limitinterface' && PVE::Database::checkInterface($param->{$k}) eq 0;
			$dbconf->{network}->{$k} = $param->{$k}; 
	    }
		
		PVE::Database::save_hostdb_conf($dbconf);
		return undef;

	}
});
1;
