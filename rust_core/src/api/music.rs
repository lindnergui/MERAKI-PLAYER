use std::path::PathBuf;

use tokio::task;

use crate::database;
use crate::models::{Song, SongSource};
use crate::{jellyfin, scanner, subsonic};

/// Creates (or migrates) the catalog database and makes it active for later calls.
///
/// Flutter supplies the path because it owns the platform-aware application data
/// directory on both Android and Linux.
pub async fn init_db(database_path: String) -> Result<(), String> {
    let database_path = require_non_empty(database_path, "database_path")?;
    database::init(PathBuf::from(database_path))
        .await
        .map_err(|error| error.to_string())
}

/// Recursively scans a directory, reads audio tags with `lofty`, and replaces the
/// local portion of the catalog in one SQLite transaction.
pub async fn scan_local_music(path: String) -> Result<Vec<Song>, String> {
    let path = require_non_empty(path, "path")?;
    let root = PathBuf::from(path);

    // Filesystem traversal and metadata decoding are blocking operations. Moving
    // them to Tokio's blocking pool keeps the FRB async executor responsive.
    let songs = task::spawn_blocking(move || scanner::scan_directory(&root))
        .await
        .map_err(|error| format!("local music scan task failed: {error}"))?
        .map_err(|error| error.to_string())?;

    database::replace_source(SongSource::Local, songs.clone())
        .await
        .map_err(|error| error.to_string())?;

    Ok(songs)
}

/// Downloads the Subsonic catalog and atomically refreshes its SQLite cache.
///
/// The plaintext password is used only to create Subsonic token-authenticated
/// requests and is never written to the catalog database.
pub async fn fetch_subsonic_songs(
    server_url: String,
    username: String,
    password: String,
) -> Result<Vec<Song>, String> {
    let server_url = require_non_empty(server_url, "server_url")?;
    let username = require_non_empty(username, "username")?;
    let password = require_password(password)?;

    let songs = subsonic::fetch_songs(&server_url, &username, &password)
        .await
        .map_err(|error| error.to_string())?;

    database::replace_source(SongSource::Subsonic, songs.clone())
        .await
        .map_err(|error| error.to_string())?;

    Ok(songs)
}

/// Autentica no Jellyfin e atualiza apenas seu catálogo, sem armazenar a senha.
pub async fn fetch_jellyfin_songs(
    server_url: String,
    username: String,
    password: String,
) -> Result<Vec<Song>, String> {
    let server_url = require_non_empty(server_url, "server_url")?;
    let username = require_non_empty(username, "username")?;
    let password = require_password(password)?;
    let songs = jellyfin::fetch_songs(&server_url, &username, &password)
        .await
        .map_err(|error| error.to_string())?;
    database::replace_source(SongSource::Jellyfin, songs.clone())
        .await
        .map_err(|error| error.to_string())?;
    Ok(songs)
}

fn require_password(password: String) -> Result<String, String> {
    if password.is_empty() {
        Err("Informe a senha do servidor.".to_owned())
    } else {
        Ok(password)
    }
}

/// Returns the unified local + Subsonic + Jellyfin catalog.
pub async fn get_all_songs() -> Result<Vec<Song>, String> {
    database::get_all_songs()
        .await
        .map_err(|error| error.to_string())
}

fn require_non_empty(value: String, field: &str) -> Result<String, String> {
    let value = value.trim().to_owned();
    if value.is_empty() {
        Err(format!("{field} must not be empty"))
    } else {
        Ok(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preserva_senha_exatamente_como_digitada() {
        let password = "  senha &#+%\"  ";
        assert_eq!(require_password(password.into()).unwrap(), password);
        assert!(require_password(String::new()).is_err());
    }
}
