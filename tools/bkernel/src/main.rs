//! `BKernel` build and validation command-line tool.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};

const VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, PartialEq, Eq)]
struct SourcePin {
    version: String,
    archive: String,
    url: String,
    sha256: String,
    top_dir: String,
}

fn print_help() {
    println!(
        "bkernel {VERSION}\n\
         Rust tooling for reproducible BubbleOS Linux kernel builds.\n\n\
         USAGE:\n    bkernel <COMMAND>\n\n\
         COMMANDS:\n\
         \thelp, --help       Show this help\n\
         \tversion, --version Show tool version\n\
         \tstatus             Show scaffold status\n\
         \tsource verify [FILE]  Verify the pinned source archive\n\
         \tsource fetch [DIR]    Download, verify and extract pinned source"
    );
}

fn manifest_value<'a>(manifest: &'a str, key: &str) -> Result<&'a str, String> {
    for line in manifest.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((candidate, value)) = line.split_once('=') {
            if candidate.trim() == key {
                return Ok(value.trim().trim_matches('"'));
            }
        }
    }
    Err(format!("missing '{key}' in kernel-source.toml"))
}

fn load_source_pin(manifest_path: &Path) -> Result<SourcePin, String> {
    let manifest = fs::read_to_string(manifest_path)
        .map_err(|error| format!("cannot read {}: {error}", manifest_path.display()))?;
    let pin = SourcePin {
        version: manifest_value(&manifest, "version")?.to_owned(),
        archive: manifest_value(&manifest, "archive")?.to_owned(),
        url: manifest_value(&manifest, "url")?.to_owned(),
        sha256: manifest_value(&manifest, "sha256")?.to_owned(),
        top_dir: manifest_value(&manifest, "top_dir")?.to_owned(),
    };

    if pin.archive.is_empty()
        || pin.archive.contains('/')
        || pin.archive.contains('\\')
        || pin.top_dir.is_empty()
        || pin.top_dir.contains('/')
        || pin.top_dir.contains('\\')
    {
        return Err("unsafe archive or top_dir in source manifest".to_owned());
    }
    if pin.sha256.len() != 64 || !pin.sha256.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        return Err("source manifest contains an invalid SHA-256 digest".to_owned());
    }
    if !pin.url.starts_with("https://") {
        return Err("source archive URL must use HTTPS".to_owned());
    }

    Ok(pin)
}

fn verify_archive(path: &Path, expected_sha256: &str) -> Result<(), String> {
    if !path.is_file() {
        return Err(format!("source archive does not exist: {}", path.display()));
    }

    let output = Command::new("sha256sum")
        .arg(path)
        .output()
        .map_err(|error| format!("cannot execute sha256sum: {error}"))?;
    if !output.status.success() {
        return Err("sha256sum failed".to_owned());
    }

    let stdout = String::from_utf8(output.stdout)
        .map_err(|error| format!("sha256sum returned non-UTF-8 output: {error}"))?;
    let actual = stdout
        .split_whitespace()
        .next()
        .ok_or_else(|| "sha256sum returned an empty result".to_owned())?;

    if !actual.eq_ignore_ascii_case(expected_sha256) {
        return Err(format!(
            "SHA-256 mismatch for {}: expected {}, got {}",
            path.display(),
            expected_sha256,
            actual
        ));
    }

    println!("SHA-256 verified: {actual}  {}", path.display());
    Ok(())
}

