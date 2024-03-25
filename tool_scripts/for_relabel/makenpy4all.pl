=b
makenpy files for all sout files.
Only good for scf.
perl ../tool_scripts/makenpy4all.pl 
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

my $set_No = 5;#How many raw data number to make a set
my $currentPath = getcwd();# dir for all scripts
chdir("..");
my $mainPath = getcwd();# main path of Perl4dpgen dir
chdir("$currentPath");

#for QE convertion
my $ry2eV = 13.605684958731;
my $bohr2ang = 0.52917721067;
my $bohr2ang3 = 0.14818471127;
my $kbar2bar = 1000;#000.;
my $kbar2evperang3 = 1.0/ (160.21766208*10.0);
my $force_convert = $ry2eV / $bohr2ang;
my $cal_type = "scf";#all considered qe output
my $force_cri = 7;#criterion to filter proper sout files for training,1.5*your matplot range
my $virial_cri = 15;#criterion to filter proper sout files for training,1.5*your matplot range

my $forkNo = 1;#although we don't have so many cores, only for submitting jobs into slurm
my $pm = Parallel::ForkManager->new("$forkNo");

my @oldraw = `find ./ -type f -name "*.raw" -exec readlink -f {} \\;`;
for my $i (@oldraw){`rm -f $i`;}

my @oldnpy = `find ./ -type f -name "*.npy" -exec readlink -f {} \\;`;
for my $i (@oldnpy){`rm -f $i`;}

