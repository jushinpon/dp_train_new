=b
make qe input files for all strucutres in labelled folders.
You need to use this script in the dir with all dpgen collections (in all_cfgs folder)
perl ../tool_scripts/cfg2QEinput.pl 
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use List::Util qw(min max);
use Cwd;
use POSIX;
use Parallel::ForkManager;
use lib '../scripts';#assign pm dir
use elements;#all setting package

my $max4relabel = 2;# how many cfgs you want to use in labelled folder
my $lowerbound = 0.05;#below which not lebelled

my $currentPath = getcwd();# dir for all scripts
chdir("..");
my $mainPath = getcwd();# main path of Perl4dpgen dir
chdir("$currentPath");

my $forkNo = 1;#although we don't have so many cores, only for submitting jobs into slurm
my $pm = Parallel::ForkManager->new("$forkNo");

if(-e "nolabel.dat"){
    print "###nolabel.dat exists\n\n";
    my @nolabel = `grep -v '^[[:space:]]*\$' ./nolabel.dat`;
    map { s/^\s+|\s+$//g; } @nolabel;

    for my $n (@nolabel){#loop over folders with no labelled sub folder
        unless (-e "$n/md.out"){
            print "no md.out in $n. Skipped!\n";
            next; 
        }
        my @maxf = `grep -v '^[[:space:]]*\$' $n/md.out | grep -v step|awk '{print \$5}'`;
        map { s/^\s+|\s+$//g; } @maxf;
       
        my @temp = grep { $_ > $lowerbound}  @maxf; 
        unless (@maxf){
            print "max force deviation is lower than \$lowerbound ($lowerbound) in $n\n";
            next; 
        }
        my @step = `grep -v '^[[:space:]]*\$' $n/md.out | grep -v step|awk '{print \$1}'`;
        map { s/^\s+|\s+$//g; } @step;        
        my @maxsort = sort {$a <=> $b} @maxf;
       # my $max4relabel
        `rm -rf $n/labelled`;
        `mkdir $n/labelled`;
        my $pro_value;
        for my $m (0..$#maxsort){#find the proper value
            my $tempf = $maxsort[$m];
               # print "## $m: $tempf\n";

            if($tempf > $lowerbound and $m <= $max4relabel){    
                $pro_value = $tempf;
            }
        }
        print "##Maxf to relabel (.lt.): $pro_value\n";
        ####begin relabelling
        for my $m (0..$#maxf){#original sequence
            my $tempf = $maxf[$m];
               # print "## $m: $tempf\n";
            if($tempf > $lowerbound and $tempf < $pro_value){    
               my $lmpfile = "lmp_$step[$m].cfg";
               `cp $n/lmp_output/$lmpfile $n/labelled/$lmpfile`
            }
        }


    }

}
else{
    print "###no nolabel.dat\n\n";
    my @temp = `find ./ -maxdepth 2 -mindepth 2 -type d -name "*" -exec readlink -f {} \\;|sort`;
    map { s/^\s+|\s+$//g; } @temp;
    my @nolabel;
    my $count = 0;
    for my $d (@temp){
        unless(-e "$d/labelled"){
            $count++;
            `touch nolabel.dat` if($count == 1);
            push @nolabel,$d;
            `echo $d >> nolabel.dat`;
        }
    }
    my $nolabelNo = @nolabel;
    unless($nolabelNo){
        print "all folders with labelled subfolders. No need to relabel.\n";
    }
    else{
        print "##Folders without labelled subfolders: $nolabelNo\n";
        print "\n\n!!!!!! PLEASE CHECK nolabel.dat and then conduct the same script again.\n";
    }
}
