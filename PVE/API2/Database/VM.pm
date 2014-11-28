package PVE::API2::Database::VMBase;

use strict;
use warnings;
use PVE::JSONSchema qw(get_standard_option);
use PVE::Cluster;
use PVE::Database;
use PVE::API2::Database::Network;

use Data::Dumper; # fixme: remove

use base qw(PVE::RESTHandler);

sub register_handlers {
    my ($class, $rule_env) = @_;
	
    $class->register_method({
	name => 'index',
	path => '',
	method => 'GET',
	permissions => { user => 'all' },
	description => "Directory index.",
	parameters => {
	    additionalProperties => 0,
	    properties => {
			node => get_standard_option('pve-node'),
			vmid => get_standard_option('pve-vmid'),
	    },
	},
	returns => {
	    type => 'array',
	    items => {
			type => "object",
			properties => {},
	    },
	    links => [ { rel => 'child', href => "{name}" } ],
	},
	code => sub {
	    my ($param) = @_;

	    my $result = [
		{ name => 'all' },
		{ name => 'network' },
		];

	    return $result;
	}});

	$class->register_method ({
		name => 'get_all',
		path => 'all',
		method => 'GET',
		description => "get database sections and values.",
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
			my ($conf, undef) = PVE::Database::copy_object_with_digest($dbconf);
			return $conf;
	}});
}


package PVE::API2::Database::VM;
use strict;
use warnings;

use base qw(PVE::API2::Database::VMBase);

__PACKAGE__->register_method ({
    subclass => "PVE::API2::Database::Network::VM",  
    path => 'network',
});

__PACKAGE__->register_handlers('vm');

package PVE::API2::Database::CT;
use strict;
use warnings;

use base qw(PVE::API2::Database::VMBase);

__PACKAGE__->register_method ({
    subclass => "PVE::API2::Database::Network::CT",  
    path => 'network',
});

__PACKAGE__->register_handlers('vm');

1;