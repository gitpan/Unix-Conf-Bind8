# Bind8 Conf class.
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

=head1 NAME

Unix::Conf::Bind8::Conf - Front end for a suite of classes for manipulating
a Bind8 style configuration file. 

=head1 SYNOPSIS

Refer to the SYNOPSIS section for Unix::Conf::Bind8.

=head1 DESCRIPTION

This class has interfaces for the various class methods of the classes that 
reside beneath Unix::Conf::Bind8::Conf. This class is an internal class and 
should not be accessed directly. Methods in this class can be accessed 
through a Unix::Conf::Bind8::Conf object which is returned by 
Unix::Conf::Bind8->new_conf (). Refer to Unix::Conf::Bind8 for further 
details.

=cut

package Unix::Conf::Bind8::Conf;

use strict;
use warnings;

use Unix::Conf;
use Unix::Conf::Bind8::Conf::Directive;
use Unix::Conf::Bind8::Conf::Lib;
use Unix::Conf::Bind8::Conf::Logging;
use Unix::Conf::Bind8::Conf::Options;
use Unix::Conf::Bind8::Conf::Acl;
use Unix::Conf::Bind8::Conf::Zone;
use Unix::Conf::Bind8::Conf::Include;

#
# Unix::Conf::Bind8::Conf object
# The object is a reference to reference to an anonymous hash.
# The anonymous hash is referred to here as CONFDS for conf datastructure.
# => {
#	ROOT => CONFDS of the first Conf object in the tree.
#	FH
#	HEAD
#	TAIL
#	LOGGING
#	OPTION
#	ACL
#	ZONE
#	INCLUDE
#	ALL_LOGGING		defined only in a ROOT node
#	ALL_OPTION		defined only in a ROOT node
#	ALL_ACL			defined only in a ROOT node
#	ALL_ZONE		defined only in a ROOT node
#	ALL_INCLUDE		defined only in a ROOT node
#	ERRORS
#	DIRTY
# }
#

=over 4

=item new ()

 Arguments
 FILE         => 'path of the configuration file',
 SECURE_OPEN  => 0/1,       # default 1 (enabled)

Class constructor.
Creates a new Unix::Conf::Bind8::Conf object. The constructor parses the 
Bind8 file specified by FILE and contains subobjects representing various 
directives like options, logging, zone, acl etc. Direct use of this 
constructor is deprecated. Use Unix::Conf::Bind8->new_conf () instead.
Returns a Unix::Conf::Bind8::Conf object on success, or an Err object on 
failure.

=cut

sub new
{
	my $invocant = shift ();
	my %args =  @_;
	my ($new, $conf_fh, $ret);

	# get and validate arguments
	my $conf_path = $args{FILE} || return (Unix::Conf->_err ('new', "FILE not specified"));
	my $secure_open = defined ($args{SECURE_OPEN}) ? $args{SECURE_OPEN} : 1;
	$conf_fh = Unix::Conf->_open_conf (
		NAME 		=> $conf_path,
		SECURE_OPEN => $secure_open,
	) or return ($conf_fh);

	my $head =  { PREV => undef }; 
	my $tail =  { NEXT => undef }; 
	$head->{NEXT} = $tail;
	$tail->{PREV} = $head;

	$new = bless (
		\{ 
			DIRTY => 0, 
			HEAD => $head,
			TAIL => $tail,
		},
	);
	$$new->{FH} = $conf_fh;
	# in case no ROOT was passed then we were not called from 
	# Unix::Conf::Bind8::Conf::Include->new (). So set ourselves
	# as ROOT as it is so.
	# NOTE: we set the hashref to which the object (a scalar ref)
	# points to as the value for ROOT, to solve the circular ref problem
	$ret = $new->__root ($args{ROOT} ? $args{ROOT} : $$new) or return ($ret);
	eval { $ret = $new->__parse_conf () } or return ($@);
	return ($new);
}

# Class destructor.
sub DESTROY
{
	my $self = $_[0];

	if ($self->dirty ()) {
		my $file;
		# go through the array of directives and create a string representing
		# the whole file.

		for (my $ptr = $$self->{HEAD}{NEXT}; $ptr && $ptr ne $$self->{TAIL}; $ptr = $ptr->{NEXT}) {
			$file .= ${$ptr->_rstring ()};
		}

		# set the string as the contents of the ConfIO object.
		$$self->{FH}->set_scalar (\$file);
	}
	undef (%{$$self});
}

=item fh ()

Object method.
Returns the ConfIO object representing the configuration file.

=cut

sub fh
{
	my $self = $_[0];
	return ($$self->{FH});
}

sub dirty
{
	my ($self, $dirty) = @_;

	if (defined ($dirty)) {
		$$self->{DIRTY} = $dirty;
		return (1);
	}
	return ($$self->{DIRTY});
}

#
# The _add_dir* routines, insert an object into the per Conf hash and the
# ALL_* hash which resides in the ROOT Conf.
#

for my $dir qw (zone acl include) {
	no strict 'refs';

	my $meth = "_add_$dir";
	*$meth = sub {
		my $obj = $_[0];
		my ($root, $parent, $name);
		$parent = $obj->_parent () or return ($root);
		$root = $parent->{ROOT};
		$name = $obj->name () or return ($name);
		return (Unix::Conf->_err ("$meth", "$dir `$name' already defined"))
			if ($root->{"ALL_\U$dir\E"}{$name});
		# store in per Conf hash as well as in the ROOT Conf object
		$parent->{"\U$dir\E"}{$name} = $root->{"ALL_\U$dir\E"}{$name} = $obj;
		return (1);
	};

	# we get from the ROOT ALL_DIR* hash, so we can get a directive
	# defined in any Conf file from any Conf object.
	# maybe it is better to restrict _get_* to directives defined in
	# that file only.
	$meth = "_get_$dir";
	*$meth = sub {
		my ($confds, $name) = @_;
		return (Unix::Conf->_err ("$meth", "$dir `$name' not defined"))
			unless ($confds->{ROOT}{"ALL_\U$dir\E"}{$name});
		return ($confds->{ROOT}{"ALL_\U$dir\E"}{$name});
	};

	$meth = "_del_$dir";
	*$meth = sub {
		my $obj = $_[0];
		my ($root, $parent, $name);
		$parent = $obj->_parent () or return ($root);
		$root = $parent->{ROOT};
		$name = $obj->name () or return ($name);
		return (Unix::Conf->_err ("$meth", "$dir `$name' not defined"))
			unless ($root->{"ALL_\U$dir\E"}{$name});
		$root->{"ALL_\U$dir\E"}{$name} = $parent->{"\U$dir\E"}{$name} = undef;
		return (1);
	};
}

for my $dir qw (options logging) {
	no strict 'refs';

	my $meth = "_add_$dir";
	*$meth = sub {
		my $obj = $_[0];
		my ($root, $parent);
		$parent = $obj->_parent () or return ($parent);
		$root = $parent->{ROOT};
		return (Unix::Conf->_err ("$meth", "`$dir' already defined"))
			if ($root->{"ALL_\U$dir\E"});
		$root->{"ALL_\U$dir\E"} = $parent->{"\U$dir\E"} = $obj;
		return (1);
	};

	# we get from the ROOT ALL_DIR* hash, so we can get a directive
	# defined in any Conf file from any Conf object.
	# maybe it is better to restrict _get_* to directives defined in
	# that file only.
	$meth = "_get_$dir";
	*$meth = sub {
		my $confds = $_[0];
		return (Unix::Conf->_err ("$meth", "`$dir' not defined"))
			unless ($confds->{ROOT}{"ALL_\U$dir\E"});
		return ($confds->{ROOT}{"ALL_\U$dir\E"});
	};

	$meth = "_del_$dir";
	*$meth = sub {
		my $obj = $_[0];
		my ($root, $parent);
		$root = $obj->_parent () or return ($root);
		$root = $parent->{ROOT};
		return (Unix::Conf->_err ("$meth", "`$dir' not defined"))
			unless ($root->{"ALL_\U$dir\E"});
		$root->{"ALL_\U$dir\E"} = $parent->{"\U$dir\E"} = undef;
		return (1);
	};
}

