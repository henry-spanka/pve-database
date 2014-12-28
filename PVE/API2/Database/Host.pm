package PVE::API2::Database::HostBase;

use strict;
use warnings;
use PVE::JSONSchema qw(get_standard_option);
use PVE::Cluster;
use PVE::Database;
use PVE::API2::Database::Network::Host;

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
			my ($conf, undef) = PVE::Database::copy_object_with_digest($dbconf);
			return $conf;
	}});
}

package PVE::API2::Database::Host;
use strict;
use warnings;

use base qw(PVE::API2::Database::HostBase);

__PACKAGE__->register_method ({
    subclass => "PVE::API2::Database::Network::Host",  
    path => 'network',
});

__PACKAGE__->register_handlers('node');

1;