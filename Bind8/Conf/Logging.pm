# Logging
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8::Conf::Logging - Class representing the 'logging'
directive in a Bind8 Configuration file.

=head1 SYNOPSIS

    use Unix::Conf::Bind8;
    my ($conf, $logging, $channel, $ret);

    $conf = Unix::Conf::Bind8->new_conf (
        FILE        => '/etc/named.conf',
        SECURE_OPEN => 1,
    ) or $conf->die ("couldn't open `named.conf'");
    
    # get an existing logging object
    $logging = $conf->get_logging () 
        or $logging->die ("couldn't get logging");
    
    # or create a new logging object
    $logging = $conf->new_logging (
        CHANNELS => [
            {
                NAME             => 'my_file_chan',
                OUTPUT           => 'file',
                FILE             => {
				  PATH     => '/var/log/named/file_chan.log',
				  VERSIONS => 3,
				  SIZE     => '10k',
                },
                SEVERITY         => { NAME => 'debug', LEVEL => '3' },
                'PRINT-TIME'     => 'yes',
                'PRINT-SEVERITY' => 'yes',
                'PRINT-CATEGORY' => 'yes'
            },
            {
                NAME             => 'my_syslog_chan',
                OUTPUT           => 'syslog',
                SYSLOG           => 'daemon',
                SEVERITY         => { NAME => 'info' },
                'PRINT-TIME'     => 'yes',
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
		WHERE	=> 'FIRST',
    ) or $logging->die ("couldn't create logging");

    # create new channel
    $channel = $logging->new_channel (
        NAME             => 'new_chan',
        OUTPUT           => 'syslog',
        SYSLOG           => 'info',
        SEVERITY         => { NAME => 'debug', LEVEL => 3 },
        'PRINT-TIME'     => 'yes',
        'PRINT-SEVERITY' => 'no',
        'PRINT-CATEGORY  => 'yes',
    ) or $channel->die ("couldn't create `new_chan'");

    # or get an already defined channel
    $channel = $logging->get_channel ('my_file_chan)
        or $channel->die ("couldn't get `my_file_chan'");

    # For further operations on channel objects refer to the 
    # documentation for Unix::Conf::Bind8::Conf::Logging::Channel

    # delete define channel
    $ret = $logging->delete_channel ('my_syslog_chan')
        or $ret->die 

    # iterate through defined channels 
    printf "%s\n", $_->name () for ($logging->channels ());

    # set channels for categories
    $ret = $logging->category (
	    'eventlib', [ qw (new_chan default_syslog) ]
    ) or $ret->die ("couldn't set channels for category `eventlib'");
    
    # delete categories
    $ret = $logging->delete_category ('db') 
        or $ret->die ("coudn't delete category `db'");

    # print out defined categories
    # note the difference in the usage for channels () and categories ().
    print "$_\n" for ($logging->categories ());

=head1 DESCRIPTION

This class has methods to handle the various aspects of the logging statement.
Channels are implemented as a sub class, while categories are handled within
this class itself.

=cut

package Unix::Conf::Bind8::Conf::Logging;

use strict;
use warnings;
use Unix::Conf;

use Unix::Conf::Bind8::Conf::Directive;
our @ISA = qw (Unix::Conf::Bind8::Conf::Directive);

use Unix::Conf::Bind8::Conf;
use Unix::Conf::Bind8::Conf::Lib;
use Unix::Conf::Bind8::Conf::Logging::Channel;

=over 4

=item new ()

 Arguments
 CHANNELS    => [ 
     { 
         NAME             => 'channel-name',
         OUTPUT           => 'value',        # syslog|file|null
         FILE             => {               # only if OUTPUT eq 'file'
		   PATH     => 'file-name',
		   VERSIONS => number,
		   SIZE     => size_spec,
         },
         SYSLOG           => 'facility-name',# only if OUTPUT eq 'syslog'
         SEVERITY         => 'severity-name',
         'PRINT-TIME'     => 'value',        # yes|no
         'PRINT-SEVERITY' => 'value',        # yes|no
         'PRINT-CATEGORY' => 'value',        # yes|no
     },
 ],
 CATEGORIES  => [
     [ CATEGORY-NAME    => [ qw (channel1 channel2) ] ],
 ],
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object

Class constructor.
Create a new Unix::Conf::Bind8::Conf::Logging object, initialize it, and 
return it on success, or an Err object on failure.

=cut

sub new
{
	# discard the invocant class
	shift ();
	my %args = @_;
	my $new = bless ({});
	my $ret;

	$args{PARENT} || return (Unix::Conf->_err ('new', "PARENT not specified"));
	$ret = $new->_parent ($args{PARENT}) or return ($ret);
	if ($args{CHANNELS}) {
		for (@{$args{CHANNELS}}) {
			$ret = $new->new_channel (%{$_}) or return ($ret);
		}
	}
	if ($args{CATEGORIES}) {
		for (@{$args{CATEGORIES}}) {
			$ret = $new->category (@{$_}) or return ($ret);
		}
	}
	$ret = Unix::Conf::Bind8::Conf::_add_logging ($new) or return ($ret);
	$args{WHERE} = 'LAST' unless ($args{WHERE});
	$ret = Unix::Conf::Bind8::Conf::_insert_in_list ($new, $args{WHERE}, $args{WARG})
		or return ($ret);
	return ($new);
}

=item category ()

 Arguments
 'CATEGORY-NAME',
 [ qw (channel1 channel2) ],      # optional

Object method.
Get/Set the object's channel attribute. If the an array reference is passed
as the second argument, sets the catetgory 'CATEGORY-NAME' channels to the 
elements of the array ref. 
Returns true if able to set channels if array ref passed as the second 
argument, an Err object otherwise. If second argument is not passed, then
returns the channels set for category as an array reference if defined, 
an Err object otherwise.

=cut

sub category
{
	my ($self, $category, $channels) = @_;

	return (Unix::Conf->_err ('category', "illegal category `$category'"))
		unless (__valid_category ($category));
	if ($channels) {
		my $ret;
		for (@$channels) {
			$ret = __valid_channel ($self, $_) or return ($ret)
		}
		for (@$channels) {
			$self->{categories}{$category}{$_} = 1;
		}
		$self->dirty (1);
		return (1);
	}
	return (
		defined ($self->{categories}{$category}) ? 
			[ keys (%{$self->{categories}{$category}}) ] : 
			Unix::Conf->_err ('category', "category `$category' not defined")
	);
}

=item delete_category ()

 Arguments
 'CATEGORY-NAME',

Object method.
Deletes category named by 'CATEGORY-NAME', and returns true if successful,
an Err object otherwise.

=cut

sub delete_category 
{
	my ($self, $category) = @_;

	return (Unix::Conf->_err ('delete_category', "illegal category `$category'"))
		unless (__valid_category ($category));
	return (Unix::Conf->_err ('delete_category', "`$category' not explicitly defined"))
		unless (defined ($self->{categories}{$category}));
	undef ($self->{categories}{$category});
	$self->dirty (1);
	return (1);
}

=item categories ()

Object method.
Iterate through defined categories, returning names of all defined categories
in a list context, or one at a time in a scalar context.

=cut

sub categories
{
	return (
		wantarray () ? keys (%{$_[0]->{categories}}) : (each (%{$_[0]->{categories}}))[0]
	);
}

################################## CHANNEL #####################################
#                                                                              #

# put this in the logging object later on, since it doesn't have to be shared
# across conf objects
my %Channels;

=item new_channel ()

 Arguments
 [
     {
         NAME             => 'channel-name',
         OUTPUT           => 'value',        # syslog|file|null
         FILE             => 'file-name',    # only if OUTPUT eq 'file'
         SYSLOG           => 'facility-name',# only if OUTPUT eq 'syslog'
         SEVERITY         => 'severity-name',
         'PRINT-TIME'     => 'value',        # yes|no
         'PRINT-SEVERITY' => 'value',        # yes|no
         'PRINT-CATEGORY' => 'value',        # yes|no
     },
 ],

Object method.
This method is a wrapper around the class constructor for 
Unix::Conf::Bind8::Conf::Logging::Channel. Use this method instead of the
accessing the constructor directly.
Returns a new Unix::Conf::Bind8::Conf::Logging::Channel object on success,
an Err object otherwise.

=cut

sub new_channel
{
	my $self = shift ();
	return (Unix::Conf::Bind8::Conf::Logging::Channel->new (@_, PARENT => $self));
}

=item get_channel ()

 Arguments
 'CHANNEL-NAME',

Object method.
Returns a channel object for 'CHANNEL-NAME', if defined (either through a call
to new_channel (), or one defined while parsing the configuration file), an
Err object otherwise.

=cut

sub get_channel
{
	return (Unix::Conf->_err ('get_channel', "channel name not specified"))
		unless ($_[1]);
	return (_get_channel (@_));
}

=item delete_channel ()
 
 Arguments
 'CHANNEL-NAME'

Object method.
Deletes channel object for 'CHANNEL-NAME', if defined (either through a call
to new_channel (), or one defined while parsing the configuration file), an
Err object otherwise.

=cut

sub delete_channel
{
	my ($self, $name) = @_;
	my $channel;
	$channel = _get_channel ($self->_parent (), $name) or return ($channel);
	return ($channel->delete ());
}

=item channels ()

Class/Object method
Iterates through the list of defined Unix::Conf::Bind8::Conf::Logging::Channel
objects, returning one at a time when called in scalar context, or a list of 
all defined objects when called in list context.

=cut

sub channels
{
	return (
		wantarray () ? values (%Channels) : (each (%Channels))[1]
	);
}

sub _add_channel
{
	my $obj = $_[0];
	
	my ($name, $parent);
	return (Unix::Conf->_err ("_add_channel", "Channel object not specified"))
		unless ($obj);
	$name = $obj->name () or return ($name);
	$parent = $obj->_parent () or return ($parent);
	return (Unix::Conf->_err ("_add_channel", "Channel `$name' already defined"))
		if ($parent->{CHANNEL}{$name});
	$parent->{CHANNEL}{$name} = $obj;
	return (1);
}

sub _get_channel
{
	my ($parent, $name) = @_;

	return (Unix::Conf->_err ("_get_channel", "Channel name not specified"))
		unless ($name);
	return (Unix::Conf->_err ("_add_channel", "Channel `$name' not defined"))
		unless ($parent->{CHANNEL}{$name});
	return ($parent->{CHANNEL}{$name});
}

sub _del_channel
{
	my $obj = $_[0];
	
	my ($name, $parent);
	return (Unix::Conf->_err ("_del_channel", "Channel object not specified"))
		unless ($obj);
	$name = $obj->name () or return ($name);
	return (Unix::Conf->_err ('_del_channel', "channel `$name' is predefined, cannot be deleted"))
		if (_is_predef_channel ($name));
	$parent = $obj->_parent () or return ($parent);
	return (Unix::Conf->_err ("_del_channel", "Channel `$name' not defined"))
		unless ($parent->{CHANNEL}{$name});
	$parent->{CHANNEL}{$name} = undef;
}

sub _is_predef_channel
{
	my $name = $_[0];

	return (Unix::Conf->_err ('_is_predef_channel', "`$name' not a predefined channel"))
		if ($name !~ /^(default_syslog|default_debug|default_stderr|null)$/);
	return (1);
}

sub __valid_channel
{
	my ($self, $name) = @_;
	
	return (Unix::Conf->_err ('__valid_channel', "invalid channel `$name'"))
		unless (_is_predef_channel ($name) || _get_channel ($self, $name));
	return (1);
}

#                                    END                                       #
################################## CHANNEL #####################################


sub __render
{
	my $self = $_[0];
	my $rendered;

	$rendered = "logging {\n";
	
	# render all channels
	for (values (%Channels)) {
		$rendered .= $_->__render ();
	}

	my $channels;
	# render defined categories
	for (keys (%{$self->{categories}})) {
		$channels = $self->category ($_) or return ($channels);
		local $" = "; ";
		$rendered .= "\tcategory $_ { @$channels };\n"
	}
	$rendered .= "};\n";
	return ($self->_rstring (\$rendered));
}

1;
__END__
