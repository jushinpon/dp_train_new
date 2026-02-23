##This module is developed by Prof. Shin-Pon JU at NSYSU on Feb 23, 2026, for smearing cold (mv)
package iso_energy; 

use strict;
use warnings;

our (%iso_energy); # energy in eV for isolated atoms

$iso_energy{"Ag"} = -3906.78584415037;
$iso_energy{"Al"} = -533.718267557445;
$iso_energy{"As"} = -242.950084897211;
$iso_energy{"B"}  = -80.2694041758875;
$iso_energy{"Br"} = -635.755617442696;
$iso_energy{"C"}  = -241.708238111662;
$iso_energy{"Cl"} = -451.138764744849;
$iso_energy{"Co"} = -4055.91460087228;
$iso_energy{"Cr"} = -2383.73712800374;
$iso_energy{"Cu"} = -5490.2432023194;
$iso_energy{"F"}  = -657.92951352515;
$iso_energy{"Fe"} = -4474.60123674061;
$iso_energy{"Ge"} = -2902.34838666975;
$iso_energy{"H"}  = -12.4869104373294;
$iso_energy{"Hf"} = -1527.79233929595;
$iso_energy{"I"}  = -5153.85570085937;
$iso_energy{"Li"} = -195.340260238398;
$iso_energy{"Mg"} = -455.87683473385;
$iso_energy{"Mn"} = -2869.82880801822;
$iso_energy{"Mo"} = -1859.87717663166;
$iso_energy{"N"}  = -266.345506042045;
$iso_energy{"Na"} = -1295.9398887531;
$iso_energy{"Nb"} = -4538.2620705371;
$iso_energy{"Ni"} = -4665.6984384081;
$iso_energy{"O"}  = -559.951083278747;
$iso_energy{"P"}  = -185.732927443182;
$iso_energy{"Pb"} = -11840.947003043;
$iso_energy{"Pt"} = -2860.98314486877;
$iso_energy{"Ru"} = -2558.11132364438;
$iso_energy{"S"}  = -323.772831055858;
$iso_energy{"Sb"} = -2513.70106233755;
$iso_energy{"Sc"} = -1245.32439086877;
$iso_energy{"Si"} = -149.962631601698;
$iso_energy{"Sn"} = -2217.82837689113;
$iso_energy{"Ta"} = -1920.64503186663;
$iso_energy{"Te"} = -357.401300651066;
$iso_energy{"Ti"} = -1616.76009283613;
$iso_energy{"V"}  = -1968.42861785736;
$iso_energy{"W"}  = -2153.61126827044;
$iso_energy{"Y"}  = -1185.88916907337;
$iso_energy{"Zn"} = -6278.63627133857;
$iso_energy{"Zr"} = -1341.74107270288;


sub eleObj {# return properties of an element
    my $elem = shift @_;
    
    return ($iso_energy{"$elem"});#return value only
}

1;               # Loaded successfully
