#if you use old scripts not put labelled structures as validation dataset,
#you may use this one. Can only use once, becuase the structure of data paths will be changed!

use strict;
use warnings;
use lib '.';#assign pm dir for current dir
use all_settings;# package for all setting
use elements;# package for element information

use List::Util ("shuffle","max");

require './DFTout2npy_QE.pl';#QE output to npy files
require './dp_train.pl';
my $forkNo = 1;#modify in the future
my $pm = Parallel::ForkManager->new("$forkNo");

#load all settings first
my ($system_setting_hr,$dptrain_setting_hr,$npy_setting_hr,$lmp_setting_hr,$scf_setting_hr) = 
&all_settings::setting_hash();
my %system_setting = %{$system_setting_hr};
my %dptrain_setting = %{$dptrain_setting_hr};
my %npy_setting = %{$npy_setting_hr};
my %lmp_setting = %{$lmp_setting_hr};
my %scf_setting = %{$scf_setting_hr};
my $jobtype = $system_setting{jobtype};
my @allIniStr = @{$system_setting{allIniStr}};
my $currentPath = $system_setting{script_dir};
my $mainPath = $system_setting{main_dir};# main path of dpgen folder
my $force_upperbound = $system_setting{force_upperbound};
my $useFormationEnergy = $system_setting{useFormationEnergy};
my $doDFT4dpgen = $system_setting{doDFT4dpgen};#if no, collect all cfg files for DFT
my $doiniTrain = $system_setting{doiniTrain};#if no, collect all cfg files for DFT


my $ratio4val = $system_setting{ratio4val};

my @all_labels = `find -L $mainPath/all_npy -type d -name "label_0*"`;
map { s/^\s+|\s+$//g; } @all_labels;
print "\n\nThe following is to build validation dataset for labelled structures!\n";
sleep(1);
@all_labels = shuffle @all_labels;
my $labelNo = @all_labels;
my $label4val = floor($ratio4val * $labelNo);
print "All labelled structure Number: $labelNo\n";
print " labelled structure Number for validation: $label4val\n";
sleep(1);
for my $l (0..$label4val){
    print "$all_labels[$l]\n";
    system("mkdir -p $all_labels[$l]/val");
    system("mv $all_labels[$l]/*.* $all_labels[$l]/val/");
    #`cp -R $all_labels[$l]/set* $all_labels[$l]/val/`;
}