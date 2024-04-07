use warnings;
use strict;

`rm -rf ../initial`;#if you have old files in initial, you may mark this line.
`mkdir ../initial`;
open(BAD, "> ./bad_files_checkbysoftlink.dat") or die $!;
print BAD "#The following files are bad and filtered by softlink4initial.pl\n"; 
#####make link for labelled folders
my $include_labelled = "no";#if yes, you need to provide parent paths of your labelled folders (@all_labelled) 
my @all_labelled;
if($include_labelled eq "yes"){
    @all_labelled = qw(
        /home/ben/dpgen/new_allnpy05/all_cfgs/
        /home/ben/dpgen/new-2_allnpy06/all_cfgs/
        /home/ben/dpgen/new-3_allnpy07/all_cfgs/
        /home/ben/dpgen/new-4_allnpy08/all_cfgs/
        /home/ben/dpgen/new-5_allnpy09/all_cfgs/
        /home/ben/dpgen/new-6_allnpy10/all_cfgs/
        /home/ben/dpgen/tension_label_allnpy11/all_cfgs/
        /home/ben/dpgen/tension_label-2_allnpy12/all_cfgs/
        /home/ben/dpgen/heating-1_allnpy13/all_cfgs/
        /home/ben/dpgen/heating-2_allnpy14/all_cfgs/
    );
    map { s/^\s+|\s+$//g; } @all_labelled;
}

#for initial folder
my @all_inifolder;
#!!! make the following if you have place everything in the initial folder
@all_inifolder= qw(
    /home/jsp1/test/perl4dpgen_20221025/initial
);
map { s/^\s+|\s+$//g; } @all_inifolder;

##make softlink for initial 
print BAD "\n#Part1: files in original initial folder (md or vc-md is allowed!)\n"; 

my @all_ini;
for (@all_inifolder){
    my @temp = `find $_ -mindepth 1 -maxdepth 1 -type d `;
    map { s/^\s+|\s+$//g; } @temp;
    @all_ini = (@all_ini,@temp);
}

#my @all_ini = `find ../initial -type f -name "*.sout"`;
map { s/^\s+|\s+$//g; } @all_ini;
for my $i (@all_ini){
    my @temp = split(/\//,$i);
    
    my $relax = `grep -e relax -e vc-relax $i/$temp[-1].in`;
       $relax =~ s/^\s+|\s+$//g;
    
    my $nonCon = `grep "convergence NOT achieved" $i/$temp[-1].sout`;
       $nonCon =~ s/^\s+|\s+$//g;

    my $jobdone = `grep "JOB DONE" $i/$temp[-1].sout`;
       $jobdone =~ s/^\s+|\s+$//g;
       #if($nonCon){
       #     print "ini convergence NOT achieved: $i/$temp[-1].sout\n";
       #    
       # }
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