use warnings;
use strict;

#for initial folder
my @all_inifolder;
#!!! make the following if you have place everything in the initial folder
@all_inifolder= qw(
    /home/ben/dpgen/perl4dpgen_standalone-virial/initial_test
);
my $sour = "/home/ben/dpgen/perl4dpgen_standalone-virial/initial_test";
my $des = "/home/ben/dpgen/perl4dpgen_standalone-virial/initial_test_picked";
`rm -rf /home/ben/dpgen/perl4dpgen_standalone-virial/initial_test_picked`;#if you have old files in initial, you may mark this line.
`mkdir /home/ben/dpgen/perl4dpgen_standalone-virial/initial_test_picked`;
map { s/^\s+|\s+$//g; } @all_inifolder;

##make softlink for initial 
my @all_ini;
for (@all_inifolder){
    my @temp = `find $_ -mindepth 1 -maxdepth 1 -type d `;
    map { s/^\s+|\s+$//g; } @temp;
    @all_ini = (@all_ini,@temp);
}

#my @all_ini = `find ../initial -type f -name "*.sout"`;
map { s/^\s+|\s+$//g; } @all_ini;
my $counter = 0;
for my $i (@all_ini){#all subfolder paths having sout and in files
    
    my @fileNu = `find $i -mindepth 1 -maxdepth 1 -type f -name *.sout`;
    map { s/^\s+|\s+$//g; } @fileNu;
       
    if (@fileNu > 1){#if more than 1 sout file
        #my $dirname = `dirname $i`;
        #$dirname =~ s/^\s+|\s+$//g;
        
        for my $j (@fileNu){# full path of a sout file.
            my $basename = `basename $j`;
            $basename =~ s/^\s+|\s+$//g;
            $basename =~ s/\.sout//g;

            print "\n\n****path: $i\n";
            print "file j: $j\n";
            #print "dirname: $dirname\n ";
            print "basename: $basename\n ";
            #`rm -rf $des/$basename`;
            my $index ="$basename"."_". sprintf("%07d",$counter);
            `rm -rf $sour/$index`;
            `mkdir $sour/$index`;
            `cp $i/$basename.in $sour/$index/$index.in`; 
            `cp $i/$basename.sout $sour/$index/$index.sout`;
            $counter++; 
        }  

        `mv $i $des`;      
    }    
    
}

##make softlink for all labelled folders
#if($include_labelled eq "yes"){
#    my @good_labelled;
#    for (@all_labelled){
#        my @temp = `find $_ -name labelled -type d `;
#        map { s/^\s+|\s+$//g; } @temp;
#        for my $i (@temp){
#            unless(`ls $i`){
#                print "empty: $i\n";
#            }
#            else{
#                push @good_labelled, $i;
#            }
#        }
#    }
#
#    open(FH, "> ./npy_files_path.dat") or die $!;
#    print FH "#Original_path --> path in the initial folder\n";  
#    my $counter = 0;
#    for my $i (@good_labelled){    
#        my @temp = `find $i -name "*.sout" -type f `;
#        #my @temp_in = `find $i -name "*.in" -type f `;
#        #my @temp_data = `find $i -name "*.data" -type f `;
#        map { s/^\s+|\s+$//g; } @temp;
#
#        for my $j (@temp){ 
#            my $basename = `basename $j`;
#            my $dirname = `dirname $j`;
#            $basename =~ s/^\s+|\s+$//g;
#            $dirname =~ s/^\s+|\s+$//g;
#            $basename =~ s/\.sout//g;
#
#            #print "path: $j\n";  
#            #print "$dirname\n";  
#            #print "$basename\n";  
#            my $index ="label_". sprintf("%07d",$counter);
#            #print "index:$index\n";   
#            `rm -rf ../initial/$index`;
#            `mkdir ../initial/$index`;
#            `cp $i/$basename.sout ../initial/$index/$index.sout`;
#            `cp $i/$basename.in ../initial/$index/$index.in`;
#            #`cp $i/$basename.data ../initial/$index/$index.data`;
#            print FH "$i/$basename.sout --> ../initial/$index/$index.sout\n";
#            $counter++;
#        }
#    }
#  close(FH);
#}