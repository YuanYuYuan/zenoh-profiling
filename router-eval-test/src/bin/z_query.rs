use futures::prelude::stream::{
    StreamExt,
    // TryStreamExt
};
use clap::Parser;
use zenoh::config::Config;
use zenoh::prelude::SplitBuffer;
use std::time::Duration;
use zenoh::query::{QueryConsolidation, QueryTarget};
use zenoh::prelude::r#async::AsyncResolve;
use std::path::PathBuf;


type Error = Box<dyn std::error::Error + Send + Sync>;
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Parser)]
struct Args {
    #[clap(short, long, parse(from_os_str))]
    config: PathBuf,

    #[clap(short, long, default_value = "30")]
    timeout: u64,
}

#[async_std::main]
async fn main() -> Result<()> {
    let mut builder = env_logger::Builder::from_default_env();
    builder.format_timestamp_nanos().init();

    let Args {
        config,
        timeout,
    } = Args::parse();

    let config = Config::from_file(config).unwrap();
    let session = zenoh::open(config).res().await.unwrap().into_arc();
    println!("[Query] PID: {}", session.id());

    let num_replied = session
        .get("key/*")
        .target(QueryTarget::All)
        .timeout(Duration::from_millis(10000))
        .consolidation(QueryConsolidation::none())
        .res()
        .await?
        .stream()
        .take_until(
            async move {
                async_std::task::sleep(Duration::from_secs(timeout)).await;
            }
        )
        .map(|reply| {
            if let Ok(sample) = reply.sample {
                println!(
                    "[Query] Received reply '{}' from '{}'",
                    String::from_utf8_lossy(&sample.value.payload.contiguous()),
                    sample.key_expr.as_str()
                );
            }
        })
        .count()
        .await;

    println!("[Query] Ended with {} peers replied.", num_replied);

    Ok(())
}
