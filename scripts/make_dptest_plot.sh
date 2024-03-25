#!/bin/sh
#sed_anchor01
#SBATCH --output=dptest_plot.dat
#SBATCH --job-name=dptest_plot
#SBATCH --nodes=1
##SBATCH --ntasks-per-node=8
#SBATCH --partition=All
##SBATCH --ntasks-per-node=12
##SBATCH --reservation=GPU_test
##SBATCH --exclude=node18,node20
##SBATCH --gres=gpu:0 
#source activate deepmd-cpu
threads=$(nproc)
export OMP_NUM_THREADS=$threads
export KMP_AFFINITY=granularity=fine,compact,1,0
export KMP_BLOCKTIME=0
export KMP_SETTINGS=TRUE
echo "perl script"
perl ./dptest_matplot.pl
echo "dptest_matplot.pl done !"

