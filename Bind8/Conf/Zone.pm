# Bind8 Zone handling
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8::Conf::Zone - Class for representing the Bind8 zone 
directive

=head1 SYNOPSIS

	Refer to the SYNOPSIS section in Unix::Conf::Bind8 for an overview.

=head1 DESCRIPTION

=over 4

=cut

package Unix::Conf::Bind8::Conf::Zone;

use strict;
use warnings;
use Unix::Conf;

use Unix::Conf::Bind8::Conf::Directive;
our @ISA = qw (Unix::Conf::Bind8::Conf::Directive);

use Unix::Conf::Bind8::Conf;
use Unix::Conf::Bind8::Conf::Lib;
use Unix::Conf::Bind8::Conf::Acl;

# dont become too restrictive. i am putting in validations offhand.
# recheck with Bind behaviour.
# Arguments: zone class
# INCOMPLETE
sub validate ($)
{
	my ($zone) = @_;
	my $errmsg = "";

	($zone->type () eq 'master') && do {
		$errmsg .= sprintf ("no records file defined for master zone `%s'\n", $zone->name ())
			if (! $zone->file ());
		$errmsg .= sprintf ("masters defined for master zone `%s'\n", $zone->name ()) 
			if ($zone->masters ()); 
	};
	($zone->type () eq 'slave') && do {
		$errmsg .= sprintf ("masters not defined for slave zone `%s'\n", $zone->name ())
			if (! $zone->masters ());
	};
	($zone->type () eq 'forward') && do {
		$errmsg .= sprintf ("masters defined for forward zone `%s'\n", $zone->name ()) 
			if ($zone->masters ()); 
		$errmsg .= sprintf ("forward not defined for forward zone `%s'\n", $zone->name ()) 
			if (! $zone->forward ());
		$errmsg .= sprintf ("forwarders not defined for forward zone `%s'\n", $zone->name ()) 
			if (! $zone->forwarders ());
	};

	return ($errmsg) if ($errmsg);
	return ();
}

