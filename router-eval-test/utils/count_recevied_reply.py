#!/usr/bin/env python3

import argparse
from pathlib import Path
import json

parser = argparse.ArgumentParser()
parser.add_argument(
    '--in-dir',
    type=Path,
    default=Path('./outputs/peer-8'),
    help='folder containing the output logs'
)
args = parser.parse_args()

print(f'>>> Processing {args.in_dir}')
num_peers = int(args.in_dir.stem.split('-')[-1])

with open(args.in_dir / 'node_mapping.json') as f:
    node_mapping = json.load(f)

counter = {pid: 0 for (pid, node_name) in node_mapping.items() if node_name not in ['RO', 'QU'] }
print(counter)
#  with open(args.in_dir / 'log/query.txt') as f:
#      for line in f.readlines():
#          if 'Received reply' in line:
