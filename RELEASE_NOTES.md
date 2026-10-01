# Meraki Player 1.3.6 — Versão para Windows

O Meraki Player agora está disponível para Windows 10/11 de 64 bits (x64), com a mesma interface e as bibliotecas local, Jellyfin e Subsonic.

- **Instalador EXE:** baixe `meraki-windows-setup.exe` e siga o assistente em português. Instalação por usuário, sem exigir administrador.
- **Edição portátil:** extraia todo o arquivo `meraki-windows-portable.zip` e execute `meraki.exe`, mantendo as DLLs e a pasta `data` juntas.
- Compilação nativa em modo Release, com o núcleo Rust e as bibliotecas de áudio e vídeo incluídos. Não é necessário instalar Flutter ou Rust.
- Controles de reprodução integrados ao Windows e às teclas de mídia.
- Catálogo e preferências armazenados na pasta de dados do usuário. A edição portátil também usa essa pasta; desinstalar não remove sua biblioteca local.
- Android e Linux continuam disponíveis nesta release. As telas e o fluxo do aplicativo foram preservados.

O instalador não possui certificado comercial de assinatura digital. Baixe somente desta página oficial.

Desenvolvimento: Guilherme Lindner (@lindnergui).
