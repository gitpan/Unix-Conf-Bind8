# Bind8 Options
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8::Conf::Options - Class for representing Bind8 options
directive

=head1 SYNOPSIS

    use Unix::Conf;
    my ($conf, $options, $ret);
    $conf = Unix::Conf::Bind8->new_conf (
        FILE        => '/etc/named.conf',
        SECURE_OPEN => 1,
    ) or $conf->die ("couldn't open `named.conf'");

    # get an options object if one is defined
    $options = $conf->get_options ()
        or $options->die ("couldn't get options");
    
    # or create a new one
    $options = $conf->new_options (
        DIRECTORY  => 'db',
        VERSION    => '8.2.3-P5',
    ) or $options->die ("couldn't create options");

     
    # now enable/disable individual options using the options object.
    my $acl = $conf->new_acl (
        NAME     => 'query-acl',
	   ELEMENTS => [ qw (10.0.0.1 10.0.0.2 10.0.0.3) ],
    );
    $acl->die ("couldn't create `query-acl'") unless ($acl);
    $ret = $options->allow_query ($acl) 
        or $ret->die ("couldn't set allow-query");
    $options->delete_allow_transfer ();
        
=head1 DESCRIPTION

=over 4

=cut

package Unix::Conf::Bind8::Conf::Options;

use strict;
use warnings;
use Unix::Conf;

use Unix::Conf::Bind8::Conf::Directive;
our @ISA = qw (Unix::Conf::Bind8::Conf::Directive);

use Unix::Conf::Bind8::Conf;
use Unix::Conf::Bind8::Conf::Lib;
use Unix::Conf::Bind8::Conf::Acl;

=item version ()

=item directory ()

=item named_xfer ()

=item dump_file ()

=item memstatistics_file ()

=item pid_file ()

=item statistics_file ()

 Arguments
 'string',      # optional

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item auth_nxdomain ()

=item deallocate_on_exit ()

=item dialup ()

=item fake_iquery ()

=item fetch_glue ()

=item has_old_clients ()

=item host_statistics ()

=item multiple_cnames ()

=item notify ()

=item recursion () 

=item rcf2308_type1 ()

=item use_id_pool ()

=item treat_cr_as_space () 

=item also_notify ()

=item maintain_ixfr_base ()

 Arguments
 'string',     # Optional. allowed values are 'yes', 'no'

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item  forward ()

 Arguments
 'string',     # optional. allowed values are 'only', 'first'

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item allow_query ()

=item allow_transfer ()

=item allow_recursion ()

=item blackhole ()

 Arguments
 object,      # Unix::Conf::Bind8::Conf::Acl object

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item lame_ttl ()

=item max_transfer_time_in ()

=item max_ncache_ttl ()

=item min_roots ()

=item serial_queries ()

=item max_serial_queries ()

=item transfers_in ()

=item transfers_out ()

=item transfers_per_ns ()

=item max_ixfr_log_size ()

=item cleaning_interval ()

=item heartbeat_interval ()

=item interface_interval ()

=item statistics_interval ()

 Arguments
 number,       # Optional

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item transfer_format ()
 
 Arguments
 'string',    # Optional. Allowed arguments are 'one-answer', 
              # 'many-answers'

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item valid_ipaddress ()

 Arguments
 'string',   # Optional. The argument must be an IP Address in the
             # dotted quad notation

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item coresize ()

=item datasize ()

=item files ()

=item stacksize ()

 Arguments
 'string',   # Optional. The argument must be a size spec. Refer to
             # the Bind8 manual for a definitio of size_spec.

Object method.
Get/Set attributes from the invoking object.
If called with a string argument, the method tries to set the corresponding 
attribute and returns true on success, an Err object otherwise. Returns
value of the corresponding attribute if defined, an Err object otherwise.

=item delete_version ()

=item delete_directory ()

=item delete_named_xfer ()

=item delete_dump_file ()

=item delete_memstatistics_file ()

=item delete_pid_file ()

=item delete_statistics_file ()

=item delete_auth_nxdomain ()

=item delete_deallocate_on_exit ()

=item delete_dialup ()

=item delete_fake_iquery ()

=item delete_fetch_glue ()

=item delete_has_old_clients ()

=item delete_host_statistics ()

=item delete_multiple_cnames ()

=item delete_notify ()

=item delete_recursion ()

=item delete_rfc2308_type1 ()

=item delete_use_id_pool ()

