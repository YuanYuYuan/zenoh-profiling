#!/usr/bin/env python3

from glob import glob
from pathlib import Path
from tap import Tap
import os
import polars as pl
import plotly.express as px
import plotly.graph_objects as go

def load_usage(dir: Path, n_peers: int) -> pl.DataFrame:
    data = pl.read_csv(os.path.join(dir, '%d.csv' % n_peers))
    data = data.select([
        pl.lit(n_peers).alias('n_peers'),
        pl.all()
    ])
    data['CPU'] = data['CPU'].rolling_mean(30)
    return data


class MyArgParser(Tap):
    # the directory containing the experiemental results
    data_dir: Path = Path('csv')
    # specify max number of threads used in this experiment
    num_thread: int = 8
    #  # specify max memory size (GB) used in this experiment
    #  memory_size: int = 16
    # if not specified, plot the curves interactively on the browser
    output_dir: Path = Path('plotting')


args = MyArgParser().parse_args()

# load data
n_peers_list = sorted(map(
    lambda fp: int(Path(fp).stem),
    glob(os.path.join(args.data_dir, '*.csv'))
))
usages = pl.concat([
    load_usage(args.data_dir, n_peers)
    for n_peers in n_peers_list
])
#  usages['MEM'] /= 1e3

#  # plot delivery ratio
#  delivery_ratios = load_delivery_ratio(args.exp_dir, n_peers_list)
#  fig = px.line(
#      delivery_ratios,
#      x='n_peers',
#      y='delivery_ratio',
#      title='Receive Rate',
#      labels={
#          'n_peers': '# Peers',
#          'delivery_ratio': 'Ratio (%)'
#      }
#  )
#  fig.update_layout(
#      xaxis = dict(
#          tickmode = 'linear',
#          dtick = 1
#      )
#  )
#  if args.output_dir:
#      os.makedirs(args.output_dir, exist_ok=True)
#      fig.write_image(os.path.join(
#          args.output_dir,
#          'delivery-ratio.jpg'
#      ))
#  else:
#      fig.show()


# plot each CPU & memory usage
for n_peers in n_peers_list:
    trace1 = go.Scatter(
        x=usages[usages['n_peers'] == n_peers]['t'],
        y=usages[usages['n_peers'] == n_peers]['CPU'],
        marker=dict(color="blue"),
        name='CPU',
        yaxis='y1',
    )
    trace2 = go.Scatter(
        x=usages[usages['n_peers'] == n_peers]['t'],
        y=usages[usages['n_peers'] == n_peers]['MEM'],
        marker=dict(color="red"),
        name='Memory',
        yaxis='y2',
    )
    layout = go.Layout(
        title='CPU & Memory Usage, # Peers: %d' % n_peers,
        xaxis={
            'title': 'Time (sec)',
            'range': [0, 16],
            'dtick': 1,
        },
        yaxis={
            'title': 'CPU (%)',
            'range': [0, 100 * args.num_thread],
            'dtick': 100,
        },
        yaxis2={
            'title': 'Memory (MB)',
            'overlaying': 'y',
            'side': 'right',
            'range': [0, 800],
            'dtick': 100,
            #  'dtick': 1,
        },
        legend={
            'y': 1.18,
            'x': 0.92
        }
    )
    fig = go.Figure(
        data=[trace1, trace2],
        layout=layout
    )

    os.makedirs(args.output_dir, exist_ok=True)
    fig.write_image(os.path.join(
        args.output_dir,
        'n-peers-%02d.jpg' % n_peers
    ))