# change to access the hash members directly instead of thro the methods.
# that should speed up things a bit
sub __render
{
	my $self = $_[0];
	my ($rendered, $tmp);

	# name class { type
	if ($self->__defined_class ()) {
		$rendered = sprintf (qq (zone "%s" %s {\n\ttype %s;\n), $self->name (), $self->class (), $self->type ());
	}	
	else {
		$rendered = sprintf (qq (zone "%s" {\n\ttype %s;\n), $self->name (), $self->type ());
	}

	$rendered .= qq (\tfile "$tmp";\n)
		if (($tmp = $self->file ()));
	if (($tmp = $self->masters ())) {
		local $" = "; ";
		$rendered .= sprintf (qq (\tmasters %s{\n\t\t@{$tmp};\n\t};\n), ($self->masters_port ()) ? "port @{[$self->masters_port ()]} " : "");
	}

	$rendered .= qq (\tforward $tmp;\n)
		if (($tmp = $self->forward ()));
	if (($tmp = $self->forwarders ())) {
		local $" = "; ";
		$rendered .= qq (\tforwarders {\n\t\t@{$tmp};\n\t};\n);
	}

	$rendered .= qq (\tcheck-names $tmp;\n)
		if (($tmp = $self->check_names ()));

	$rendered .= qq (\tnotify $tmp;\n)
		if (($tmp = $self->notify ()));
	if (($tmp = $self->also_notify ())) {
		local $" = "; ";
		$rendered .= qq (\talso-notify {\n\t\t@{$tmp};\n\t};\n);
	}

	# The values are represented by an ACL. Get the elements, stringify it
	# and set the ACL to clean, so that the destructors do not write it to file
	{
		local $" = "; ";
		$rendered .= qq (\tallow-update {\n\t\t@{$tmp->elements ()};\n\t};\n)
			if (($tmp = $self->allow_update ())); 
		$rendered .= qq (\tallow-query {\n\t\t@{$tmp->elements ()};\n\t};\n)
			if (($tmp = $self->allow_query ()));
		$rendered .= qq (\tallow-transfer {\n\t\t@{$tmp->elements ()};\n\t};\n)
			if (($tmp = $self->allow_transfer ()));
	}

	$rendered .= "};\n";
	return ($self->_rstring (\$rendered));
}

=item new ()

 Arguments
 NAME             => 'name',
 TYPE             => 'type',            # 'master'|'slave'|'forward'|'stub'|'hint'
 CLASS            => 'class',           # 'in'|'hs'|'hesiod'|'chaos'
 FILE             => 'pathname',
 MASTERS          => [ qw (ip1 ip2) ],  # only if TYPE =~  /'slave'|'stub'/
 FORWARD          => 'yes_no',
 FORWARDERS       => [ qw (ip1 ip2) ],
 CHECK-NAMES      => 'value',           # 'warn'|'fail'|'ignore'
 ALLOW-UPDATE     => [ qw (host1 host2) ],
 ALLOW-QUERY      => [ qw (host1 host2) ],
 ALLOW-TRANSFER   => [ qw (host1 host2) ],
 DIALUP           => 'yes_no',
 NOTIFY           => 'yes_no',
 ALSO-NOTIFY      => [ qw (ip1 ip2) ],

Class constructor
Creates a new Unix::Conf::Bind8::Conf::Zone object and returns 
it if successful, an Err object otherwise. Direct use of this 
method is deprecated. Use Unix::Conf::Bind8::Conf::new_zone () 
instead.

=cut

sub new
{
	shift ();
	my $new = bless ({});
	my %args = @_;
	my ($ret, $acl);
	
	$args{NAME} || return (Unix::Conf->_err ('new', "zone name not specified"));
	$args{PARENT} || return (Unix::Conf->_err ('new', "PARENT not specified"));

	$ret = $new->_parent ($args{PARENT}) or return ($ret);
	$ret = $new->name ($args{NAME}) or return ($ret);

	$ret = $new->type ($args{TYPE}) or return ($ret)
		if ($args{TYPE});
	$ret = $new->class ($args{CLASS}) or return ($ret)
		if ($args{CLASS});
	$ret = $new->file ($args{FILE}) or return ($ret) 
		if ($args{FILE});
	$ret = $new->masters ($args{MASTERS}) or return ($ret) 
		if ($args{MASTERS});
	$ret = $new->forward ($args{FORWARD}) or return ($ret)
		if ($args{FORWARD});
	$ret = $new->forwarders ($args{FORWARDERS}) or return ($ret)
		if ($args{FORWARDERS});
	$ret = $new->check_names ($args{'CHECK-NAMES'}) or return ($ret)
		if ($args{'CHECK-NAMES'});

	if ($args{'ALLOW-UPDATE'}) {
		$acl = Unix::Conf::Bind8::Conf::Acl->new (ELEMENTS => $args{'ALLOW-UPDATE'})
			or return ($acl);
		$ret = $new->allow_update ($acl) or return ($ret)
	}
	if ($args{'ALLOW-QUERY'}) {
		$acl = Unix::Conf::Bind8::Conf::Acl->new (ELEMENTS => $args{'ALLOW-QUERY'})
			or return ($acl);
		$ret = $new->allow_query ($acl) or return ($ret)
	}
	if ($args{'ALLOW-TRANSFER'}) {
		$acl = Unix::Conf::Bind8::Conf::Acl->new (ELEMENTS => $args{'ALLOW-TRANSFER'})
			or return ($acl);
		$ret = $new->allow_transfer ($acl) or return ($ret)
	}

	$ret = $new->dialup ($args{DIALUP}) or return ($ret)
		if ($args{DIALUP});
	$ret = $new->notify ($args{NOTIFY}) or return ($ret)
		if ($args{NOTIFY});
	$ret = $new->also_notify ($args{'ALSO-NOTIFY'}) or return ($ret)
		if ($args{'ALSO-NOTIFY'});

	$args{WHERE} = 'LAST' unless ($args{WHERE});
	$ret = Unix::Conf::Bind8::Conf::_insert_in_list ($new, $args{WHERE}, $args{WARG})
		or return ($ret);
	return ($new);
}

=item name ()

 Arguments
 'zone',    # optional

Object method.
Get/Set object's name attribute. If argument is passed, the method tries to 
set the name attribute to 'zone', and returns true if successful, an Err 
object otherwise. If no argument is passed, returns the name of the zone, 
if defined, an Err object otherwise.

=cut

sub name
{
	my ($self, $name) = @_;

	if (defined ($name)) {
		my $ret;
		# strip the double quotes if any
		$name =~ s/^"(.+)"$/$1/;
		# already defined. changing name
		if ($self->{name}) {
			$ret = Unix::Conf::Bind8::Conf::_del_zone ($self) or return ($ret);
		}
		$self->{name} = $name;
		$ret = Unix::Conf::Bind8::Conf::_add_zone ($self) or return ($ret);
		$self->dirty (1);
		return (1);
	}
	return ($self->{name});
}

=item class

 Arguments
 'class',     # optional

Object method.
Get/Set object's class attribute. If argument is passed, the method tries 
to set the class attribute to 'class', and returns true if successful, an 
Err object otherwise. If no argument is passed, returns the class of 
the zone, if defined, an Err object otherwise.

=cut

sub class
{
	my ($self, $class) = @_;

	if (defined ($class)) {
		return (Unix::Conf->_err ('class', "illegal class `$class'"))
			if ($class !~ /^(in|hs|hesoid|chaos)$/);
		$self->{class} = $class;
		return (1);
	}
	return ( defined ($self->{class}) ? $self->{class} : "IN" );
}

sub __defined_class { return ( defined ($_[0]->{class}) ); }

=item file

 Arguments
 'file',    # optional

Object method.
Get/Set the object's file attribute. If argument is passed, the method tries 
to set the file attribute to 'file', and returns true if successful, and 
Err object otherwise. If no argument is passed, returns the file of the zone, if 
defined, an Err object otherwise.

=cut

sub file
{
	my ($self, $file) = @_;

	if (defined ($file)) {
		# strip the double quotes if any
		$file =~ s/^"(.+)"$/$1/;
		$self->{file} = $file;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{file}) ? $self->{file} : Unix::Conf->_err ('file', "file not defined")
	);
}

=item type ()

 Arguments
 'type',    # optional

Object method.
Get/Set the object's type attribute. If argument is passed, the method 
tries to set the type attribute to 'type', and returns true if successful, 
an Err object otherwise. If no argument is passed, returns the type of the 
zone, if defined, an Err object otherwise.

=cut

sub type
{
	my ($self, $type) = @_;

	if (defined ($type)) {
		return (Unix::Conf->_err ('type', "illegal type `$type'"))
			if ($type !~ /^(hint|master|slave|stub|forward)$/); 
		$self->{type} = $type;
		$self->dirty (1);
		return (1);
	}
	return ($self->{type});
}

=item add_masters ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Add the list of IP addresses specified in the argument to the list of 
masters and return true if successful, an Err object otherwise.

=cut

sub add_masters 
{
	my ($self, $addresses) = @_;

	if (defined ($addresses)) {
		for (@$addresses) {
			return (Unix::Conf->_err ('add_masters', "illegal IP address `$_'"))
				if (! __valid_ipaddress ($_));
		}
		push (@{$self->{masters}[1]}, @$addresses);
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_masters', "addresses to be added not specified"));
}

=item masters ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Get/Set the object's masters attribute. If argument is passed, the method 
tries to set the masters attribute to the list, and returns true if 
successful, an Err object otherwise. If no argument is passed, returns 
an array ref containing the masters list for zone, if defined, an Err 
object otherwise.

=cut

sub masters
{
	my ($self, $addresses) = @_;

	if (defined ($addresses)) {
		for (@$addresses) {
			return (Unix::Conf->_err ('masters', "illegal IP address `$_'"))
				if (! __valid_ipaddress ($_));
		}
		# Reset old ones
		$self->{masters}[1] = [];
		push (@{$self->{masters}[1]}, @$addresses);
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{masters}[1]) ?  [ @{$self->{masters}[1]} ] :
			Unix::Conf->_err ('masters', "masters not defined")
	);
}

=item masters_port ()

 Arguments
 'port',     # optional

Object method.
Get/Set the object's masters port attribute. If argument is passed, the 
method tries to set the masters port attribute to 'port', and returns true if 
successful, an Err object otherwise. If no argument is passed, returns the 
masters port, if defined, an Err object otherwise.

=cut

sub masters_port
{
	my ($self, $port) = @_;

	if (defined ($port)) {
		$self->{masters}[0] = $port;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{masters}[0]) ? $self->{masters}[0] : 
			Unix::Conf->_err ('masters_port', "masters port not defined")
	);
}

