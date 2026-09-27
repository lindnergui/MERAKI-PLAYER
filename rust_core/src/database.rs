use std::path::{Path, PathBuf};
use std::sync::OnceLock;

use rusqlite::{Connection, params};
use tokio::sync::RwLock;
use tokio::task;

use crate::error::{CoreError, CoreResult};
use crate::models::{Song, SongSource};

static DATABASE_PATH: OnceLock<RwLock<Option<PathBuf>>> = OnceLock::new();

fn database_path_slot() -> &'static RwLock<Option<PathBuf>> {
    DATABASE_PATH.get_or_init(|| RwLock::new(None))
}

pub(crate) async fn init(path: PathBuf) -> CoreResult<()> {
    validate_database_path(&path)?;
    let path_for_task = path.clone();

    task::spawn_blocking(move || initialize_connection(&path_for_task))
        .await
        .map_err(|error| CoreError::BackgroundTask(error.to_string()))??;

    *database_path_slot().write().await = Some(path);
    Ok(())
}

pub(crate) async fn replace_source(source: SongSource, songs: Vec<Song>) -> CoreResult<()> {
    let path = configured_path().await?;

    task::spawn_blocking(move || {
        let mut connection = open_connection(&path)?;
        let transaction = connection.transaction()?;

        transaction.execute(
            "DELETE FROM songs WHERE source = ?1",
            params![source.as_db_value()],
        )?;

        {
            let mut statement = transaction.prepare(
                "INSERT INTO songs (
                    id,
                    title,
                    artist,
                    album,
                    cover_art_url_or_path,
                    stream_url_or_file_path,
                    duration_seconds,
                    source
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            )?;

            for song in &songs {
                statement.execute(params![
                    song.id,
                    song.title,
                    song.artist,
                    song.album,
                    song.cover_art_url_or_path,
                    song.stream_url_or_file_path,
                    song.duration_seconds,
                    song.source.as_db_value(),
                ])?;
            }
        }

        transaction.commit()?;
        Ok(())
    })
    .await
    .map_err(|error| CoreError::BackgroundTask(error.to_string()))?
}

pub(crate) async fn get_all_songs() -> CoreResult<Vec<Song>> {
    let path = configured_path().await?;

    task::spawn_blocking(move || {
        let connection = open_connection(&path)?;
        let mut statement = connection.prepare(
            "SELECT
                id,
                title,
                artist,
                album,
                cover_art_url_or_path,
                stream_url_or_file_path,
                duration_seconds,
                source
             FROM songs
             ORDER BY artist COLLATE NOCASE, album COLLATE NOCASE, title COLLATE NOCASE",
        )?;

        let rows = statement.query_map([], song_from_row)?;
        rows.collect::<Result<Vec<_>, _>>().map_err(CoreError::from)
    })
    .await
    .map_err(|error| CoreError::BackgroundTask(error.to_string()))?
}

async fn configured_path() -> CoreResult<PathBuf> {
    database_path_slot()
        .read()
        .await
        .clone()
        .ok_or(CoreError::DatabaseNotInitialized)
}

fn validate_database_path(path: &Path) -> CoreResult<()> {
    if path.as_os_str().is_empty() {
        return Err(CoreError::InvalidInput(
            "database path must not be empty".to_owned(),
        ));
    }

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    Ok(())
}

fn initialize_connection(path: &Path) -> CoreResult<()> {
    let mut connection = open_connection(path)?;
    let version = connection.query_row("PRAGMA user_version", [], |row| row.get::<_, u32>(0))?;

    match version {
        0 => {
            let transaction = connection.transaction()?;
            transaction.execute_batch(
                "CREATE TABLE IF NOT EXISTS songs (
                    id                       TEXT PRIMARY KEY NOT NULL,
                    title                    TEXT NOT NULL,
                    artist                   TEXT,
                    album                    TEXT,
                    cover_art_url_or_path    TEXT,
                    stream_url_or_file_path  TEXT NOT NULL,
                    duration_seconds         INTEGER,
                    source                   TEXT NOT NULL CHECK (source IN ('local', 'subsonic', 'jellyfin'))
                );

                CREATE INDEX IF NOT EXISTS idx_songs_source ON songs(source);
                CREATE INDEX IF NOT EXISTS idx_songs_library_order
                    ON songs(artist, album, title);

                PRAGMA user_version = 2;",
            )?;
            transaction.commit()?;
            Ok(())
        }
        1 => {
            // SQLite exige recriar a tabela para ampliar a restrição CHECK.
            // A transação preserva todo o catálogo existente em caso de falha.
            let transaction = connection.transaction()?;
            transaction.execute_batch(
                "CREATE TABLE songs_v2 (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    artist TEXT,
                    album TEXT,
                    cover_art_url_or_path TEXT,
                    stream_url_or_file_path TEXT NOT NULL,
                    duration_seconds INTEGER,
                    source TEXT NOT NULL CHECK (source IN ('local', 'subsonic', 'jellyfin'))
                );
                INSERT INTO songs_v2 SELECT * FROM songs;
                DROP TABLE songs;
                ALTER TABLE songs_v2 RENAME TO songs;
                CREATE INDEX idx_songs_source ON songs(source);
                CREATE INDEX idx_songs_library_order ON songs(artist, album, title);
                PRAGMA user_version = 2;",
            )?;
            transaction.commit()?;
            Ok(())
        }
        2 => Ok(()),
        other => Err(CoreError::UnsupportedDatabaseVersion(other)),
    }
}

