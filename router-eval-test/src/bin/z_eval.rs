use zenoh::{
    prelude::Sample,
    config::Config,
    queryable::EVAL,
};
use async_std::stream::StreamExt;
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
    disable_peers_autoconnect: bool,

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
        disable_peers_autoconnect,
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
                if disable_peers_autoconnect {
                    config
                        .scouting
                        .set_peers_autoconnect(Some(false))
                        .unwrap();
                }
                if let Some(x) = connect_ {
                    config
                        .connect
                        .endpoints
                        .extend(vec![x.try_into()?]);
                }

                config.set_mode(Some(mode)).unwrap();

                config
            };
            let session = zenoh::open(config).await?;
            let key_expr = format!("/key/{}", idx);
            let mut queryable = session
                .queryable(key_expr.clone())
                .kind(EVAL)
                .await
                .unwrap();
            println!("[Eval] Peer #{} builds queryable at '/key/{}'", idx, idx);
            while let Some(query) = queryable.next().await {
                println!("[Eval] Peer #{} received query {}", idx, query.selector());
                query.reply_async(Sample::new(
                    key_expr.clone(),
                    format!("Hi, I'm peer {}.", session.id().await)
                )).await;
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
