# Espaço Café · PAES Cabo

Aplicação para operação do café após o culto: cardápio público, pedidos, caixa, cozinha, estoque, retirada e recibos. Frontend em Vite/JavaScript. Supabase fornece Postgres, Auth, Storage e Realtime.

Para uma instalação nova, abra **COMECE-AQUI.html**. Se você já usa o Espaço Café, abra **ATUALIZAR-COZINHA.html** antes de publicar: a alteração requer atualizar também uma função no Supabase.

## Fluxo principal

1. A administração publica alimentos e ajusta estoque por quantidade.
2. Caixa ou cliente registra a comanda. O banco calcula os preços e reserva unidades em uma transação.
3. A equipe confirma um recebimento real. O pedido passa de pendente para pago.
4. A cozinha recebe os pedidos pagos e toca em **Pronto** uma única vez. Quando houver a retirada, o caixa ou a administração abre **Pedidos** e confirma a entrega.
5. O cliente consulta seu pedido por um token aleatório. O painel de TV mostra apenas senhas.
6. No encerramento, o caixa registra o valor físico contado. O banco calcula esperado e diferença, separando Pix e cartão.

## Arquitetura

- Roteamento de página única, com rewrites para Vercel.
- Credenciais de navegador limitadas à Project URL e Publishable/anon key.
- Contas da equipe em Supabase Auth; permissões em `cafe_private.staff`, sem confiar em user_metadata ou em campos enviados pelo cliente.
- Funções `SECURITY DEFINER` com `search_path` vazio, nomes de tabelas qualificados e permissões explícitas.
- Tabelas com RLS e somente leitura pelo navegador. Escritas passam pelas funções com validação de perfil.
- `cafe_place_order` é público e cria somente pedidos pendentes. Não recebe preço nem autorização de pagamento do cliente.
- `cafe_counter_order` pode registrar e receber em uma mesma transação, com perfil de caixa/admin.
- Criação idempotente por UUID de requisição; pagamentos e estornos únicos por pedido.
- Bloqueios de linha, ordem estável dos produtos e transação para reservar estoque. Valores monetários inteiros em centavos.
- Editar produto não altera seu estoque: reposições/perdas têm função separada e registro do motivo.
- Preço, nome e quantidade são copiados para o pedido. Alterações futuras no cardápio não mudam recibos antigos.
- Cancelamento de venda exige confirmação da devolução real; o histórico de pagamento é preservado.
- Acesso público ao pedido exige o token aleatório de 128 bits. Ele vai no fragmento do link, não na query string.
- Pedidos e informações financeiras têm políticas por perfil. O painel da cozinha não recebe pendências nem o livro de pagamentos.
- Realtime na equipe, com atualização periódica de apoio. Cliente e retirada usam consultas de escopo limitado.
- Toda ação importante tem registro em `cafe_audit`; estoque tem movimentos próprios.
- Um atendimento aberto por vez. Fechamento só ocorre sem pedidos em andamento.

## Banco

`cafe_settings`: preferências, abertura de pedidos online e chave Pix pública.

`cafe_sessions`: abertura e fechamento por atendimento.

`cafe_products`: cardápio, preço e estoque disponível.

`cafe_orders`: snapshot de itens, cliente, etapas e situação de pagamento.

`cafe_payments`: recebimentos e devoluções, sem dados de cartão.

`cafe_cash_moves`: entradas extras e sangrias.

`cafe_stock_moves`: reservas, cancelamentos e ajustes.

`cafe_audit`: histórico de ações.

`cafe_private.staff`: autorização de voluntários, fora do schema público.

## Desenvolvimento

```bash
npm install
npm run dev
npm test
npm run build
```

Os testes de banco executam o SQL em Postgres local em memória (PGlite), com roles anon/authenticated e tabelas mínimas que simulam Auth/Storage. Não usam contas externas. Teste o funcionamento conjunto com o Supabase real antes do primeiro culto.

## Assets

`paes-cabo.png` é a imagem de referência fornecida. O recorte de apresentação da marca é feito por CSS, sem redesenhar o símbolo. `cafe-encontro.png` é uma fotografia ilustrativa gerada para o projeto. Os quatro SVGs de categorias são ilustrações locais. As imagens ilustrativas não identificam o cardápio real da igreja.

DM Sans e Manrope usam Google Fonts, com fontes do sistema como fallback. A aplicação continua legível se as fontes externas não carregarem.

## Operação

Os clientes não precisam de conta. O acesso de equipe é autenticado e não possui cadastro público pelo site. Proteja os dispositivos de caixa e cozinha e encerre a conta após o uso compartilhado.

Não há modo de venda offline. Erros de rede mantêm o pedido no formulário para nova tentativa, reaproveitando a requisição. Não recarregue uma venda incerta para criar outra sem conferir primeiro em Pedidos.

O Pix é um payload estático BR Code com valor e identificador; seu CRC é validado nos testes. A confirmação bancária permanece manual. Para integrar um provedor, será necessário backend com webhooks autenticados e conciliação.

No ambiente de desenvolvimento sem Supabase, os dados são locais no navegador. Essa demonstração não reproduz concorrência entre aparelhos independentes. A integração real entre os aparelhos é feita pelo Supabase.

Essa entrega é um projeto local para instalação própria. Não cria projeto Supabase, não publica repositório e não faz deploy em contas externas automaticamente.
