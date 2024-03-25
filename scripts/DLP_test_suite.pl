#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use POSIX;
use List::Util qw/shuffle/;

###parameters to set first
##### The one you need to set only
my $testNo = 10;#the test structure number randomly picked from /initial/ (superlarge value for all,like 100000000)
######
my $lmp_exe = "/opt/lammps-mpich-4.0.3/lmpdeepmd";
my $currentPath = getcwd();
my $parent_path = `dirname $currentPath`;
$parent_path =~ s/^\s+|\s+$//g;
`rm -rf $parent_path/DLP_test`;#remove old data
`mkdir -p   $parent_path/DLP_test`;
my @datafile = `find -L $parent_path/initial -maxdepth 2 -mindepth 2 -type f -name "*.data"`;#find all data files to read by read_data in lmp scripts
map { s/^\s+|\s+$//g; } @datafile;
die "No data files\n" unless(@datafile);

#####DLP files
my @pb = `find $parent_path/dp_train -type f -name "*.pb"`;#DLP files
map { s/^\s+|\s+$//g; } @pb;
die "No DLP pb files\n" unless(@pb);

@datafile = shuffle @datafile;#all npy files need use the same shuffled ids
##get possible max number
my $max;
if($testNo > @datafile){
    $max = @datafile;
}
else{
    $max = $testNo;
}

my @lmp_path;#all paths of lmp scripts
for (0 .. $max -1){
    @pb = shuffle @pb;# shuffled pb ids, use the first element only
    my $datafile = $datafile[$_];
    my $dir = `dirname $datafile`;#get path
    $dir =~ s/^\s+|\s+$//g;
    my $filename =`basename $datafile`;#get path
    $filename =~ s/^\s+|\s+$//g;
    my $foldername = $filename;
    $foldername =~ s/\.data//g;
    `mkdir -p $parent_path/DLP_test/$foldername`;
    my $rand4vel = int(rand()*100000);
    my %lmp_para = (
           input_data => "$datafile",#data path
           output_script => "$parent_path/DLP_test/$foldername/$foldername.in",
           DLP => "$pb[0]",
           step => 50000, #step for NPT
           rand => $rand4vel
    );     
    &lmp_script(\%lmp_para);
    push @lmp_path,"$parent_path/DLP_test/$foldername/$foldername.in";
}#all data files
#making slurm file for conducting all lmp jobs
my @string = qq(
#!/bin/sh
#SBATCH --output=lmp4all.out
#SBATCH --job-name=DLP_test
#SBATCH --nodes=1
#SBATCH --partition=All
source activate deepmd-cpu
np=\$(nproc)
#export LD_LIBRARY_PATH=/opt/mpich-4.0.3/lib:\$LD_LIBRARY_PATH
#export PATH=/opt/mpich-4.0.3/bin:/opt/lammps-mpich-4.0.3:\$PATH
);

map { s/^\s+|\s+$//g; } @string;
my $string = join("\n",@string);

unlink "$parent_path/DLP_test/lmp4all.sh";
open(FH, '>', "$parent_path/DLP_test/lmp4all.sh") or die $!;
print FH "$string\n";

map { s/^\s+|\s+$//g; } @lmp_path;#all lmp in
for (@lmp_path){
    my $dir = `dirname $_`;
    my $file = `basename $_`;
    $dir =~ s/^\s+|\s+$//g;
    $file =~ s/^\s+|\s+$//g;
    print FH "cd $dir;mpiexec -np \$np lmp -in $file\n";
}

close(FH);

`cd $parent_path/DLP_test;sbatch lmp4all.sh`;
#####here doc for lmp in##########
sub lmp_script
{

my ($lmp_hr) = @_;

my $lmp_script = <<"END_MESSAGE";
print "Simulating $lmp_hr->{input_data}"
units metal 
dimension 3 
boundary p p p 
box tilt large
atom_style atomic 
atom_modify map array 
shell mkdir lmp_output
# ---------- input data to read --------------------- 
read_data $lmp_hr->{input_data}
replicate 2 2 2
variable timesize equal 0.002
variable temp equal 300
variable press equal 0.0
variable tdamp equal \${timesize}*100
variable pdamp equal \${timesize}*1000
timestep \${timesize}
# ---------- Define Interatomic Potential --------------------- 
pair_style deepmd $lmp_hr->{DLP}
pair_coeff * * 
#----------------------------------------------
neighbor 2.0 bin 
neigh_modify delay 10 every 5 check yes one 5000
#-----------------minimize---------------------
shell cd lmp_output
fix 5 all box/relax aniso 0.0
thermo 100
thermo_style custom step density pxx pyy pzz pe
dump 1 all custom 200 MIN_*.cfg id type x y z xu yu zu
minimize 1e-12 1e-12 20000 20000
unfix 5
undump 1
shell cd ..

write_data after_minimize.data

shell cd lmp_output
reset_timestep 0
velocity all create \${temp} $lmp_hr->{rand} mom yes rot yes dist gaussian
velocity all scale \${temp}

thermo 200
thermo_style custom step temp density pxx pyy pzz pe
#list headers first

print "step,temp,density,pxx,pyy,pzz,pe" file DLP.csv screen no
fix 1 all npt temp \${temp} \${temp} \${tdamp} aniso \${press} \${press} \${pdamp}
fix printdata all print 100 "\$(step),\$(temp),\$(density),\$(pxx),\$(pyy),\$(pzz),\$(pe)" append DLP.csv screen no

dump 1 all custom 200 NPT_*.cfg id type x y z xu yu zu
run $lmp_hr->{step}
unfix 1
unfix printdata
undump 1
shell cd ..

write_data after_NPT.data
print "End of simulating $lmp_hr->{input_data}"
print "ALL DONE!"
END_MESSAGE

#my $file = $lmp_hr->{output_script};
open(FH, '>', $lmp_hr->{output_script}) or die $!;
print FH $lmp_script;
close(FH);
}
