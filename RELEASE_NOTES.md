# Meraki Player 1.3.7 — Redesenho Desktop & Versão Windows

O Meraki Player 1.3.7 traz a interface desktop completamente redesenhada para telas grandes, com estética retro em pixel art, além de melhorias no suporte a Windows, Android e Linux.

### Principais novidades:
- **Nova interface desktop:** Redesenho completo do layout para telas a partir de 600 dp com navegação lateral personalizada.
- **Toca-discos retro em pixel art:** Deck interativo com vinil giratório dinâmico, braço de agulha animado, visualizador de onda sonora e controle de pitch/volume.
- **Navegação lateral reformulada:** Abas dedicadas para Início, Favoritas, Biblioteca completa (com abas para Todas as Músicas, Álbuns, Artistas e Baixadas) e Tocando Agora.
- **Fila e Descobertas:** Carrossel horizontal de próximas faixas na fila e seção de destaques aleatórios na tela inicial.
- **Tipografia Pixelify Sans:** Tipografia estilizada integrada ao aplicativo.
- **Instalador EXE:** baixe `meraki-windows-setup.exe` e siga o assistente em português. Instalação por usuário, sem exigir administrador.
- **Edição portátil:** extraia todo o arquivo `meraki-windows-portable.zip` e execute `meraki.exe`, mantendo as DLLs e a pasta `data` juntas.
- Compilação nativa em modo Release, com o núcleo Rust e as bibliotecas de áudio e vídeo incluídos. Não é necessário instalar Flutter ou Rust.
- Controles de reprodução integrados ao Windows e às teclas de mídia.
- Catálogo e preferências armazenados na pasta de dados do usuário. A edição portátil também usa essa pasta; desinstalar não remove sua biblioteca local.
- Android e Linux continuam disponíveis nesta release com os pacotes `meraki-android.apk` e `meraki.flatpak`.

O instalador não possui certificado comercial de assinatura digital. Baixe somente desta página oficial.

Desenvolvimento: Guilherme Lindner (@lindnergui).
