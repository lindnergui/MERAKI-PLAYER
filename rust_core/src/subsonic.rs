use std::time::Duration;

use futures::stream::{self, StreamExt, TryStreamExt};
use reqwest::{Client, Url};
use serde::Deserialize;
use uuid::Uuid;

use crate::error::{CoreError, CoreResult};
use crate::models::{Song, SongSource};

const API_VERSION: &str = "1.16.1";
const CLIENT_NAME: &str = "meraki";
const ALBUM_PAGE_SIZE: usize = 500;
const MAX_CONCURRENT_ALBUM_REQUESTS: usize = 8;

pub(crate) async fn fetch_songs(
    server_url: &str,
    username: &str,
    password: &str,
) -> CoreResult<Vec<Song>> {
    let client = SubsonicClient::new(server_url, username, password)?;
    client.fetch_all_songs().await
}

#[derive(Clone)]
struct SubsonicClient {
    http: Client,
    rest_base_url: String,
    username: String,
    token: String,
    salt: String,
    server_scope: String,
}

impl SubsonicClient {
    fn new(server_url: &str, username: &str, password: &str) -> CoreResult<Self> {
        let normalized_server_url = server_url.trim().trim_end_matches('/');
        let parsed = Url::parse(normalized_server_url).map_err(|error| {
            CoreError::InvalidInput(format!("invalid Subsonic server URL: {error}"))
        })?;

        if !matches!(parsed.scheme(), "http" | "https") {
            return Err(CoreError::InvalidInput(
                "Subsonic server URL must use http or https".to_owned(),
            ));
        }
        if !parsed.username().is_empty() || parsed.password().is_some() {
            return Err(CoreError::InvalidInput(
                "put Subsonic credentials in the username/password fields, not in the URL"
                    .to_owned(),
            ));
        }
        if parsed.query().is_some() || parsed.fragment().is_some() {
            return Err(CoreError::InvalidInput(
                "Subsonic server URL must not contain a query string or fragment".to_owned(),
            ));
        }

        let rest_base_url = if normalized_server_url.ends_with("/rest") {
            normalized_server_url.to_owned()
        } else {
            format!("{normalized_server_url}/rest")
        };

        let salt = Uuid::new_v4().simple().to_string();
        let token = format!("{:x}", md5::compute(format!("{password}{salt}")));
        let scope_digest = format!("{:x}", md5::compute(normalized_server_url));
        let server_scope = scope_digest[..12].to_owned();

        Ok(Self {
            http: Client::builder()
                .connect_timeout(Duration::from_secs(10))
                .timeout(Duration::from_secs(30))
                .user_agent("Meraki/0.1")
                .build()?,
            rest_base_url,
            username: username.to_owned(),
            token,
            salt,
            server_scope,
        })
    }

    async fn fetch_all_songs(&self) -> CoreResult<Vec<Song>> {
        self.ping().await?;

        let album_ids = self.fetch_album_ids().await?;
        let song_batches = stream::iter(album_ids)
            .map(|album_id| {
                let client = self.clone();
                async move { client.fetch_album_songs(&album_id).await }
            })
            .buffer_unordered(MAX_CONCURRENT_ALBUM_REQUESTS)
            .try_collect::<Vec<_>>()
            .await?;

        let mut songs = song_batches.into_iter().flatten().collect::<Vec<_>>();
        songs.sort_unstable_by(|left, right| {
            left.artist
                .cmp(&right.artist)
                .then_with(|| left.album.cmp(&right.album))
                .then_with(|| left.title.cmp(&right.title))
        });
        Ok(songs)
    }

    async fn ping(&self) -> CoreResult<()> {
        let response = self.get_envelope("ping", &[]).await?;
        response.ensure_ok()
    }

    async fn fetch_album_ids(&self) -> CoreResult<Vec<String>> {
        let mut album_ids = Vec::new();
        let mut offset = 0;

        loop {
            let size = ALBUM_PAGE_SIZE.to_string();
            let offset_value = offset.to_string();
            let response = self
                .get_envelope(
                    "getAlbumList2",
                    &[
                        ("type", "alphabeticalByName"),
                        ("size", &size),
                        ("offset", &offset_value),
                    ],
                )
                .await?;
            response.ensure_ok()?;

            let page = response
                .album_list
                .map(|list| list.albums)
                .unwrap_or_default();
            let page_len = page.len();
            album_ids.extend(page.into_iter().map(|album| album.id));

            if page_len < ALBUM_PAGE_SIZE {
                break;
            }
            offset += page_len;
        }

        Ok(album_ids)
    }

