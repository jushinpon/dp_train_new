##This module is developed by Prof. Shin-Pon JU at NSYSU on March 28 2021
package iso_energy; 

use strict;
use warnings;

our (%iso_energy); # energy in eV for isolated atoms

$iso_energy{"Ag"} = 0.0;
$iso_energy{"Al"} = 0.0;
$iso_energy{"As"} = 0.0;
$iso_energy{"B"}  = 0.0;
$iso_energy{"Br"} = 0.0;
$iso_energy{"C"}  = 0.0;
$iso_energy{"Cl"} = 0.0;
$iso_energy{"Co"} = 0.0;
$iso_energy{"Cr"} = 0.0;
$iso_energy{"Cu"} = 0.0;
$iso_energy{"F"}  = 0.0;
$iso_energy{"Fe"} = 0.0;
$iso_energy{"Ge"} = 0.0;
$iso_energy{"H"}  = 0.0;
$iso_energy{"Hf"} = 0.0;
$iso_energy{"I"}  = 0.0;
$iso_energy{"Li"} = 0.0;
$iso_energy{"Mg"} = 0.0;
$iso_energy{"Mn"} = 0.0;
$iso_energy{"Mo"} = 0.0;
$iso_energy{"N"}  = 0.0;
$iso_energy{"Na"} = 0.0;
$iso_energy{"Nb"} = 0.0;
$iso_energy{"Ni"} = 0.0;
$iso_energy{"O"}  = 0.0;
$iso_energy{"P"}  = 0.0;
$iso_energy{"Pb"} = 0.0;
$iso_energy{"Pt"} = 0.0;
$iso_energy{"Ru"} = 0.0;
$iso_energy{"S"}  = 0.0;
$iso_energy{"Sb"} = 0.0;
$iso_energy{"Sc"} = 0.0;
$iso_energy{"Si"} = 0.0;
$iso_energy{"Sn"} = 0.0;
$iso_energy{"Ta"} = 0.0;
$iso_energy{"Te"} = 0.0;
$iso_energy{"Ti"} = 0.0;
$iso_energy{"V"}  = 0.0;
$iso_energy{"W"}  = 0.0;
$iso_energy{"Y"}  = 0.0;
$iso_energy{"Zn"} = 0.0;
$iso_energy{"Zr"} = 0.0;


sub eleObj {# return properties of an element
    my $elem = shift @_;
    
    return ($iso_energy{"$elem"});#return value only
}

1;               # Loaded successfully
