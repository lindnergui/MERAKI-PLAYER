use thiserror::Error;

#[derive(Debug, Error)]
pub(crate) enum CoreError {
    #[error("database has not been initialized; call init_db first")]
    DatabaseNotInitialized,

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("filesystem error: {0}")]
    Io(#[from] std::io::Error),

    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),

    #[error("database schema version {0} is newer than this Meraki build supports")]
    UnsupportedDatabaseVersion(u32),

    #[error("HTTP error: {0}")]
    Http(reqwest::Error),

    #[error("background task failed: {0}")]
    BackgroundTask(String),

    #[error("Subsonic error: {0}")]
    Subsonic(String),

    #[error("Jellyfin: {0}")]
    Jellyfin(String),
}

impl From<reqwest::Error> for CoreError {
    fn from(error: reqwest::Error) -> Self {
        // URLs de mídia podem conter tokens; nunca mostrá-las nos erros.
        Self::Http(error.without_url())
    }
}

pub(crate) type CoreResult<T> = Result<T, CoreError>;
