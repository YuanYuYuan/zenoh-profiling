use zenoh::{
    prelude::{Sample, r#async::AsyncResolve},
    config::Config,
    // queryable::EVAL,
};
// use async_std::stream::StreamExt;
use clap::Parser;
use rand::Rng;
// use rand::prelude::SliceRandom;
use futures::{future::{try_join_all, select}, FutureExt};
use std::time::Duration;
use std::path::PathBuf;

type Error = Box<dyn std::error::Error + Send + Sync>;
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Parser)]
struct Args {
    #[clap(short, long)]
    num_peers: usize,

    #[clap(short, long, parse(from_os_str))]
    config: PathBuf,

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
        config,
        timeout,
        peer_id_shift,
    } = Args::parse();


    let jobs = (0..num_peers).map(|idx| {
        let idx = idx + peer_id_shift;
        let mut rng = rand::thread_rng();
        let time = std::time::Duration::from_millis(rng.gen_range(0..1000));
        let config_path = config.clone();
        async_std::task::spawn(async move {
            async_std::task::sleep(time).await;
            let config = Config::from_file(config_path).unwrap();
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