=item delete_treat_cr_as_space ()

=item delete_also_notify ()

=item delete_forward ()

=item delete_allow_query ()

=item delete_allow_recursion ()

=item delete_allow_transfer ()

=item delete_blackhole ()

=item delete_lame_ttl ()

=item delete_max_transfer_time_in ()

=item delete_max_ncache_ttl ()

=item delete_min_roots ()

=item delete_serial_queries ()

=item delete_max_serial_queries ()

=item delete_transfer_format ()

=item delete_transfers_in ()

=item delete_transfers_out ()

=item delete_transfers_per_ns ()

=item delete_transfer_source ()

=item delete_maintain_ixfr_base ()

=item delete_max_ixfr_log_size ()

=item delete_coresize ()

=item delete_datasize ()

=item delete_files ()

=item delete_stacksize ()

=item delete_cleaning_interval ()

=item delete_heartbeat_interval ()

=item delete_interface_interval ()

=item delete_statistics_interval ()

=item delete_topology ()

Object method.
Deletes the corresponding directive if defined and returns true, or an Err
object otherwise.

=cut

# Methods that have a valid routine are automatically created. The rest are
# hand coded.
my %Supported_Options = (
	'version'				=> \&__valid_string,
	'directory'				=> \&__valid_string,
	'named-xfer'			=> \&__valid_string,
	'dump-file'				=> \&__valid_string,
	'memstatistics-file'	=> \&__valid_string,
	'pid-file'				=> \&__valid_string,
	'statistics-file'		=> \&__valid_string,

	'auth-nxdomain'			=> \&__valid_yesno,
	'deallocate-on-exit'	=> \&__valid_yesno,
	'dialup'				=> \&__valid_yesno,
	'fake-iquery'			=> \&__valid_yesno,
	'fetch-glue'			=> \&__valid_yesno,
	'has-old-clients'		=> \&__valid_yesno,
	'host-statistics'		=> \&__valid_yesno,
	'multiple-cnames'		=> \&__valid_yesno,
	'notify'				=> \&__valid_yesno,
	'recursion'				=> \&__valid_yesno,
	'rfc2308-type1'			=> \&__valid_yesno,
	'use-id-pool'			=> \&__valid_yesno,
	'treat-cr-as-space'		=> \&__valid_yesno,
	'also-notify'			=> \&__valid_yesno,

	'forward'				=> \&__valid_forward,

	'allow-query'			=> 'acl',
	'allow-recursion'		=> 'acl',
	'allow-transfer'		=> 'acl',
	'blackhole'				=> 'acl',

	'lame-ttl'				=> \&__valid_number,
	'max-transfer-time-in'	=> \&__valid_number,
	'max-ncache-ttl'		=> \&__valid_number,
	'min-roots'				=> \&__valid_number,
	# the man page provides this directive
	'serial-queries'		=> \&__valid_number,
	# the sample named.conf with bind suggests this.
	'max-serial-queries'	=> \&__valid_number,

	'transfer-format'		=> \&__valid_transfer_format,

	'transfers-in'			=> \&__valid_number,
	'transfers-out'			=> \&__valid_number,
	'transfers-per-ns'		=> \&__valid_number,

	'transfer-source'		=> \&__valid_ipaddress,

	'maintain-ixfr-base'	=> \&__valid_yesno,
	'max-ixfr-log-size'		=> \&__valid_number,

	'coresize'				=> \&__valid_sizespec,
	'datasize'				=> \&__valid_sizespec,
	'files'					=> \&__valid_sizespec,
	'stacksize'				=> \&__valid_sizespec,

	'cleaning-interval'		=> \&__valid_number,
	'heartbeat-interval'	=> \&__valid_number,
	'interface-interval'	=> \&__valid_number,
	'statistics-interval'	=> \&__valid_number,

	'topology'				=> 'acl',

	# methods below have only their delete_* counterpart created via closure
	# as the pattern of arguments don't fit well into a template
	'check-names'			=> 0,
	'forwarders'			=> 0,
	'listen-on'				=> 0,
	'query-source'			=> 0,
);

