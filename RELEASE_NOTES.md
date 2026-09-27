# Meraki Player 1.3.5 — Conexão com Jellyfin

Correção do erro 404 ao conectar um servidor Jellyfin: agora o aplicativo usa a API nativa do Jellyfin, em vez das rotas Subsonic.

- Selecione **Jellyfin** em **Configurações → Tipo de servidor**, informe a URL, o usuário e a senha e toque em **Testar conexão e sincronizar**.
- Sincronização de músicas com paginação, metadados, capas e reprodução autenticada, inclusive no catálogo do Android Auto.
- Bibliotecas Jellyfin, Subsonic e local preservadas separadamente. O banco existente é atualizado automaticamente.
- Senhas mantidas exatamente como digitadas, incluindo espaços e caracteres especiais.
- Mensagens de erro sem URLs contendo tokens de autenticação.
- Verificação de atualizações apontando para o repositório MERAKI-PLAYER.

A senha não é salva. O catálogo local guarda URLs com o token da sessão para permitir reprodução; se a sessão for revogada no servidor, sincronize novamente.

Desenvolvimento: Guilherme Lindner (@lindnergui).
