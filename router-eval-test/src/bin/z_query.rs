use futures::prelude::stream::{StreamExt, TryStreamExt};
use clap::Parser;
use zenoh::config::Config;
use zenoh::prelude::SplitBuffer;
use zenoh_protocol_core::WhatAmI;
use std::time::Duration;


type Error = Box<dyn std::error::Error + Send + Sync>;
type Result<T, E = Error> = std::result::Result<T, E>;

#[derive(Parser)]
struct Args {
    #[clap(short, long)]
    disable_multicast: bool,

    #[clap(short, long, default_value = "peer")]
    mode: WhatAmI,

    #[clap(short, long)]
    connect: Option<String>,

    #[clap(short, long, default_value = "30")]
    timeout: u64,
}

#[async_std::main]
async fn main() -> Result<()> {
    let Args {
        disable_multicast,
        connect,
        mode,
        timeout,
    } = Args::parse();

    let config = {
        let mut config = Config::default();
        if disable_multicast {
            config.scouting.multicast.set_enabled(Some(false)).unwrap();
        }
        if let Some(x) = connect {
            config.connect.endpoints.extend(vec![x.try_into()?]);
        }

        config.set_mode(Some(mode)).unwrap();
        config
    };

    let session = zenoh::open(config).await?;
    println!("[Query] PID: {}", session.id().await);
    let num_replied = session
        .get("/key/*")
        .await?
        .as_trystream()
        .take_until(
            async move {
                async_std::task::sleep(Duration::from_secs(timeout)).await;
            }
        )
        .and_then(|reply| async move {
            println!(
                "[Query] Received reply '{}' from '{}'",
                String::from_utf8_lossy(&reply.sample.value.payload.contiguous()),
                reply.sample.key_expr.as_str()
            );
            Result::<_, Error>::Ok(())
        })
        .count()
        .await;

    println!("[Query] Ended with {} peers replied.", num_replied);

    Ok(())
}
