#!/bin/sh
#sed_anchor01
#SBATCH --output=dptest_plot4compress.dat
#SBATCH --job-name=dptest_compress
#SBATCH --nodes=1
##SBATCH --ntasks-per-node=8
#SBATCH --partition=All
##SBATCH --ntasks-per-node=12
##SBATCH --reservation=GPU_test
##SBATCH --reservation=script_test
##SBATCH --exclude=node18,node20
##SBATCH --gres=gpu:0 
#source activate deepmd-cpu

hostname

if [ -f /opt/anaconda3/bin/activate ]; then
    
    source /opt/anaconda3/bin/activate deepmd-cpu-v3
    export LD_LIBRARY_PATH=/opt/deepmd-cpu-v3/lib:/opt/deepmd-cpu-v3/lib/deepmd_lmp:$LD_LIBRARY_PATH
    export PATH=/opt/deepmd-cpu-v3/bin:$PATH

elif [ -f /opt/miniconda3/bin/activate ]; then
    source /opt/miniconda3/bin/activate deepmd-cpu-v3
    export LD_LIBRARY_PATH=/opt/deepmd-cpu-v3/lib:/opt/deepmd-cpu-v3/lib/deepmd_lmp:$LD_LIBRARY_PATH
    export PATH=/opt/deepmd-cpu-v3/bin:$PATH
else
    echo "Error: Neither /opt/anaconda3/bin/activate nor /opt/miniconda3/bin/activate found."
    exit 1  # Exit the script if neither exists
fi

#always use one node for training
node=1
#threads per core (for all our PCs)
threads=$(nproc)
processors=$(nproc)
np=$(($node*$processors/$threads))

#The following for deepmd v3
#export DP_INTRA_OP_PARALLELISM_THREADS=\$processors
#export DP_INTER_OP_PARALLELISM_THREADS=\$np

export DP_INTRA_OP_PARALLELISM_THREADS=$np
export DP_INTER_OP_PARALLELISM_THREADS=$processors
export OMP_NUM_THREADS=$processors

echo "perl script"
perl ./dptest4compress_matplot.pl
echo "dptest4compress_matplot.pl done !"

