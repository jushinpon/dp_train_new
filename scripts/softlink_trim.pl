#!/usr/bin/perl
use strict;
use warnings;
use File::Path qw(remove_tree);  # For recursive directory deletion

# Define directories
my $exp_dir    = "/home/jsp/SnPbTe_alloys/QE_from_MatCld/cifs_exp";
my $theory_dir = "/home/jsp/SnPbTe_alloys/QE_from_MatCld/cifs_theory";
my $initial_dir = "/home/jsp/SnPbTe_alloys/dp_train_new/initial";

# Define filtering criteria
my @need = ("Sn", "Pb");         # Elements that MUST be present
my @notrequired = ("Te");        # Elements that MUST NOT be present

# Read experimental CIF files and store prefixes in @exp
my @exp;
my %exp_hash;
opendir(my $exp_dh, $exp_dir) or die "Cannot open directory $exp_dir: $!";
while (my $file = readdir($exp_dh)) {
    next unless $file =~ /^(.+)\.cif$/;
    push @exp, $1;
    $exp_hash{$1} = 1;
}
closedir($exp_dh);

# Read theoretical CIF files and filter using @need and @notrequired
my @theory;
my %theory_hash;
opendir(my $theory_dh, $theory_dir) or die "Cannot open directory $theory_dir: $!";
while (my $file = readdir($theory_dh)) {
   # print "\$file: $file\n";
    next unless $file =~ /^(.+)\.cif$/;
    my $prefix = $1;
    #print "\$1: $1\n";
    
    # Check if all required elements exist
    my $contains_needed = 1;
    foreach my $element (@need) {
        unless ($prefix =~ /$element/) {
            $contains_needed = 0;
            last;
        }
    }

    # Check if any not-required elements exist
    my $contains_notrequired = 0;
    foreach my $element (@notrequired) {
        if ($prefix =~ /$element/) {
            $contains_notrequired = 1;
            last;
        }
    }
    #print "$contains_needed,$contains_notrequired\n";
    # If the prefix satisfies the conditions, add it to @theory
    if ($contains_needed && !$contains_notrequired) {
        push @theory, $prefix;
        $theory_hash{$prefix} = 1;
    }
}
closedir($theory_dh);
#for (keys %theory_hash){print "$_\n";}
#die;
# Read initial directories and filter based on @exp and @theory
my @filtered_dirs;
my @dirs_to_remove;

opendir(my $init_dh, $initial_dir) or die "Cannot open directory $initial_dir: $!";
while (my $dir = readdir($init_dh)) {
    next if $dir =~ /^\./; # Skip hidden files and parent/child directories
    my $full_path = "$initial_dir/$dir"; # Full directory path

    # Extract base prefix by removing suffixes like "-T300-P0"
    my ($base_prefix) = $dir =~ /^([A-Za-z0-9_+-]+)/;

    # Debug print
    print "Checking folder: $dir (Base Prefix: $base_prefix)\n";

    # Check if the extracted base name is in @exp or @theory
    if (exists $exp_hash{$base_prefix} || exists $theory_hash{$base_prefix}) {
        print " -> Keeping: $dir (Matched in exp or theory)\n";
        push @filtered_dirs, $dir;
        next;
    }

    # Keep folders that do not contain "mp-xxxx" (avoid removing non-mp folders)
    if ($dir !~ /mp-\d+/) {
        print " -> Keeping: $dir (No mp-xxxx found)\n";
        push @filtered_dirs, $dir;
        next;
    }

    # If not in @exp or @theory and contains "mp-xxxx", mark for deletion
    print " -> Removing: $dir (Not in exp/theory & contains mp-xxxx)\n";
    push @dirs_to_remove, $full_path;
}
closedir($init_dh);

# Print results for verification
print "\nExperimental CIFs (@exp):\n", join("\n", @exp), "\n\n";
print "Theoretical CIFs (@theory):\n", join("\n", @theory), "\n\n";
print "Filtered Initial Directories (Kept):\n", join("\n", @filtered_dirs), "\n\n";
print "Directories to be REMOVED:\n", join("\n", @dirs_to_remove), "\n";

# Remove unfiltered directories
foreach my $dir (@dirs_to_remove) {
    print "Removing: $dir\n";
    #remove_tree($dir, { error => \my $err });
    #
    #if (@$err) {
    #    print "Error removing $dir: @$err\n";
    #} else {
    #    print "$dir removed successfully.\n";
    #}
}
