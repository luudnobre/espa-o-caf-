# Verificação da atualização da cozinha

Foram executados `npm test` e `npm run build` nesta versão.

Os testes automatizados verificam que:

- Pedidos pagos chegam à cozinha; pedidos pendentes não são liberados para preparo.
- A cozinha pode marcar **Pronto** diretamente e não confirma a entrega.
- Pedidos já existentes no estado antigo **em preparo** continuam visíveis e podem ser marcados como prontos.
- A tela da cozinha oferece somente o botão **Pronto** por pedido a preparar.
- O caixa confirma a entrega; o atendimento não fecha com pedidos abertos.
- O painel público mostra a senha dos pedidos pagos a preparar e prontos, sem nome ou token.
- A atualização SQL pode ser aplicada duas vezes numa instalação simulada sem apagar o pedido pago existente.
- Os testes da versão anterior sobre pagamentos, estoque, permissões, recibos e Pix continuam passando.

O banco foi testado com Postgres em memória (PGlite) e não acessa o Supabase real da igreja. A nova tela foi verificada por testes automatizados de marcação HTML e de fluxo simulado; não houve ensaio em navegador conectado ao seu projeto Supabase. Faça o teste em **ATUALIZAR-COZINHA.html** antes do primeiro uso real.