=item notify ()

 Arguments
 'yes_no',    # optional

Object method.
Get/Set the object's notify attribute. If argument is passed, the method 
tries to set the notify attribute to 'yes_no', and returns true if 
successful, an Err object otherwise. If no argument is passed, returns the 
notify of the zone, if defined, an Err object otherwise.

=cut

sub notify
{
	my ($self, $notify) = @_;

	if (defined ($notify)) {
		return (Unix::Conf->_err ('notify', "illegal syntax `notify  $notify'"))
			if (! __valid_yesno ($notify));
		$self->{notify} = $notify;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{notify}) ? $self->{notify} : Unix::Conf->_err ('notify', "notify not defined")
	);
}

=item add_also_notify ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Add the list of IP addresses specified in the argument, to the 
also_notify list and return true if successful, an Err object 
otherwise.

=cut

sub add_also_notify
{
	my ($self, $addresses) = @_;

	if (defined ($addresses)) {
		for (@$addresses) {
			return (Unix::Conf->_err ('add_also_notify', "illegal IP address `$_'"))
				if (! __valid_ipaddress ($_));
		}
		push (@{$self->{'also-notify'}}, @$addresses);
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_also_notify', "addresses to be added not specified"));
}

=item also_notify ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Get/Set the object's also_notify attribute. If argument is passed, the 
method tries to set the also_notify attribute to the list, and returns 
true if successful, an Err object otherwise. If no argument is passed, returns 
an array ref containing the also_notify list for zone, if defined, an Err 
object otherwise.

=cut

sub also_notify
{
	my ($self, $addresses) = @_;

	if (defined ($addresses)) {
		for (@$addresses) {
			return (Unix::Conf->_err ('also_notify', "illegal IP address `$_'"))
				if (! __valid_ipaddress ($_));
		}
		# Reset old ones
		$self->{'also-notify'} = [];
		push (@{$self->{'also-notify'}}, @$addresses); 
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{'also-notify'}) ? $self->{'also-notify'} :
			Unix::Conf->_err ('also_notify', "also-notify not defined")
	);
}

