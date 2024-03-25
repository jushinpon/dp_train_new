use warnings;
use strict;

#for initial folder
my @all_inifolder;
#!!! make the following if you have place everything in the initial folder
my $source = "/root/dp_train/initial";
my @all_QEin = `find $source -type f -name *.in`;
map { s/^\s+|\s+$//g; } @all_QEin;

##make softlink for initial 

for (@all_QEin){
    my $dirname = `dirname $_`;
    $dirname =~ s/^\s+|\s+$//g;
   
    my $temp = `grep scf $_`;
    if($temp){
        my $prefix = `basename $_`;
        $prefix =~ s/\.in|\s+$//g;
        my @temp = `grep ! $dirname/$prefix.sout`;
        if(@temp > 1){print "two ! for scf, bad sout files: $_\n"}

    }
}