#!/usr/bin/env python3

import argparse
from pathlib import Path
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from tqdm import tqdm

parser = argparse.ArgumentParser()
parser.add_argument(
    '--in-dir',
    type=Path,
    default=Path('./_outputs-trace-peer-32-failed'),
)
parser.add_argument(
    '--out-dir',
    type=Path,
    default=Path('./_stat-computation-time'),
)

args = parser.parse_args()

time_start = []
time_end = []

# check passed or failed
query_log_file = list(args.in_dir.glob('log/query/*.txt'))
assert len(query_log_file) == 1
is_passed = False
with open(query_log_file[0]) as f:
    for line in f.readlines():
        if 'passed' in line:
            is_passed = True
            break

for file in tqdm(args.in_dir.glob('log/eval/*.txt')):
    peer_idx = int(file.stem.split('-')[-1])
    with open(file) as f:
        for line in f.readlines():
            if 'Compute trees' in line:
                time_start.append({
                    'time': pd.to_datetime(
                        line.split(' ')[0].split('[')[-1],
                        format='%Y-%m-%dT%H:%M:%S.%fZ'
                    ).timestamp() * 1000,
                    'peer': peer_idx,
                })

            elif 'Computations completed' in line:
                time_end.append({
                    'time': pd.to_datetime(
                        line.split(' ')[0].split('[')[-1],
                        format='%Y-%m-%dT%H:%M:%S.%fZ'
                    ).timestamp() * 1000,
                    'peer': peer_idx,
                })

assert len(time_start) == len(time_end), (len(time_start), len(time_end))
data = {
    'start': pd.DataFrame(time_start),
    'end': pd.DataFrame(time_end),
}
for key in data:
    data[key].sort_values(['peer', 'time'])
data['end']['time'] -= data['start']['time']
num_peers = len(data['end']['peer'].unique())
stat = data['end'].groupby(['peer'], as_index=False).agg({'time': ['sum', 'mean']})
stat.columns = ['peer', 'sum', 'mean']

fig = make_subplots(
    rows=2,
    cols=1,
    shared_xaxes=True,
    x_title='Peer',
    y_title='Time (ms)',
    subplot_titles=(
        '%.2f ± %.2f' % (stat['sum'].mean(), stat['sum'].std()),
        '%.2f ± %.2f' % (stat['mean'].mean(), stat['mean'].std()),
    ),
)
fig.add_trace(
    go.Bar(
        x=stat['peer'],
        y=stat['sum'],
        name='Total',
    ),
    1,
    1
)
fig.add_trace(
    go.Bar(
        x=stat['peer'],
        y=stat['mean'],
        name='Average',
    ),
    2,
    1
)
fig.update_layout(go.Layout(
    title='Time of Routes & Trees Computation on %d Peer(s), Result: %s' % (num_peers, 'Passed' if is_passed else 'Failed'),
    width=1280,
    height=720,
    #  width=1920,
    #  height=1080,
))

for ax in fig['layout']:
    if ax[:5] == 'xaxis':
        fig['layout'][ax]['dtick'] = 1

args.out_dir.mkdir(exist_ok=True)
fig.write_image(args.out_dir / ('%d-%s.png' % (num_peers, 'passed' if is_passed else 'failed')))
#  fig.show()
