# Bind8 Conf Parser
# Very rudimentary hand coded parser. Since the grammar is not recursive
# it was easy to hand code one.
# The supported syntax is the one specified in the man page for named.conf
# provided with bind-8.2.3
#
# Copyright Karthik Krishnamurthy <karthik.k@extremix.net>

package Unix::Conf::Bind8::Conf;

use strict;
use warnings;
use Unix::Conf;

use Unix::Conf::Bind8::Conf::Lib;

# Ideally we would want to pass this as argument. No sense in being dogmatic
# about such issues, and incur unecessary overhead.
my $Conf;

{
	my %Dispatch = (
		'logging'   	=> \&__parse_logging,
		'options'   	=> \&__parse_options,
		'zone'      	=> \&__parse_zone,
		'acl'       	=> \&__parse_named_acl,
		'include'   	=> \&__parse_include,
		'controls'  	=> \&__eat_statement,
		'server'    	=> \&__eat_statement,
		'key'       	=> \&__eat_statement,
		'trusted-keys' 	=> \&__eat_statement,
	);

	my ($FH, @Parse_Stack);
	my ($Tokens, $Token, $Lines);

	sub __lineno () 		{ return ($FH->lineno ());	}
	sub __token_start ()	{ return ($$Token[1]); 		}
	sub __token_end ()		{ return ($$Token[2]);		}

	sub __pushfile 
	{
		push (@Parse_Stack, [ $Conf, $FH, $Tokens, $Token, $Lines ]); 
		$Tokens = []; 
	}

	# at the last pop all the static variables will contain undef.
	# this has a desired sideeffect. $Lines contains ref to the array of lines
	# in $FH. References will be released properly at the end of the parse.
	sub __popfile  
	{
		($Conf, $FH, $Tokens, $Token, $Lines) = @{pop (@Parse_Stack)}; 
	}

	# ARGUMENTS:
	#	start lineno, start offset, end lineno, end offset
	sub __substr ($$$$)
	{
		my ($sl, $so, $el, $eo) = @_;
		my $rstring;
		if ($sl == $el) { 	# single line
			$rstring = substr ($$Lines[$sl], $so, $eo - $so);
		}
		else { 	# >= 2 lines
			$rstring = substr ($$Lines[$sl], $so);
			$sl++;
			# if $sl == $el now then there are only 2 lines
			$rstring .= join ('', @{$Lines}[$sl..($el - 1)]) if ($sl < $el);
			$rstring .= substr ($$Lines[$el], 0, $eo) if ($eo > 0);
		}
		return (\$rstring);
	}

	# Argument is the Bind8::Conf obj which represents the file
	sub __parse_conf ()
	{
	 	__pushfile ();
		($Conf, $FH) = ($_[0], $_[0]->fh ());
		$Lines = $FH->getlines ();
		my ($token, $handler, $obj, $dummy);
		my ($slineno, $elineno, $soffset, $eoffset) = (0, 0, 0, 0);

		while (defined ($token = __gettoken ())) {
			# mark begining of the first token in a statement
			$slineno = __lineno (), $soffset = __token_start ();

			# carve up the lines and store the data after the end of the last 
			# statement and before the end of the current one. store it as 
			# a separate object. This is only if there is any separation between
			# the two. This test also works for any comment before the start of
			# the first statement.
			if ($slineno > $elineno || ($slineno = $elineno && $soffset > $eoffset)) {
				$dummy = $Conf->new_dummy () or die ($dummy);
				$dummy->_rstring (__substr ($elineno, $eoffset, $slineno, $soffset));
			}
			
			die (Unix::Conf->_err ('__parse_conf', "illegal statement `$token'"))
				unless (defined ($handler = $Dispatch{$token}));
			# Handlers return Unix::Conf::Err or parsed object
			return ($obj)	unless (($obj = $handler->()));

			# mark the end of the last token in the statment
			$elineno = __lineno (), $eoffset = __token_end ();
			# store the string representing the statement
			$obj->_rstring (__substr ($slineno, $soffset, $elineno, $eoffset));
		}
		# add anything after the end of the last token of the last statement
		# but do it only if file not empty
		if (scalar (@$Lines) > 0) {
			# get the last line and the offset of the last char on the last line
			# this will then be used to calculate the string after the last token
			$slineno = $#{$Lines}; $soffset = length ($$Lines[$slineno]);
			if ($slineno > $elineno || 
				($slineno == $elineno && $soffset > $eoffset)) {
				$dummy = $Conf->new_dummy () or die ($dummy);
				$dummy->_rstring (__substr ($elineno, $eoffset, $slineno, $soffset));
			}
		}
		$Conf->dirty (0);
		__popfile ();
		return (1);
	}

	sub __peek
	{
		my $_token = __gettoken ();
		ungettoken ();
		return ($_token);
	}

	sub __ungettoken () { unshift (@$Tokens, $Token); }
	sub __gettoken (;$)
	{
		my $token;

GETTOKEN_TOP:
		unless (defined ($token = __gettoken1 ())) {
			die (Unix::Conf->_err ('__gettoken', "expected token, encountered EOF"))
				if ($_[0]);
			return ($token)
		}
		if ($token eq '/*') {
			# in case there is an EOF inside a comment $token will be undef
			# this will print a warning as we are using it in an eq expr
			no warnings;
			until (($token = __gettoken1 ()) eq '*/') {
				die (Unix::Conf->_err ('__gettoken', "end of file inside comment\n"))
					unless (defined ($token));
			}
			goto GETTOKEN_TOP;
		}
		return ($token);
	}

	sub __gettoken1 ()
	{
		my ($line, $in_comment);
	
		until (defined ($Token = shift (@$Tokens))) {
			return ($line)
				unless (defined ($line = $FH->getline ()));
			$line =~ s/^(.*?)#.*\Z/$1/;     # sanitize `#'
			$line =~ s/^(.*?)\/\/.*\Z/$1/;  # sanitize `//'
	
			# tokenize
			while ($line =~ /(\/\*|\*\/|".+"|[a-zA-Z0-9-_.\/]+|[{};!*])/g) {
				push (@$Tokens, [$1, $-[1], $+[1]]);
			}
		}
		return ($$Token[0]);
	}
}

# TO BE USED LATER
## this routine is called when the parser encounters a near fatal error
## while parsing a statement. we seek to the next valid statement and start
## parsing from there
#sub __recover ()
#{
#	my $token;
#
#	my @statements = keys (%Dispatch);
#	local $"="|";
#	while (defined ($token = __gettoken (1))) {
#		if ($token =~ /^(@statements)$/) {
#			ungettoken ($token);
#			return (1);
#		}
#	}
#	# control will never reach here. we'll die in the tokenizer
#	return ();
#}

# Handles non critical errors
# execute argument and store the ret in the conf obj.
# ARGUMENTS:
#	code
# RETURN:
#	same as the return of the code executed
sub __eval_warn (&)
{
	my $ret;
	$ret = &{$_[0]} or $Conf->__add_err ($ret);
	return ($ret);
}

# Handle critical error
# execute argument and blow up passing the Unix::Conf::Err return to the catcher
sub __eval_die (&)
{
	my $ret;
	$ret = &{$_[0]} or die ($ret);
	return ($ret);
}

# Check to see if the next token is $_[0]. If not add a warning and return 
# false. The basic assumption here is that with all the characters used with
# slurp_*, the most common mistake is that they are forgotten. So continuing
# with the parse after ungettoken (), has a good chance of recovering.
sub __slurp_stuff ($)
{
	if ((my $token = __gettoken(1)) ne $_[0]) {
		$Conf->__add_err (Unix::Conf->_err ('__slurp_stuff', "expected `$_[0]', got $token"));
		__ungettoken ();
		return ();
	}
	return (1);
}

sub __slurp_semicolon	() { return (__slurp_stuff (';')); }
sub __slurp_openbr		() { return (__slurp_stuff ('{')); }
sub __slurp_closebr		() { return (__slurp_stuff ('}')); }

# eat up statements we do not support.
sub __eat_statement ()
{
	my (@stack, $token);
	until (__gettoken (1) eq '{'){;}	# waste till the starting '{'
	#push (@stack, '{');					# push in the opening '{'
	while (defined ($token = __gettoken (1))) {
		if ($token eq '{') {
			push (@stack, '{');
		}
		elsif ($token eq '}') {
			last unless (defined (pop (@stack)));
		}
	}
	__slurp_semicolon ();
	return ($Conf->new_dummy ());
}

sub __parse_include ()
{
	my $token = __gettoken (1);
	my ($include, %args);

	$token =~ s/"(.+)"/$1/;
	$args{FILE} = $token;
	$args{SECURE_OPEN} = $Conf->fh ()->secure_open ();
	$include = __eval_die { $Conf->new_include (%args) };
	__slurp_semicolon ();
	return ($include);
}

my @zone_dir1 = qw (
	type
	file
	notify
	forward
	transfer-source
	check-names
	max-transfer-time-in
);
	
sub __parse_zone ()
{
	my ($token, $zone, $name);

	$zone = __eval_die { $Conf->new_zone ( NAME => __gettoken (1) ) };
	if (($token = __gettoken (1)) ne '{') {	# there might be an optional class
		__eval_warn { $zone->class ($token) };
		__slurp_openbr ();
	}

	# now parse zone directives
	while (($token = __gettoken (1)) ne '}') {
		local $" = "|";
		($token =~ /^(@zone_dir1)$/) && do {
			$token =~ s/-/_/g;
			__eval_warn { $zone->$token (__gettoken (1)) };
			goto SEMICOLON;
		};
		($token =~ /^allow-(transfer|query|update)$/) && do {
			my $acl;
			$token =~ s/-/_/g;
			($acl = __parse_acl ()) && __eval_warn { $zone->$token ($acl) };
			next;
		};
		($token eq 'masters') && do {
			if (($token = __gettoken (1)) eq 'port') {
				__eval_warn { $zone->masters_port (__gettoken (1)) };
			}
			else {
				__ungettoken ();
			}
			__parse_ipaddress ($zone, "add_masters");
			goto SEMICOLON;
		};
		($token =~ /^(also-notify|forwarders)$/) && do {
			$token =~ s/-/_/g;
			__parse_ipaddress ($zone, "add_$token");
			goto SEMICOLON;
		};
		($token eq 'pubkey') && do {
			while (($token = __gettoken (1)) ne ';') {
				;
			}
			next;
		};
		die (Unix::Conf->_err ('__parse_zone', "`$token' illegal/unsupported zone directive"));

SEMICOLON:
		__slurp_semicolon ();
	}

	# end of the zone statement
	__slurp_semicolon (); 
	return ($zone);
}

sub __parse_named_acl () { return (__parse_acl (1)); }

# Arguments: '1' (indicating true) if it is a named acl (acl 'aclname' { ..)
# the same subroutine is used to parse acls in front of directives like
# allow-query.
sub __parse_acl (;$)
{
	my ($named) = @_;
	my ($token, $acl, $name);

	if ($named) {
		$acl = __eval_die { $Conf->new_acl (NAME => ($name = __gettoken (1))) };
	}
	else {
		$acl = __eval_die { $Conf->new_acl () };
	}

	__slurp_openbr ();
	while (($token = __gettoken (1)) ne '}') {
		if ($token eq 'key') {	# ignore 'key'
			__gettoken (1); __slurp_semicolon ();
		}
		else {
			$token .= __gettoken (1) if ($token eq '!');
			__eval_warn { $acl->add_elements ([ "$token" ]) };
			__slurp_semicolon ();
		}
	}
	__slurp_semicolon ();
	return ($acl);
}

# let parse_channel and parse_category handle the appropriate statements
sub __parse_logging ()
{
	my ($token, $logging);

	$logging = __eval_die { $Conf->new_logging () };
	__slurp_openbr ();
	while (($token = __gettoken (1)) ne '}') {
		($token eq 'channel') &&	do {	__parse_channel ($logging); };
		($token eq 'category') &&	do { 	__parse_category ($logging); };
	}
	__slurp_semicolon ();
	return ($logging);
}

sub __parse_channel ($)
{
	my $logging = $_[0];
	my ($channel, $token, $path, $versions, $size);

	my $name = __gettoken (1);
	$channel = __eval_die { $logging->new_channel (NAME => $name) };
	__slurp_openbr ();

	while (($token = __gettoken (1)) ne '}') {
		($token eq 'file') && do {
			__eval_warn { $channel->output ($token) }; 
			$path = __gettoken (1);
			while (($token = __gettoken (1)) ne ';') {
				($token eq 'versions') and $versions = __gettoken (1);
				($token eq 'size') and $size = __gettoken (1);
			}
			my @args;
			push (@args, ( PATH => $path));
			push (@args, ( VERSION => $versions))	if ($versions);
			push (@args, ( SIZE => $size)) 			if ($size);
				
			__eval_warn { $channel->file ( @args ) };
			next;
		};
		# we slurp the semicolon in every case instead of doing in at the bottom
		# is so that we can check for the illegal channel directive.
		($token eq 'syslog') && do {
			__eval_warn { $channel->output ($token) }; 

			# channel boo { syslog; } is legal syntax. refer to the named.conf
			# in src/bin/named (channel no_info_messages). however the
			# syntax in the named.conf man page doesnt suggest that
			if (($token = __gettoken (1)) ne ';') {
				__eval_warn { $channel->syslog ($token) };
				__slurp_semicolon ();
			}	
			next;
		};
		($token eq 'null') && do { 
			__slurp_semicolon ();
			next;
		};
		($token eq 'severity') && do {
			my $severity = __gettoken (1);
			my @args = ( NAME => $severity );
			# check to see if there is a debug level
			if (($token = __gettoken (1)) ne ';') {
				push (@args, (LEVEL => $token));
				__slurp_semicolon ();
			}
			__eval_warn { $channel->severity (@args) };
			next;
		};
		($token =~ /^print-(category|severity|time)$/) && do {
			(my $meth = $token) =~ s/-/_/g;
			$token = __gettoken (1);
			__eval_warn { $channel->$meth ($token); };
			__slurp_semicolon ();
			next;
		};
		die (Unix::Conf->_err ('__parse_channel', "`$token' illegal channel directive"));
	}

	__slurp_semicolon ();
	return (1);
}

