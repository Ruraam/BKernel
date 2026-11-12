//! BKernel build and validation command-line tool.

use std::env;
use std::process::ExitCode;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn print_help() {
    println!(
        "bkernel {VERSION}\n\
         Rust tooling for reproducible BubbleOS Linux kernel builds.\n\n\
         USAGE:\n    bkernel <COMMAND>\n\n\
         COMMANDS:\n\
         \thelp, --help       Show this help\n\
         \tversion, --version Show tool version\n\
         \tstatus             Show scaffold status"
    );
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    match args.next().as_deref() {
        None | Some("help") | Some("--help") | Some("-h") => print_help(),
        Some("version") | Some("--version") | Some("-V") => {
            println!("bkernel {VERSION}");
        }
        Some("status") => {
            println!("BKernel tooling: initialized");
            println!("Kernel source pin: not configured");
            println!("Kernel build: disabled until source and configuration are pinned");
            println!("Rust orchestration: available");
        }
        Some(command) => {
            return Err(format!("unknown command: {command}\nRun 'bkernel --help'."));
        }
    }

    if let Some(extra) = args.next() {
        return Err(format!("unexpected argument: {extra}"));
    }

    Ok(())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("bkernel: {error}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn version_is_defined() {
        assert!(!env!("CARGO_PKG_VERSION").is_empty());
    }
}
