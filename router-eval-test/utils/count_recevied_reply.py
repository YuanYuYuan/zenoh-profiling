#!/usr/bin/env python3

import argparse
from pathlib import Path
import json
import pandas as pd
import plotly.express as px

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

counter = {node_name: 0 for (_, node_name) in node_mapping.items() if node_name not in ['RO', 'QU'] }

with open(args.in_dir / 'log/query.txt') as f:
    for line in f.readlines():
        if 'Received reply' in line:
            pid = line.split('peer')[-1].split('.')[0].strip()
            counter[node_mapping[pid]] += 1

is_passed = True
for val in counter.values():
    if val == 0:
        is_passed = False
        break

data = pd.DataFrame({'peer': counter.keys(), 'count': counter.values()})
fig = px.bar(
    data,
    x='peer',
    y='count',
    labels={'peer': 'Peer', 'count': 'Count'},
    title='Number of Received Replies (%s)' % ('Passed' if is_passed else 'Failed')
)
fig.update_layout(yaxis={'dtick':1})
fig.show()