{
	no strict 'refs';
	for my $option (keys (%Supported_Options)) {
		my $meth = $option;
		$meth =~ tr/-/_/;

		# Options taking ACL elements as arguments
		($Supported_Options{$option} eq 'acl') 		&& do {
			*$meth = sub {
				my ($self, $acl) = @_;

				if (defined ($acl)) {
					return (Unix::Conf->_err ("$meth", "argument must be a Unix::Conf::Bind8::Conf::Acl object"))
						unless (UNIVERSAL::isa ($acl, 'Unix::Conf::Bind8::Conf::Acl'));
					$self->{options}{$option} = $acl;
					$self->dirty (1);
					return (1);
				}
				return (
					defined ($self->{options}{$option}) ? $self->{options}{$option} : Unix::Conf->_err ("$meth", "Option $option not defined")
				);
			};

			# add_* counterpart for options taking ACL elements as arguments
			*{"add_$meth"} = sub {
				my ($self, $elements) = @_;

				if (defined ($elements)) {
					my $ret;
					$self->{options}{$option} = Unix::Conf::Bind8::Conf::Acl->new () 
						unless ($self->{options}{'allow-query'});
					$ret = $self->{options}{$option}->add_elements ($elements) or return ($ret);
					$self->dirty (1);
					return (1);
				}
				return (Unix::Conf->_err ("add_$meth", "elements not specified"));
			};

			# *_elements
			*{"${meth}_elements"} = sub {
				return (
					defined ($_[0]->{$option}) ? $_[0]->{$option}->elements () : 
						Unix::Conf->_err ("{$meth}_elements", "Option $option not defined")
				);
			};
			goto CREATE_DELETE;
		};

		# These methods have the corresponding validation routines
		("$Supported_Options{$option}" =~ /^CODE/)	&& do {
			*$meth = sub {
				my ($self, $arg) = @_;
				
				if (defined ($arg)) {
					return (Unix::Conf->_err ("$meth", "invalid argument $arg"))
						unless (&{$Supported_Options{$option}}($arg));
					$self->{options}{$option} = $arg;
					$self->dirty (1);
					return (1);
				}
				return (
					defined ($self->{options}{$option}) ? $self->{options}{$option} : Unix::Conf->_err ("$meth", "Option $option not defined")
				);
			};
		};

CREATE_DELETE:
		# delete_*
		*{"delete_$meth"} = sub {
			return (Unix::Conf->_err ("delete_$meth", "option `$option' not defined"))
				unless (defined ($_[0]->{$option}));
			undef ($_[0]->{$option});
			$_[0]->dirty (1);
			return (1);
		};
	}
}

=item delete_option ()

 Arguments
 'OPTION-NAME',

Object method.
Deletes the corresponding directive if defined and returns true, or an Err
object otherwise.

=cut

sub delete_option 
{
	my ($self, $option) = @_;

	return (Unix::Conf->_err ('delete_option', "Option `$option' not supported or invalid"))
		unless (defined ($Supported_Options{$option}));
	return (Unix::Conf->_err ('delete_option', "option `$option' not defined"))
		unless (defined ($self->{options}{$option}));
	undef ($self->{options}{$option});
	return (1);
}

=item check_names ()

 Arguments
 'string',        # 'master'|'slave'|'response'
 'string',        # 'warn'|'fail'|'ignore'

Object method.
Get/Set the 'check-name' attribute from the invoking object. If arguments
are passed the method tries to set the 'check-names' attribute and return
true if successful, an Err object otherwise. If no arguments are passed,
then the method tries to return the value of the 'check-names' attribute if
defined, an Err object otherwise.

=cut

sub check_names
{
	my $self = shift ();
	if (@_) {
		return (Unix::Conf->_err ('check_names', "incorrect number of arguments (expected 2)"))
			unless (@_ == 2);
		return (Unix::Conf->_err ('check_names', "illegal argument `$_[0]'"))
			if ($_[0] !~ /^(master|slave|response)$/);
		return (Unix::Conf->_err ('check_names', "illegal argument `$_[1]'"))
			unless (__valid_checknames ($_[1]));
		@{$self->{options}{'check-names'}} = @_;
		return (1);
	}
	return (
		defined ($self->{options}{'check-names'}) ? [ @{$self->{options}{'check-names'}} ] :
			Unix::Conf->_err ('check_names', "option `check-names' not defined")
	);
}

=item forwarders ()

 Arguments
 [ 'IP_Address1', 'IP_Address2', ]  # the IP Addresses must be 
                                    # specified in the dotted 
                                    # quad notation.