# ARGUMENTS:
# 	Unix::Conf::Bind8::Conf::Directive subclass instalce
#	WHERE => ('FIRST'|'LAST'|'BEFORE'|'AFTER')
#	WARG  => Unix::Conf::Bind8::Conf::Directive subclass instance
#			 # in case WHERE =~ /('BEFORE'|'AFTER')/
# This routine uses the PARENT ref in an object to insert itself in the
# doubly linked list in the parent Unix::Conf::Bind8::Conf object.
sub _insert_in_list ($$;$)
{
	my ($obj, $where, $arg) = @_;

	return (Unix::Conf->_err ("__insert_in_list", "`$obj' not instance of a subclass of Unix::Conf::Bind8::Conf::Directive"))
		unless (UNIVERSAL::isa ($obj, "Unix::Conf::Bind8::Conf::Directive"));
	return (Unix::Conf->_err ("__insert_in_list", "`$where', illegal argument"))
		if ($where !~ /^(FIRST|LAST|BEFORE|AFTER)$/);
	my $conf = $obj->_parent ();

	# now insert the directive in the doubly linked list
	# insert at the head
	($where eq 'FIRST') && do {
		$obj->{PREV} = $conf->{HEAD};
		$obj->{NEXT} = $conf->{HEAD}{NEXT};
		$conf->{HEAD}{NEXT}{PREV} = $obj;
		$conf->{HEAD}{NEXT} = $obj;
		goto END;
	};
	# insert at tail
	($where eq 'LAST') && do {
		$obj->{NEXT} = $conf->{TAIL};
		$obj->{PREV} = $conf->{TAIL}{PREV};
		$conf->{TAIL}{PREV}{NEXT} = $obj;
		$conf->{TAIL}{PREV} = $obj;
		goto END;
	};

	return (Unix::Conf->_err ("__insert_in_list", "$where not an child of Unix::Conf::Bind8::Conf::Directive"))
		unless (UNIVERSAL::isa ($arg, "Unix::Conf::Bind8::Conf::Directive"));
	# before $arg
	($where eq 'BEFORE') && do {
		$obj->{NEXT} = $arg;
		$obj->{PREV} = $arg->{PREV};
		$arg->{PREV}{NEXT} = $obj;
		$arg->{PREV} = $obj;
		goto END;
	};
	# after $arg
	($where eq 'AFTER') && do {
		$obj->{NEXT} = $arg->{NEXT};
		$obj->{PREV} = $arg;
		$arg->{NEXT}{PREV} = $obj;
		$arg->{NEXT} = $obj;
	};
END:
	return (1);
}

# ARGUMENTS
# Unix::Conf::Bind8::Conf::Directive subclass object
# Delete object from the doubly linked list.
sub _delete_from_list ($)
{
	my $obj = $_[0];

	return (
		Unix::Conf->_err (
			"__delete_from_list", 
			"`$obj' not instance of a subclass of Unix::Conf::Bind8::Conf::Directive"
		)
	) unless (UNIVERSAL::isa ($obj, "Unix::Conf::Bind8::Conf::Directive"));
	$obj->{NEXT}{PREV} = $obj->{PREV};
	$obj->{PREV}{NEXT} = $obj->{NEXT};
	return (1);
}

sub __root
{
	my ($self, $root) = @_;

	if ($root) {
		$$self->{ROOT} = $root;
		return (1);
	}
	return (
		defined ($$self->{ROOT}) ? $$self->{ROOT} :
			Unix::Conf->_err ('__root', "ROOT not defined")
	);
}

