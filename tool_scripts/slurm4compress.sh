#!/bin/bash
#sed_anchor01
#SBATCH --output=compress_training.lmpout
#SBATCH --job-name=compress_training
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=64
##SBATCH -c 64
#SBATCH --partition=C64M32
source activate deepmd-cpu
dp train out.json --init-frz-model graph-compress.pb
dp freeze -o graph-compress_training.pb
conda deactivate

