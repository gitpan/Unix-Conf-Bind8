# Bind8 front. 
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8 - Front end for a suite of classes for manipulating a
Bind8 conf and associated zone record files.

=head1 SYNOPSIS

    use Unix::Conf::Bind8;
    my ($conf, $ret);

    # get a new Bind8::Conf object. If one exists with the same 
    # name it is parsed.
    $conf = Unix::Conf::Bind8->new_conf (
        FILE => 'named.conf', 
        SECURE_OPEN => 1
    ) or $conf->die ('could not open \'named.conf\'');

    my $options;
    # create a new Bind8::Conf::Options which is added to
	# named.conf
    $options = $conf->new_options (
        DIRECTORY => 'db',
        VERSION => 'Remote root assured',
		# refer to the documentation for Unix::Conf::Bind8::Conf::new_options
    ) or $options->die ('dead');

    # or get a Bind8::Conf::Options object representing an existing 
	# options directive in named.conf.
    $options = $conf->get_options () or $options->die ('dead');
    # now handle individual options
    # set version
    $options->version ('You must be joking');
    # delete dump-file
    $options->delete_dump_file ();
    # get the value for notify
    $ret = $option->notify () or $ret->die ('dead');
    print "notify => $ret\n";

    # delete the options statement from named.conf
    $conf->delete_options ();

    # ZONE
    my $zone;
    # create a new Bind8::Conf::Zone object and add it to named.conf
    $zone = $conf->new_zone (
        NAME => 'extremix.net', 
		TYPE => 'master', 
		FILE => 'db.extremix.net',
    ) or $zone->die ('couldn't create zone');
	
    # get a Bind8::Conf::Zone object representing an existing 
	# zone
    $zone = $conf->get_zone ('extremix.net');

    # manipulate a zone obj.
    $zone->type ('slave');
    $zone->masters ([ qw (192.168.1.1 192.168.1.2) ]);
    $zone->delete_directive ('allow-transfer');

    # delete an existing zone
    $ret = $conf->delete_zone ('some.zone')
        or $ret->die ("couldn't delete zone");

    # ACLs
    my $acl;
    # create new Bind8::Conf::Acl object and add it to named.conf
    $acl = $conf->new_acl (
        NAME 		=> 'xfer-acl', 
		ELEMENTS	=> [ qw (10.0.0.1 10.0.0.2) ],
		WHERE		=> 'AFTER',
		WARG		=> $zone
    ) or $acl->die ("couldn't create acl 'xfer-acl'");

    # or get a Bind8::Conf::Acl object representing 'xfer-acl'.
    $acl = $conf->get_acl ('xfer-acl')
        or $acl->die ("couldn't get acl");

    # add elements to the acl
    $acl->add_elements ( [ qw (10.0.0.3 10.0.0.4) ]);

    # delete ACL 'xfer-acl' from named.conf
    $ret = $conf->delete_acl ('xfer-acl')
        or $acl->die ("couldn't delete acl");

    # LOGGING
    my $logging
    # Create a new Bind8::Conf::Logging object and add it to 
    # named.conf
    $logging = $conf->new_logging (
        CHANNELS => [
            {   
                NAME => 'my_file_chan',
                OUTPUT => 'file', 
                FILE => { 
				    PATH     => '/var/log/named/file_chan.log', 
					SIZE     => '10k', 
					VERSIONS => 'unlimited', 
				},
                SEVERITY => { NAME => 'debug', LEVEL => '3' }, 
                'PRINT-TIME' => 'yes', 
                'PRINT-SEVERITY' => 'yes', 
                'PRINT-CATEGORY' => 'yes' 
            },
            {   
                NAME => 'my_syslog_chan', 
                OUTPUT => 'syslog', 
                SYSLOG => 'daemon', 
                SEVERITY => { NAME => 'info' }, 
                'PRINT-TIME' => 'yes', 
                'PRINT-SEVERITY' => 'yes', 
                'PRINT-CATEGORY' => 'yes' 
            },
        ],
        CATEGORIES => [
            [ db                => [ qw (my_file_chan default_debug default_syslog) ] ],
            [ 'lame-servers'    => [ qw (null) ], ],
            [ cname             => [ qw (null) ], ],
            ['xfer-out'         => [ qw (default_stderr) ], ]
        ],
		WHERE	   => 'FIRST',
    ) or $logging->die ('couldn't create logging');

    # get a Bind8::Conf::Logging object representing an existing logging 
    # directive
    $logging = $conf->get_logging () 
        or $logging->die ("couldn't get logging");

    # handle channels
    # Create a new Bind8::Conf::Logging::Channel object and add it to the
    # logging directive.
    $ret = $logging->new_channel (
        NAME => 'new_chan', 
        OUTPUT => 'file', 
        FILE => '/var/log/new_chan.log'
    ) or $ret->die ('couldn't create new channel');

    # or delete channel 'my_file_chan' from the logging statement.
    $ret = $logging->delete_channel ('my_file_chan') 
        or $ret->die ('couldn't delete channel');

    # set channels for a category
    $ret = $logging->category ('security', [ qw (new_chan) ])
        or $ret->die ('couldn't set category');
    # delete directive category 'cname' from the logging statement.
    $ret = $logging->delete_category ('cname') 
        or $ret->die ('couldn't delete');

    # INCLUDE
    my $include;
    # create a new Bind8::Conf::Include object and add it to named.conf
    $include = $conf->new_include (
        FILE => 'slaves.conf', 
        SECURE_OPEN => 1
    ) or $include->die ('couldn't create include);
    my $slave_conf = $include->child ();
    # now $slave_conf can be used to create/delete zones/acls etc...
    # other methods are get_include, delete_include

    # HANDLING RECORDS
    # almost all methods need a label. All records are attached to 
    # one. If labels are not absolute (not ending in a '.', they 
    # are considered relative to the DB origin (zone name). A label of 
    # '' means the records are attached to the origin itself. For 
    # example below the origin for the db is extremix.net. So any 
    # records with a label of '' is attached for extremix.net. 
    # Alternatively it could be specified as 'extremix.net.'
    my $db;

    # Get a Bind8::DB object representing the zone records for 
    # 'extremix.net'
    $db = $conf->get_db ('extremix.net');	

    # manipulate records for extremix.net
    $ret = $db->new_soa (
        CLASS     => 'IN', 
        TTL       => '1W', 
        AUTH_NS   => 'ns1.extremix.net', 
        MAIL_ADDR => 'hostmaster.extremix.net', 
        SERIAL    => 1, 
        REFRESH   => '1W', 
        RETRY     => '1W', 
        EXPIRE    => '1W', 
        MIN_TTL   => '1W'
    ) or $ret->die ('could not set SOA');

	# set MX records for label ''. Previous MX record objects
	# associated with this label are deleted.
    $ret = $db->set_mx ( '', [
            { RDATA => 'mx1.extremix.net', MXPREF => 10, CLASS => 'IN' },
            { RDATA => 'mx2.extremix.net', MXPREF => 20, CLASS => 'IN' },
		]
    ) or $ret->die ('could not set MX records for extremix.net');

	# Add another MX record with label ''
    $ret = $db->new_mx (
	    LABEL  => '', 
        RDATA  => 'mx.outside.net', 
        MXPREF => '30' 
		TTL	   => '1w',
	) or $ret->die ('could not add MX for extremix.net');

	# delete the specific MX record object with label ''
	# and RDATA of mx2.extremix.net. Not specifying
	# rdata would delete all MX records attached to that label
    $ret = $db->delete_mx ( 
	    LABEL => '', 
        RDATA    => 'mx2.extremix.net' 
	) or $ret->die ('could not delete MX for extremix.net');

    # similary methods exist for adding other records like A, 
	# CNAME, PTR these methods do not have the MXPREF argument. 
	# Otherwise the syntax remains the same. Refer to the 
	# documentation for various methods in Unix::Conf::Bind8::DB.

    # get NS records for a certain label
    $ret = $db->get_ns ( LABEL => '' )
        or $ret->die ("couldn't get NS records for extremix.net");
    print "NS records for extremix.net :\n";
    print "\t$_\n" for (@$ret);

=cut

package Unix::Conf::Bind8;

use 5.6.0;
use strict;
use warnings;

use Unix::Conf::Bind8::Conf;
use Unix::Conf::Bind8::DB;

$Unix::Conf::Bind8::VERSION = "0.2";

=over 4

=item new_conf ()

 Arguments
 FILE        => PATHNAME,
 SECURE_OPEN => 1/0,       # default 1 (enabled)

Class Method
Read Bind8 configuration file PATHNAME or create one if none
exists.
Returns a Bind8::Conf object in case of success or an Err object 
in case of failure. Refer to docs for Bind8::Conf for further
information.

=cut

sub new_conf () 
{ 
	shift (); 
	return (Unix::Conf::Bind8::Conf->new (@_)); 
}

=item new_db ()

 Arguments
 FILE        => PATHNAME,	 # pathname of the records file
 ORIGIN      => ZONE_ORIGIN, # from the zone statement
 CLASS       => ZONE_CLASS,	 # from the zone statement
 SECURE_OPEN => 1/0,         # default 1 (enabled)

Class method.
Read a zone records file PATHNAME or create one if none exists.
Returns a Bind8::DB object in case of success or an Err object in
case of failure. Refer to docs for Bind8::DB for further
information.

=cut
	
sub new_db () 
{ 
	shift (); 
	return (Unix::Conf::Bind8::DB->new (@_)); 
}

1;
__END__

=head1 STATUS

Beta. While the module is still incomplete, the interface will most 
probably remain the same, with new methods being added. While there is
still quite some work to do, this module is pretty usable with most of the
common directives supported well.
	
=head1 TODO

This module does not support certain directives like server, topology, 
sortlist, key, and the other new features in Bind9. Very few options 
like sortlist and rrset-order are not supported. The zone directive 
pubkey is also not handled. 
The parser is a terrible hack. Need to change it. Probably should
use the BIND-Conf_Parser.

=head1 BUGS

This module is designed to modify the actual directives itself, leaving
the data in between two directives, often comments, to remain unmolested. 
This results in a small problem, that newlines after directives are not 
deleted when directives themselves are.
POD may be out of date. Refer to the code itself.

=head1 AVAILABILITY

This module is available from 
http://www.extremix.net/UnixConf/Unix-Conf-Bind8-0.2.tar.gz

It is also available from CPAN under my PAUSE ID: KARTHIKK.

=head1 LICENCE

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with the program; if not, write to the Free Software Foundation, Inc. :

59 Temple Place, Suite 330, Boston, MA 02111-1307

=head1 COPYRIGHT

Copyright (c) 2002, Karthik Krishnamurthy <karthik.k@extremix.net>.