    async fn fetch_album_songs(&self, album_id: &str) -> CoreResult<Vec<Song>> {
        let response = self
            .get_envelope("getAlbum", &[("id", album_id)])
            .await?;
        response.ensure_ok()?;

        Ok(response
            .album
            .map(|album| album.songs)
            .unwrap_or_default()
            .into_iter()
            .map(|song| self.to_song(song))
            .collect())
    }

    fn to_song(&self, remote: SubsonicSong) -> Song {
        let stream_url = self
            .endpoint_url("stream", &[("id", remote.id.as_str())])
            .to_string();
        let cover_art_url_or_path = remote.cover_art.as_deref().map(|cover_art_id| {
            self.endpoint_url("getCoverArt", &[("id", cover_art_id)])
                .to_string()
        });

        Song {
            id: format!("subsonic:{}:{}", self.server_scope, remote.id),
            title: remote.title,
            artist: normalized(remote.artist),
            album: normalized(remote.album),
            cover_art_url_or_path,
            stream_url_or_file_path: stream_url,
            duration_seconds: remote.duration,
            source: SongSource::Subsonic,
        }
    }

    async fn get_envelope(
        &self,
        method: &str,
        extra_query: &[(&str, &str)],
    ) -> CoreResult<SubsonicResponse> {
        let response = self
            .http
            .get(self.endpoint_url(method, extra_query))
            .send()
            .await?;
        if response.status() == reqwest::StatusCode::NOT_FOUND {
            return Err(CoreError::Subsonic(
                "API Subsonic não encontrada. Se o servidor for Jellyfin, selecione Jellyfin nas configurações.".to_owned(),
            ));
        }
        let response = response
            .error_for_status()?
            .json::<SubsonicEnvelope>()
            .await?;

        Ok(response.response)
    }

    fn endpoint_url(&self, method: &str, extra_query: &[(&str, &str)]) -> Url {
        let mut url = Url::parse(&format!("{}/{method}.view", self.rest_base_url))
            .expect("validated Subsonic base URL");
        {
            let mut query = url.query_pairs_mut();
            query
                .append_pair("u", &self.username)
                .append_pair("t", &self.token)
                .append_pair("s", &self.salt)
                .append_pair("v", API_VERSION)
                .append_pair("c", CLIENT_NAME)
                .append_pair("f", "json");
            for (key, value) in extra_query {
                query.append_pair(key, value);
            }
        }
        url
    }
}

#[derive(Debug, Deserialize)]
struct SubsonicEnvelope {
    #[serde(rename = "subsonic-response")]
    response: SubsonicResponse,
}

#[derive(Debug, Deserialize)]
struct SubsonicResponse {
    status: String,
    #[serde(default)]
    error: Option<SubsonicApiError>,
    #[serde(rename = "albumList2", default)]
    album_list: Option<AlbumList>,
    #[serde(default)]
    album: Option<AlbumDetails>,
}

impl SubsonicResponse {
    fn ensure_ok(&self) -> CoreResult<()> {
        if self.status == "ok" {
            return Ok(());
        }

        let message = self.error.as_ref().map_or_else(
            || format!("server returned status '{}'", self.status),
            |error| format!("{} (code {})", error.message, error.code),
        );
        Err(CoreError::Subsonic(message))
    }
}

#[derive(Debug, Deserialize)]
struct SubsonicApiError {
    code: i32,
    message: String,
}

#[derive(Debug, Deserialize)]
struct AlbumList {
    #[serde(rename = "album", default)]
    albums: Vec<AlbumReference>,
}

#[derive(Debug, Deserialize)]
struct AlbumReference {
    id: String,
}

#[derive(Debug, Deserialize)]
struct AlbumDetails {
    #[serde(rename = "song", default)]
    songs: Vec<SubsonicSong>,
}

#[derive(Debug, Deserialize)]
struct SubsonicSong {
    id: String,
    title: String,
    #[serde(default)]
    artist: Option<String>,
    #[serde(default)]
    album: Option<String>,
    #[serde(rename = "coverArt", default)]
    cover_art: Option<String>,
    #[serde(default)]
    duration: Option<u32>,
}

fn normalized(value: Option<String>) -> Option<String> {
    value
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn builds_token_authenticated_urls_without_plaintext_password() {
        let client = SubsonicClient::new("https://music.example.test", "alice", "secret")
            .expect("Subsonic client");
        let url = client.endpoint_url("ping", &[]).to_string();

        assert!(url.contains("u=alice"));
        assert!(url.contains("t="));
        assert!(url.contains("s="));
        assert!(!url.contains("secret"));
        assert!(!url.contains("p="));
    }
}