Object method.
Get/Set the 'forwarders' attribute in the invoking object. If an array ref
is passed as argument, the method tries to set the 'forwarders' attribute
and returns true on success, an Err object otherwise. If no arguments are
passed then the method tries to return an array ref if the 'forwarders'
attribute is defined, an Err object otherwise.

=cut

sub forwarders
{
	my ($self, $elements) = @_;
	
	if ($elements) { 
		for (@$elements) {
			return (Unix::Conf->_err ('forwarders', "illegal IPv4 address $_"))
				unless (__valid_ipaddress ($_));
		}
		$self->{options}{forwarders} = [ @$elements ];
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{options}{forwarders}) ? [ @{$self->{options}{forwarders}} ] :
			Unix::Conf->_err ('forwarders', "option `forwarders' not set")
	);
}

=item add_forwarders ()

 Arguments
 [ 'IP_Address1', 'IP_Address2', ]  # the IP Addresses must be 
                                    # specified in the dotted 
                                    # quad notation.

Object method.
Add the elements of the argument, to the 'forwarders' attribute. Return
true on success, an Err object otherwise.

=cut

sub add_forwaders
{
	my ($self, $elements) = @_;

	if ($elements) {
		for (@$elements) {
			return (Unix::Conf->_err ('add_forwarders', "illegal IPv4 address $_"))
				unless (__valid_ipaddress ($_));
		}
		push (@{$self->{options}{forwarders}}, @$elements);
		$self->dirty (1);
		return (1);
	}
	return (Unix::Conf->_err ('add_forwarders', "elements not specified"));
}

# This option is a little awkward to handle. finish later
my $LO_Port 	= 0; 
my $LO_Acl		= 1;
# Multiple listen-on statements are allowed. All of them are stored in an 
# [] in options->{'listen-on'}. Each element of the array is a [], where 
# the first element is the port and the second the acl
sub listen_on
{
	my $self = shift ();
	my %args = @_;
	
	if ($args{ACL}) {
		return (Unix::Conf->_err ('listen_on', "ACL must be a Unix::Conf::Bind8::Conf::Acl object"))
			unless (UNIVERSAL::isa ($args{ACL}, 'Unix::Conf::Bind8::Conf::Acl'));
		return (Unix::Conf->_err ('listen_on', "illegal PORT `$args{PORT}'"))
			unless ($args{PORT} =~ /^\d+$/);
		# init
		$self->{options}{'listen-on'} = [ [$args{PORT}, $args{ACL}], ];
		$self->dirty (1);
		return (1);
	}
	return ($self->{options}{'listen-on'}) 
		if (defined ($self->{options}{'listen-on'}));
	return (Unix::Conf->_err ('listen_on', "option `listen-on' not defined"));
}

sub add_listen_on 
{
	my $self = shift ();
	my %args = @_;

	if ($args{ACL}) {
		return (Unix::Conf->_err ('add_listen_on', "ACL must be a Unix::Conf::Bind8::Conf::Acl object"))
			unless (UNIVERSAL::isa ($args{ACL}, 'Unix::Conf::Bind8::Conf::Acl'));
		return (Unix::Conf->_err ('add_listen_on', "illegal PORT `$args{PORT}'"))
			unless ($args{PORT} =~ /^\d+$/);
		push (@{$self->{options}{'listen-on'}}, [$args{PORT}, $args{ACL}]); 
		$self->dirty (1);
		return (1);
	}
}

sub query_source
{
	my ($self, $port, $address) = @_;
	
	if ($port || $address) {
		#my %args = @_;
		if ($address) {
			return (Unix::Conf->_err ('query_source', "illegal IP address `$address'"))
				unless (__valid_ipaddress ($address) || $address eq '*');
		}
		if ($port) {
			return (Unix::Conf->_err ('query_source', "illegal port `$port'"))
				unless (__valid_ipaddress ($port) || $port eq '*');
		}
		@{$self->{options}{'query-source'}} = ($port, $address);
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{options}{'query-source'}) ? @{$self->{options}{'query-source'}} :
			Unix::Conf->_err ('query_source', "option `query-source' not defined")
	);
}

=item options

Object method.
Iterates through the list of defined options returning their name one at a
time in a scalar context, or a list of all defined option names in list
context.

=cut

sub options
{
	return (
		wantarray () ? keys (%{$_[0]->{options}}) : (each (%{$_[0]->{options}}))[0]
	);
}

=item new ()

 Arguments
 OPTION-NAME   => value,      # the value type is dependant on the option