fn open_connection(path: &Path) -> CoreResult<Connection> {
    let connection = Connection::open(path)?;
    connection.execute_batch(
        "PRAGMA foreign_keys = ON;
         PRAGMA journal_mode = WAL;
         PRAGMA synchronous = NORMAL;
         PRAGMA busy_timeout = 5000;",
    )?;
    Ok(connection)
}

fn song_from_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Song> {
    let source_value: String = row.get(7)?;
    let source = SongSource::from_db_value(&source_value).ok_or_else(|| {
        rusqlite::Error::FromSqlConversionFailure(
            7,
            rusqlite::types::Type::Text,
            std::io::Error::new(
                std::io::ErrorKind::InvalidData,
                format!("unknown song source: {source_value}"),
            )
            .into(),
        )
    })?;

    Ok(Song {
        id: row.get(0)?,
        title: row.get(1)?,
        artist: row.get(2)?,
        album: row.get(3)?,
        cover_art_url_or_path: row.get(4)?,
        stream_url_or_file_path: row.get(5)?,
        duration_seconds: row.get(6)?,
        source,
    })
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[tokio::test]
    async fn replaces_one_source_without_removing_the_other() {
        let directory = tempdir().expect("temporary directory");
        let path = directory.path().join("catalog.sqlite3");
        init(path).await.expect("database initialization");

        replace_source(SongSource::Local, vec![song("local:1", SongSource::Local)])
            .await
            .expect("local insert");
        replace_source(
            SongSource::Subsonic,
            vec![song("subsonic:1", SongSource::Subsonic)],
        )
        .await
        .expect("Subsonic insert");

        let songs = get_all_songs().await.expect("catalog query");
        assert_eq!(songs.len(), 2);
        replace_source(SongSource::Jellyfin, vec![song("jellyfin:1", SongSource::Jellyfin)])
            .await.unwrap();
        assert_eq!(get_all_songs().await.unwrap().len(), 3);
        replace_source(SongSource::Jellyfin, vec![]).await.unwrap();
        assert_eq!(get_all_songs().await.unwrap().len(), 2);
    }

    #[test]
    fn migra_catalogo_antigo_sem_perder_musicas() {
        let directory = tempdir().unwrap();
        let path = directory.path().join("antigo.sqlite3");
        let connection = Connection::open(&path).unwrap();
        connection.execute_batch(
            "CREATE TABLE songs (
                id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, artist TEXT,
                album TEXT, cover_art_url_or_path TEXT, stream_url_or_file_path TEXT NOT NULL,
                duration_seconds INTEGER, source TEXT NOT NULL CHECK (source IN ('local', 'subsonic'))
            );
            INSERT INTO songs VALUES ('local:1', 'Local', NULL, NULL, NULL, '/music.ogg', 10, 'local');
            INSERT INTO songs VALUES ('subsonic:1', 'Remota', NULL, NULL, NULL, 'https://example.test', 20, 'subsonic');
            PRAGMA user_version = 1;"
        ).unwrap();
        drop(connection);
        initialize_connection(&path).unwrap();
        initialize_connection(&path).unwrap();
        let connection = Connection::open(&path).unwrap();
        assert_eq!(connection.query_row("SELECT COUNT(*) FROM songs", [], |row| row.get::<_, i32>(0)).unwrap(), 2);
        assert_eq!(connection.query_row("PRAGMA user_version", [], |row| row.get::<_, i32>(0)).unwrap(), 2);
        connection.execute("INSERT INTO songs (id, title, stream_url_or_file_path, source) VALUES ('jellyfin:1', 'Nova', 'https://example.test', 'jellyfin')", []).unwrap();
    }

    fn song(id: &str, source: SongSource) -> Song {
        Song {
            id: id.to_owned(),
            title: id.to_owned(),
            artist: None,
            album: None,
            cover_art_url_or_path: None,
            stream_url_or_file_path: id.to_owned(),
            duration_seconds: None,
            source,
        }
    }
}
