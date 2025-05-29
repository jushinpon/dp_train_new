##This module is developed by Prof. Shin-Pon JU at NSYSU on March 28 2021
package iso_energy; 

use strict;
use warnings;

our (%iso_energy); # energy in eV for isolated atoms

$iso_energy->{"Ag"} = -3906.59601981073;
$iso_energy->{"Al"} = -533.718664027105;
$iso_energy->{"As"} = -242.950089114973;
$iso_energy->{"B"} = -80.2693591410703;
$iso_energy->{"Br"} = -635.755638123337;
$iso_energy->{"C"} = -241.70828096957;
$iso_energy->{"Cl"} = -451.138785561547;
$iso_energy->{"Co"} = -4054.35008152619;
$iso_energy->{"Cr"} = -2378.47259202176;
$iso_energy->{"Cu"} = -5489.97431221516;
$iso_energy->{"F"} = -657.496620630477;
$iso_energy->{"Fe"} = -4471.71168898861;
$iso_energy->{"Ge"} = -2902.34829374292;
$iso_energy->{"H"} = -12.4868317964703;
$iso_energy->{"Hf"} = -1527.79227398866;
$iso_energy->{"I"} = -5153.85642359335;
$iso_energy->{"Li"} = -195.001140173483;
$iso_energy->{"Mg"} = -455.876831876656;
$iso_energy->{"Mn"} = -2864.73906957712;
$iso_energy->{"Mo"} = -1855.0720183707;
$iso_energy->{"N"} = -266.345481007584;
$iso_energy->{"Na"} = -1295.93985052112;
$iso_energy->{"Nb"} = -4538.17004998351;
$iso_energy->{"Ni"} = -4665.50195299722;
$iso_energy->{"O"} = -559.95106287022;
$iso_energy->{"P"} = -185.732956151177;
$iso_energy->{"Pb"} = -11840.9468318835;
$iso_energy->{"Pt"} = -2860.52747224789;
$iso_energy->{"Ru"} = -2556.36596025496;
$iso_energy->{"S"} = -323.772835953905;
$iso_energy->{"Sb"} = -2512.26406118529;
$iso_energy->{"Si"} = -149.962652010225;
$iso_energy->{"Sn"} = -2217.18969569849;
$iso_energy->{"Ta"} = -1920.64494506236;
$iso_energy->{"Te"} = -357.401215615535;
$iso_energy->{"Ti"} = -1615.67447169544;
$iso_energy->{"V"} = -1965.42757655124;
$iso_energy->{"W"} = -2153.61034934247;
$iso_energy->{"Zn"} = -6278.63627174674;
$iso_energy->{"Zr"} = -1341.68291452224;

sub eleObj {# return properties of an element
    my $elem = shift @_;
    
    return ($iso_energy{"$elem"});#return value only
}

1;               # Loaded successfully
