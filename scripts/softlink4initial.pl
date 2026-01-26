use warnings;
use strict;

`rm -rf ../initial`;#if you have old files in initial, you may mark this line.
`mkdir ../initial`;

open(BAD, "> ./bad_files_checkbysoftlink.dat") or die $!;
print BAD "#The following files are bad and filtered by softlink4initial.pl\n"; 
#####make link for labelled folders

#for setting scaleID range, you need to check your scale script settings.
#original setting are too wide, you may narrow them down to a real tensile and compessive strain range.
#vol from 0.95 to 1.05
#for length range 0.95**(1./3.) and 1.05**(1./3.).
# for orignal deform script settings, -0.25 to 0.25 is too wide. (21 scaled structures)
#if you only use scaleID from $scaleID_lowerBound to $scaleID_upperBound 
my $scaleID_lowerBound = -1;
my $scaleID_upperBound = 30;

my $include_labelled = "no";#if yes, you need to provide parent paths of your labelled folders (@all_labelled) 
my @all_labelled;
if($include_labelled eq "yes"){
    @all_labelled = qw(
        
    );
    map { s/^\s+|\s+$//g; } @all_labelled;
}

#for initial folder
my @all_inifolder;
#!!! make the following if you have place everything in the initial folder (don't put dimer results here)
@all_inifolder= qw(    
   /home/jsp1/HEA_10elements/categorized_UMA/*/  
);

map { s/^\s+|\s+$//g; } @all_inifolder;
#put your dimer folders here if you have
my @all_dimerfolder;
@all_dimerfolder= qw(    
   
);
map { s/^\s+|\s+$//g; } @all_dimerfolder;

my @dimer_pairs;
print BAD "\n#Part1: files in original initial folder (md or vc-md is allowed!)\n"; 

for my $i (@all_dimerfolder){
    my @temp_folders = `find $i -mindepth 1 -maxdepth 1 -type d `;
    map { s/^\s+|\s+$//g; } @temp_folders;
    for my $j (@temp_folders){
        #filter out some bad dimer results (atractive one)!
        my @temp = split(/\//,$j);
        $temp[-1] =~ m/(.*)_(dimer\d\d)/;
        #print "dimer pair: $1 and $2\n";

        my $file = "$j/$temp[-1].sout";

        my $jobdone = `grep "JOB DONE" $j/$temp[-1].sout`;
        $jobdone =~ s/^\s+|\s+$//g;

        unless($jobdone){
            print BAD "No \"JOB DONE\" for dimer cases: $j/$temp[-1].sout\n";
            next;
        }
        open my $fh, "-|", "grep", "-A", "3", "Forces acting on atoms (cartesian axes, Ry/au):", $file
            or die "Cannot open grep: $!";
        my @forcetemp = grep { !/Forces acting on atoms/ && !/--/ && !/^\s*$/ } <$fh>;
        close $fh;
#      #my @forcetemp = `grep -A 2 \"Forces acting on atoms (cartesian axes, Ry/au):\ $i/$temp[-1].sout|grep -v \"Forces acting on atoms\"|grep -v \"--\"`;
        map { s/^\s+|\s+$//g; } @forcetemp;
        my $join_forces = join("\n", @forcetemp);
       # print "dimer forces:\n$join_forces\n";
        my @forces_values = split(/\s+/, $forcetemp[0]);
        #print "dimer forces values: $forces_values[6]\n";
        if($forces_values[6] > 0.0){
            print BAD "dimer_atractive folder skipped: $j/$temp[-1].sout\n";
            next;
        }

       push @dimer_pairs, $j;
    }
}



 #/home/jsp1/AlP/QE_from_MatCld/QEall_set/
    #/home/jsp1/AlP/QE4heat/softlink4training/
    #/home/jsp1/AlP/from195/

##make softlink for initial 

#filter out some bad ini folders
my @all_ini;
for (@all_inifolder){
    my @temp = `find $_ -mindepth 1 -maxdepth 1 -type d `;
    map { s/^\s+|\s+$//g; } @temp;
    @all_ini = (@all_ini,@temp);
}

@all_ini = (@all_ini,@dimer_pairs);

#my @all_ini = `find ../initial -type f -name "*.sout"`;
map { s/^\s+|\s+$//g; } @all_ini;
for my $i (@all_ini){
    my @temp = split(/\//,$i);
    
    my $relax = `grep -e relax -e vc-relax $i/$temp[-1].in`;
       $relax =~ s/^\s+|\s+$//g;
    
    my $scf = `grep calculation $i/$temp[-1].in | grep scf`;
       $scf =~ s/^\s+|\s+$//g;

    my $nonCon = `grep "convergence NOT achieved" $i/$temp[-1].sout`;
       $nonCon =~ s/^\s+|\s+$//g;

    my $jobdone = `grep "JOB DONE" $i/$temp[-1].sout`;
       $jobdone =~ s/^\s+|\s+$//g;
    #filter scaleID
    if($temp[-1] =~ m|scale_\dd_(.*)|){
        my $scaleID = $1;
        print "scaleID:$scaleID\n";
        if( ($scaleID < $scaleID_lowerBound) or ($scaleID > $scaleID_upperBound) ){
            print BAD "**scaleID $scaleID out of range: $i/$temp[-1].sout\n";
            next;
        }
    }

       #if($nonCon){
       #     print "ini convergence NOT achieved: $i/$temp[-1].sout\n";
       #    
       # }
    
    if($scf){
        my @stresses = `grep "total   stress"  $i/$temp[-1].sout`;
        map { s/^\s+|\s+$//g; } @stresses;
        if (@stresses > 1){
            print BAD "bad scf output: $i/$temp[-1].sout\n";
            next;
        }
    }

       #convergence NOT achieved
    if (!($relax =~ m/relax/) and ($jobdone =~ m/JOB DONE/) and !($nonCon =~ m/convergence NOT achieved/)){   
        `mkdir ../initial/$temp[-1]`;        
        `ln -s $i/$temp[-1].in ../initial/$temp[-1]/$temp[-1].in`; 
        `ln -s $i/$temp[-1].sout ../initial/$temp[-1]/$temp[-1].sout`; 
        #`ln -s $i/$temp[-1].data ../initial/$temp[-1]/$temp[-1].data`;   
    }
    elsif(!($jobdone =~ m/JOB DONE/)){
        print BAD "No \"JOB DONE\": $i/$temp[-1].sout\n";
    }
    elsif($nonCon =~ m/convergence NOT achieved/ and $jobdone =~ m/JOB DONE/){
        print BAD "\"convergence NOT achieved with JOB DONE\": $i/$temp[-1].sout\n";
    }
    elsif($relax =~ m/relax/){
        print BAD "\"relax or vc-relax (not used for DLP)\": $i/$temp[-1].sout\n";
    }
    else{
        print BAD "\nOther errors (need to check!)\": $i/$temp[-1].sout\n";
    }
   # if($nonCon){
   #    print "ini convergence NOT achieved: $i/$temp[-1].sout\n";
   #    die;
   # }
}

##make softlink for all labelled folders
if($include_labelled eq "yes"){
    my @good_labelled;
    print BAD "\n\n#Part2: files in labelled folders (scf)\n"; 

    for (@all_labelled){
        my @temp = `find $_ -name labelled -type d `;
        map { s/^\s+|\s+$//g; } @temp;
        for my $i (@temp){
            unless(`ls $i`){
                print "empty: $i\n";
                print BAD "empty folder: $i\n";
            }
            else{
                push @good_labelled, $i;
            }
        }
    }

    open(FH, "> ./npy_files_path.dat") or die $!;
    print FH "#Original_path --> path in the initial folder\n";  
    my $counter = 0;
    for my $i (@good_labelled){    
        my @temp = `find $i -name "*.sout" -type f `;
        #my @temp_in = `find $i -name "*.in" -type f `;
        #my @temp_data = `find $i -name "*.data" -type f `;
        map { s/^\s+|\s+$//g; } @temp;

        for my $j (@temp){ 
            my $basename = `basename $j`;
            my $dirname = `dirname $j`;
            $basename =~ s/^\s+|\s+$//g;
            $dirname =~ s/^\s+|\s+$//g;
            $basename =~ s/\.sout//g;

            #print "path: $j\n";  
            #print "$dirname\n";  
            #print "$basename\n";  
            my $index ="label_". sprintf("%07d",$counter);
            #print "index:$index\n";
            my $relax = `grep -e relax -e vc-relax $i/$basename.sout`;
                $relax =~ s/^\s+|\s+$//g;

            my $nonCon = `grep "convergence NOT achieved" $i/$basename.sout`;
               $nonCon =~ s/^\s+|\s+$//g;
               #if($nonCon){
               #      print "convergence NOT achieved: $i/$basename.sout\n";
               #    print "$nonCon\n";              
               # }

            my $jobdone = `grep "JOB DONE" $i/$basename.sout`;
               $jobdone =~ s/^\s+|\s+$//g;
            
            # some strange output!     
            my @stresses = `grep "total   stress"  $i/$basename.sout`;
            map { s/^\s+|\s+$//g; } @stresses;
            if (@stresses > 1){
                print BAD "bad scf output: $i/$basename.sout\n";
                next;
            }

            if (!($relax =~ m/relax/) and ($jobdone =~ m/JOB DONE/) and !($nonCon =~ m/convergence NOT achieved/) ){   
                    `mkdir ../initial/$index`;
                    `cp $i/$basename.sout ../initial/$index/$index.sout`;
                    `cp $i/$basename.in ../initial/$index/$index.in`;
                    #`cp $i/$basename.data ../initial/$index/$index.data`;
                    print FH "$i/$basename.sout --> ../initial/$index/$index.sout\n";
                    $counter++;
                }
                elsif(!($jobdone =~ m/JOB DONE/) ){
                    print BAD "No \"JOB DONE\": $i/$basename.sout\n";
                }
                elsif($nonCon =~ m/convergence NOT achieved/ and $jobdone =~ m/JOB DONE/){
                    print BAD "\"convergence NOT achieved with JOB DONE\": $i/$basename.sout\n";
                }
                elsif($relax =~ m/relax/){
                    print BAD "\"relax or vc-relax (not used for DLP)\": $i/$basename.sout\n";
                }
                else{
                    print BAD "\nOther errors (need to check!)\": $i/$basename.sout\n";
                }

               # if($nonCon){
               #      print "convergence NOT achieved: $i/$basename.sout\n";
               #    print "$nonCon\n"; 
               #    die "final die\n" ;             
               # }

        }
    }
  close(FH);
}
close(BAD);