=item forward ()

 Arguments
 'yes_no',    # optional

Object method.
Get/Set the object's forward attribute. If argument is passed, the method 
tries to set the forward of the zone object to 'yes_no', and returns true 
if successful, an Err object otherwise. If no argument is passed, returns 
the forward of the zone, if defined, an Err object otherwise.

=cut

sub forward
{
	my ($self, $val) = @_;

	if (defined ($val)) {
		return (Unix::Conf->_err ('forward', "zone directive `forward' can be used only for zone type `forward'"))
			if ($self->type () ne 'forward');
		return (Unix::Conf->_err ('forward', "illegal value($val) for zone directive `forward'"))
			if (! __valid_forward ($val));
		$self->{forward} = $val;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{forward}) ? $self->{forward} :
			Unix::Conf->_err ('forward', "forward not defined")
	);
}

=item forwarders ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Get/Set the object's forwaders attribute. If argument is passed, the 
method tries to set the forwaders list of the zone object to the list, 
and returns true if successful, an Err object otherwise. If no argument 
is passed, returns an array ref containing the forwaders list for zone, if 
defined, an Err object otherwise.

=cut

sub forwarders 
{
	my ($self, $addresses) = @_;

	if (defined ($addresses)) {
		for (@$addresses) {
			return (Unix::Conf->_err ('forwarders', "illegal IP address `$_'"))
				if (! __valid_ipaddress ($_));
		}
		# Reset old ones
		$self->{forwarders} = [];
		push (@{$self->{forwarders}}, @$addresses); 
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{forwarders}) ? [ @{$self->{forwarders}} ] :
			Unix::Conf->_err ('fowarders', "forwarders not defined")
	);
}

