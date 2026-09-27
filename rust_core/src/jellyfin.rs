use std::collections::HashMap;
use std::time::Duration;

use reqwest::{Client, Response, StatusCode, Url};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::{CoreError, CoreResult};
use crate::models::{Song, SongSource};

const PAGE_SIZE: usize = 500;

pub(crate) async fn fetch_songs(
    server_url: &str,
    username: &str,
    password: &str,
) -> CoreResult<Vec<Song>> {
    let mut client = JellyfinClient::new(server_url)?;
    client.authenticate(username, password).await?;
    client.fetch_all_songs().await
}

struct JellyfinClient {
    http: Client,
    base_url: Url,
    server_scope: String,
    token: String,
    user_id: String,
}

impl JellyfinClient {
    fn new(server_url: &str) -> CoreResult<Self> {
        let mut base_url = Url::parse(server_url.trim()).map_err(|_| {
            CoreError::InvalidInput("Informe uma URL válida do servidor Jellyfin.".into())
        })?;
        if !matches!(base_url.scheme(), "http" | "https")
            || base_url.host_str().is_none()
            || !base_url.username().is_empty()
            || base_url.password().is_some()
            || base_url.query().is_some()
            || base_url.fragment().is_some()
        {
            return Err(CoreError::InvalidInput(
                "Use a URL HTTP ou HTTPS do Jellyfin, sem credenciais, parâmetros ou fragmentos.".into(),
            ));
        }
        // Preserva instalações em subdiretórios, como https://host/jellyfin/.
        let path = format!("{}/", base_url.path().trim_end_matches('/'));
        base_url.set_path(&path);
        let server_scope = format!("{:x}", md5::compute(base_url.as_str()))[..12].to_owned();
        let device_id = Uuid::new_v4().simple().to_string();
        let mut headers = reqwest::header::HeaderMap::new();
        headers.insert(
            reqwest::header::AUTHORIZATION,
            format!(
                "MediaBrowser Client=\"Meraki\", Device=\"Meraki Player\", DeviceId=\"{device_id}\", Version=\"1.3.5\""
            )
            .parse()
            .expect("cabeçalho de identificação válido"),
        );
        Ok(Self {
            http: Client::builder()
                .connect_timeout(Duration::from_secs(10))
                .timeout(Duration::from_secs(30))
                // Evita encaminhar credenciais a outro endereço por redirecionamento.
                .redirect(reqwest::redirect::Policy::none())
                .default_headers(headers)
                .build()?,
            base_url,
            server_scope,
            token: String::new(),
            user_id: String::new(),
        })
    }

    fn endpoint(&self, segments: &[&str]) -> Url {
        let mut url = self.base_url.clone();
        url.path_segments_mut()
            .expect("URL HTTP validada")
            .pop_if_empty()
            .extend(segments.iter().copied());
        url
    }

    async fn authenticate(&mut self, username: &str, password: &str) -> CoreResult<()> {
        let response = self
            .http
            .post(self.endpoint(&["Users", "AuthenticateByName"]))
            .json(&Credentials { username, pw: password })
            .send()
            .await?;
        let session = checked(response)?.json::<Session>().await?;
        if session.access_token.is_empty() || session.user.id.is_empty() {
            return Err(CoreError::Jellyfin("O servidor retornou uma sessão inválida.".into()));
        }
        self.token = session.access_token;
        self.user_id = session.user.id;
        Ok(())
    }

    async fn fetch_all_songs(&self) -> CoreResult<Vec<Song>> {
        let mut songs = Vec::new();
        let mut offset = 0;
        loop {
            let response = self
                .http
                .get(self.endpoint(&["Users", &self.user_id, "Items"]))
                .header("X-Emby-Token", &self.token)
                .query(&[
                    ("IncludeItemTypes", "Audio".to_owned()),
                    ("Recursive", "true".to_owned()),
                    ("SortBy", "SortName".to_owned()),
                    ("SortOrder", "Ascending".to_owned()),
                    ("EnableTotalRecordCount", "true".to_owned()),
                    ("StartIndex", offset.to_string()),
                    ("Limit", PAGE_SIZE.to_string()),
                ])
                .send()
                .await?;
            let page = checked(response)?.json::<ItemPage>().await?;
            let count = page.items.len();
            songs.extend(page.items.into_iter().map(|item| self.to_song(item)));
            offset += count;
            if count == 0 || page.total_record_count.is_some_and(|total| offset >= total) {
                break;
            }
        }
        Ok(songs)
    }