Class Constructor.
Create a new Unix::Conf::Bind8::Conf::Options object and return it if
successful, or an Err object otherwise. Direct use of this method is deprecated.
Use Unix::Conf::Bind8::Conf::new_options () instead.

=cut

sub new
{
	my $self = shift ();
	my $new = bless ({});
	my $ret;

	my %args = @_;
	$args{PARENT} || return (Unix::Conf->_err ('new', "PARENT not specified"));
	$ret = $new->_parent ($args{PARENT}) or return ($ret);
	delete ($args{PARENT});	# as PARENT is not a valid option
	for (keys (%args)) {
		my $option = $_;
		$option =~ tr/A-Z/a-z/;
		return (Unix::Conf->_err ('new', "Option $option not supported"))
			unless (defined ($Supported_Options{$option}));
		# change it into the corresponding method name
		$option =~ tr/-/_/;
		$new->$option ($args{$_}) or return ($ret);
	}
	$ret = Unix::Conf::Bind8::Conf::_add_options ($new) or return ($ret);
	$args{WHERE} = 'LAST' unless ($args{WHERE});
	$ret = Unix::Conf::Bind8::Conf::_insert_in_list ($new, $args{WHERE}, $args{WARG}) 
		or return ($ret);
	return ($new);
}

sub __valid_option
{
	my ($self, $option) = @_;

	local $" = "|";
	my  @opts = keys (%Supported_Options);
	return ($option =~ /^(@opts)$/);
}

