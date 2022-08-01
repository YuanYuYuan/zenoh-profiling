#!/usr/bin/env python3

import argparse
from pathlib import Path
import pandas as pd
import plotly.express as px

parser = argparse.ArgumentParser()
parser.add_argument(
    '--exp-dir',
    type=Path,
    default=Path('./exp/reply-rate'),
)
args = parser.parse_args()


def load_sample_data(sample_dir: Path):
    query_log_files = list(sample_dir.glob('peer-*/log/query.txt'))

    data = {
        'peer': [],
        'reply': [],
    }
    for file in query_log_files:
        num_peers = int(str(file).split('peer-')[-1].split('/')[0])
        result = None
        with open(file) as f:
            for line in f.readlines():
                if 'Ended with' in line:
                    result = int(line.split('Ended with ')[-1].split(' peers')[0])
                    break
        if result is None:
            print(file, 'contains error!')
        #  assert result is not None, file
        data['peer'].append(num_peers)
        data['reply'].append(result)

    data = pd.DataFrame(data).sort_values(['peer'])
    data['reply'] = data['reply'] / data['peer'] * 100
    data['sample'] = str(sample_dir).split('/')[-2]
    return data

data = pd.concat([
    load_sample_data(dir / 'outputs')
    for dir in args.exp_dir.glob('*')
    if dir.is_dir()
])

fig = px.line(
    data,
    x='peer',
    y='reply',
    color='sample',
    symbol='sample',
    title='Reply Rate',
    markers=True,
    labels={'sample': 'Exp name'}
)

fig.update_layout(
    xaxis = dict(
        title = 'Number of Peers',
        tickmode = 'array',
        tickvals = data['peer'],
    ),
    yaxis = dict(
        title = 'Reply Rate (%)',
        dtick = 10,
    )
)
#  fig.show()
fig.write_image(args.exp_dir / 'reply-rate.png')
