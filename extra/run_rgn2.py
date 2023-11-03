#RUN with rgn2 conda env
import os
import sys
import re
import json
import subprocess
from pathlib import Path
from ter2pdb import ter2pdb
from Bio import SeqIO

def get_args(name='default', input_file='in.fa', miniconda='/mnt/miniconda3/'):
    return input_file, miniconda

rgn2_location = os.getcwd()
in_file, miniconda_location = get_args(*sys.argv)
record = SeqIO.read(in_file, "fasta")

sys.path.append('alphafold')
sequence = str(record.seq)
seq_id = record.id

MAX_SEQUENCE_LENGTH = 1023

aatypes = set('ACDEFGHIKLMNPQRSTVWY')  # 20 standard aatypes
if not set(sequence).issubset(aatypes):
  raise Exception(f'Input sequence contains non-amino acid letters: {set(sequence) - aatypes}. AlphaFold only supports 20 standard amino acids as inputs.')
if len(sequence) > MAX_SEQUENCE_LENGTH:
  raise Exception(f'Input sequence is too long: {len(sequence)} amino acids, while the maximum is {MAX_SEQUENCE_LENGTH}. Please use the full AlphaFold system for long sequences.')

DATA_DIR = 'aminobert_output'
RUN_DIR = 'runs/15106000'
OUTPUT_DIR = 'output'
REFINE_DIR = 'output/refine_model1'
SEQ_PATH = os.path.join(DATA_DIR, f'{seq_id}.fa')
TER_PATH = os.path.join(RUN_DIR, '1', 'outputsTesting', f'{seq_id}.tertiary')
MINICONDA_PATH = os.path.join(miniconda_location, "etc/profile.d/conda.sh")

print("Starting protling...")

try:
    config_file = os.path.join(RUN_DIR, 'configuration')
    captured = subprocess.run(f'''source {MINICONDA_PATH}
                  conda activate rgn2
                  python rgn/protling.py {config_file} -p -e weighted_testing -a -g 0''', executable='/bin/bash', shell=True, capture_output=True, check=True)
    print(captured)
except subprocess.CalledProcessError as e:
  print(e.stderr)
  raise

print('Prediction completed!')

print('Relaxing...')
recycles = 1

ter2pdb.run_ca_to_allatom(seq_path=SEQ_PATH, ter_path=TER_PATH,
                          output_dir=OUTPUT_DIR, seq_id=seq_id)

try:
    out_suffix = '_prediction'
    path_parent = Path(SEQ_PATH).parent
    af2_dir = os.path.join(rgn2_location, "alphafold/")
    captured = subprocess.run(f'''source {MINICONDA_PATH}
                    conda activate af2
                    TF_FORCE_UNIFIED_MEMORY=1 XLA_PYTHON_CLIENT_MEM_FRACTION=2.0 python ter2pdb/run_af2rank.py refine_model1 --target_list {seq_id} --af2_dir {af2_dir} --out_suffix {out_suffix} --seq_dir {path_parent} --pdb_dir {OUTPUT_DIR} --output_dir {OUTPUT_DIR} --deterministic --seq_replacement - --mask_sidechains_add_cb --model_num 1 --recycles {recycles}''', executable='/bin/bash', shell=True, capture_output=True)
    print(captured)
except subprocess.CalledProcessError as e:
  print("ERROR:\n")
  print(e.stderr)
  raise

print('Refinement completed!')