=item add_forwaders ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Add the list of IP addresses specified in the argument, to the forwaders 
list and return true if successful, an Err object otherwise.

=cut

sub add_forwarders
{
	my ($self, $addresses) = @_;

	if (defined ($addresses)) {

		for (@$addresses) {
			return (Unix::Conf->_err ('forwarders', "illegal IP address `$_'\n"))
				if (! __valid_ipaddress ($_));
		}
		push (@{$self->{forwarders}}, @$addresses); 
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ("add_also_forwarders", "forwarders not specified"));
}

=item add_allow_transfer ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Add the list of IP addresses specified in the argument, to the allow_transfer 
list and return true if successful, an Err object otherwise.

=cut

sub add_allow_transfer
{
	my ($self, $elements) = @_;

	if ($elements) {
		my $ret;
		$self->{'allow-transfer'} = Unix::Conf::Bind8::Conf::Acl->new ()
			unless ($self->{'allow-transfer'});
		$ret = $self->{'allow-transfer'}->add_elements ($elements) or return ($ret);
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_allow_transfer', "elements not specified"))
}

=item allow_transfer ()

 Arguments
 acl_object,    # optional

Object method.
Get/Set the object's allow_transfer attribute. This is represented by a 
Unix::Conf::Bind8::Conf::Acl object. If argument is passed, the method 
tries to set the allow_transfer attribute, and returns true if successful, 
an Err object otherwise. If no argument is passed, the method returns the 
value of the allow_transfer attribute, if defined, an Err object otherwise.

=cut

sub allow_transfer 
{
	my ($self, $acl) = @_;

	if ($acl) {
		my $ret;
		return (Unix::Conf->_err ('allow_transfer', "argument must be a Unix::Conf::Bind8::Conf::Acl object"))
			unless (UNIVERSAL::isa ($acl, 'Unix::Conf::Bind8::Conf::Acl'));
		$self->{'allow-transfer'} = $acl;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{'allow-transfer'}) ? $self->{'allow-transfer'} :
			Unix::Conf->_err ('allow_transfer', "allow-transfer not defined")
	);
}

=item allow_transfer_elements ()

Object method.
Returns an array ref containing the elements of allow-transfer acl.

=cut

sub allow_transfer_elements
{
	return (
		defined ($_[0]->{'allow-transfer'}) ? $_[0]->{'allow-transfer'}->elements () :
			Unix::Conf->_err ('allow_transfer_elements', "allow-transfer not defined")
	);
}

=item add_allow_query ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Add the list of IP addresses specified in the argument, to the allow_query 
list and return true if successful, an Err object otherwise.

=cut

