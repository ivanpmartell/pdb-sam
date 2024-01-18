import os
import sys
import re
import json
import subprocess
from pathlib import Path
from ter2pdb import ter2pdb
from Bio import SeqIO

def get_args(name='default', input_file='in.fa'):
    return input_file

in_file = get_args(*sys.argv)
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

run_inputs = {'sequence': sequence, 'seq_id': seq_id}
with open("run.json", "w") as f:
    json.dump(run_inputs, f)

DATA_DIR = 'aminobert_output'
RUN_DIR = 'runs/15106000'
OUTPUT_DIR = 'output'
REFINE_DIR = 'output/refine_model1'
SEQ_PATH = os.path.join(DATA_DIR, f'{seq_id}.fa')
TER_PATH = os.path.join(RUN_DIR, '1', 'outputsTesting', f'{seq_id}.tertiary')

#Generate AminoBERT embeddings
sys.path.append(os.path.join(os.getcwd(), 'aminobert'))

import shutil
from aminobert.prediction import aminobert_predict_sequence
from data_processing.aminobert_postprocessing import aminobert_postprocess

DATASET_NAME = '1'
PREPEND_M = True
AMINOBERT_CHKPT_DIR = 'resources/aminobert_checkpoint/AminoBERT_runs_v2_uniparc_dataset_v2_5-1024_fresh_start_model.ckpt-1100000'

with open("run.json", "r") as f:
    run_inputs = json.load(f)

# Remove old data since AminoBERT combines entire directory to create dataset.
if os.path.exists(DATA_DIR):
  shutil.rmtree(DATA_DIR)
os.makedirs(DATA_DIR)

aminobert_predict_sequence(seq=run_inputs['sequence'], header=run_inputs['seq_id'],
                           prepend_m=PREPEND_M, checkpoint=AMINOBERT_CHKPT_DIR,
                           data_dir=DATA_DIR)
aminobert_postprocess(data_dir=DATA_DIR, dataset_name=DATASET_NAME, prepend_m=PREPEND_M)
print("Aminobert embeddings complete!")
