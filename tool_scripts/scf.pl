use strict;
use warnings;
use Cwd;
use JSON::PP;
use List::Util qw(min max);
use POSIX;
use lib '.';
use HEA;
use Expect;
use Data::Dumper;
my $currentPath = getcwd();
my $user = "zhi";

my $slurmbatch = "182.sh"; #slurm filename
my $QE_path = "/opt/QEGCC_MPICH3.4.2/bin/pw.x";
my $optbatch = "scf.in";
my $cif = "$currentPath/atomsk.cif";


my @myelement = sort ("Cr","Cu","Ni","Si","Zn");
my $myelement = join ('',@myelement);
my $types = @myelement;


#my $nstep = 100;
my $ibrav = 0;
my $cleanall = "no";
# my $kpoints = "5 5 5 0 0 0";


my @ciffile = sort `find $currentPath/initial -maxdepth 1 -name "*.cif"`;
chomp @ciffile;

#for(0..$#cif)
#{
# if($cif[$_] =~ /^\/home\/zhao\/atomsk\/binary\/(mp-\d+.cif)/gm)
#    {
#        push @mp,$1;                                              
#    } 
# }
my %HEA;
my %myelement;
my %pm;
my @rho_cutoff;
my @cutoff;

#######  json  ######
my $json;
{
    local $/ = undef;
    open my $fh, '<', '/opt/QEpot/SSSP_efficiency.json';
    $json = <$fh>;
    close $fh;
}
my $decoded = decode_json($json);

#######  HEA.pm  ######
for(0..$#myelement){
    $myelement{$_+1} = $myelement[$_];
    $HEA{"$myelement[$_]"}{type} = $_+1;
}
for (@myelement){
    @{$pm{$_}} = &HEA::eleObj("$_"); 
    $HEA{"$_"}{rho_cutoff} = $decoded -> {$_}->{rho_cutoff};
    $HEA{"$_"}{cutoff} = $decoded -> {$_} -> {cutoff};
    $HEA{"$_"}{jsonname} = $decoded->{$_}->{filename};
    $HEA{"$_"}{mass} = ${$pm{$_}}[2];
    $HEA{"$_"}{magn} = 0.2;

    push @rho_cutoff, $HEA{"$_"}{rho_cutoff};
    push @cutoff, $HEA{"$_"}{cutoff};
}

    my $rho_cutoff = max(@rho_cutoff);
    my $cutoff = max(@cutoff);

`sed -i 's:^ibrav.*:ibrav = $ibrav:' $currentPath/$optbatch`;
`sed -i '/ATOMIC_SPECIES/,/ATOMIC_POSITIONS.*/{/ATOMIC_SPECIES/!{/ATOMIC_POSITIONS.*/!d}}' $currentPath/$optbatch`;
`sed -i '/ATOMIC_POSITIONS.*/,/CELL_PARAMETERS.*/{/ATOMIC_POSITIONS.*/!{/CELL_PARAMETERS.*/!d}}' $currentPath/$optbatch`;
`sed -i '/K_POINTS.*/,/ATOMIC_SPECIES.*/{/K_POINTS.*/!{/ATOMIC_SPECIES.*/!d}}' $currentPath/$optbatch`;
`sed -i '/CELL_PARAMETERS.*/,/!End/{/CELL_PARAMETERS.*/!{/!End/!d}}' $currentPath/$optbatch`;
`sed -i '/nspin = 2/,/!systemend/{/nspin = 2/!{/!systemend/!d}}' $currentPath/$optbatch`;









CIF:{
    for my $id (0..$#ciffile){
    my ($cif_path) = $ciffile[$id] =~ (m/(.*)\/.*.cif/);
    my ($cif_name) = $ciffile[$id] =~ (m/.*\/(.*).cif/);
    my @ele = $cif_name =~/([A-Z]{1}[a-z]{0,1})/gm;
    my $prefix = "$cif_path/$cif_name";
    my $foldername = "$currentPath/$myelement/scf/$cif_name";


     &atomsk($prefix);
    &lmp2data($cif_name,$prefix);
    `mkdir -p $foldername`; 
    `cp $currentPath/$optbatch $foldername/$cif_name.in`;

    &setting($foldername,$cif_name,@ele);
    print "$cif_name\n";
    &ibrav0($foldername,$cif_name,"$prefix.data");
    &slurm($foldername,$cif_name);

    }
}

