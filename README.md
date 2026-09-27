<p align="center">
  <img src="https://raw.githubusercontent.com/lindnergui/MERAKI-PLAYER/main/assets/images/meraki_logo.png" width="180" alt="Logo do Meraki Player">
</p>

<h1 align="center">Meraki Player</h1>

<p align="center">
  Sua música, do seu jeito: biblioteca local, Subsonic, Jellyfin e reprodução integrada<br>
  para Linux e Android — inclusive no Android Auto.
</p>

<p align="center">
  <a href="https://github.com/lindnergui/MERAKI-PLAYER/releases/latest"><img src="https://img.shields.io/github/v/release/lindnergui/MERAKI-PLAYER?display_name=tag&amp;sort=semver&amp;style=for-the-badge" alt="Versão mais recente"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/lindnergui/MERAKI-PLAYER?style=for-the-badge" alt="Licença MIT"></a>
  <img src="https://img.shields.io/badge/plataformas-Linux%20%7C%20Android-A855F7?style=for-the-badge" alt="Linux e Android">
  <a href="https://github.com/lindnergui/MERAKI-PLAYER/actions/workflows/release.yml"><img src="https://github.com/lindnergui/MERAKI-PLAYER/actions/workflows/release.yml/badge.svg" alt="Status da release"></a>
</p>

## Download

> [!IMPORTANT]
> Baixe o Meraki Player somente pela página oficial de
> [Releases do GitHub](https://github.com/lindnergui/MERAKI-PLAYER/releases/latest).
> Ela contém sempre a versão estável mais recente e suas notas de lançamento.

| Sistema | Formato | Suporte / distribuições | Download oficial |
| --- | --- | --- | --- |
| Linux | Flatpak | Linux x86-64; Fedora, Ubuntu, Debian e outras distribuições compatíveis com Flatpak | [Baixar Flatpak](https://github.com/lindnergui/MERAKI-PLAYER/releases/latest/download/meraki.flatpak) |
| Android | APK | Android e Android Auto | [Baixar APK](https://github.com/lindnergui/MERAKI-PLAYER/releases/latest/download/meraki-android.apk) |

[Ver todas as versões e notas de lançamento](https://github.com/lindnergui/MERAKI-PLAYER/releases)

## Instalação

### Linux — Flatpak

Baixe o arquivo `meraki.flatpak`. Você pode dar dois cliques nele para abrir a
loja de aplicativos compatível da sua distribuição ou instalar pelo terminal:

```bash
flatpak install --user ./meraki.flatpak
flatpak run com.github.lindnergui.meraki
```

Caso ainda não tenha Flatpak, siga o [guia oficial de
configuração](https://flatpak.org/setup/). Para atualizar, instale o bundle
mais recente novamente. Para remover o Meraki Player:

```bash
flatpak uninstall com.github.lindnergui.meraki
```

### Android — APK e Android Auto

1. Baixe `meraki-android.apk` no celular pela página de Releases.
2. Ao abrir o arquivo, permita a instalação de apps dessa origem quando o
   Android solicitar.
3. Confirme a instalação e abra o **Meraki Player**.
4. Para o Android Auto, conecte o celular ao veículo após instalar o app. O
   Meraki aparecerá como aplicativo de mídia em veículos compatíveis.

> [!TIP]
> Instale APKs apenas da Release oficial. Você pode desativar novamente a
> permissão de fontes desconhecidas após a instalação.

## Principais recursos

- biblioteca local: escaneie e reproduza músicas armazenadas no dispositivo;
- Subsonic e Jellyfin: escolha o tipo de servidor nas configurações para sincronizar e reproduzir o catálogo remoto;
- reprodução em segundo plano com controles na notificação, tela bloqueada e
  integração MPRIS no Linux;
- Android Auto: catálogo, metadados, capas e comandos de mídia no veículo;
- favoritos, álbuns, artistas, músicas baixadas e controles de fila;
- interface escura, responsiva e otimizada para desktop e celulares;
- verificação opcional de atualizações a cada inicialização.

## Atualizações e Releases

O Meraki verifica de forma opcional se há uma Release mais recente ao iniciar.
Escolha **Atualizar agora** para abrir a página oficial ou **Agora não** para
continuar usando a versão instalada.

O workflow [`.github/workflows/release.yml`](.github/workflows/release.yml) é
executado quando uma tag iniciada por `v` é enviada ao GitHub. Ele gera e anexa
automaticamente à Release:

- `meraki-android.apk` para Android;
- `meraki.flatpak` para Linux x86-64.

## Desenvolvimento

O Meraki Player usa **Flutter** e **Rust** com `flutter_rust_bridge`. Este
projeto não utiliza Node.js ou Tauri; os comandos abaixo são os equivalentes
corretos para desenvolver e compilar o aplicativo.

### Pré-requisitos

- Flutter estável;
- Rust (a versão definida em [`rust-toolchain.toml`](rust-toolchain.toml));
- Android SDK e JDK 17 para gerar APKs;
- para Linux, as dependências de desenvolvimento do Flutter/GTK;
- para Flatpak, `flatpak` e `flatpak-builder`.

### Preparar o ambiente

```bash
git clone https://github.com/lindnergui/MERAKI-PLAYER.git
cd MERAKI-PLAYER
flutter pub get
flutter_rust_bridge_codegen generate
```

### Executar e validar

```bash
flutter run -d linux
flutter analyze
flutter test
```

### Gerar um APK Android

```bash
flutter build apk --release
```

O arquivo final é criado em:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### Gerar pacotes Linux localmente

Para criar e testar o Flatpak:

```bash
scripts/build-flatpak.sh
flatpak install --user ./dist/meraki.flatpak
flatpak run com.github.lindnergui.meraki
```

## Licença

Distribuído sob a licença MIT. Consulte [LICENSE](LICENSE).
