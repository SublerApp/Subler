#!/usr/bin/perl

# ok, mar/98
#
package Text::Roman;
require 5.000;
require Exporter;

	@ISA = (Exporter);
	@EXPORT = qw(roman roman2int isroman mroman2int ismroman);

	$VERSION = 3.01;

	$ALGS = 'IVXLCDM';
	@alg = split '', $ALGS;
	# for int2rom:
	@alginf = (-1, 0, 0, 2, 2, 4, 4);
	%parsub = (IV=>A, IX=>B, XL=>E, XC=>F, CD=>G, CM=>H);
	%val = (I=>1, V=>5, X=>10, L=>50, C=>100, D=>500, M=>1000,
		A=>4, B=>9, E=>40, F=>90, G=>400, H=>900);
	%maxpos = (I=>2, V=>3, X=>29, L=>39, C=>299, D=>399, M=>2999,
			A=>0, B=>0, E=>9, F=>9, G=>99, H=>99);
			
	for $i (0..$#alg)
		{ $valg[$i] = $val{$alg[$i]};
		}



sub roman_stx
{ my $x  = shift;
my $aux = $$x;

$$x = uc $$x;
if ($$x eq $aux || lc $$x eq $aux)
	{ if ($$x =~ /^[IXCMVLD]+$/  &&  $$x !~ /([IXCM])\1{3,}|([VLD])\2+/)
		{ $$x =~ s/(IV|IX|XL|XC|CD|CM)/$parsub{$1}/g;
		$$x !~ /[AB].*?I|[EF].*?X|[GH].*?C/;
		}
	else
		{ '';}
	}
else
	{'';
	}
}



sub roman2int
	{ my $x = shift;
	my ($at, $flag, $i);
	my $val=0;
	my $ant=0;
	my @U;
	my $U='';
	
	if (&roman_stx(\$x))
		{ @U = split('', $x);
		for ($i = $#U; $i >= 0; $i--) 
			{ $at = $val{$U[$i]};
			return ''	if ($at<$ant);
			$val += $at;
			$ant = $at;
			}
		$val;
		}
	else
		{ '';
		}
	}


sub mroman2int
# allows '_' milhar syntax (LX_XXIII, L_X_XXIII)
#
{ my $x = shift;
my $s=0;
my ($sroman, $i, $aux);
my $y='';
my @partes;

@partes = split ('_',$x);
$sroman = pop @partes;
for $i (@partes)
	{ $y .= $i;
	}
$aux = &roman2int($y);
return '' if ($y =~ /^(I{1,3})$/ || !$aux);
$s += $aux*1000;
$aux = &roman2int($sroman);
return '' if (!$aux);
$s+$aux;
}



sub ismroman
# allows '_' milhar syntax (LX_XXIII, L_X_XXIII)
#
{ my $x = shift;
my ($i,$sroman);
my $y='';
my @partes;

if ($x =~ /^[_IXCMVLD]+$/)
	{ @partes = split ('_',$x);
	$sroman = pop @partes;
	for $i (@partes)
		{ $y .= $i;
		}
	return '' if ($y =~ /^(I{1,3})$/ || !&isroman($y));
	return &isroman($sroman);
	}
}



sub isroman
# same efect that (&roman2int($x)>0), but fasted
#
{ my $x = shift;
my $y=$x;
$x = uc $x;

($x eq $y || lc $x eq $y) && $x =~ /^(M{1,3}(D(C{1,3}(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3})))?|C{0,3}XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))))?|CD(XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))))?|(C{1,3}(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3})))?|C{0,3}XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3})))))?|M{0,3}CM(XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))))?|(D(C{1,3}(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3})))?|C{0,3}XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))))?|CD(XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))))?|(C{1,3}(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3})))?|C{0,3}XC(IX|(VI{0,3}|IV|I{1,3}))?|(L(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))?|XL(IX|(VI{0,3}|IV|I{1,3}))?|(X{1,3}(VI{0,3}|IV|I{1,3})?|X{0,3}IX|(VI{0,3}|IV|I{1,3}))))))$/;
}



sub roman_div
{
   my ($a, $b) = @_;
   my $inf = $alginf[$b];
   
   if ($b<0)
   	    { (0,-1); }
   elsif ( int($a/$valg[$b])>0 )
		{ ($b,-1); }
   elsif ( $a+$valg[$inf]>=$valg[$b] )
   		{ ($b, $inf); }
   else
   		{ &roman_div($a,$b-1); }
   }


sub roman_do
	{ my ($x, $str_x) = @_;
	my ($aux, $inf);
	
	($aux, $inf) = &roman_div($x,$#alg);
	if ($x>0 && $inf<0)
		{ &roman_do($x-$valg[$aux], $str_x.$alg[$aux]); }
	elsif ($x>0 && $inf>=0)
		{ &roman_do( $x+$valg[$inf]-$valg[$aux], $str_x.$alg[$inf].$alg[$aux] ); }
	else 
		{ $str_x; }
	}

	
sub roman
	{ my ($x) = @_;
	if ($x <1 || $x > 3999)
		{'';}
	else
		{ roman_do($x,""); }
	}

	
1;


__END__



=head1 NAME

Text::Roman - Converts roman algarism in integer numbers and the contrary, recognize algarisms.

=head1 SYNOPSIS

	use Text::Roman;

	print roman(123);

=head1 DESCRIPTION

Text::Roman::roman() is a very simple algarism converter. It converts a single integer
(in arabic algarisms) at a time to its roman correspondent. The conventional roman numbers
goes from 1 up to 3999. MROMANS (milhar romans) range is 1 up to 3999*1000+3999=4002999.

Up to these number we will found symbols as:??????but they do not concern this specific
package. There is no concern for mix cases, like 'Xv', 'XiiI', as legal roman algarism
numbers.

=over

=item B<roman($int)>: return string containing  the roman corresponding to the given integer, or '' if the integer is out of domain...

=item B<roman2int($str)>: return '' if $str is not roman or return integer if it is.

=item B<isroman($str)>: verify whether the given string is a conventional roman number, if it is return 1; if it is not return 0...

=back

Quite same follows for B<mroman2int($str)> and B<ismroman($str)>, except that these functions
treat milhar romans.

=head1 SPECIFICATION

Roman number has origin in following BNF-like formula:

a =	I{1,3}

b =	V\a?|IV|\a

e =	X{1,3}\b?|X{0,3}IX|\b

ee =	IX|\b

f =	L\e?|XL\ee?|\e

g =	C{1,3}\f?|C{0,3}XC\ee?|\f

gg =	XC\ee?|\f

h =	D\g?|CD\gg?|\g

j =	M{1,3}\h?|M{0,3}CM\gg?|\h

=head1 REFERENCES

Especification supplied by redactor's manual of newspaper "O Estado de São Paulo".
URL: http://www.estado.com.br/redac/norn-nro.html

=head1 EXAMPLE

	use Text::Roman;
	
	$roman	= "XXXV";
	$mroman	= 'L_X_XXIII';
	print roman(123), "\n";
	print roman2int($roman), "\n"	if isroman($roman);
	print mroman2int($mroman), "\n"	if ismroman($mroman);

=head1 BUGS

No one known.

=head1 AUTHOR

Peter de Padua Krauss, krauss@ifqsc.sc.usp.br.

=head1 COPYRIGHT

1.2-krauss/set/97; 1.0-krauss/3/ago/97

=cut
