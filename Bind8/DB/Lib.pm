# general utility routines
#
# Copyright Karthik Krishnamurthy
package Unix::Conf::Bind8::DB::Lib;

use strict;
use warnings;

require Exporter;
our @ISA = qw (Exporter);
our @EXPORT = qw ( 
	__make_relative
	__make_absolute
	__is_absolute
	__is_validttl
);

sub __make_relative ($$)
{
	my ($origin, $label) = @_;
	my $ret = $label;

	$ret =~ s/^(?:([\w.\-]+)\.)?$origin$/defined ($1) ? $1 : ''/ie
		if ($label =~ /^[\w.-]+\.$/);
	return ($ret);
}

# ARGUMENTS:
#	ORIGIN
#	ARG
sub __make_absolute ($$)	
{ 
	my ($origin, $label) = @_;
	return (
		($label =~ /^[\w.-]+\.$/) ? $label : 
			($origin ? "$label.$origin" : $label)
	);
}

sub __is_absolute ($) 		{ return ($_[0] =~ /^[\w.-]+\.$/); 	}
sub __is_validttl ($) 		{ return ($_[0] =~ /^(?:(?:\d+[wdhms])+|\d+$)/oi); }

1;
