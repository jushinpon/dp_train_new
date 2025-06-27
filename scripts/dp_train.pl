=b
conducting dp XX.json 
=cut
use warnings;
use strict;
use JSON::PP;
use Data::Dumper;
use Cwd;
use POSIX;
use Parallel::ForkManager;

sub dp_train{

my ($ss_hr,$dps_hr) = @_;
my $mainPath = $ss_hr->{main_dir};# main path of dpgen folder
my $currentPath = $ss_hr->{script_dir};
my $debug = $ss_hr->{debug};
my @allnpy_folder = @{$dps_hr->{allnpy_dir}};
my @type_map = @{$dps_hr->{type_map}};
my @atom_ener = @{$dps_hr->{atom_ener}};
my $working_dir = $dps_hr->{working_dir};#training folder
my $json_script = $dps_hr->{json_script};#json template
my $json_outdir = $dps_hr->{json_outdir};#modified json output dir

#the follwoing is the base weight for probability of each type of data
my $ajustProb = "yes";
my %Prob = (
    'mp_pattern'    => 0.1,
    'surface'   => 0.1,
    #'label'         =  [],
    'others'        => 0.6, #mainly for homemade
    'heating'        => 0.2, 
    'dimer'        => 0.05, 
);

# Define the keywords that should be classified as "others" if you want to filter them out
my @keywords = ("");#no mp case with the higher probability
#my @keywords = ("mp-1883","mp-19717");
my %keyword_hash = map { $_ => 1 } @keywords;  # Convert list to hash for fast lookup
my $use_hybrid = $dps_hr->{use_hybrid};#use hybrid or not
print "!!!!use hybrid: $use_hybrid\n";

#### modify json file for dpmd-kit, need to be done in main script
my $json;
{
    local $/ = undef;
    open my $fh, '<', "$json_script" or die "no template.json in scripts path $json_script\n";
    $json = <$fh>;
    close $fh;
}
my $decoded = decode_json($json);

#get training and validation folders
my @allnpy_Trafolder;
my @allnpy_Valfolder;

for my $v (@allnpy_folder){
    #print "$v\n";
    if($v =~ /.+\/val$/){
        push @allnpy_Valfolder,$v; 
    }
    else{
        push @allnpy_Trafolder,$v; 
    }
}
die "No val folder for your system. Try to  use a smaller number for \$set_No in all_setting.pm" unless(@allnpy_Trafolder);
map { s/^\s+|\s+$//g; } @allnpy_Valfolder;
map { s/^\s+|\s+$//g; } @allnpy_Trafolder;
#my @prob;
# Hashes to classify data
my %categories = (
    'mp_pattern'    => [],
    'surface'   => [],
    #'label'         => [],
    'others'        => [], #mainly for homemade
    'heating'        => [], 
    'dimer'        => [] 
);

for my $path (@allnpy_Trafolder){
    $path =~ s/\/$//g;#remove the last /

    #find folders with keyword in the path
    if ($path =~ /_mp-(\d+)-T/) {
        my $basename = "mp-$1";

        # Check if it matches a keyword (move to "others" category)
        if (exists $keyword_hash{$basename}) {
            push @{ $categories{'others'} }, $path;
            next;
        }
    }

    if ($path =~ /^(?!.*-P0)(?!.*dimer).*/) {
        push @{ $categories{'heating'} }, $path;
    }
    elsif ($path =~ /_mp-\d+-T\d+-P0/) {
        push @{ $categories{'mp_pattern'} }, $path;
    }
    elsif ($path =~ /_\d{3}-T/) {
        push @{ $categories{'surface'} }, $path;
    }
    #elsif ($path =~ /label/i) {
    #    push @{ $categories{'label'} }, $path;
    #}
    elsif ($path =~ /dimer/) {
        push @{ $categories{'dimer'} }, $path;
    }
    else {
        push @{ $categories{'others'} }, $path;
    }    
    #print "$_\n";
    
    }

#

# Create probability array
my @cat_nonzero;
my @prob;
my @allnpy_Trafolder_temp;
for my $cat (sort keys %categories) {
    my $cat_size = @{ $categories{$cat} };
    if ($cat_size > 0) {
        push @cat_nonzero, $cat;
        push @prob,$Prob{$cat};
        @allnpy_Trafolder_temp = (@allnpy_Trafolder_temp,@{ $categories{$cat} });
        #print "$cat,$Prob{$cat}\n";        
    }
}

@allnpy_Trafolder = @allnpy_Trafolder_temp;
# Calculate the total sum of probabilities
my $sum_prob = 0;
$sum_prob += $_ for @prob;

# Normalize probabilities so their total is 1
@prob = map { $_ / $sum_prob } @prob;

my @range;
my $start = 0;
my $end = 0;
for my $c (0..$#cat_nonzero) {
    my $cat = $cat_nonzero[$c];
    my $prob = $prob[$c];
    my $cat_size = @{ $categories{$cat} };
    $end = $start + $cat_size;
    push @range, "$start:$end:$prob";
    #print "$cat, $start:$end:$prob\n";
    $start = $start + $cat_size;
}
my $prob = join(";", ("prob_sys_size",@range));
#my @prob = map { 
#    my $val = $_; 
#    grep { $val eq $_ } @prob_patterns ? $prob_weight : 0.1 
#} @all_train_dataset;
if($ajustProb eq "yes"){
   $decoded->{training}->{training_data}->{auto_prob} = $prob;#clean it first
}

###########

# Print results
unlink 'PROB.txt' if (-e 'PROB.txt');
foreach my $category (  sort keys %categories) {
    print "\n$category:\n";
    `echo $category: >> PROB.txt`;
    for (@{ $categories{$category}}) {
        my $path = $_;
        $path =~ s/\/$//g;#remove the last /
        print "$path\n";
        `echo $path >> PROB.txt`;
    };
}

##modify set folders' parent path
$decoded->{training}->{training_data}->{systems} = [@allnpy_Trafolder];#clean it first
#find folders with /val
$decoded->{training}->{validation_data}->{systems} = [@allnpy_Valfolder];#clean it first
$decoded->{model}->{type_map} = [@type_map];#clean it first
###
my $trainNo = $ss_hr->{trainNo};
my $trainstep = $dps_hr->{trainstep};
my $forkNo = $trainNo;# $trainNo;
my $pm = Parallel::ForkManager->new("$forkNo");
#make json for original dp train
for (1..$trainNo){
    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    my $seed1 = ceil(12345 * (rand() + $_ * rand()) );
	chomp $seed1;
   # $decoded->{model}->{descriptor}->{seed} = $seed1;
    my $seed2 = ceil(12345 * (rand() + $_ * rand()));
	chomp $seed2;
    $decoded->{model}->{fitting_net}->{seed} = $seed2;
    $decoded->{model}->{fitting_net}->{atom_ener} = [map { sprintf("%.1f", $_) + 0 } @atom_ener];#eV/atom, the energy of each element in DLP elements
    #$decoded->{model}->{fitting_net}->{atom_ener} = [@atom_ener];#eV/atom, the energy of each element in DLP elements

    my $seed3 = ceil(12345 * (rand() + $_ * rand()));
    chomp $seed3;
    $decoded->{training}->{seed} = $seed3;
    $decoded->{training}->{numb_steps} = $trainstep;    
    $decoded->{training}->{save_ckpt} = $dps_hr->{save_ckpt};    
    $decoded->{training}->{disp_file} = $dps_hr->{disp_file};    
    $decoded->{training}->{save_freq} = $dps_hr->{save_freq};    
    $decoded->{training}->{disp_freq} = $dps_hr->{disp_freq};    
    $decoded->{learning_rate}->{start_lr} = $dps_hr->{start_lr};    
    $decoded->{learning_rate}->{decay_steps} = $dps_hr->{decay_steps};
    $decoded->{learning_rate}->{decay_rate} = 0.95;
    
    if($use_hybrid eq "no"){
        $decoded->{model}->{descriptor}->{seed} = $seed1;
        $decoded->{model}->{descriptor}->{rcut} = $dps_hr->{rcut};    
        $decoded->{model}->{descriptor}->{rcut_smth} = $dps_hr->{rcut_smth};    
        #$decoded->{model}->{descriptor}->{set_davg_zero} = $dps_hr->{set_davg_zero};    
        $decoded->{model}->{descriptor}->{type} = $dps_hr->{descriptor_type};
    }
    else{
        $decoded->{model}->{descriptor}->{list}->[0]->{seed} = $seed1;
        my $seed4 = ceil(12345 * (rand() + $_ * rand()) );
        chomp $seed4;
        $decoded->{model}->{descriptor}->{list}->[1]->{seed} = $seed4;
        #set the rcut and smth for se_e2 descriptor
        $decoded->{model}->{descriptor}->{list}->[0]->{rcut} = $dps_hr->{se_e2_a_rcut};
        $decoded->{model}->{descriptor}->{list}->[0]->{rcut_smth} = $dps_hr->{se_e2_a_rcut_smth};
        #set the rcut and smth for se_e3_a descriptor
        $decoded->{model}->{descriptor}->{list}->[1]->{rcut} = $dps_hr->{se_e3_a_rcut};
        $decoded->{model}->{descriptor}->{list}->[1]->{rcut_smth} = $dps_hr->{se_e3_a_rcut_smth};

    }


    {
        local $| = 1;
        open my $fh, '>', "$json_outdir/graph$temp.json";
        print $fh JSON::PP->new->pretty->encode($decoded);#encode_json($decoded);
        close $fh;
    }
     $pm-> finish;
}
$pm->wait_all_children;

#make json for compress dp train
my $compresstrainstep = $dps_hr->{compresstrainstep};

for (1..$trainNo){
    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    my $seed1 = ceil(12345 * (rand() + $_ * rand()) );
	chomp $seed1;
    $decoded->{model}->{descriptor}->{seed} = $seed1;
    my $seed2 = ceil(12345 * (rand() + $_ * rand()));
	chomp $seed2;
    $decoded->{model}->{fitting_net}->{seed} = $seed2;
    $decoded->{model}->{fitting_net}->{atom_ener} = [map { sprintf("%.1f", $_) + 0 } @atom_ener];#eV/atom, the energy of each element in DLP elements

    #$decoded->{model}->{fitting_net}->{atom_ener} = [@atom_ener];#eV/atom, the energy of each element in DLP elements
    my $seed3 = ceil(12345 * (rand() + $_ * rand()));
    chomp $seed3;
    $decoded->{training}->{seed} = $seed3;
    $decoded->{training}->{numb_steps} = $compresstrainstep; 
    $decoded->{training}->{save_ckpt} = $dps_hr->{save_ckpt4compress};;    
    $decoded->{training}->{disp_file} = $dps_hr->{disp_file4compress};;    
    $decoded->{training}->{save_freq} = $dps_hr->{save_freq};    
    $decoded->{training}->{disp_freq} = $dps_hr->{disp_freq};    
    $decoded->{learning_rate}->{start_lr} = $dps_hr->{start_lr4compress};    
    $decoded->{learning_rate}->{decay_steps} = $dps_hr->{decay_steps};    
    $decoded->{model}->{descriptor}->{rcut} = $dps_hr->{rcut};    
    $decoded->{model}->{descriptor}->{rcut_smth} = $dps_hr->{rcut_smth};    
    $decoded->{model}->{descriptor}->{type} = $dps_hr->{descriptor_type};    
       
    {
        local $| = 1;
        open my $fh, '>', "$json_outdir/graph$temp-compress.json";
        print $fh JSON::PP->new->pretty->encode($decoded);#encode_json($decoded);
        close $fh;
    }
     $pm-> finish;
}
$pm->wait_all_children;

##conducting dp_train 
for (1..$trainNo){
    $pm->start and next;
    my $temp = sprintf("%02d",$_);
    chomp $temp;
    chdir("$mainPath/dp_train/graph$temp/");
    system("rm -rf *");
	system("sbatch ../slurm_dp$temp.sh");
    #slurm
	chdir("$currentPath");
    $pm-> finish;
}
$pm->wait_all_children;

}# end sub
1;