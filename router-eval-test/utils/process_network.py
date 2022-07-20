#!/usr/bin/env python3

import argparse
from pathlib import Path
import networkx as nx
import matplotlib.pyplot as plt
from tqdm import tqdm
from multiprocessing import Pool
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument(
    '--in-dir',
    type=Path,
    default=Path('./_outputs/peer-8'),
    help='folder containing the output logs'
)
parser.add_argument(
    '--out-dir',
    type=Path,
    default=Path('./plots'),
    help='output folder name would be created under the in-dir'
)


args = parser.parse_args()

print(f'>>> Processing {args.in_dir}')

num_peers = int(args.in_dir.stem.split('-')[-1])
log_files = {
    key: args.in_dir / f'log/{key}.txt'
    for key in ['router', 'eval', 'query']
}

router_pid = None
with open(log_files['router']) as f:
    for line in f.readlines():
        if 'PID' in line:
            router_pid = line.split(':')[-1].strip()
            break
assert router_pid is not None


query_pid = None
with open(log_files['query']) as f:
    for line in f.readlines():
        if 'PID' in line:
            query_pid = line.split(':')[-1].strip()
            break
assert query_pid is not None

peer_pid = []
with open(log_files['eval']) as f:
    for line in f.readlines():
        if 'PID' in line:
            peer_pid.append(line.split(':')[-1].strip())
assert len(set(peer_pid)) == num_peers

# pid -> node name
node_mapping = {router_pid: 'RO'}
node_mapping.update({pid: 'P%d' % (idx + 1) for (idx, pid) in enumerate(peer_pid)})
node_mapping.update({query_pid: 'QU'})
nodes = list(node_mapping.values())
#  print(node_mapping)
import json

with open(args.in_dir / 'node_mapping.json', 'w') as f:
    json.dump(node_mapping, f, indent=4)

dot_files = sorted(list(
    (args.in_dir / 'network').glob('**/*.dot')
), key=lambda p: p.stem)
start_time = int(dot_files[0].stem)


def plot_graph(dot_file, title, out_file):
    # clique including query
    pos = nx.circular_layout(node_mapping.values())

    # consider query using client mode
    pos = nx.circular_layout([n for n in node_mapping.values() if n != 'QU'])
    pos['QU'] = np.array([1.5, 0])

    graph = nx.nx_pydot.read_dot(dot_file)
    remap = {
        k: node_mapping[v['label'].strip('"')]
        for (k, v) in graph._node.items()
    }
    graph = nx.relabel_nodes(graph, remap)

    scouted = list(graph.nodes)
    for node in nodes:
        if node not in scouted:
            graph.add_node(node)

    color_map = ['green' if n in scouted else 'red' for n in graph]

    fig, axes = plt.subplots(
        nrows=1,
        ncols=2,
        gridspec_kw={'width_ratios': [2, 1]},
        figsize=(12, 7.5)
    )
    fig.suptitle(title)

    nx.draw_networkx(
        graph,
        pos,
        ax=axes[0],
        with_labels=True,
        node_size=800,
        node_color=color_map,
        alpha=0.5
    )
    axes[0].set_title('Graph')
    axes[0].axis('equal')
    axes[0].set_axis_off()

    degrees = [graph.degree[n] for n in nodes]
    axes[1].set_title('Degrees')
    axes[1].set_xticks(range(0, len(nodes), 5))
    axes[1].set_xlim([0, len(nodes)])
    bars = axes[1].barh(nodes, degrees)
    axes[1].bar_label(bars)

    plt.tight_layout()
    plt.savefig(out_file, dpi=100)
    plt.close(fig)


def job(dot_file):
    timestamp = int(dot_file.stem) - start_time
    pid = str(dot_file).split('/')[-2]
    node_name = node_mapping[pid]
    out_dir = args.in_dir / args.out_dir / node_name
    out_dir.mkdir(parents=True, exist_ok=True)
    title = '[%s] Timestamp: %d (ns)' % (node_name, timestamp)
    out_file = out_dir / ('%d.png' % timestamp)
    plot_graph(dot_file, title, out_file)


with Pool() as pool:
    list(tqdm(pool.imap_unordered(job, dot_files), total=len(dot_files)))
