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
use List::Util qw/shuffle/;

my $submitJobs = "yes";#only check how many labelled cfg files, then decide how 

#for your sh file
my %sbatch_para = (
            nodes => 1,#how many nodes for your qe job
            ntasks_per_node => 12,
            partition => "debug",#which partition you want to use
            pwPath => "/opt/QEGCC_MPICH4.0.3/bin/pw.x", #qe executable          
            mpiPath => "/opt/mpich-4.0.3/bin/mpiexec" #mpipath          
            );
#my $onlyCheckcfgNumber = "no";#only check how many labelled cfg files, then decide how 
#many you want to use for DFT,
## maxmium number for dft input files to create, set a super large number for selecting all 
#my $maxDFTfiles = 30;

my $currentPath = getcwd();# dir for all scripts
chdir("..");
my $mainPath = getcwd();# main path of Perl4dpgen dir
chdir("$currentPath");

my $forkNo = 1;#although we don't have so many cores, only for submitting jobs into slurm
my $pm = Parallel::ForkManager->new("$forkNo");
#remove all old qe input file first
#my @old_in = `find ./ -type f -name "*.in" -exec readlink -f {} \\;`;
#
#die;

#you may use relabel script to increase more labelled folders if needed
my @oldsh = `find ./ -type f -name "*.sh" -exec readlink -f {} \\;|sort`;
for my $i (@oldsh){`rm -f $i`;}

my @oldsout = `find ./ -type f -name "*.sout" -exec readlink -f {} \\;|sort`;
for my $i (@oldsout){`rm -f $i`;}

my @allQEin = `find ./ -type f -name "*.in" -exec readlink -f {} \\;|sort`;
map { s/^\s+|\s+$//g; } @allQEin;
#my @pathOfAllcfgs;
my $jobNo = 0;
for my $i (@allQEin){
    #print "$dir\n";
    my $basename = `basename $i`;
    my $dirname = `dirname $i`;
    $basename =~ s/\.in//g; 
    chomp ($basename,$dirname);
    `rm -f $dirname/$basename.sh`;
    $jobNo++;
my $here_doc =<<"END_MESSAGE";
#!/bin/sh
#SBATCH --output=$basename.sout
#SBATCH --job-name=Job$jobNo
#SBATCH --nodes=$sbatch_para{nodes}
#SBATCH --ntasks-per-node=$sbatch_para{ntasks_per_node}
#SBATCH --partition=$sbatch_para{partition}
export LD_LIBRARY_PATH=/opt/mpich-4.0.3/lib:\$LD_LIBRARY_PATH
export PATH=/opt/mpich-4.0.3/bin:\$PATH
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries_2018.0.128/linux/mkl/lib/intel64_lin:\$LD_LIBRARY_PATH

$sbatch_para{mpiPath} $sbatch_para{pwPath} -in $basename.in
rm -rf pwscf.save
sleep 60
END_MESSAGE
    #chomp $here_doc;
    #print "$here_doc";
    open(FH, "> $dirname/$basename.sh") or die $!;
    print FH $here_doc;
    close(FH);
    if($submitJobs eq "yes"){
        chdir($dirname);
        `sbatch $basename.sh`;
        chdir($currentPath);
    }    
}#  