sub add_allow_query
{
	my ($self, $elements) = @_;

	if ($elements) {
		my $ret;
		$self->{'allow-query'} = Unix::Conf::Bind8::Conf::Acl->new ()
			unless ($self->{'allow-query'});
		$ret = $self->{'allow-query'}->add_elements ($elements) or return ($ret);
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_allow_query', "elements not specified"))
}

=item allow_query ()

 Arguments
 acl_object,    # optional

Object method.
Get/Set the object's allow_query attribute. This is represented by a 
Unix::Conf::Bind8::Conf::Acl object. If argument is passed, the method tries 
to set the allow_query attribute, and returns true if successful, an Err 
object otherwise. If no argument is passed, the method returns the value of 
the allow_query attribute, if defined, an Err object otherwise.

=cut

sub allow_query
{
	my ($self, $acl) = @_;

	if ($acl) {
		my $ret;
		return (Unix::Conf->_err ('allow_query', "argument must be a Unix::Conf::Bind8::Conf::Acl object"))
			unless (UNIVERSAL::isa ($acl, 'Unix::Conf::Bind8::Conf::Acl'));
		$self->{'allow-query'} = $acl;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{'allow-query'}) ? $self->{'allow-query'} :
			Unix::Conf->_err ('allow_query', "allow-query not defined")
	);
}

=item allow_query_elements ()

Object method.
Returns an array ref containing the elements of allow-query acl.

=cut

sub allow_query_elements
{
	return (
		defined ($_[0]->{'allow-query'}) ? $_[0]->{'allow-query'}->elements () :
			Unix::Conf->_err ('allow_query', "allow-query not defined")
	);
}

=item add_allow_update ()

 Arguments
 [ qw (ip1 ip2) ],

Object method.
Add the list of IP addresses specified in the argument, to the allow_update 
list and return true if successful, an Err object otherwise.

=cut

sub add_allow_update
{
	my ($self, $elements) = @_;

	if ($elements) {
		my $ret;
		$self->{'allow-update'} = Unix::Conf::Bind8::Conf::Acl->new ()
			unless ($self->{'allow-update'});
		$ret = $self->{'allow-update'}->add_elements ($elements) or return ($ret);
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_allow_update', "elements not specified"))
}

=item allow_update ()

 Arguments
 acl_object,    # optional

Object method.
Get/Set the object's allow_update attribute. This is represented by a 
Unix::Conf::Bind8::Conf::Acl object. If argument is passed, the method tries 
to set the allow_update attribute, and returns true if successful, an Err 
object otherwise. If no argument is passed, the method returns the value of
the allow_update attribute, if defined, an Err object otherwise.

=cut

sub allow_update
{
	my ($self, $acl) = @_;

	if ($acl) {
		my $ret;
		return (Unix::Conf->_err ('allow_update', "argument must be a Unix::Conf::Bind8::Conf::Acl object"))
			unless (UNIVERSAL::isa ($acl, 'Unix::Conf::Bind8::Conf::Acl'));
		$self->{'allow-update'} = $acl;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{'allow-update'}) ? $self->{'allow-update'} :
			Unix::Conf->_err ('allow_update', "allow-update not defined")
	);
}

=item allow_update_elements ()

Object method.
Returns an array ref containing the elements of allow-update acl.

=cut

sub allow_update_elements
{
	return (
		defined ($_[0]->{'allow-update'}) ? $_[0]->{'allow-update'}->elements () :
			Unix::Conf->_err ('allow_update', "allow-update not defined")
	);
}

=item check_names ()

 Arguments
 'fail_warn_ignore',    # optional

Object method.
Get/Set zone check-names. If argument is passed, the method tries to 
set the check-names of the zone object to 'fail_warn_ignore', and 
returns true if successful, an Err object otherwise. If no argument 
is specified, returns the value of the check-names attribute, if defined, 
an Err object otherwise.

=cut

sub check_names
{
	my ($self, $val) = @_;

	if (defined ($val)) {
		return (Unix::Conf->_err ('check_names', "illegal value `$val' for zone directive `check-names'"))
			if (! __valid_checknames ($val));
		$self->{'check-names'} = $val;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{'check-names'}) ? $self->{'check-names'} :
			Unix::Conf->_err ('check_names', "check-names not defined")
	);
}

=item transfer_source ()

 Arguments
 'IP Address',    # optional

Object method.
Get/Set the transfer-source attribute. If argument is passed, the method 
tries to set the transfer-source attribute to 'IP Address', and returns 
true if successful, an Err object otherwise. If no argument is passed, 
returns the value of the transfer-source attribute, if defined, an Err 
object otherwise.

