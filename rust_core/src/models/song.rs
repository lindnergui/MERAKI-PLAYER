/// Identifies which subsystem owns a catalog entry.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SongSource {
    Local,
    Subsonic,
    Jellyfin,
}

/// A playback-ready song shared by local and Subsonic libraries.
///
/// `stream_url_or_file_path` deliberately contains either an HTTP(S) URL or an
/// absolute local path so that Flutter can hand it directly to `just_audio`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Song {
    pub id: String,
    pub title: String,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub cover_art_url_or_path: Option<String>,
    pub stream_url_or_file_path: String,
    pub duration_seconds: Option<u32>,
    pub source: SongSource,
}

impl SongSource {
    pub(crate) const fn as_db_value(self) -> &'static str {
        match self {
            Self::Local => "local",
            Self::Subsonic => "subsonic",
            Self::Jellyfin => "jellyfin",
        }
    }

    pub(crate) fn from_db_value(value: &str) -> Option<Self> {
        match value {
            "local" => Some(Self::Local),
            "subsonic" => Some(Self::Subsonic),
            "jellyfin" => Some(Self::Jellyfin),
            _ => None,
        }
    }
}