sub __render
{
	my ($rendered, $tmp, $tmp1);
		
	$rendered = qq (options {\n);

	$rendered .= qq (\tdirectory "$tmp";\n)
		if (($tmp = $_[0]->directory ()));
	$rendered .= qq (\tversion "$tmp";\n)
		if (($tmp = $_[0]->version ()));
	$rendered .= qq (\tnamed-xfer "$tmp";\n)
		if (($tmp = $_[0]->named_xfer ()));
	$rendered .= qq (\tdump-file "$tmp";\n)
		if (($tmp = $_[0]->dump_file ()));
	$rendered .= qq (\tmemstatistics-file "$tmp";\n)
		if (($tmp = $_[0]->memstatistics_file ()));
	$rendered .= qq (\tpid-file "$tmp";\n)
		if (($tmp = $_[0]->pid_file ()));
	$rendered .= qq (\tstatistics-file "$tmp";\n)
		if (($tmp = $_[0]->statistics_file ()));
	$rendered .= qq (\tauth-nxdomain $tmp;\n)
		if (($tmp = $_[0]->auth_nxdomain ()));
	$rendered .= qq (\tdeallocate-on-exit $tmp;\n)
		if (($tmp = $_[0]->deallocate_on_exit ()));
	$rendered .= qq (\tdialup $tmp;\n)
		if (($tmp = $_[0]->dialup ()));
	$rendered .= qq (\tfake-iquery $tmp;\n)	
		if (($tmp = $_[0]->fake_iquery ()));
	$rendered .= qq (\tfetch-glue $tmp;\n)
		if (($tmp = $_[0]->fetch_glue ()));
	$rendered .= qq (\thas-old-clients $tmp;\n)
		if (($tmp = $_[0]->has_old_clients ()));
	$rendered .= qq (\thost-statistics $tmp;\n)
		if (($tmp = $_[0]->host_statistics ()));
	$rendered .= qq (\tmultiple-cnames $tmp;\n)
		if (($tmp = $_[0]->multiple_cnames ()));
	$rendered .= qq (\tnotify $tmp;\n)
		if (($tmp = $_[0]->notify ()));
	$rendered .= qq (\trecursion $tmp;\n)
		if (($tmp = $_[0]->recursion ()));
	$rendered .= qq (\trfc2308-type1 $tmp;\n)
		if (($tmp = $_[0]->rfc2308_type1 ()));
	$rendered .= qq (\tuse-id-pool $tmp;\n)
		if (($tmp = $_[0]->use_id_pool ()));
	$rendered .= qq (\ttreat-cr-as-space $tmp;\n)
		if (($tmp = $_[0]->treat_cr_as_space ()));
	$rendered .= qq (\talso-notify $tmp;\n)
		if (($tmp = $_[0]->also_notify ()));
	$rendered .= qq (\tforward $tmp;\n)
		if (($tmp = $_[0]->forward ()));
	if (($tmp = $_[0]->forwarders ())) {
		local $" = "; ";
		$rendered .= "\tforwarders { @$tmp; };\n"
	}
	# clean this up.
	if (($tmp = $_[0]->check_names ())) {
		$rendered .= qq (\tcheck-names );
		$rendered .= qq ($$tmp[0] $$tmp[1]);
		$rendered .= ";\n";	
	}
	# here we dont call Acl::->render instead rendering ourself
	# by getting the elements (). this is because we want to print the
	# whole thing on one line. 
	if (($tmp = $_[0]->allow_query_elements ())) {
		local $" = "; ";
		$rendered .= qq (\tallow-query { @$tmp; };\n)
	}
	if (($tmp = $_[0]->allow_recursion_elements ())) {
		local $" = "; ";
		$rendered .= qq (\tallow-recursion { @$tmp; };\n)
	}
	if (($tmp = $_[0]->allow_transfer_elements ())) {
		local $" = "; ";
		$rendered .= qq (\tallow-transfer { @$tmp; };\n)
	}
	# Update this part after listen-on handling is complete
	#if (($tmp = $_[0]->listen_on ())) {
	#	my $port;
	#	local $" = "; ";
	#	$rendered .= qq (\tlisten-on );
	#	$rendered .= qq (port $port )
	#		if (defined ($port = $_[0]->listen_on_port ()));
	#	$rendered .= qq ({ @{$tmp->elements ()}; };\n);	
	#}
	if ((($tmp, $tmp1) = $_[0]->query_source ()) == 2) {
		$rendered .= qq (\tquery-source );
		$rendered .= qq (port $tmp) 	if ($tmp);
		$rendered .= qq (address $tmp1)	if ($tmp1);
		$rendered .= ";\n";
	}
	$rendered .= qq (\tlame-ttl $tmp;\n)
		if (($tmp = $_[0]->lame_ttl ()));
	$rendered .= qq (\tmax-transfer-time-in $tmp;\n)
		if (($tmp = $_[0]->max_transfer_time_in ()));
	$rendered .= qq (\tmax-ncache-ttl $tmp;\n)
		if (($tmp = $_[0]->max_ncache_ttl ()));
	$rendered .= qq (\tmin-roots $tmp;\n)
		if (($tmp = $_[0]->min_roots ()));
	$rendered .= qq (\tserial-queries $tmp;\n)
		if (($tmp = $_[0]->serial_queries ()));
	$rendered .= qq (\ttransfer-format $tmp;\n)
		if (($tmp = $_[0]->transfer_format ()));
	$rendered .= qq (\ttransfers-in $tmp;\n)
		if (($tmp = $_[0]->transfers_in ()));
	$rendered .= qq (\ttransfers-out $tmp;\n)
		if (($tmp = $_[0]->transfers_out ()));
	$rendered .= qq (\ttransfers-per-ns $tmp;\n)
		if (($tmp = $_[0]->transfers_per_ns ()));
	$rendered .= qq (\ttransfer-source $tmp;\n)
		if (($tmp = $_[0]->transfer_source ()));
	$rendered .= qq (\tmaintain-ixfr-base $tmp;\n)
		if (($tmp = $_[0]->maintain_ixfr_base ()));
	$rendered .= qq (\tmax-ixfr-log-size $tmp;\n)
		if (($tmp = $_[0]->max_ixfr_log_size ()));

	$rendered .= qq (\tcoresize $tmp;\n)
		if (($tmp = $_[0]->coresize ()));
	$rendered .= qq (\tdatasize $tmp;\n)
		if (($tmp = $_[0]->datasize ()));
	$rendered .= qq (\tfiles $tmp;\n)
		if (($tmp = $_[0]->files ()));
	$rendered .= qq (\tstacksize $tmp;\n)
		if (($tmp = $_[0]->stacksize ()));
	$rendered .= qq (\tcleaning-interval $tmp;\n)
		if (($tmp = $_[0]->cleaning_interval ()));
	$rendered .= qq (\theartbeat-interval $tmp;\n)
		if (($tmp = $_[0]->heartbeat_interval ()));
	$rendered .= qq (\tinterface-interval $tmp;\n)
		if (($tmp = $_[0]->interface_interval ()));
	$rendered .= qq (\tstatistics-interval $tmp;\n)
		if (($tmp = $_[0]->statistics_interval ()));

	$rendered .= qq (};\n);
	return ($_[0]->_rstring (\$rendered));
}

1;
__END__
