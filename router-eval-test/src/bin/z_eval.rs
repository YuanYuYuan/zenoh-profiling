use zenoh::{
    prelude::{Sample, r#async::AsyncResolve},
    config::Config,
    // queryable::EVAL,
};
// use async_std::stream::StreamExt;
use clap::Parser;
use rand::Rng;
// use rand::prelude::SliceRandom;
use zenoh_protocol_core::WhatAmI;
use futures::{future::{try_join_all, select}, FutureExt};
use std::time::Duration;

type Error = Box<dyn std::error::Error + Send + Sync>;
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Parser)]
struct Args {
    #[clap(short, long)]
    num_peers: usize,

    #[clap(short, long)]
    disable_multicast: bool,

    #[clap(short, long)]
    no_gossip: bool,

    #[clap(short, long)]
    use_peer_linkstate: bool,

    #[clap(short, long, default_value = "peer")]
    mode: WhatAmI,

    #[clap(short, long)]
    connect: Option<String>,

    #[clap(short, long, default_value = "30")]
    timeout: u64,

    #[clap(short, long, default_value = "0")]
    peer_id_shift: usize,
}

#[async_std::main]
async fn main() -> Result<()> {
    // // use this to capture warn & error while piping stdout/stderr to files
    // env_logger::init();

    let mut builder = env_logger::Builder::from_default_env();
    builder.format_timestamp_nanos().init();

    let Args {
        num_peers,
        disable_multicast,
        no_gossip,
        use_peer_linkstate,
        connect,
        mode,
        timeout,
        peer_id_shift,
    } = Args::parse();


    let jobs = (0..num_peers).map(|idx| {
        let idx = idx + peer_id_shift;
        let connect_ = connect.clone();
        let mut rng = rand::thread_rng();
        let time = std::time::Duration::from_millis(rng.gen_range(0..1000));
        // let choices = [0, 1000];
        // let time = std::time::Duration::from_millis(*[0, 1000].choose(&mut rng).unwrap());
        async_std::task::spawn(async move {
            async_std::task::sleep(time).await;
            let config = {
                let mut config = Config::default();
                if disable_multicast {
                    config
                        .scouting
                        .multicast
                        .set_enabled(Some(false))
                        .unwrap();
                }

                config
                    .scouting
                    .gossip
                    .set_enabled(Some(!no_gossip))
                    .unwrap();

                config
                    .routing
                    .peer
                    .set_mode(if use_peer_linkstate {
                        Some("linkstate".to_string())
                    } else {
                        Some("".to_string())
                    })
                    .unwrap();

                dbg!(config.routing().peer().mode());

                if let Some(x) = connect_ {
                    config
                        .connect
                        .endpoints
                        .extend(vec![x.try_into()?]);
                }

                config.set_mode(Some(mode)).unwrap();

                config
            };
            let session = zenoh::open(config).res().await.unwrap().into_arc();
            let key_expr = format!("key/{}", idx);
            let queryable = session
                .declare_queryable(key_expr.clone())
                .res()
                .await
                .unwrap();
            println!("[Eval] Peer #{} builds queryable at '/key/{}'", idx, idx);
            while let Ok(query) = queryable.recv_async().await {
                println!("[Eval] Peer #{} received query {}", idx, query.selector());
                let replied_text = Sample::try_from(key_expr.clone(), format!("Hi, I'm peer {}.", session.id())).unwrap();
                query.reply(Ok(replied_text)).res().await.unwrap();
            }
            // queryable.close();
            // session.close();
            Result::<_, Error>::Ok(())
        })
    });

    select(try_join_all(jobs), async_std::task::sleep(Duration::from_secs(timeout)).boxed()).await;

    println!("[Eval] Ended.");

    Ok(())
}
