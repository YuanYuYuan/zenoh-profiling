use zenoh::{
    prelude::Sample,
    config::Config,
    queryable::EVAL,
};
use async_std::stream::StreamExt;
use clap::Parser;

// #[cfg(feature = "dhat-heap")]
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

type Error = Box<dyn std::error::Error + Send + Sync>;
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Parser)]
struct Args {
    #[clap(short, long)]
    num_peers: usize,

    #[clap(short, long)]
    disable_multicast: bool,

    #[clap(short, long)]
    connect: Option<String>,
}

#[async_std::main]
async fn main() -> Result<()> {
    let _profiler = dhat::Profiler::new_heap();

    let Args {
        num_peers,
        disable_multicast,
        connect,
    } = Args::parse();


    let jobs = (0..num_peers).map(|idx| {
        let connect_ = connect.clone();
        async_std::task::spawn(async move {
            let config = {
                let mut config = Config::default();
                if disable_multicast {
                    config
                        .scouting
                        .multicast
                        .set_enabled(Some(false))
                        .unwrap();
                }
                if let Some(x) = connect_ {
                    config
                        .connect
                        .endpoints
                        .extend(vec![x.try_into()?]);
                }
                config
            };
            let session = zenoh::open(config).await?;
            let key_expr = format!("/key/{}", idx);
            let mut queryable = session
                .queryable(key_expr.clone())
                .kind(EVAL)
                .await
                .unwrap();
            while let Some(query) = queryable.next().await {
                println!("Received query: {}", query.selector());
                query.reply_async(Sample::new(
                    key_expr.clone(),
                    format!("Hi, I'm peer {}.", idx)
                )).await;
            }
            // queryable.close();
            // session.close();
            Result::<_, Error>::Ok(())
        })
    });

    futures::future::try_join_all(jobs).await?;

    Ok(())
}