sub __parse_category ($)
{
	my $logging = $_[0];
	my ($channel, $category, @channels, @pos);

	$category = __gettoken (1);
	__slurp_openbr ();
	while (($channel = __gettoken (1)) ne '}') {
		if ($logging->__valid_channel ($channel)) {
			push (@channels, $channel);
		}
		else {
			die (Unix::Conf->_err ('__parse_category', "`$channel' undefined channel"));
		}
		__slurp_semicolon ();
	}

	__slurp_semicolon ();
	__eval_warn { $logging->category ($category, \@channels); };
	return (1);
}

sub __parse_options 
{
	my ($token, $tmp, $ret);
	my $options = __eval_die { $Conf->new_options () };
	
	__slurp_openbr ();
	while (($token = __gettoken (1)) ne '}') {

		($token eq 'forwarders') && do {
			__parse_ipaddress ($options, "add_forwarders");
			goto SEMICOLON;
		};
		($token eq 'check-names') && do {
			$token = __gettoken (1); $tmp = __gettoken (1);
			__eval_warn { $options->check_names ($token, $tmp) };
			goto SEMICOLON;
		};
		# this option is only parsed. not handled
		($token eq 'listen-on') && do {
			my $arg;
			if (__gettoken (1) eq 'port') {
				$arg->{PORT} = __gettoken (1);
			}	
			$arg->{ACL} = __parse_acl () 
				&& __eval_warn { $options->add_listen_on ($arg->{ACL}) }; 
			next;
		};
		($token eq 'query-source') && do {
			my ($port, $address);
			while (($token = __gettoken (1)) ne ';') {
				$port = __gettoken (1) 		if ($token eq 'port');
				$address = __gettoken (1)	if ($token eq 'address');
			}
			__eval_warn { $options->query_source ($port, $address) };	
			next;
		};
		# UNHANDLED CASES
		($token =~ /^(topology|sortlist)$/) && do {
			my $acl = __parse_acl ();
			next;
		};	
		($token eq 'rrset-order') && do {
			while (($token = __gettoken (1)) ne '}') {
				;
			}
			goto SEMICOLON;
		};	
		($token eq 'max-ixfr-log-size') && do {
			__gettoken (1);
			goto SEMICOLON;
		};	

		($token =~ /^allow-(query|recursion|transfer)$/) && do {
			my $acl;
			$token =~ s/-/_/g;
			($acl = __parse_acl ()) && __eval_warn { $options->$token ($acl) };
			next;
		};
		# Handle the general case 
		do {
			die (Unix::Conf->_err ('__parse_options', "`$token' illegal/unsupported option"))
				unless ($options->__valid_option ($token));
			$token =~ s/-/_/g;
			my $arg = __gettoken (1);
			__eval_warn { $options->$token ($arg) };
			goto SEMICOLON;
		};	

SEMICOLON:	__slurp_semicolon ();	
	}

	__slurp_semicolon ();
	return ($options);
}

# ARGUMENTS:
#	Unix::Conf::Bind8::Conf::* obj to which the ipaddress is to be added
#	method name of the first arg which is to be invoked to add the obj
# 		that method must accept a [] as its only argument
sub __parse_ipaddress ($$)
{
	my ($object, $method) = @_;
	my $token;

	__slurp_openbr ();
	while (($token = __gettoken (1)) ne '}') {
		__eval_warn { $object->$method ([ "$token" ]) };
		__slurp_semicolon ();
	}
}

1;
__END__
