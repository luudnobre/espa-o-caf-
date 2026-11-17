# Verificação da entrega

## Verificado automaticamente

- 20 testes aprovados com `npm test`.
- Migração SQL executada duas vezes sem apagar dados nem duplicar permissões.
- Usuário comum não consegue se tornar administrador.
- Caixa/cozinha não conseguem editar cardápio nem imagens fora de suas permissões.
- Tabelas não aceitam gravação direta pelo navegador.
- Pedido público não consegue informar preço diferente do banco.
- Caixa fechado e pedidos online pausados bloqueiam novas comandas.
- Reserva de estoque e impedimento de venda após esgotamento.
- Falha no pedido ou no recebimento reverte a transação inteira.
- Repetição da requisição não duplica comanda, pagamento ou devolução.
- Cozinha não lê pendências nem movimentações financeiras pelas tabelas.
- Somente pedidos pagos avançam e as etapas precisam seguir a ordem.
- Consulta pública de retirada não expõe nome, token nem conteúdo do pedido.
- Token errado não encontra pedido.
- Cancelamento devolve estoque apenas uma vez.
- Edição do cardápio preserva o estoque e o preço registrado no pedido antigo.
- Troco não é contado como venda.
- Fechamento considera fundo, vendas em dinheiro, devoluções, entradas e sangrias.
- Dinheiro/Pix/cartão são separados.
- CSV preserva caracteres e protege textos que se parecem com fórmulas.
- Recibo diferencia pagamento de comanda pendente e escapa textos HTML.
- CRC do Pix e representação de centavos conferidos.

## Verificado no navegador

- Cardápio com hero ilustrativo e marca PAES Cabo.
- Inclusão no carrinho e totalização.
- Pedido público com nome, observação, senha e pagamento pendente.
- Pedido aparecendo no painel da equipe.
- Confirmação em dinheiro e atualização para pago.
- Preparo na cozinha e acompanhamento na tela do cliente.
- Painel administrativo com indicadores e navegação.

## Limites da verificação

O banco foi testado em Postgres local por PGlite; nenhum projeto Supabase real da igreja foi acessado. Os testes verificam regras e bloqueios, mas não substituem um ensaio com duas pessoas/aparelhos no Supabase instalado. Não foram executadas transações financeiras reais, entrega de e-mail SMTP, impressão em equipamento físico nem testes de carga em produção.

Depois de instalar, faça um ensaio: abra o caixa, cadastre um item com duas unidades, peça pelo celular, confirme no caixa, prepare e entregue na cozinha, confira o recibo e encerre o atendimento. Confira também o estoque ao cancelar uma comanda de teste.