my @allsout_temp = `find ./ -type f -name "*.sout" -exec readlink -f {} \\;`;
map { s/^\s+|\s+$//g; } @allsout_temp;
my @allsout;
my $total_file;
my $good_file;
for (@allsout_temp){
	$total_file++;
	my $natom1 = `grep 'number of atoms/cell' $_ |awk '{print \$NF+1}'`;
	chomp $natom1;#atom number + 1 (for including space line in qe output)
	my @forcetemp = `grep -A $natom1 "Forces acting on atoms (cartesian axes, Ry/au):" $_`;#`grep -A 3 "total   stress" $out[$id]`
	my @force = grep {if(m/^.+force =\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)\s+([-+]?\d+\.?\d+)/){
			$_ = [$1*$force_convert,$2*$force_convert,$3*$force_convert];}} @forcetemp;
	
	my $index = 1;
    for my $fr  (0..$#force){
		my @temp = @{$force[$fr]};
		map { s/^\s+|\s+$//g; } @temp;
		for my $f (@temp){
			if(abs($f) > $force_cri){
				#print "####$_\n";
				#print "The abs force of $fr + 1 atom is larger than $force_cri eV/A in $_\n";
				#print "force: $f\n";
				$index = 0;
			}
		} 
	}# end of force evaluation

	#begin virial evaluation
    #unit-cell volume          =    1476.9024 (a.u.)^3

	my $cellVol = `grep "unit-cell volume" $_|awk '{print \$4*$bohr2ang3}'`;
    chomp $cellVol;
	my $convert = $kbar2evperang3*$cellVol;
	my @totalstress = `grep -A 3 "total   stress" $_|grep -v "total   stress"|grep -v -- '--'|awk '{print \$(NF-2)*$convert " "\$(NF-1)*$convert " "\$NF*$convert}'`;
	map { s/^\s+|\s+$//g; } @totalstress;
	for my $st (@totalstress){
		my @temp = split(/\s+/,$st);
		for my $s (@temp){
			chomp $s;
			if(abs($s) > $virial_cri){
				#print "The abs virial is larger than $virial_cri in $_\n";				
				#print "stress: $s\n";
				$index = 0;				
			}
		}

	}
	
	my @jobdone = `grep "JOB DONE" $_`;
	$index = 0 unless(@jobdone);#if no JOB DONE
	my @scf_problem = `grep "convergence NOT achieved after" $_`;#|grep "convergence NOT achieved after"`;	
	$index = 0 if(@scf_problem);
	if($index){
		$good_file++;
		push @allsout,$_;
	};
}

my $percent = ($good_file/$total_file)*100;

print "\n\n** All sout No.: $total_file\n";
print "** good sout No. under force and virial criterions: $good_file\n";
print "** percentage under force and virial criterions for all sout files:". sprintf("%.2f",$percent)."%\n";
sleep(3);
#print "@allsout\n";
#die;
my %str;#get the same structure for key and make an array for collecting related sout files
for my $s (@allsout){
    $s =~ m#.+/T\d+-P\d+-R\d+-(.+)/labelled/lmp_\d+.sout#;    
    push @{$str{$1}},$s;
}

my @npy = ("energy","virial","force","coord","box");


`rm -rf $currentPath/all_npy_cfgs`;#remove old data
`mkdir -p $currentPath/all_npy_cfgs/str`;

for my $k (sort keys %str){#
    #print "***$k\n";
	my $inistr_dir = "$mainPath/initial/$k";#type.raw in initial path
    #make npy path
	my $npyout_dir = "$currentPath/all_npy_cfgs/str/$k";
	`rm -rf $npyout_dir`;
	`mkdir -p $npyout_dir`;

    my @out = @{$str{$k}};
    my @dftin;
	#get all qe input files
    for my $s (@out){
        my $basename = `basename $s`;
        my $dirname = `dirname $s`;
        $basename =~ s/\.sout//g;
        chomp ($dirname,$basename);
        my $in = "$dirname/$basename\.in";
        my $ls = `ls $in`;
        #print "$dirname,$basename,$in\n";
        die "No $dirname/$basename.in\n" unless($ls);
        push @dftin,"$in";
    }

    my $outNo = @out;
    my $inNo = @dftin;
    die "The number of QE input and sout files are not equal !!!\n" if($inNo != $outNo);
    	
    my @eraw;#energy.npy
    my @vraw;#virial.npy need to check further!!!
    my @fraw;#force.npy
    my @craw;#coord.npy
    my @braw;#box.npy
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
	    next if(@scf_problem);#skip this sout if not converaged!!

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
	    $cal_type1[0] =~ /\s*calculation\s*=\s*["|'](.+)["|']/;#must use array
	    #chomp $1;
	    my $cal_type1 = $1;
        chomp $cal_type1;
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
	    	#print "Current calculation type: $cal_type, keyword: \"$temp[0]\" \n";
    
	    }
	    else{
	    	print "Current calculation type: $cal_type\n";
	    }	
		################# energy ############
		##!    total energy              =    (-158.01049803) Ry
		#the first energy corresponds to the structure in input file
		my @totalenergy;
	    @totalenergy = grep {if(m/^\s*!\s*total energy\s*=\s*([-+]?\d*\.?\d*)/){
	    $_ = $1*$ry2eV;}} @all;
        unless (@totalenergy){
	    	print "no total energy was found in $out[$id] or dft calculation failed!!\n";
	        next;
	    }

        for (@totalenergy){chomp;push @eraw,$_}
	    $energyNo = @totalenergy;

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
		# we need the first one for scf,and vc-relax needs the second one, which is 
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
			for my $idf1 ($temp..$temp + $natom -1){
				@temp = (@temp,@{$force[$idf1]}[0..2]);#three elements to merger
			}
			chomp @temp;
			my $tempNo = @temp/3;
			# print "\$tempNo:$tempNo,". scalar(@temp) ."\n";
			die "force set number of a frame is not equal to atom number in $out[$id]\n" if ($natom != $tempNo);
			push @fraw,[@temp];
		}

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
	}#loop over all sout files for a %str key

	######converting npy

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
			die "the rows in $npy[$f].raw are different from those of energy.raw in $npyout_dir \n";
		}
	}
	
	#making groups for prefix set
	#$set_No = 19;
	my $groupNo;
	$groupNo = floor($enNo/$set_No);
	#print "\n#####Warning!!!The set.XXX number is fewer than 4. Current $groupNo, and better to use a smaller number for \$set_No in all_setting.pm (ok for labeled data)\n" if ($groupNo <= 3);
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



}#loop over a str hash key (collect all related sout files)

print "\n#### All Done ####\n";