# ARGUMENTS:
#	Unix::Conf::Err obj
# called by the parser to push errors messages generated during parsing.
sub __add_err
{
	my ($self, $errobj, $lineno) = @_;

	$errobj = Unix::Conf->_err ('add_err', "argument not passed")
		unless (defined ($errobj));
	push (@{$$self->{ERRORS}}, $errobj);
}

################################### DUMMY ######################################
#                                                                              #

=item new_dummy ()

 Arguments
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object
 				  # WARG is to be provided only in case WHERE eq 'BEFORE 
				  # or WHERE eq 'AFTER'

Object method.
Creates a dummy directive. Such directives are used to hold data 
between two directives, i.e. comments, whitespace etc.
Returns a Unix::Conf::Bind8::Conf::Directive object on success or 
Err object on failure.

=cut

sub new_dummy 
{
	my $self = shift;
	return (Unix::Conf->_err ('new_options', "not a class constructor"))
		unless (ref ($self));
	return (Unix::Conf::Bind8::Conf::Directive->new ( @_, PARENT => $$self ));
}

#                                    END                                       #
################################### DUMMY ######################################

################################## OPTIONS #####################################
#                                                                              #

=item new_options ()

 Arguments
 SUPPORTED-OPTION-NAME-IN-CAPS => value    
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object
 				  # WARG is to be provided only in case WHERE eq 'BEFORE 
				  # or WHERE eq 'AFTER'

Object Method.
Refer to Unix::Conf::Bind8::Conf::Options for supported options. The 
arguments should be same as expected by various the various methods of 
Unix::Conf::Bind8::Conf::Options.
Returns a Unix::Conf::Bind8::Conf::Options object on success or an Err 
object on failure.

=cut
 
sub new_options
{
	my $self = shift ();
	return (Unix::Conf->_err ('new_options', "not a class constructor"))
		unless (ref ($self));
	return (Unix::Conf::Bind8::Conf::Options->new (@_, PARENT => $$self ));
}

=item get_options ()

Object method.
Returns the Unix::Conf::Bind8::Conf::Options object if defined (either 
through a call to new_options or one created when the configuration file 
is parsed) or Err if none is defined.

=cut

sub get_options
{
	return (_get_options (${$_[0]}));
}

=item delete_options ()

Object method
Deletes the defined (either through a call to new_options or one created 
when the configuration file is parsed) Unix::Conf::Bind8::Conf::Options 
object.
Returns true if a Unix::Conf::Bind8::Conf::Options object is present, an 
Err object otherwise.

=cut

sub delete_options
{
	my ($options, $ret);
	$options = _get_options (${$_[0]}) or return ($options);
	return ($options->delete ());
}
	
#                                    END                                       #
################################## OPTIONS #####################################

#################################### ACL #######################################
#                                                                              #

=item new_acl ()

 Arguments
 NAME      => 'acl-name',				# Optional
 ELEMENTS  => [ qw (10.0.0.1 10.0.0.2 192.168.1.0/24) ],
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object
 				  # WARG is to be provided only in case WHERE eq 'BEFORE 
				  # or WHERE eq 'AFTER'

Object method.
Returns a new Unix::Conf::Bind8::Conf::Acl object on success or an Err object
on failure.

=cut

sub new_acl
{
	my $self = shift ();
	return (Unix::Conf->_err ('new_acl', "not a class constructor"))
		unless (ref ($self));
	return (Unix::Conf::Bind8::Conf::Acl->new (@_, PARENT => $$self ));
}

=item get_acl ()

 Arguments
 'ACL-NAME',

Class/Object method.
Returns the Unix::Conf::Bind8::Conf::Acl object representing 'ACL-NAME' if
defined (either through a call to new_acl or one created when the 
configuration file is parsed), an Err object otherwise.

=cut

