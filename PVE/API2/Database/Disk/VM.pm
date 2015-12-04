package PVE::API2::Database::Disk::VM;

use strict;
use warnings;
use PVE::JSONSchema qw(get_standard_option);
use PVE::Cluster;
use PVE::Database;

use Data::Dumper; # fixme: remove

use base qw(PVE::RESTHandler);

my $disk_properties = {};

my $add_disk_properties = sub {
    my ($properties) = @_;

    foreach my $k (keys %$disk_properties) {
       $properties->{$k} = $disk_properties->{$k};
    }
    
    return $properties;
};

__PACKAGE__->register_method ({
    name => 'get_disk',
    path => '',
    method => 'GET',
    description => "get disk database section",
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
    returns => {
        type => 'object',
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
        my ($conf, undef) = PVE::Database::copy_object_with_digest($dbconf->{disk});
        return $conf;
    }
});
    
__PACKAGE__->register_method ({
    name => 'set_disk',
    path => '',
    method => 'POST',
    description => "set and update disk section database variables",
    protected => 1,
    permissions => {
        check => ['perm', '/vms/{vmid}', [ 'VM.Audit' ]],
    },
    parameters => {
        additionalProperties => 0,
        properties => &$add_disk_properties({
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

        foreach my $k (keys %$disk_properties) {
            next if !defined($param->{$k});
            $dbconf->{disk}->{$k} = $param->{$k}; 
        }
        
        PVE::Database::save_vmdb_conf($param->{vmid}, $dbconf);
        return undef;

    }
});
1;

