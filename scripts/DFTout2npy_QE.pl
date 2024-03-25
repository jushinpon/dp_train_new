=b
unit comvertion:
http://greif.geo.berkeley.edu/~driver/conversions.html
Usage: perl DFTout2npy.pl 
This script is for QE only
For vc-md: viral with momentum contribution cannot be used for virial.npy, so dropped
For scf:
For vc-relax (relax): only the last energy, forces, virial can be used. 
!    total energy 
unit-cell volume
=cut
use warnings;
use strict;
use Data::Dumper;
use Cwd;
use POSIX;
use List::Util ("shuffle","max");

sub DFTout2npy_QE{

my ($ss_hr,$npy_hr) = @_;#recive hash reference for setting
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my $ratio4val = $ss_hr->{ratio4val};#should assign dynamically
my $useFormationEnergy = $ss_hr->{useFormationEnergy};
my $force_upperbound = $ss_hr->{force_upperbound};
my $dftBE_all = $npy_hr->{dftBE};
my $expBE_be = $npy_hr->{expBE};
my $npyout_dir =$npy_hr->{npyout_dir};#store raw and set folders
my $sout_dir = $npy_hr->{dftsout_dir};#DFT sout
open(SK, ">> $mainPath/npy_conversion_info/skipped_sout.dat") or die $!;
#close(SK);

open(UD, ">> $mainPath/npy_conversion_info/used_sout.dat") or die $!;
#close(UD);
#for QE convertion
my $ry2eV = 13.605684958731;
my $bohr2ang = 0.52917721067;
my $bohr2ang3 = 0.14818471127;
my $kbar2bar = 1000;#000.;
my $kbar2evperang3 = 1.0/ (160.21766208*10.0);
my $force_convert = $ry2eV / $bohr2ang;
#print "\$sout_dir: $sout_dir\n";
my @out = <$sout_dir/*.sout>;# all DFT output files through slurm
die "No DFT sout file in $npy_hr->{dftsout_dir}\n" unless(@out);
my @dftin = <$sout_dir/*.in>;# all DFT input files

die "No DFT input file in $npy_hr->{dftsout_dir}\n" unless(@out);
#prefix should be the same
@out = sort @out;
@dftin = sort @dftin;

my $outNo = @out;
my $inNo = @dftin;
die "The number of QE input and sout files are not equal !!!\n" if($inNo != $outNo);

for my $id (0..$#out){
	my $in = `basename $dftin[$id]`;
	chomp $in;
	$in =~ s/^\s+|\s+$//;
	$in =~ /(.*)\.\w+/;
	#print "$in $1\n";
	my $pre_in = $1;
	
	my $out = `basename $out[$id]`;
	chomp $out;
	$out =~ s/^\s+|\s+$//;
	$out =~ /(.*)\.\w+/;
	#print "$out $1\n";
	my $pre_out = $1;	
	die "The prefixes of in and corresponding sout files must be the same. Currently, $out[$id] and $dftin[$id] have been checked.\n",
	 if($pre_out ne $pre_in);
}

#check calculation type to decide which data can be
chomp  $dftin[0];
my @cal_type = `grep calculation $dftin[0]`;#|grep "calculation"`;	
chomp @cal_type;
$cal_type[0] =~ /\s*calculation\s*=\s*["|'](.+)["|']/;#must use array
#$cal_type[0] =~ /\s*calculation\s*=\s*"(.+)"/;#must use array
chomp $1;
my $cal_type = $1;
die "no calculation type in $dftin[0]\n" unless($cal_type);
#die "only support 1 QE input file currently" if($inNo != 1);
#die "only support 1 QE output file currently" if($outNo != 1);

#!check ibrave later

# The following five arrays are used for collecting data from all sout files
my @eraw;#energy.npy
my @vraw;#virial.npy need to check further!!!
my @fraw;#force.npy
my @craw;#coord.npy
my @braw;#box.npy

my @npy = ("energy","virial","force","coord","box");
#vc-MD, MD: virial npy is not used
#vc-relax: only the last one scf can be used for all npy files

my %raw_ref = (
energy => \@eraw,
virial => \@vraw,
force => \@fraw,
coord => \@craw,
box => \@braw
);
my $energyNo;# use it to check all data rows of npy files. They should be identical
for my $id (0..$#out){
	chomp $id;
	print "**current file: $out[$id]\n"; 

	#loop over all sout files in the following:
	#check whether SCF problem exists!
	chomp  $dftin[$id];
	my @scf_problem = `grep "convergence NOT achieved after" $out[$id]`;#|grep "convergence NOT achieved after"`;	
	die "You have SCF convergence problem in the DFT sout file, $out[$id]!!!\n" if(@scf_problem);

	#     number of atoms/cell      =           16
	###******from type.raw
	my @natom = `cat $out[$id]|sed -n '/number of atoms\\/cell/p'|awk '{print \$5}'`;	
	#@natom could more than 1 for vc-relax,so the array should be used
	#my $natom = `grep  "number of atoms/cell" $out[0]|awk '{print \$5}'`;#|sed -n '/number of atoms\\/cell/p'|awk '{print \$5}'`;	
	my $natom = $natom[0];#must use array for `` output in Perl
	chomp $natom;
	#print "\$natom:$natom\n";
	die "You don't get the Atom Number in the DFT sout file, $out[$id]!!!\n" unless($natom);
	my $nat = `cat $dftin[$id]|sed -n '/nat =/p'|awk '{print \$3}'`;	
	chomp $nat;
	#print "\$nat:$nat\n";
	#my $ndiff = $natom - $nat;
	die "You don't get the Atom Number in the DFT input file, $dftin[$id]!!!\n" unless($nat);
	die "the Atom Number in the DFT sout ($out[$id]) and dftin ($dftin[$id]) files are not the same or no dft input file!!!\n" if($natom != $nat);
	
	#check calculation type to decide which data can be
	chomp  $dftin[$id];
	my @cal_type1 = `grep calculation $dftin[$id]`;#|grep "calculation"`;	
	chomp @cal_type1;
	$cal_type1[0] =~ /\s*calculation\s*=\s*"(.+)"/;#must use array
	chomp $1;
	my $cal_type1 = $1;
	die "no calculation type in $dftin[$id]\n" unless($cal_type);
    die "the calculation types of all input files are not the same! the same calculation types should be used in a folder\n",
	if($cal_type1 ne $cal_type);

	open my $all ,"< $out[$id]";
	my @all = <$all>;
	close($all);

	if ($cal_type eq "vc-relax" or $cal_type eq "relax"){
		my @temp = grep m/End of BFGS Geometry Optimization/, @all;
		die "\nThe vc-relax (or relax) in $out[$id] hasn't been done (no 'End of BFGS Geometry Optimization')! no data can be used for npy files.
	You need to do vc-relax (or relax) with a larger nstep value or drop this case by modifying all_setting.pm!\n" unless (@temp);
		chomp @temp;
		$temp[0] =~ s/^\s+|\s+$//;
		print "Current calculation type: $cal_type, keyword: \"$temp[0]\" \n";
		
	}
	else{
		print "Current calculation type: $cal_type\n";
	}	
################# energy ############
##!    total energy              =    (-158.01049803) Ry
#the first energy corresponds to the structure in input file
	my @totalenergy;
	if($useFormationEnergy eq "yes"){
		@totalenergy = grep {if(m/^\s*!\s*total energy\s*=\s*([-+]?\d*\.?\d*)/){
		$_ = $1*$ry2eV - $dftBE_all + $expBE_be;}} @all;
	}
	else{
		@totalenergy = grep {if(m/^\s*!\s*total energy\s*=\s*([-+]?\d*\.?\d*)/){
		$_ = $1*$ry2eV;}} @all;
	}

	#my	$lmpE = (($totE - $sumDFTatomE) + $sumLMPatomE) / $atomnumber; #use in MS perl
    unless (@totalenergy){
		print "no total energy was found in $out[$id] or dft calculation failed!!\n";
	    return
	}
    for (@totalenergy){chomp;push @eraw,$_}
	$energyNo = @totalenergy;
	#for (1..@eraw){my $id = $_ -1; print "$id $eraw[$id]\n";}

# get system volume for virial (in unit of eV)
# new unit-cell volume =   1707.20246 a.u.^3 (   252.98130 Ang^3 )	only for vc-relax
# 0 for scf and relax, mainly for vc-relax and vc-md
	my @newcellVol = grep {if(m/^\s+new unit-cell volume.+\(\s+(.+)\s+Ang\^3\s+\)/){$_ = $1;}} @all;
    chomp @newcellVol;

# unit-cell volume =   1707.20246 a.u.^3
# 1 for scf, relax, and md, 2 for vc-relax (if done)  	
	my @cellVol = grep {if(m/^\s+unit-cell volume\s+=\s+(.+)\s+\(a.u.\)\^3/){$_=$1*$bohr2ang3;}} @all;
    chomp @cellVol;
	
	if ($cal_type eq "vc-relax"){
       my $temp = @cellVol; 
	die "There is no final scf in $out[$id] (after 'End of BFGS Geometry Optimization')! no data can be used for npy files.
You need to do vc-relax, scf or drop this case by modifying all_setting.pm!\n" if ($temp != 2);
	
	my @jobdone = grep m/JOB DONE./, @all;#grep m/JOB DONE./ @all;
	#print "\@jobdone: @jobdone\n";
	die "last scf failed in $out[$id] for vc-relax, you need to fix this problem" unless(@jobdone);
	}
# we need the first one for scf, vc-relax needs the second one, which is 
# equal to the last one of @newcellVol.		

###virial (kbar)  three data for each line
#   0.00000058  -0.00000001  -0.00000003            (0.09)       (-0.00)       (-0.00)
	my @totalstress = `grep -A 3 "total   stress" $out[$id]`;
	#system("grep -n -A3 \"total   stress\" $out[$id]");
	chomp @totalstress; 
	my @virial;
	#for (0..$#totalstress){print "$_,$totalstress[$_]\n"; }
	
	my $vol_counter = 0;
	for (@totalstress){#for scf, only 3 items. For vc-relax or relax, could be more than 3
	  my $temp = int ($vol_counter/3);
		if(m/^\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+[-+]?\d+\.?\d+\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			if($temp == 0 or $cal_type eq "relax" or $cal_type eq "md"){#for relax and scf, only $cellVol[0] exists, which comes from in file 
			    #For vc-relax and vc-md, @cellVol keeps the initial volume value (the same as in file)
				
				push @virial, [$1*$kbar2evperang3*$cellVol[0],$2*$kbar2evperang3*$cellVol[0],$3*$kbar2evperang3*$cellVol[0]];
	  			$vol_counter++;
			}
			else{
				push @virial, [$1*$kbar2evperang3*$newcellVol[$temp - 1],$2*$kbar2evperang3*$newcellVol[$temp - 1],$3*$kbar2evperang3*$newcellVol[$temp - 1]];
				$vol_counter++;
			}  
			
	  }
	}

	die "no virial was found in $out[$id]\n" unless (@virial);
    my $virtalNo = @virial/3;
	die "virial set number is not equal to energy number in $out[$id]\n" if ($energyNo != $virtalNo);

	for my $idv (1..@virial/3){#@virial has three elements
		my $temp = ($idv -1) * 3;
		chomp (@{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]);
		#print "$idv: @{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]\n";
		push   @vraw, [@{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]];
	}
	#for (1..@vraw){my $id = $_ -1; print "$id: @{$vraw[$id]}\n";}

############## force ############   #Ry/au
#  Forces acting on atoms (cartesian axes, Ry/au):

#     atom    1 type  1   force =    -0.00000604   -0.00000000   -0.00000604
    my $natom1 = $natom + 1; #a blank line after the pattern 
	my @forcetemp = `grep -A $natom1 "Forces acting on atoms (cartesian axes, Ry/au):" $out[$id]`;#`grep -A 3 "total   stress" $out[$id]`
	my @force = grep {if(m/^.+force =\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			$_ = [$1*$force_convert,$2*$force_convert,$3*$force_convert];}} @forcetemp;
    my $forceNo = @force/$natom;# frame number
	die "force set number $forceNo is not equal to energy number in $out[$id]\n" if ($energyNo != $forceNo);
	
	for my $idf (1..@force/$natom){# loop over frames
		#print "$_ @{$force[$_ -1]}[0..2]\n";
		my $temp = ($idf - 1) * $natom;# beginning id of each force set for a frame 
		my @temp; #collecting all forces of a frame
		for my $idf1 ($temp..$temp + $natom -1){#loop over atom id of each frame
			@temp = (@temp,@{$force[$idf1]}[0..2]);#three elements to merge
			if(max(map abs($_), @{$force[$idf1]}[0..2]) > $force_upperbound){
				my @tempf = @{$force[$idf1]}[0..2];
				my @Ryf = map{$_/$force_convert;} @tempf;
				my $atomid = $idf1 - $temp + 1;
				print SK "In file: $out[$id]\n";
				print SK "x,y, and z forces of atom $atomid:\n";
				print SK "@tempf in eV/A\n";
				print SK "@Ryf in Ry/Au\n\n";
				close(SK);
				return;
			}
		}
		chomp @temp;
		my $tempNo = @temp/3;
		# print "\$tempNo:$tempNo,". scalar(@temp) ."\n";
		die "force set number of a frame is not equal to atom number in $out[$id]\n" if ($natom != $tempNo);
		push @fraw,[@temp];
	}
	my @allforces;
	#print "input: $dftin[$id]\n";
	for my $i (1..@fraw){
		my $id = $i -1;
		@allforces = (@allforces,@{$fraw[$id]});
	}
	my $maxforce = sprintf("%.6f",max(map abs($_), @allforces));
	print UD "**current file: $out[$id]\n"; 
	print "Max force (eV/A): $maxforce\n";
	print UD "Max force (eV/A): $maxforce\n";
	
############## coord ############
##ATOMIC_POSITIONS (angstrom)        
##Al           -0.0000004209       -0.0000004098       -0.0000002490
#ATOMIC_POSITIONS {angstrom} for input file
	my @coord1 = `grep -A $natom "ATOMIC_POSITIONS {angstrom}" $dftin[$id]`;
	my @coord2 = `grep -A $natom "ATOMIC_POSITIONS (angstrom)" $out[$id]`;
	my @coord = (@coord1,@coord2);
	chomp @coord;
	my @tempcoord;
	for(@coord){
		chomp;
		#print "$_\n";
		#if(m/^\w+\s+([-+]?\d+\.?\d*)\s+([-+]?\d+\.?\d*)\s+([-+]?\d+\.?\d*)/){
		if(m/^\w+\s+([-+]?\d+\.?\d*e?[+-]?\d*)\s+([-+]?\d+\.?\d*e?[+-]?\d*)\s+([-+]?\d+\.?\d*e?[+-]?\d*)/){
			#print "**$_\n";
			push @tempcoord, [$1,$2,$3];
		}	
	}
    die "no coord was found in $out[$id]\n" unless (@tempcoord);
	#for (0..$#tempcoord){print "$_:$tempcoord[$_]\n";}
	my $tempcoord = @tempcoord/$natom;
	#MD has 1 more coord set number than energy number
	die "coord set number $tempcoord is fewer than the energy number $energyNo in $out[$id] !\n" if ($tempcoord < $energyNo);

	for my $idc (1..@tempcoord/$natom){#@virial has three elements
		my $temp = ($idc - 1) * $natom;# beginning id of each force set for a frame 
		my @temp; #collecting all forces of a frame
		for my $idc1 ($temp.. $temp + $natom -1){
			@temp = (@temp,@{$tempcoord[$idc1]}[0..2]);#three elements to merger
		}
		chomp @temp;
		my $tempNo = @temp/3;
		# print "\$tempNo:$tempNo,". scalar(@temp) ."\n";
		die "coor set number $tempNo of a frame is not equal to atom number $natom in $out[$id]\n" if ($natom != $tempNo);
		push @craw,[@temp];
	}
	#print "$tempcoord > $energyNo\n";
	#die;
	if($tempcoord > $energyNo){ pop @craw;} # for MD, the last one is useless. 
	#for (1..@craw){my $id = $_ -1; print "$id: @{$craw[$id]}\n";}
############### box ############
###CELL_PARAMETERS (angstrom)
###4.031848986   0.000000009   0.000000208
#    my @elem = `grep -v '^[[:space:]]*\$' $in|grep -A $nat "ATOMIC_POSITIONS [(|{]angstrom[)|}]"|grep -v "ATOMIC_POSITIONS [(|{]angstrom[)|}]"|grep -v -- '--'|awk '{print \$1}'`;
    my @CellVec1 = `grep -v '^[[:space:]]*\$' $dftin[$id]|grep -A 3 "CELL_PARAMETERS {angstrom}"|grep -v "CELL_PARAMETERS {angstrom}"|grep -v -- '--'`;
	map { s/^\s+|\s+$//g; } @CellVec1;
	#print "\@CellVec1: @CellVec1\n";
	#die;
	#my @CellVec1 = `grep -A 3 "CELL_PARAMETERS {angstrom}" $dftin[$id]`;
	my @CellVec2 = '';#mainly get cell information from sout 

	if($cal_type eq "vc-relax" or $cal_type eq "vc-md"){
		@CellVec2 = `grep -v '^[[:space:]]*\$' $out[$id]|grep -A 3 "CELL_PARAMETERS [(|{]angstrom[)|}]"|grep -v "CELL_PARAMETERS [(|{]angstrom[)|}]"|grep -v -- '--'`;
		#grep -A 3 "CELL_PARAMETERS (angstrom)" $out[$id]`;#no data for md and relax.
		map { s/^\s+|\s+$//g; } @CellVec2;
	}
	elsif($cal_type eq "relax" or $cal_type eq "md"){#no cell data in sout
		for my $cid (1..$energyNo-1){#first cell info has been put in @CellVec1
			my $id = ($cid -1)*3;
			#for my $row (0..2){
			$CellVec2[$id] = $CellVec1[0];
			$CellVec2[$id+1] = $CellVec1[1];
			$CellVec2[$id+2] = $CellVec1[2];
		}
	}
	my @CellVec = (@CellVec1,@CellVec2);
	#die;
	chomp @CellVec; 
	my @cell;
	for (@CellVec){
	  if(m/^\s*([-+]?\d+\.?\d*e?[+-]?\d*)\s+([-+]?\d+\.?\d*e?[+-]?\d*)\s+([-+]?\d+\.?\d*e?[+-]?\d*)/){
			push @cell, [$1,$2,$3];
	  }	
	}    
    die "no cell vector was found in $out[$id]\n" unless (@cell);
    my $cellNo = @cell/3;
	#MD has one more
	if($cal_type ne "relax"){#for relax, only cell information can be found in QE in file 
		die "cell vector set number $cellNo is fewer than the energy number $energyNo in $out[$id]\n" if ($energyNo > $cellNo);
	}
	
	for my $idc (1..@cell/3){#@virial has three elements
		my $temp = ($idc -1) * 3;
		chomp (@{$cell[$temp]}[0..2],@{$cell[$temp + 1]}[0..2],@{$cell[$temp + 2]}[0..2]);
		#print "$idv: @{$virial[$temp]}[0..2],@{$virial[$temp + 1]}[0..2],@{$virial[$temp + 2]}[0..2]\n";
		push   @braw, [@{$cell[$temp]}[0..2],@{$cell[$temp + 1]}[0..2],@{$cell[$temp + 2]}[0..2]];
	}

	if ($energyNo < $cellNo){pop @braw;} # for MD, the last one is useless.
}

#shuffling all raw arraies

my @ref_id = (0..$energyNo - 1);
@ref_id = shuffle @ref_id;#all npy files need use the same shuffled ids

for my $f (@npy){#loop over all npy types
    my @raw;	
	for my $d (0..$#ref_id){
		my $tempid = $ref_id[$d];
		$raw[$d] = ${$raw_ref{$f}}[$tempid];
		#print "$d: $tempid,$raw[$d],".${$raw_ref{$f}}[$tempid]."\n";			
	}
	@{ $raw_ref{$f} } = @raw;
}

#make folder when all are good.
my $inistr_dir = $npy_hr->{inistr_dir}; 
`mkdir -p $npyout_dir`;
`cp $inistr_dir/type.raw $npyout_dir/type.raw`;
#print "\$npyout_dir: $npyout_dir\n";
#die;
for my $f (@npy){
	my $filepath = "$npyout_dir/$f.raw";
	open my $t ,">$filepath";
    my @raw = @{ $raw_ref{$f} };
	#print "\n***$f\n";
	if ($cal_type eq "vc-relax" or $cal_type eq "relax"){#ONLY NEED THE LAST ONES
		
			my $r = $raw[-1];
			if ($f eq "energy"){
				chomp $r;
				print $t "$r";
				print $t "\n"; 
		    }
			else{
				chomp @{$r};
				print $t "@{$r}";# dereference
				print $t "\n"; 
			}

	}
	else{	
		for my $id (0..$#raw){
			my $r = $raw[$id];
			if ($f eq "energy"){
				chomp $r;
				print $t "$r";
				print $t "\n" unless($id == $#raw); 
		    }
			else{
				chomp @{$r};
				print $t "@{$r}";# dereference
				print $t "\n" unless($id == $#raw); 
			}
		}
	}

	close($t);
}
my @tempNo = `cat $npyout_dir/$npy[0].raw`;#total new line symbol number
my $enNo = @tempNo;
#print "\$enNo: $enNo\n";
#die;
#my $enNo = `cat $npyout_dir/$npy[0].raw|wc -l`;#total new line symbol number
for my $f (1..$#npy){
	my @temp = `cat $npyout_dir/$npy[$f].raw`;
	my $temp = @temp;
	if ($temp != $enNo){
		print "$enNo $temp\n";
		die "the rows in $npy[$f].raw are different from those of energy.raw for $npy_hr->{dftsout_dir}\n";
	}
}

#making groups for prefix set
#$set_No = 19;
my $groupNo;
#if(!$enNo%$set_No){
my $set_No = floor($ratio4val * $enNo);	
if($set_No == 0){$set_No = 100000;}#let groupNo = 0 if enNo is not enough
$groupNo = floor($enNo/$set_No);
print "\n#####Warning!!!The set.XXX number is fewer than 4. Current $groupNo, and better to use a smaller number for \$set_No in all_setting.pm (ok for labeled data)\n" if ($groupNo <= 3);
#}
#else{
#	$groupNo = floor($enNo/$set_No) + 1;
#}
#print "$enNo,$set_No, $groupNo\n";
for my $f (0..$#npy){
	my @temp = `cat $npyout_dir/$npy[$f].raw`;
	map { s/^\s+|\s+$//g; } @temp;
	if($groupNo > 2){
		for my $g (0..$groupNo-1){
			my $setID = sprintf("%03d",$g);
			my $startid = $g * $set_No;
			my $endid = ($g + 1) * $set_No - 1;
			$endid = $#temp if($g == $groupNo-1);#last set group could have more
			chomp $setID;
			my $filepath = "$npyout_dir/$npy[$f].raw$setID";
			open my $t ,">$filepath";
			for my $i ($startid..$endid){
				print $t "$temp[$i]\n";# dereference
				#print $t "\n" unless($i == $#raw);
			} 
			close($t);
		}
	}
	else{
		my $setID = sprintf("%03d",0);#$groupNo = 0
		system("cp $npyout_dir/$npy[$f].raw $npyout_dir/$npy[$f].raw$setID");
	}	
}

#print $enNo;
if($groupNo > 2){
	for my $s (0..$groupNo-1){
		my $setID = sprintf("%03d",$s);#only 0 is enough
		my $npyset;
		#if($s == $groupNo-1){+
		#	$npyset = "valset.000";#for validation
		#}
		#else{
			$npyset = "set.$setID";
		#}
		`rm -rf $npyout_dir/$npyset`;
		`mkdir -p $npyout_dir/$npyset`;
		`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/box.raw$setID"   , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/box",    data)'`;
		`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/coord.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/coord",  data)'`;
		`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/energy.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/energy",  data)'`;
		`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/force.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/force",  data)'`;

		#if($cal_type ne "md" and $cal_type ne "vc-md"){#kinetic energy contribution is insignificant
		`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/virial.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/virial",  data)'`;
		if($s == $groupNo-1){
			`rm -rf $npyout_dir/val`;
			`mkdir -p $npyout_dir/val`;
			`cp $npyout_dir/type.raw $npyout_dir/val/ `;
			`mv $npyout_dir/box.raw$setID $npyout_dir/val/box.raw `;
			`mv $npyout_dir/coord.raw$setID $npyout_dir/val/coord.raw `;
			`mv $npyout_dir/energy.raw$setID $npyout_dir/val/energy.raw `;
			`mv $npyout_dir/force.raw$setID $npyout_dir/val/force.raw `;
			`mv $npyout_dir/virial.raw$setID $npyout_dir/val/virial.raw `;
			`mv $npyout_dir/$npyset $npyout_dir/val/ `;
		}
	}
}
else{
	my $setID = sprintf("%03d",0);#$groupNo = 0
	my $npyset;
	$npyset = "set.$setID";
	`rm -rf $npyout_dir/$npyset`;
	`mkdir -p $npyout_dir/$npyset`;
	`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/box.raw$setID"   , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/box",    data)'`;
	`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/coord.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/coord",  data)'`;
	`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/energy.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/energy",  data)'`;
	`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/force.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/force",  data)'`;
	`python -c 'import numpy as np; data = np.loadtxt("$npyout_dir/virial.raw$setID" , ndmin = 2); data = data.astype (np.float32); np.save ("$npyout_dir/$npyset/virial",  data)'`;
}  
#die; 
}# end sub
1;