    fn media_url(&self, segments: &[&str]) -> Url {
        let mut url = self.endpoint(segments);
        // just_audio e as capas recebem URLs; a senha nunca é persistida.
        url.query_pairs_mut().append_pair("api_key", &self.token);
        url
    }

    fn to_song(&self, item: AudioItem) -> Song {
        let mut stream_url = self.media_url(&["Audio", &item.id, "stream"]);
        stream_url.query_pairs_mut().append_pair("static", "true");
        let cover = if item.image_tags.contains_key("Primary") {
            Some(item.id.as_str())
        } else {
            item.album_primary_image_tag.as_ref().and(item.album_id.as_deref())
        };
        Song {
            id: format!("jellyfin:{}:{}", self.server_scope, item.id),
            title: item.name,
            artist: normalized(item.artists.map(|artists| artists.join(", ")))
                .or_else(|| normalized(item.album_artist)),
            album: normalized(item.album),
            cover_art_url_or_path: cover.map(|id| {
                self.media_url(&["Items", id, "Images", "Primary"]).to_string()
            }),
            stream_url_or_file_path: stream_url.to_string(),
            duration_seconds: item.run_time_ticks.and_then(|ticks| (ticks / 10_000_000).try_into().ok()),
            source: SongSource::Jellyfin,
        }
    }
}

fn checked(response: Response) -> CoreResult<Response> {
    let message = match response.status() {
        StatusCode::UNAUTHORIZED => "Usuário ou senha inválidos, ou sessão expirada. Sincronize novamente.",
        StatusCode::FORBIDDEN => "Este usuário não tem permissão para acessar o conteúdo no Jellyfin.",
        StatusCode::NOT_FOUND => "Jellyfin não encontrado. Confira a URL e o tipo de servidor selecionado.",
        status if status.is_redirection() => "O servidor redirecionou a conexão. Informe a URL final do Jellyfin.",
        status if status.is_success() => return Ok(response),
        _ => return Err(CoreError::Jellyfin(format!("O servidor respondeu com HTTP {}. Tente novamente.", response.status().as_u16()))),
    };
    Err(CoreError::Jellyfin(message.into()))
}

fn normalized(value: Option<String>) -> Option<String> {
    value.map(|value| value.trim().to_owned()).filter(|value| !value.is_empty())
}