sub lmp2data
{
    (my $ele, my $prefix) = @_;

    open my $temp ,"<$prefix.lmp";
    my @data =<$temp>;
    close $temp;

    #my @ele = grep("([A-Z]{1}[a-z]{0,1})",$ele);
    my @ele = $ele =~/([A-Z]{1}[a-z]{0,1})/gm;
    #print Dumper @ele;
    `cp $prefix.lmp $prefix.data`;


    `sed -i 's:.*atom types.*: $types atom types:' $prefix.data`;

    `sed -i '/Masses.*/,/Atoms .*/{/Masses.*/!{/Atoms .*/!d}}' $prefix.data`;
    `sed -i '/Masses.*/a \n' $prefix.data`;
    `sed -i '/Atoms .*/,\${/Atoms .*/!d}' $prefix.data`;
    `sed -i '/Atoms .*/a \n' $prefix.data`;
    for(@myelement){
        `sed -i '/Atoms .*/i $HEA{$_}{type} $HEA{$_}{mass}' $prefix.data`;
    }
    for(@data){
        if(m/^\s*(\d+)\s+(\d+)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)$/gm)
       {
        my $type = $HEA{$ele[$2-1]}{type};
        `sed -i '\$i $1 $type $3 $4 $5' $prefix.data`;
       } 
 
    }
    my $data = join ("",@data);
    my  $regax ="xy\s+xz\s+yz\s+";
    #if( $data !~ /$regax/gmi) 
    #    {                                   
    #        `sed -i '/zhi.*/a 0 0 0 xy xz yz' $prefix.data`;
    #    }


    `sed -i '/Atoms .*/a \n' $prefix.data`;
    #`cp $prefix.data $currentPath/$myelement/data/crystal/$ele\_Fine.data`;
    # `rm -rf $prefix.lmp`;
}
sub atomsk
{

    (my $prefix) = @_;
    `rm -rf $prefix.lmp`;
    my $exp = Expect->new;
    my $expectT = 1;#
	$exp = Expect->spawn("atomsk $prefix.cif $prefix.lmp \n");
	$exp->expect($expectT,[
                qr/xy/i,
				sub {
						my $self = shift ;
						$self->send("n\n");
                        exp_continue;                            
					}
            ],
            [
                qr/xz/i,
				sub {
						my $self = shift ;
						$self->send("n\n");
                        exp_continue;                        
					}
            ],
            [   
                qr/yz/i,
				sub {
						my $self = shift ;
						$self->send("n\n");
                        exp_continue;                        
					}
			]
		);
    # `rm -rf $prefix.cif`;
    
}
sub setting
{
    (my $foldername ,my $prefix,my @ele) = @_;
    my $elelegth = @ele;
    # print "!!!@ele";
    ###ATOMIC_SPECIES### 
    # my @coords = grep {if(m/([A-Z]{1}[a-z]{0,1})/gm){
    #     $_ = [$1];
    #     print "!!!$1";
    #     }} reverse @ele;
    # `sed -i '/ATOMIC_SPECIES/a $_  $HEA{$_}{mass}  $HEA{$_}{jsonname}' $foldername/$prefix.in`;
        #   for(@ele){
        my @eles = reverse (@ele);
        # `sed -i '/ATOMIC_SPECIES/a $eles  $HEA{$eles}{mass}  $HEA{$eles}{jsonname}' $foldername/$prefix.in`;
        # }
        for(@eles){
        `sed -i '/ATOMIC_SPECIES/a $_  $HEA{$_}{mass}  $HEA{$_}{jsonname}' $foldername/$prefix.in`;
        }
    ##starting_magnetization###
    for (1..$#eles+1){
        `sed -i '/nspin = 2/a starting_magnetization($_) =  $HEA{$myelement{$_}}{magn}' $foldername/$prefix.in`;
    } 
    ### cutoff ###
        `sed -i 's:^ecutwfc.*:ecutwfc = $cutoff:' $foldername/$prefix.in`;
        `sed -i 's:^ecutrho.*:ecutrho = $rho_cutoff:' $foldername/$prefix.in`;    
    ###type###
        `sed -i 's:^ntyp.*:ntyp = $elelegth:' $foldername/$prefix.in`;
    ### Kpoints ###
    # `sed -i '/K_POINTS.*/a $kpoints' $foldername/$prefix.in`;
}
sub ibrav0
{
    (my $foldername , my $prefix , my $data) = @_;
    open my $temp ,"< $data";
    my @data =<$temp>;
    close $temp;

    `sed -i 's:ATOMIC_POSITIONS.*:ATOMIC_POSITIONS {angstrom}:' $foldername/$prefix.in`;
    `sed -i 's:CELL_PARAMETERS.*:CELL_PARAMETERS {angstrom}:' $foldername/$prefix.in`;
    my $atoms;
    my $move;
    my $lx;
    my $ly;
    my $lz; 
    my $xy = 0;
    my $xz = 0;
    my $yz = 0;

    for(@data){
    ###atoms###
        if(m/(\d+)\s+atoms/s){ 
        $atoms = $1;
        `sed -i 's:^nat.*:nat = $1:' $foldername/$prefix.in`;
        }
    ###CELL_PARAMETERS###
        if(m/(\-?\d*\.*\d*\w*[+-]?\d*)\s+\-?\d*\.*\d*\w*[+-]?\d*\s+xlo/s){
            $move = $1;
        }
    }
    for  (@data){

        ###### xlo #######
        ### 0.0 2.84708541500004 xlo xhi
        if(m/(\-?\d*\.*\d*\w*[+-]?\d*)\s+(\-?\d*\.*\d*\w*[+-]?\d*)\s+xlo/s){
            $lx = $2-$1;
        }
        ###### ylo #######
        ### 0.0 2.847085238 ylo yhi
        if(m/(\-?\d*\.*\d*\w*[+-]?\d*)\s+(\-?\d*\.*\d*\w*[+-]?\d*)\s+ylo/s){
            $ly = $2-$1;
        }
        ###### zlo #######
        ### 0.0 2.84708568799983 zlo zhi
        if(m/(\-?\d*\.*\d*\w*[+-]?\d*)\s+(\-?\d*\.*\d*\w*[+-]?\d*)\s+zlo/s){
            $lz = $2-$1;
        }
        ###### xy xz yz #######
        ### -2.65999959883181e-07 9.26000039313875e-07 5.16000064963272e-07 xy xz yz
        if(m/(\-?\d*\.*\d*\w*[+-]?\d*)\s+(\-?\d*\.*\d*\w*\+?-?\d*)\s+(\-?\d*\.*\d*\w*[+-]?\d*)\s+xy\s+xz\s+yz/s){
            $xy = $1;
            $xz = $2;
            $yz = $3;
        }

    # ###ATOMIC_POSITION###
        
        # my @coord = grep {if(m/^\d+\s+(\d+)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s?-?\d?\s?-?\d?\s?-?\d?$/gm){
        # $_ = [$1,$2,$1,$4];}} reverse @data;
        # my $movex = $2 - $move;
        # my $movey = $3 - $move;
        # my $movez = $4 - $move; 
        # `sed -i '/ATOMIC_POSITIONS {angstrom}/a $myelement{$1} $movex $movey $movez' $foldername/$prefix.in` ;
    #     if(m/^\d+\s+(\d+)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s?-?\d?\s?-?\d?\s?-?\d?$/gm) #coord
    #     {
            
    #         my $movex = $2 - $move;
    #         my $movey = $3 - $move;
    #         my $movez = $4 - $move; 
    #         `sed -i '/ATOMIC_POSITIONS {angstrom}/a $myelement{$1} $movex $movey $movez' $foldername/$prefix.in` ;
    # }

    }
        my @coord = grep {if(m/^\d+\s+(\d+)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s+(\-?\d*.?\d*e*[+-]*\d*)\s?-?\d?\s?-?\d?\s?-?\d?$/gm){
        $_ = [$1,$2,$3,$4];
        my $movex = $2 - $move;
        my $movey = $3 - $move;
        my $movez = $4 - $move; 
        `sed -i '/ATOMIC_POSITIONS {angstrom}/a $myelement{$1} $movex $movey $movez' $foldername/$prefix.in` ;
        # print $1 ; 
        # print "$2\n" ;
       }} reverse @data;
  


        
        `sed -i '/CELL_PARAMETERS {angstrom}/a  $xz $yz $lz' $foldername/$prefix.in` ;
        `sed -i '/CELL_PARAMETERS {angstrom}/a  $xy $ly 0' $foldername/$prefix.in` ;
        `sed -i '/CELL_PARAMETERS {angstrom}/a  $lx 0 0' $foldername/$prefix.in` ;

}
sub slurm
{
    (my $foldername ,my $prefix) = @_;
    `sed -i '/#SBATCH.*--job-name/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --job-name=scf_$prefix' $slurmbatch`;
	
	`sed -i '/#SBATCH.*--output/d' $slurmbatch`;
	`sed -i '/#sed_anchor01/a #SBATCH --output=$prefix.sout' $slurmbatch`;
	
	`sed -i '/mpiexec.*/d' $slurmbatch`;
	`sed -i '/#sed_anchor02/a mpiexec $QE_path -in $prefix.in' $slurmbatch`;
 #`sed -i '/mpiexec.* /opt/QEGCC/bin/pw.x/d' $slurmbatch`;
    `cp $slurmbatch $foldername/$prefix.sh`;
    chdir("$foldername");
   # system("sbatch $prefix.sh");
    print qq(sbatch $foldername/$prefix.sh\n);
    chdir("$currentPath");

}