sub get_acl
{
    my ($self, $name) = @_;

 	return (Unix::Conf->_err ('get_acl', "ACL name not specified"))
 		unless ($name);
	return (_get_acl ($$self, $name));
}

=item delete_acl ()

 Arguments
 'ACL-NAME',

Class/Object method.
Deletes the Unix::Conf::Bind8::Conf::Acl object representing 'ACL-NAME' 
if defined (either through a call to new_acl or one created when the 
configuration file is parsed) and returns true, or returns an Err object 
otherwise.

=cut

sub delete_acl
{
    my ($self, $name) = @_;
	my $acl;
	$acl = _get_acl ($$self, $name) or return ($acl);
	return ($acl->delete ());
}

=item acls ()

 Arguments
 CONTEXT	=> 'ROOT'		# Optional. If this argument is not present
 							# only ACLs defined in this conf file will
							# be returned. Else all ACLs defined will
							# be returned.

Class/Object method.
Iterates through the list of defined Unix::Conf::Bind8::Conf::Acl objects 
(either through a call to new_acl or ones created when parsing the file, 
returning an object at a time when called in scalar context, or a list of 
all objects when called in list context.

=cut

sub acls
{
	my $self = shift ();
	my %args = @_;
	if ($args{CONTEXT} && $args{CONTEXT} eq 'ROOT') {
		return (
			wantarray () ? values (%{$$self->{ROOT}{ALL_ACL}}) : (each (%{$$self->{ROOT}{ALL_ACL}}))[1]
		);
	}
	return (
		wantarray () ? values (%{$$self->{ACL}}) : (each (%{$$self->{ACL}}))[1]
	);
}

#                                    END                                       #
#################################### ACL #######################################

################################### ZONE #######################################
#                                                                              #

=item new_zone ()
 
 Arguments
 NAME          => 'zone-name',
 CLASS         => 'zone-class',        # in|hs|hesiod|chaos
 TYPE          => 'zone-type',         # master|slave|forward|stub|hint
 FILE          => 'records-file',
 MASTERS       => [ qw (10.0.0.1 10.0.0.2) ],
 FORWARD       => 'value',             # yes|no
 FORWARDERS    => [ qw (192.168.1.1 192.168.1.2) ],
 CHECK-NAMES   => 'value'              # fail|warn|ignore
 ALLOW-UPDATE  => Unix::Conf::Bind8::Conf::Acl object,
 ALLOW-QUERY   => Unix::Conf::Bind8::Conf::Acl object,
 ALLOW-TRANSFER=> Unix::Conf::Bind8::Conf::Acl object,
 NOTIFY        => 'value,              # yes|no
 ALSO-NOTIFY   => [ qw (10.0.0.3) ],
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object
 				  # WARG is to be provided only in case WHERE eq 'BEFORE 
				  # or WHERE eq 'AFTER'

Object method.
Creates and returns a new Unix::Conf::Bind8::Conf::Zone object if 
successful, or an Err object otherwise.

=cut

sub new_zone
{
	my $self = shift ();
	my ($new, $ret);
	
	return (Unix::Conf->_err ('new_zone', "not a class constructor"))
		unless (ref ($self));
	return (Unix::Conf::Bind8::Conf::Zone->new (@_, PARENT => $$self ));
}

=item get_zone ()
 Arguments
 'ZONE-NAME',

Class/Object method.
Returns the Unix::Conf::Bind8::Conf::Zone object representing ZONE-NAME 
if defined (either through a call to new_zone () or one created when 
parsing the configuration file), an Err object otherwise.

=cut

sub get_zone
{
	my ($self, $name) = @_;

	return (Unix::Conf->_err ('get_zone', "zone name not specified"))
		unless ($name);
	return (_get_zone ($$self, $name));
}

=item delete_zone ()

 Arguments
 'ZONE-NAME',

Class/Object method.
Deletes the Unix::Conf::Bind8::Conf::Zone object representing ZONE-NAME 
if defined (either through a call to new_zone () or one created when 
parsing the configuration file) and returns true, or returns an Err 
object otherwise.

=cut

sub delete_zone
{
	my ($self, $name) = @_;
	my $zone;
	$zone = _get_zone ($$self, $name) or return ($zone);
	return ($zone->delete ());
}

=item zones ()

 Arguments
 CONTEXT	=> 'ROOT'		# Optional. If this argument is not present
 							# only ZONEs defined in this conf file will
							# be returned. Else all ZONEs defined will
							# be returned.

Class/Object method.
Iterates through a list of defined Unix::Conf::Bind8::Conf::Zone objects 
(either through a call to new_zone () or ones created when parsing the 
configuration file), returning one at a time when called in scalar context, 
or a list of all objects when called in list context.

=cut

sub zones
{
	my $self = shift ();
	my %args = @_;
	if ($args{CONTEXT} && $args{CONTEXT} eq 'ROOT') {
		return (
			wantarray () ? values (%{$$self->{ROOT}{ALL_ZONE}}) : (each (%{$$self->{ROOT}{ALL_ZONE}}))[1]
		);
	}
	return (
		wantarray () ? values (%{$$self->{ZONE}}) : (each (%{$$self->{ZONE}}))[1]
	);
}

#                                   END                                        #
################################### ZONE #######################################

################################# LOGGING ######################################
#                                                                              #

=item new_logging ()

 Arguments
 CHANNELS   => [
    { 
	   NAME             => 'channel-name1',
	   OUTPUT           => 'value',      # syslog|file|null
	   SEVERITY         => 'severity',   # if OUTPUT eq 'syslog'
	   FILE             => 'path',       # if OUTPUT eq 'file'
	   'PRINT-TIME'     => 'value',      # 'yes|no'
	   'PRINT-SEVERITY' => 'value',      # 'yes|no'
	   'PRINT-CATEGORY' => 'value',      # 'yes|no'
   },
 ],
 CATEGORIES  => [
      [ category1        => [ qw (channel1 channel2) ],
      [ category2        => [ qw (channel1 channel2) ],
 ],
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object
 				  # WARG is to be provided only in case WHERE eq 'BEFORE 
				  # or WHERE eq 'AFTER'

Object method.
Creates a new Unix::Conf::Bind8::Conf::Logging object and returns it if 
successful, or an Err object otherwise.

=cut

sub new_logging
{
	my $self = shift ();
	my ($new, $ret);

	return (Unix::Conf::Bind8::Conf::Logging->new (@_, PARENT => $$self ));
}

=item get_logging ()

Class/Object method.
Returns the Unix::Conf::Bind8::Logging object if defined (either through a
call to new_logging () or one created when parsing the configuration file),
an Err object otherwise.

=cut

sub get_logging
{
	return (_get_logging (${$_[0]}));
}

=item delete_logging ()

Class/Object method.
Deletes the Unix::Conf::Bind8::Logging object if defined (either through a
call to new_logging () or one created when parsing the configuration file) 
and returns true, or returns an Err object otherwise.

=cut

sub delete_logging
{
	my $self = $_[0];
	my ($logging, $ret);
	$logging = _get_logging ($$self) or return ($logging);
	return ($logging->delete ());
}

#                                   END                                        #
################################# LOGGING ######################################

################################# INCLUDE ######################################
#                                                                              #

=item new_include ()

 Arguments
 FILE         => 'path of the configuration file',
 SECURE_OPEN  => 0/1,        # default 1 (enabled)
 WHERE		   => 'FIRST'|'LAST'|'BEFORE'|'AFTER'
 WARG		   => Unix::Conf::Bind8::Conf::Directive subclass object
 				  # WARG is to be provided only in case WHERE eq 'BEFORE 
				  # or WHERE eq 'AFTER'

Object method.
Creates a new Unix::Conf::Bind8::Conf::Include object which contains an 
Unix::Conf::Bind8::Conf object representing FILE and returns it if 
successful, or an Err object otherwise. 

=cut

sub new_include 
{
	my $self = shift ();
	
	return (
		Unix::Conf::Bind8::Conf::Include->new (
			@_,
			PARENT => $$self,
			ROOT => $self->__root ()
		)
	);
}

=item get_include ()

 Arguments
 'INCLUDE-NAME',

Object method.
Returns the Unix::Conf::Bind8::Conf::Include object representing INCLUDE-NAME 
if defined (either through a call to new_include () or one created when 
parsing the configuration file), an Err object otherwise.

=cut

sub get_include
{
	my ($self, $name) = @_;

	return (Unix::Conf->_err ('get_include', "name not specified"))
		unless ($name);
	return (_get_include ($$self, $name));
}

=item get_include_conf ()

 Arguments
 'INCLUDE-NAME'

Object method.
Return the Unix::Conf::Bind8::Conf object inside a defined 
Unix::Conf::Bind8::Conf::Include of name INCLUDE-NAME.

=cut

sub get_include_conf
{
	my ($self, $name) = @_;

	return (Unix::Conf->_err ('get_include_conf', "name not specified"))
		unless (defined ($name));
	my $ret;
	$ret = _get_include ($$self, $name) or return ($ret);
	return ($ret->conf ());
}

=item delete_include ()

 Arguments
 'INCLUDE-NAME',

Object method.
Deletes the Unix::Conf::Bind8::Conf::Include object representing INCLUDE-NAME 
if defined (either through a call to new_include () or one created when 
parsing the configuration file) and returns true, or returns an Err 
object otherwise.

=cut

sub delete_include
{
	my ($self, $name) = @_;
	my ($include, $ret);
	return (Unix::Conf->_err ('delete_include', "name not specified"))
		unless ($name);
	$include = _get_include ($$self, $name) or return ($include);
	return ($include->delete ());
}

=item includes ()

 Arguments
 CONTEXT	=> 'ROOT'		# Optional. If this argument is not present
 							# only INCLUDEs defined in this conf file will
							# be returned. Else all INCLUDEs defined will
							# be returned.

Object method.
Iterates through defined Unix::Conf::Bind8::Conf::Include objects (either 
through a call to new_include () or ones created when parsing the 
configuration file), returning one at a time when called in scalar context, 
or a list of all defined includes when called in list context.
=cut

sub includes
{
	my $self = shift ();
	my %args = @_;
	if ($args{CONTEXT} && $args{CONTEXT} eq 'ROOT') {
		return (
			wantarray () ? values (%{$$self->{ROOT}{ALL_INCLUDE}}) : (each (%{$$self->{ROOT}{ALL_INCLUDE}}))[1]
		);
	}
	return (
		wantarray () ? values (%{$$self->{INCLUDE}}) : (each (%{$$self->{INCLUDE}}))[1]
	);
}

#                                   END                                        #
################################# INCLUDE ######################################

#################################### DB ########################################
#                                                                              #

=item get_db ()

 Arguments
 'ZONE-NAME',
 0/1,        # SECURE_OPEN (OPTIONAL). If not specified the value
             # for the ConfIO object is taken.

Object method
Returns a Unix::Conf::Bind8::DB object representing the records file for
zone 'ZONE-NAME' if successful, an Err object otherwise.

=cut

sub get_db 
{
	my ($self, $zone, $secure_open) = @_;
	my $ret;
	$secure_open = $self->fh ()->secure_open () 
		unless (defined ($secure_open));
	$ret = $self->get_zone ($zone) or return ($ret);
	return ($ret->get_db ($secure_open));
}

#                                   END                                        #
#################################### DB ########################################

#################################  PARSER  #####################################
#                                                                              #
require 'Unix/Conf/Bind8/Conf/Parser.pm';
#                                   END                                        #
#################################  PARSER  #####################################

1;
__END__