fn fetch_source(cache_dir: &Path, pin: &SourcePin) -> Result<(), String> {
    fs::create_dir_all(cache_dir)
        .map_err(|error| format!("cannot create {}: {error}", cache_dir.display()))?;

    let archive_path = cache_dir.join(&pin.archive);
    if archive_path.exists() {
        match verify_archive(&archive_path, &pin.sha256) {
            Ok(()) => println!(
                "Using already verified Linux {} source archive",
                pin.version
            ),
            Err(_) => {
                fs::remove_file(&archive_path).map_err(|error| {
                    format!(
                        "cannot remove invalid archive {}: {error}",
                        archive_path.display()
                    )
                })?;
            }
        }
    }

    if !archive_path.exists() {
        let temporary_path = cache_dir.join(format!("{}.part", pin.archive));
        if temporary_path.exists() {
            fs::remove_file(&temporary_path).map_err(|error| {
                format!(
                    "cannot remove stale download {}: {error}",
                    temporary_path.display()
                )
            })?;
        }

        println!(
            "Downloading Linux {} from the pinned HTTPS URL",
            pin.version
        );
        let status = Command::new("curl")
            .args([
                "--fail",
                "--location",
                "--silent",
                "--show-error",
                "--proto",
                "=https",
                "--tlsv1.2",
                "--retry",
                "3",
                "--output",
            ])
            .arg(&temporary_path)
            .arg(&pin.url)
            .status()
            .map_err(|error| format!("cannot execute curl: {error}"))?;

        if !status.success() {
            let _ = fs::remove_file(&temporary_path);
            return Err("source download failed".to_owned());
        }

        if let Err(error) = verify_archive(&temporary_path, &pin.sha256) {
            let _ = fs::remove_file(&temporary_path);
            return Err(error);
        }

        fs::rename(&temporary_path, &archive_path)
            .map_err(|error| format!("cannot finalize source archive: {error}"))?;
    }

    verify_archive(&archive_path, &pin.sha256)?;

    let source_dir = cache_dir.join(&pin.top_dir);
    if source_dir.exists() {
        fs::remove_dir_all(&source_dir)
            .map_err(|error| format!("cannot clean old source tree: {error}"))?;
    }

    let status = Command::new("tar")
        .arg("--extract")
        .arg("--xz")
        .arg("--file")
        .arg(&archive_path)
        .arg("--directory")
        .arg(cache_dir)
        .status()
        .map_err(|error| format!("cannot execute tar: {error}"))?;

    if !status.success() {
        return Err("source archive extraction failed".to_owned());
    }
    if !source_dir.is_dir() {
        return Err(format!(
            "archive did not contain the expected directory '{}'",
            pin.top_dir
        ));
    }

    println!(
        "Verified Linux {} source extracted to {}",
        pin.version,
        source_dir.display()
    );
    Ok(())
}

fn run() -> Result<(), String> {
    let mut args = env::args().skip(1);
    match args.next().as_deref() {
        None | Some("help" | "--help" | "-h") => print_help(),
        Some("version" | "--version" | "-V") => println!("bkernel {VERSION}"),
        Some("status") => {
            println!("BKernel tooling: initialized");
            println!("Kernel source pin: Linux 7.3.4");
            println!("Kernel build: not enabled yet; toolchain and config pinning are next");
            println!("Rust tooling: pinned by rust-toolchain.toml");
        }
        Some("source") => {
            let operation = args.next().ok_or_else(|| {
                "missing source operation; use 'source verify' or 'source fetch'".to_owned()
            })?;
            let manifest_path =
                Path::new(env!("CARGO_MANIFEST_DIR")).join("../../kernel-source.toml");
            let pin = load_source_pin(&manifest_path)?;

            match operation.as_str() {
                "verify" => {
                    let archive = args
                        .next()
                        .map_or_else(|| PathBuf::from("target/sources").join(&pin.archive), PathBuf::from);
                    verify_archive(&archive, &pin.sha256)?;
                }
                "fetch" => {
                    let cache_dir = args
                        .next()
                        .map_or_else(|| PathBuf::from("target/sources"), PathBuf::from);
                    fetch_source(&cache_dir, &pin)?;
                }
                _ => return Err(format!("unknown source operation: {operation}")),
            }
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
    use super::{load_source_pin, manifest_value, SourcePin};

    #[test]
    fn parses_manifest_values() {
        let manifest = "version = \"7.3.4\"\nsha256 = \"abc\"\n";
        assert_eq!(manifest_value(manifest, "version"), Ok("7.3.4"));
        assert_eq!(manifest_value(manifest, "sha256"), Ok("abc"));
        assert!(manifest_value(manifest, "missing").is_err());
    }

    #[test]
    fn parses_pinned_source_manifest() {
        let manifest = concat!(
            "version = \"7.3.4\"\n",
            "archive = \"linux-7.3.4.tar.xz\"\n",
            "url = \"https://cdn.kernel.org/linux-7.3.4.tar.xz\"\n",
            "sha256 = \"b11b6df8295e8e991ff040b71aaa4994a8b55caa23b6b092907f195b5840fd1f\"\n",
            "top_dir = \"linux-7.3.4\"\n"
        );
        let pin = SourcePin {
            version: "7.3.4".to_owned(),
            archive: "linux-7.3.4.tar.xz".to_owned(),
            url: "https://cdn.kernel.org/linux-7.3.4.tar.xz".to_owned(),
            sha256: "b11b6df8295e8e991ff040b71aaa4994a8b55caa23b6b092907f195b5840fd1f".to_owned(),
            top_dir: "linux-7.3.4".to_owned(),
        };
        let path =
            std::env::temp_dir().join(format!("bkernel-manifest-test-{}", std::process::id()));
        std::fs::write(&path, manifest).expect("write temporary test manifest");
        assert_eq!(load_source_pin(&path).expect("valid source pin"), pin);
        std::fs::remove_file(path).expect("remove temporary test manifest");
    }
}
