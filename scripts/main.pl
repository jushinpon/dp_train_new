=b
Perl version for degen. Developed by Prof. Shin-Pon Ju at NSYSU
usage: nohup perl main.pl &
and use tail -f nohup.out to check your output at the same time.
find the max forces of all qe sout file in decending sequence: 
grep "Max force" nohup.txt|awk '{print $NF}'|sort -nr

You need to check your deepmd-kit path (dp train and lmp) and QE path for slurm job submission
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;
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
my $ratio4val = $system_setting{ratio4val};# for labelled structures serving as validation

#make data files for all QE input files
if($jobtype eq "npy_only"){
    system("perl QEin2data.pl");
}
#check all QE input file setting
my @ref_QE = `egrep "etot_conv_thr|forc_conv_thr|pseudo_dir|ecutwfc|ecutrho" $currentPath/QE_script.in`;
chomp @ref_QE;
my %QE_keyRef;#make numeric values
my %QE_keyRefOri;#original string format for double precision
##make type.raw, masses.dat, and elements.dat
my @QE_in = `find -L $mainPath/initial -type f -name "*.in"`;#all QE input
chomp @QE_in;
for my $in (@QE_in){
    print "input: $in\n";
    my $path = `dirname $in`;
    my $filename = `basename $in`;
    $filename =~ s/\..*//g;
    chomp ($path,$filename);
    my $natom = `egrep nat $in`;#check atom number in QE input. atom number <=1 is not allowed
    chomp $natom;
    $natom =~ s/^\s+|\s+$//;#remove beginnig and end empty space
    $natom =~ /(\w+)\s*=\s*(.+)/;
    chomp ($1,$2);
    my $nat = $2;
    unless($2){
        print"\n***1. Atom number zero or empty in $in is not allowed.\n";
        print"###2. Please check your QE output file to have at least 2 atoms.\n\n";
        die;    
    }
    
    #if($2 <= 3){
    #    print"\n***1. Atom number (currently, nat = $2) in $in is not allowed. The nat value should be => 4.\n";
    #    print"###2. Please modify your current system to have at least 4 atoms and conduct the QE calculation again.\n\n";
    #    die;    
    #}
    #the element id for dpgen and can be used for assigning type id for data files 
    my @typemap = @{$dptrain_setting{type_map}};
    map { s/^\s+|\s+$//g; } @typemap;
    #for lammps type id
    my %ele2id = map { $typemap[$_] => $_ + 1  } 0 .. $#typemap;
    #modify all data files when merging all systems
    my $atom_types = @typemap;

    #get the corresponding element symbols with id sequence from QE input
    my @elem = `grep -v '^[[:space:]]*\$' $in|grep -A $nat "ATOMIC_POSITIONS [(|{]angstrom[)|}]"|grep -v "ATOMIC_POSITIONS [(|{]angstrom[)|}]"|grep -v -- '--'|awk '{print \$1}'`;
    map { s/^\s+|\s+$//g; } @elem; 
    my $elements = join(" ",@elem);
    open(FH, "> $path/elements.dat") or die $!;
    print FH $elements;
    close(FH);

    my @type_raw = map { $ele2id{$elem[$_]} - 1  } 0 .. $#elem;
    my $type_raw = join(" ",@type_raw);
    #print "$type_raw\n";
    open(FH, "> $path/type.raw") or die $!;
    print FH $type_raw;
    close(FH);
   #get masses for data files
    my $mass4data;
    my $masses_dat;
    my $counter = 1;
    for my $e (0..$#typemap) {        
        my $ele = $typemap[$e];
        my $mass = &elements::eleObj("$ele")->[2];
        $mass4data .= $e+1 . " $mass  \# $ele\n";           
        $masses_dat .= "$mass\n";           
    }
    chomp $mass4data;#move the new line for the last line
    chomp $masses_dat;#move the new line for the last line
    #print "$mass4data\n";
    #print "$masses_dat\n";
    open(FH, "> $path/masses.dat") or die $!;
    print FH $masses_dat;
    close(FH);
    #get cell
    my @lmp_cell = `cat $path/$filename.data|egrep "xlo|ylo|zlo|xy"`;#"[xlo|ylo|zlo|xy]"`;#|grep -v Atoms|grep -v -- '--'`;
    die "No cell information of $path/$filename.data for $in" unless(@lmp_cell);
    map { s/^\s+|\s+$//g; } @lmp_cell;
    unless($lmp_cell[3]){$lmp_cell[3] = "0.0000 0.0000 0.0000 xy xz yz";}
    my $lmp_cell = join("\n",@lmp_cell);
    chomp $lmp_cell;
    #print "\$lmp_cell: $lmp_cell\n end\n";
    #die; 

    #system("cat $in");
    my @lmp_coors = `cat $path/$filename.data|grep -v '^[[:space:]]*\$'|grep -A $nat Atoms|grep -v Atoms|grep -v -- '--'`;
    die "No $path/$filename.data for $in" unless(@lmp_coors);
    map { s/^\s+|\s+$//g; } @lmp_coors; 
    die "data coords number is not equal to elem symbol number in QE input\n"  if(@lmp_coors != @elem) ;
    #need use QE elem symbol to assign new lmp type id
     my $coords4data;
    for my $e (0..$#lmp_coors) {
        my @tempcoords = split (/\s+/,$lmp_coors[$e]);
        map { s/^\s+|\s+$//g; } @tempcoords;
        $tempcoords[1] = $ele2id{$elem[$e]} ;#change type id here!
        my $temp = join(" ",@tempcoords);
        $coords4data .= "$temp\n";      
    }
    chomp $coords4data;
    #print "$coords4data\n";
#    die;
# modify data file

my $here_doc =<<"END_MESSAGE";
# $in

$nat atoms
$atom_types atom types

$lmp_cell

Masses

$mass4data

Atoms  # atomic

$coords4data
END_MESSAGE

    open(FH, "> $path/$filename.data") or die $!;
    print FH $here_doc;
    close(FH);
    
}

#if($onlyfinal_dptrain eq "yes") {goto final_dptrain;}
#make all required folders and slurm files for training
if($jobtype eq "dp_train"){
    &all_settings::create_required();
}

if($jobtype eq "npy_only"){# a brand new dpgen job. No previous labeled npy files exist
    print "\n\n#***Doing initial npy convertion\n";
    `rm -rf $mainPath/all_npy`;
    `rm -rf ../npy_conversion_info`;

    `mkdir -p $mainPath/all_npy`;
    `mkdir -p $mainPath/npy_conversion_info`;
    open(SK, "> $mainPath/npy_conversion_info/skipped_sout.dat") or die $!;
    print SK "##The following info presents the files with atomic force, virial, or energy over the upper or below the lower bound (check all_settings.pm)!\n\n";
    close(SK);

    open(UD, "> $mainPath/npy_conversion_info/used_sout.dat") or die $!;
    print UD "##The following info shows the files with proper atomic force, virial, and energy (check all_settings.pm)!\n\n";
    close(UD);

    #the following loop also check the required files in the corresponding folder
   # my $pm = Parallel::ForkManager->new("2");
    my $str_counter = 1;
    for my $str (@allIniStr){
    #    $pm->start and next;
        
        chomp $str;
        $npy_setting{inistr_dir}  = "$mainPath/initial/$str";
        $npy_setting{npyout_dir}  = "$mainPath/all_npy/initial/$str";
        #print "$str $npy_setting{npyout_dir}\n";    
        $npy_setting{dftsout_dir}  = "$mainPath/initial/$str";
    # check filenames 
        my $dataname =`ls $mainPath/initial/$str/$str.data`;#check data file name
        die "No $str.data in $mainPath/initial/$str\n" unless($dataname);
        my $QEname =`ls $mainPath/initial/$str/$str.in`;#check data file name
        die "No $str.in (QE input) in $mainPath/initial/$str\n" unless($QEname);
        my $QEout =`ls $mainPath/initial/$str/$str.sout`;#check data file name
        die "No $str.sout (QE output) in $mainPath/initial/$str\n" unless($QEout);
        
    #check element symbol
        my $elements =`cat $mainPath/initial/$str/elements.dat|egrep -v "#|^\$"`;#get element types of all atoms
        $elements  =~ s/^\s+|\s+$//;#remove beginnig and end empty space
	    my @elements = split (/\s+/,$elements);#id -> element type
        die "No atoms in the elements.dat for $mainPath/initial/$str\n" unless(@elements);

        my $atom_num =  @elements;#total atom number
        my %unique = map { $_ => 1 } @elements;#remove duplicate ones
        my @used_element = keys %unique;
        my $ntype = @used_element; # totoal element type
        #########################     elements.pm       #####################
        my %used_element;
        for (@used_element){
            chomp;
             #density (g/cm3), arrangement, mass, lat a , lat c
            @{$used_element{$_}} = &elements::eleObj("$_");
        }    
        if($useFormationEnergy eq "yes"){
            my @BE_all = `cat $npy_setting{inistr_dir}/dpE2expE.dat|grep -v "#"|awk '{print \$3}'`;
            die "no dpE2expE.dat in $npy_setting{inistr_dir}\n" unless (@BE_all);
            chomp @BE_all;
            $npy_setting{dftBE} = $BE_all[0];#summation of dft binding energies of all atoms
            $npy_setting{expBE} = $BE_all[1];#summation of exp binding energies of all atoms
            &DFTout2npy_QE(\%system_setting,\%npy_setting);#send settings for getting npy
        }
        else{
            $npy_setting{dftBE} = 0.0;#not used
            $npy_setting{expBE} = 0.0;#not used
            print "\n***Current npy conversion progress: $str_counter/".@allIniStr."\n";
            &DFTout2npy_QE(\%system_setting,\%npy_setting);#send settings for getting npy
            $str_counter++;
        }
    #    $pm-> finish;
    }
    #$pm->wait_all_children;
    print "\n\n****Only do the npy convertion for data in the initial folder.\n";
    print "You need to check files in $mainPath/npy_conversion_info to see".
    " if you are satisfied with your skipped QE sout files.\n";
    print "\n**Checking if any npy case is bad now\n";
    my @npy = ("energy","virial","force","coord","box");
    my @all_set = `find $mainPath/all_npy*  -type d -name "set*"`;#all npy set folders
    map { s/^\s+|\s+$//g; } @all_set;
    for my $i (@all_set){
        my $temp = `dirname $i`;
        $temp =~ s/^\s+|\s+$//g;
        die "No type.raw in $temp\n" unless(-e "$temp/type.raw");

        for my $n (@npy){
            die "No $n.npy in $i\n" unless(-e "$i/$n.npy");
        }
    }
    #begin to prepare validation dataset for labelled structures
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
    for my $l (0.. $label4val - 1){
        print "$all_labels[$l]\n";
        system("mkdir -p $all_labels[$l]/val");
        system("mv $all_labels[$l]/*.* $all_labels[$l]/val/");
        #`cp -R $all_labels[$l]/set* $all_labels[$l]/val/`;
    }
    print "**All npy related files are ready for training\n";
}
elsif($jobtype eq "dp_train"){# old npy files exist
    print "\n**Checking if any npy related files are good for training process\n";
    my @npy = ("energy","virial","force","coord","box");
    my @all_set = `find $mainPath/all_npy*  -type d -name "set*"`;#all npy set folders
    map { s/^\s+|\s+$//g; } @all_set;
    for my $i (@all_set){
        my $temp = `dirname $i`;
        $temp =~ s/^\s+|\s+$//g;
        die "No type.raw in $temp\n" unless(-e "$temp/type.raw");

        for my $n (@npy){
            die "No $n.npy in $i\n" unless(-e "$i/$n.npy");
        }
    }
    print "**All npy related files are ready for training\n";
    print "training process starts!!\n";
    
    my @allnpys = `find $mainPath/all_npy*  -type f -name "*.npy"`;
    map { s/^\s+|\s+$//g; } @allnpys;
    my %allnpyfolders;
    for (@allnpys){
        my $temp =  `dirname $_`;
        $temp =~ s/^\s+|\s+$//g;
        my $temp1 =  `dirname $temp`;
        $temp1 =~ s/^\s+|\s+$//g;
        $allnpyfolders{$temp1} = 1;
    }
    my @extraFolders = sort keys %allnpyfolders;

    #my @extraFolders = `find $mainPath/all_npy* -maxdepth 2 -mindepth 2 -type d -name "*"`;#all npy files
    chomp @extraFolders;
    die "no npy files in  $mainPath/all_npy* folders\n" unless(@extraFolders);
    #
    $dptrain_setting{allnpy_dir} = [@extraFolders];
    my $trainNo = $system_setting{trainNo};
    &dp_train(\%system_setting,\%dptrain_setting);
}
else{
    die "wrong jobtype setting in all_settings.pm\n";
}

print "perl main.pl for jobtype = \"$jobtype\" done!\n";




