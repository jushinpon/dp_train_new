use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;
use lib '.';#assign pm dir for current dir
use all_settings;# package for all setting

#load all settings first
my ($system_setting_hr,$dptrain_setting_hr,$npy_setting_hr,$lmp_setting_hr,$scf_setting_hr) = 
&all_settings::setting_hash();
my %system_setting = %{$system_setting_hr};
my %dptrain_setting = %{$dptrain_setting_hr};

my $currentPath = $system_setting{script_dir};
my $mainPath = $system_setting{main_dir};# main path of dpgen folder
my $debug = "yes";
#my $trainNo = $system_setting{trainNo};#could be found later.
my $working_dir = $dptrain_setting{working_dir};#training folder
my $npydir4matplot = "$mainPath/matplot";
my $npy_dirs = "$mainPath/all_npy*";#you may use your dir, under which all npy files are included.

`rm -rf $mainPath/matplot`;
`mkdir $mainPath/matplot`;
#keep data files
`rm -rf $mainPath/matplot_data`;
`mkdir $mainPath/matplot_data`;
###arrange npy files

my @temp = `find $npy_dirs -type d -name "set.*"`;#all npy files in set folders.
die "no npy files under set folders in all_npy* folders\n" unless(@temp);
map { s/^\s+|\s+$//g; } @temp;

print "\n**Checking if any npy case is bad now\n";
my @npy = ("energy","virial","force","coord","box");
my @all_set = @temp;#all npy set folders
map { s/^\s+|\s+$//g; } @all_set;
for my $i (@all_set){
    my $temp = `dirname $i`;
    $temp =~ s/^\s+|\s+$//g;
    die "No type.raw in $temp\n" unless(-e "$temp/type.raw");
    for my $n (@npy){
        die "No $n.npy in $i\n" unless(-e "$i/$n.npy");
    }
}
print "**All npy related files are ready for making plot files\n";

my @allnpy_temp; # dirs with all set.XXX folders
for (0..$#temp){
    my $temp = `dirname $temp[$_]`;
    $temp =~ s/^\s+|\s+$//g;
    $allnpy_temp[$_] = $temp;
}

my %temp = map {$_ => 1} @allnpy_temp;
my @allnpy = sort keys %temp; # dirs with all set.XXX folders
map { s/^\s+|\s+$//g; } @allnpy;
my $allnpyNo = @allnpy;
#for (0..$#allnpy){
#    print "$_: $allnpy[$_]\n";
#}
#
my @allnpy4train;
my @allnpy4valid;
#
##keep the information of training and validation data
`rm -f $mainPath/matplot/train_dir.txt`; 
`rm -f $mainPath/matplot/valid_dir.txt`; 
`touch $mainPath/matplot/train_dir.txt`; 
`touch $mainPath/matplot/valid_dir.txt`;
##
for (@allnpy){
    chomp;
    if(/.+\/val$/){
        push @allnpy4valid, $_;#npy for validation
        `echo $_ >> $mainPath/matplot/valid_dir.txt`;
    }
    else{
        push @allnpy4train, $_;#npy for training
        `echo $_ >> $mainPath/matplot/train_dir.txt`;
    }
}
die "No val npy files for validation\n" unless(@allnpy4valid);
die "No trainning npy files\n" unless(@allnpy4train);
#
my $train_dir = "$npydir4matplot/train_npy";#collect all training npys
my $validation_dir = "$npydir4matplot/validation_npy";
#
`rm -rf $train_dir`;
`mkdir -p $train_dir`;
`rm -rf $validation_dir`;
`mkdir -p $validation_dir`;

for (0..$#allnpy4train){#copy training npy files
    chomp;
    chomp $allnpy4train[$_];
    my @temp = `find $allnpy4train[$_] -maxdepth 1 -type d -name "set.*"`;#all npy files
    map { s/^\s+|\s+$//g; } @temp;
    for my $t (@temp){#folder name with set
        $t =~ /.+set\.(.+)$/;
        chomp $1;
        #print "\$1: $1\n";
        `mkdir -p $train_dir/$_/$1`;
        `cp -r $t $train_dir/$_/$1`;
        `cp  $allnpy4train[$_]/type.raw $train_dir/$_/$1`;
        `cp  $allnpy4train[$_]/box.raw$1 $train_dir/$_/$1/box.raw`;
        `cp  $allnpy4train[$_]/coord.raw$1 $train_dir/$_/$1/coord.raw`;
        `cp  $allnpy4train[$_]/energy.raw$1 $train_dir/$_/$1/energy.raw`;
        `cp  $allnpy4train[$_]/force.raw$1 $train_dir/$_/$1/force.raw`;
    }
}


for (0..$#allnpy4valid){#copy validation npy files
    chomp;
    `mkdir -p $validation_dir/$_`;
    `cp -r $allnpy4valid[$_] $validation_dir/$_`;
}
my @pb_files = `find $mainPath/dp_train -type f -name "*.pb"`;#all npy files
my @pb_folders = `find $mainPath/dp_train -type d -name "graph*"`;#all graphxx folders
map { s/^\s+|\s+$//g; } @pb_files;
map { s/^\s+|\s+$//g; } @pb_folders;
my $trainNo = @pb_files;
if($trainNo != @pb_folders){
    print "pb files need to be completed:".@pb_folders."\n";
    print "completed pb files: $trainNo.\n";
    die "dp train not completed!\n Be patient!\n";
}
#$trainNo = 1;
print "training number: $trainNo\n";
#make plots
my @make_plots = ("train","validation");
#my $pm = Parallel::ForkManager->new("$trainNo");
for (1..$trainNo){
#    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    #`rm ./lcurve.out`;#remove old lcurve.out in current dir 
    `cp  $mainPath/dp_train/graph$temp/lcurve.out ./`;#for loss profiles
    `cp  $mainPath/dp_train/graph$temp/lcurve.out $mainPath/matplot_data/lcurve-graph$temp.out`;#for raw data

    for (0..$#make_plots){#train and validation
        #`rm ./temp.*.out`;#remove old dp test output files in current dir 
        #`rm ./tempmod.*.out`;#remove old dp test output files in current dir 
       
        #the following for check pred. and ref. data distributions for energy, force, and virial 
        my $source = "$npydir4matplot/$make_plots[$_]"."_npy";
        my @num = `find -L $source -type f -name energy.raw`; 
        map { s/^\s+|\s+$//g; } @num;
        my $dataNu = 0;
        for my $s (@num){
           # print "$s\n";
            my @lines = `grep -v '^[[:space:]]*\$' $s`;
            $dataNu += @lines;
        }
        print "**\$dataNu: $dataNu\n";
        #system("bash -c 'source /opt/anaconda3/bin/activate deepmd-cpu'");
        if(-e "/opt/anaconda3/bin/activate"){
            system("bash -c 'source /opt/anaconda3/bin/activate deepmd-cpu;dp test -n $dataNu -m $mainPath/dp_train/graph$temp/graph$temp.pb -s $source -d ./temp.out -v 0 2>&1 >/dev/null'");
        }
        else{
            system("bash -c 'source /opt/miniconda3/bin/activate deepmd-cpu;dp test -n $dataNu -m $mainPath/dp_train/graph$temp/graph$temp.pb -s $source -d ./temp.out -v 0 2>&1 >/dev/null'");
        }#system("dp test -n $dataNu -m $mainPath/dp_train/graph$temp/graph$temp.pb -s $source -d ./temp.out -v 0 2>&1 >/dev/null");

# get atom number for normalizing energy
        `cp  ./temp.e.out $mainPath/matplot_data/$make_plots[$_]-Oritemp.e-graph$temp.out`;#for raw data
        `cp  ./temp.f.out $mainPath/matplot_data/$make_plots[$_]-temp.f-graph$temp.out`;#for raw data
        `cp  ./temp.v.out $mainPath/matplot_data/$make_plots[$_]-temp.v-graph$temp.out`;#for raw data

        `mv ./temp.e.out ./tempmod.e.out`;# for the following touch temp.e.out
        #check the required minimum number 
        my @temp = `grep "#" ./tempmod.e.out|awk '{print \$2}'`;
        die "No energy listed in temp.e.out after dp test" unless(@temp);
        map { s/^\s+|\s+$//g; } @temp;
        my $energyNo = @temp;
        if($energyNo == 1){
            print "Currently, only one reference energy in temp.e.out after dp test",
            " python script doesn't work if the energy number is 1. No png file is plotted.\n";
            last;
        }

        my @npypath = map {$_ =~ s/:$//g; $_;} @temp;#remove ":"
        die "no npy dirs for matplot\n" unless(@npypath);
        #chomp @npypath;
        my @atomNo;
        for my $npath (@npypath){
            #$_ =~ s/:$//g;
            #print "path: $_\n";
            my @temp = `cat $npath/coord.raw`;#get how many frames in this raw
            map { s/^\s+|\s+$//g; } @temp;
            for my $nu (@temp){
                $nu  =~ s/^\s+|\s+$//;
                my @sp = split(/\s+/,$nu);
                map { s/^\s+|\s+$//g; } @sp;
                my $num = @sp/3;
                push @atomNo,$num;
            }
        }
        my @tempdata = `grep -v "#" ./tempmod.e.out`;
        map { s/^\s+|\s+$//g; } @tempdata;
        my @data = grep (($_!~m{^\s*$|^#}),@tempdata); # remove blank elements
        my $dataNo = @data;
        my $atomarrayNo = @atomNo;
        die "the data number and atom number array are not equal\n" if($dataNo != $atomarrayNo);
        `touch ./temp.e.out`;
        for my $dt (0..$#data){
            $data[$dt]  =~ s/^\s+|\s+$//;
            #print "\$data[\$dt]: $data[$dt]\n";
            my @temp = split(/\s+/,$data[$dt]);
            chomp @temp;
            #print "dt: $dt, $temp[0] $temp[1]\n";
            $temp[0] = $temp[0]/$atomNo[$dt];
            $temp[1] = $temp[1]/$atomNo[$dt];
            #chmop @temp;
            `echo "$temp[0] $temp[1]" >> ./temp.e.out`;
        }
        `cp  ./temp.e.out $mainPath/matplot_data/$make_plots[$_]-temp.e-graph$temp.out`;#for raw data

# end of energy normalization
        if(-e "/opt/anaconda3/bin/activate"){
            system ("bash -c 'source /opt/anaconda3/bin/activate base;python dp_plots.py'");
        }
        else{
            system ("bash -c 'source /opt/miniconda3/bin/activate base;python dp_plots.py'");
        }
        sleep(1);
        `mv ./dp_temp.png $mainPath/matplot/00$make_plots[$_]-graph$temp.png`;    
    }#train and validation loops
#    $pm-> finish;
}
#$pm->wait_all_children;

##housekeeping
#`rm ./lcurve.out`;#remove old lcurve.out in current dir 
#`rm ./temp.*.out`;#remove old dp test output files in current dir
#`rm ./tempmod.*.out`;#remove old dp test output files in current dir

#/dp_train/graph01/lcurve.out;
#
#cp ../dp_train/graph01/lcurve.out
#`rm -f test0503*`;
#system("source activate deepmd-cpu;dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot -d test0503.out");
#`python plot_e.py`;
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/all_npysoft  -d testnew.out
##
##dp test -m /home/jsp/Perl4dpgen/dp_train/graph01/graph01.pb -s /home/jsp/Perl4dpgen/matplot  -d testnew.out