#[derive(Serialize)]
#[serde(rename_all = "PascalCase")]
struct Credentials<'a> {
    username: &'a str,
    pw: &'a str,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct Session {
    access_token: String,
    user: User,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct User {
    id: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct ItemPage {
    items: Vec<AudioItem>,
    total_record_count: Option<usize>,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
struct AudioItem {
    id: String,
    name: String,
    artists: Option<Vec<String>>,
    album_artist: Option<String>,
    album: Option<String>,
    album_id: Option<String>,
    album_primary_image_tag: Option<String>,
    run_time_ticks: Option<u64>,
    #[serde(default)]
    image_tags: HashMap<String, String>,
}

#[cfg(test)]
mod tests {
    use std::io::{BufRead, BufReader, Read, Write};
    use std::net::TcpListener;
    use std::thread;

    use serde_json::{Value, json};

    use super::*;

    // Servidor HTTP real em loopback: verifica método, caminho, cabeçalhos e corpo.
    fn mock_server(responses: Vec<(u16, Value)>) -> (String, thread::JoinHandle<Vec<(String, String)>>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/jellyfin", listener.local_addr().unwrap());
        let handle = thread::spawn(move || {
            let mut requests = Vec::new();
            for (status, body) in responses {
                let (mut socket, _) = listener.accept().unwrap();
                socket.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
                let mut reader = BufReader::new(socket.try_clone().unwrap());
                let mut headers = String::new();
                let mut length = 0;
                loop {
                    let mut line = String::new();
                    reader.read_line(&mut line).unwrap();
                    if line == "\r\n" || line.is_empty() { break; }
                    if let Some(value) = line.to_lowercase().strip_prefix("content-length:") {
                        length = value.trim().parse().unwrap();
                    }
                    headers.push_str(&line);
                }
                let mut payload = vec![0; length];
                reader.read_exact(&mut payload).unwrap();
                requests.push((headers, String::from_utf8(payload).unwrap()));
                let body = body.to_string();
                write!(socket, "HTTP/1.1 {status} Test\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len()).unwrap();
            }
            requests
        });
        (url, handle)
    }

    fn session() -> Value {
        json!({"AccessToken": "token-de-teste", "User": {"Id": "usuario"}})
    }

    #[tokio::test]
    async fn autentica_pagina_e_monta_urls_de_audio_e_capa() {
        let (url, server) = mock_server(vec![
            (200, session()),
            (200, json!({"TotalRecordCount": 2, "Items": [{
                "Id": "faixa1", "Name": "Faixa 1", "Artists": ["Artista"],
                "Album": "Álbum", "RunTimeTicks": 1230000000,
                "ImageTags": {"Primary": "capa"}
            }]})),
            (200, json!({"TotalRecordCount": 2, "Items": [{
                "Id": "faixa2", "Name": "Faixa 2", "AlbumId": "album1",
                "AlbumPrimaryImageTag": "capa-album"
            }]})),
        ]);
        let password = "  senha&#+%\"não-real  ";
        let songs = fetch_songs(&url, "alice", password).await.unwrap();
        assert_eq!(songs.len(), 2);
        assert_eq!(songs[0].source, SongSource::Jellyfin);
        assert_eq!(songs[0].duration_seconds, Some(123));
        assert_eq!(songs[0].artist.as_deref(), Some("Artista"));
        assert!(songs[0].stream_url_or_file_path.contains("/jellyfin/Audio/faixa1/stream?"));
        assert!(songs[0].stream_url_or_file_path.contains("api_key=token-de-teste"));
        assert!(songs[0].stream_url_or_file_path.contains("static=true"));
        assert!(!songs[0].stream_url_or_file_path.contains(password));
        assert!(songs[0].cover_art_url_or_path.as_ref().unwrap().contains("/Items/faixa1/Images/Primary"));
        assert!(songs[1].cover_art_url_or_path.as_ref().unwrap().contains("/Items/album1/Images/Primary"));
        let requests = server.join().unwrap();
        assert!(requests[0].0.starts_with("POST /jellyfin/Users/AuthenticateByName "));
        assert!(requests[0].0.contains("MediaBrowser Client=\"Meraki\""));
        assert_eq!(serde_json::from_str::<Value>(&requests[0].1).unwrap(), json!({"Username": "alice", "Pw": password}));
        assert!(requests[1].0.contains("IncludeItemTypes=Audio"));
        assert!(requests[1].0.contains("StartIndex=0"));
        assert!(requests[2].0.contains("StartIndex=1"));
        assert!(requests[1].0.to_lowercase().contains("x-emby-token: token-de-teste"));
    }

    #[tokio::test]
    async fn aceita_catalogo_vazio() {
        let (url, server) = mock_server(vec![(200, session()), (200, json!({"Items": [], "TotalRecordCount": 0}))]);
        assert!(fetch_songs(&url, "alice", "senha").await.unwrap().is_empty());
        server.join().unwrap();
    }

    #[tokio::test]
    async fn erros_nao_expoem_corpo_ou_credenciais() {
        for (status, expected) in [(401, "Usuário ou senha"), (403, "permissão"), (404, "não encontrado"), (302, "redirecionou"), (500, "HTTP 500")] {
            let (url, server) = mock_server(vec![(status, json!({"segredo": "nao-mostrar"}))]);
            let error = fetch_songs(&url, "alice", "senha-secreta").await.unwrap_err().to_string();
            assert!(error.contains(expected), "{error}");
            assert!(!error.contains("nao-mostrar"));
            assert!(!error.contains("senha-secreta"));
            assert!(!error.contains(&url));
            server.join().unwrap();
        }
    }

    #[tokio::test]
    async fn falha_na_segunda_pagina_nao_retorna_catalogo_parcial() {
        let (url, server) = mock_server(vec![
            (200, session()),
            (200, json!({"TotalRecordCount": 2, "Items": [{"Id": "1", "Name": "Faixa"}]})),
            (500, json!({})),
        ]);
        assert!(fetch_songs(&url, "alice", "senha").await.is_err());
        server.join().unwrap();
    }

    #[test]
    fn rejeita_urls_invalidas_e_preserva_subdiretorios() {
        for url in ["ftp://example.test", "https://alice:secret@example.test", "https://example.test/?token=x", "https://example.test/#web", "invalida"] {
            assert!(JellyfinClient::new(url).is_err());
        }
        let client = JellyfinClient::new("https://example.test/jellyfin/").unwrap();
        assert_eq!(client.endpoint(&["Users", "AuthenticateByName"]).as_str(), "https://example.test/jellyfin/Users/AuthenticateByName");
        assert_eq!(client.server_scope, JellyfinClient::new("https://example.test/jellyfin").unwrap().server_scope);
    }
}