=cut

sub transfer_source
{
	my ($self, $address) = @_;

	if (defined ($address)) {
		return (Unix::Conf->_err ('transfer_source', "illegal IP address `$address'"))
			if (! __valid_ipaddress ($address));
		$self->{'transfer-source'} = $address;
		$self->dirty (1);
		return (1);
	}

	return (
		defined ($self->{'transfer-source'}) ? $self->{'transfer-source'} :
			Unix::Conf->_err ('transfer_source', "transfer-source not defined")
	);
}

=item max_transfer_time_in ()

 Arguments
 number,

Object method.
Get/Set the max-transfer-time-in attribute. If argument is passed, the 
method tries to set the max-transfer-time-in attribute to number, and 
returns true if successful, an Err object otherwise. If no argument is 
passed, returns the value of the max-transfer-time-in attribute, if 
defined, an Err object otherwise.

=cut

sub max_transfer_time_in
{
	my ($self, $number) = @_;

	if (defined ($number)) {
		return (Unix::Conf->_err ('max_transfer_time_in', "illegal number `$number'"))
			if (! __valid_number ($number));
		$self->{'max-transfer-time-in'} = $number;
		$self->dirty (1);
		return (1);
	}

	return (
		defined ($self->{'max-transfer-time-in'}) ? $self->{'max-transfer-time-in'} :
			Unix::Conf->_err ('max_transfer_time_in', "max-transfer-time-in not defined")
	);
}

=item dialup ()

 Arguments
 'yes_no',    # optional

Object method.
Get/Set the object's dialup attribute. If argument is passed, the method 
tries to set the dialup attribute to 'yes_no', and returns true if successful, 
an Err object otherwise. If no argument is passed, returns the value of the 
dialup attribute, if defined, an Err object otherwise.

=cut

sub dialup
{
	my ($self, $dialup) = @_;

	if (defined ($dialup)) {
		return (Unix::Conf->_err ('dialup', "illegal syntax `dialup  $dialup'"))
			if (! __valid_yesno ($dialup));
		$self->{dialup} = $dialup;
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{dialup}) ? $self->{dialup} : Unix::Conf->_err ('dialup', "dialup not defined")
	);
}

=item delete_directive ()

 Arguments
 'directive',

Object method.
Deletes the directive passed as argument, if defined, and returns true, an Err object 
otherwise.

=cut

sub delete_directive
{
	my ($self, $dir) = @_;

	return (Unix::Conf->_err ('delete_zonedir', "directive to be deleted not specified"))
		unless ($dir);
	# validate $dir 
	return (Unix::Conf->_err ('delete_zonedir', "illegal zone directive `$dir'"))
		if ($dir !~ /^(type|file|masters|check-names|allow-update|allow-query|allow-transfer|forward|forwarders|transfer-source|max-transfer-time-in|notify|also-notify)$/);
	return (Unix::Conf->_err ('delete_zonedir', "cannot delete `$dir'"))
		if ($dir =~ /^(name|type)$/);
	undef ($self->{$dir});
	$self->dirty (1);
	return (1);
}

=item get_db ()

 Arguments,
 number,    # 0/1 secure open

Constructor
This method is a wrapper method of the class constructor of the Unix::Conf::Bind8::DB
class. Creates and returns a new Unix::Conf::Bind8::DB object representing the records
file for the zone, if successful, an error object otherwise.

=cut

sub get_db
{
	require Unix::Conf::Bind8::DB;
	my ($self, $secure_open) = @_;
	$secure_open = 1 unless (defined ($secure_open));

	return (
		Unix::Conf::Bind8::DB::->new (
			FILE		=> $self->file (),
			ORIGIN		=> $self->name (),
			CLASS		=> uc ($self->class ()),
			SECURE_OPEN	=> $secure_open
		)
	);
}

1;
__END__

=head1 TODO

delete_zonedir* style methods could be autocreated through
closures. Also there must be methods to delete individual
members of ALLOW-UPDATE style attributes.

=cut
