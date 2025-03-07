#!/bin/sh
#sed_anchor01
#SBATCH --output=dp01.out
#SBATCH --job-name=dp01
#SBATCH --nodes=1
##SBATCH --cpus-per-task=1
##SBATCH --ntasks-per-node=8
#SBATCH --partition=All
#SBATCH --nodelist=master
##SBATCH --ntasks-per-node=12
##SBATCH --reservation=GPU_test
##SBATCH --exclude=node18,node20
##SBATCH --gres=gpu:0
##SBATCH --reservation=script_test
##SBATCH --reservation=script_test
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
# Set threads based on hostname
if [ "$(hostname)" = "master" ]; then
    threads=24
else
    threads=$(nproc)
fi
#threads=$(nproc)
processors=$(nproc)
np=$(($node*$processors/$threads))

#The following for deepmd v3
#export DP_INTRA_OP_PARALLELISM_THREADS=\$processors
#export DP_INTER_OP_PARALLELISM_THREADS=\$np

export DP_INTRA_OP_PARALLELISM_THREADS=$np
export DP_INTER_OP_PARALLELISM_THREADS=$processors
export OMP_NUM_THREADS=$processors
### sometimes works 
#export OMP_NUM_THREADS=1
echo "###Formal dp train starts"
echo " "
#sed_anchor02
dp train Template.json
#sed_anchor03
dp freeze -o graph4.pb
#cp lcurve.out lcurve_ori.out
#sed_dpout
#cp dp.dpout dp_ori.dpout
sleep 3
echo " "
echo "###Compress the graph"
echo " "

#sed_anchor04
dp compress -i graph.pb -o graph-compress.pb
#sed_anchor05
#dp train input.json --init-frz-model graph-compress.pb
#sleep 60
echo "Done" > train_done.txt
