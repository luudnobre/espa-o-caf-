# Espaço Café · PAES Cabo

Comece abrindo **COMECE-AQUI.html** com dois cliques. Ele é um guia visual que funciona mesmo antes de instalar o sistema.

O projeto foi preparado para **VS Code → GitHub → Vercel**, com **Supabase** para autenticação, banco, fotos e atualização da equipe. Não utiliza um servidor próprio nem chaves secretas no navegador.

## 1. Abrir e experimentar no computador

1. Extraia o ZIP. Abra a pasta **espaco-cafe** no VS Code.
2. Instale o Node.js 22, versão 22.12 ou mais recente da série 22.
3. Abra Terminal → New Terminal e execute uma linha por vez:

```bash
npm install
npm run dev
```

4. Abra o endereço **Local** mostrado pelo terminal, normalmente `http://localhost:5173`.
5. Sem configuração, o modo de desenvolvimento oferece uma **demonstração local identificada**, com cardápio e pedidos fictícios. Em `/login`, os botões Administração, Caixa e Cozinha servem apenas para testar. Não há senha de produção incluída no código.

Em produção, se as variáveis do Supabase estiverem ausentes ou inválidas, o site mostra a tela de configuração e **não aceita vendas fictícias**.

## 2. Criar o banco no Supabase

Recomendação: crie um projeto novo chamado `espaco-cafe`. Assim ele fica separado do catálogo da Daiane.

1. No Supabase, crie o projeto e aguarde ficar pronto.
2. Abra **SQL Editor → New query**.
3. No VS Code, abra `supabase/01-estrutura.sql`, copie tudo, cole no SQL Editor e clique em **Run**.
4. Abra **Authentication → Users → Add user / Create new user**. Cadastre o e-mail do administrador, escolha uma senha pessoal forte e marque **Auto confirm user** se essa opção aparecer.
5. O administrador inicial configurado em `supabase/02-administrador.sql` é **dknsdaniel@gmail.com**. Para usar outro, altere somente o e-mail nesse arquivo.
6. Execute **02-administrador.sql** no SQL Editor depois de criar e confirmar o usuário.
7. Opcional: execute **03-cardapio-exemplo.sql**. Ele cria seis alimentos **ocultos e com estoque zero** para você editar. Os preços são exemplos, não valores da igreja.

Os arquivos não apagam as tabelas anteriores quando executados novamente. A estrutura cria tabelas com prefixo `cafe_`, funções com permissão por perfil e o bucket de imagens `cafe-menu`.

## 3. Conectar no VS Code

No Supabase, abra **Connect → Framework → React** e escolha a variante Vite quando necessário. Copie a **Project URL** e a **Publishable key**. Você também encontra essas informações nas configurações de API do projeto.

Crie um arquivo chamado exatamente **.env.local**, na mesma pasta do `package.json`. Não é dentro de `src`.

```env
VITE_SUPABASE_URL=https://SEU-PROJETO.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_SUA_CHAVE
```

Use os valores reais depois de cada `=`. A chave `anon` antiga também é aceita. Nunca use `service_role`, `sb_secret_` ou a senha do banco. O build bloqueia chaves que não tenham o formato público aceito.

Salve com Command+S. No terminal, pressione **Control+C**, digite `npm run dev` e pressione Enter. Abra **/login** e entre com o usuário criado no Supabase. Os botões de demonstração serão substituídos pelo formulário real.

## 4. Preparar o primeiro culto

1. **Cardápio e estoque:** edite os exemplos ou crie os alimentos reais. Informe preço, descrição, categoria, tempo de preparo e alergênicos conforme a receita. Envie fotos JPG/PNG/WebP de até 5 MB.
2. **Ajustar estoque:** adicione a produção disponível, com o motivo “Produção do domingo”. Produtos novos começam sem estoque. A edição de nome/preço não sobrescreve o estoque, para preservar as vendas simultâneas.
3. **Nossa equipe:** crie primeiro as contas em Authentication → Users no Supabase, confirme os usuários e depois autorize os mesmos e-mails no painel. Cada pessoa deve ter sua própria senha.
4. **Abrir atendimento:** informe um nome para o culto e o fundo de caixa para troco. Só pode existir um atendimento aberto por vez.
5. **Configurações:** ative “Permitir pedidos pelo celular”. Essa opção e um caixa aberto são necessários para aceitar pedidos online.
6. **Pix, opcional:** cadastre a chave Pix, o nome do recebedor e a cidade. Confira um QR de teste no aplicativo do banco antes de divulgar.
7. No caixa use **/caixa**. Na cozinha use **/cozinha**. O cardápio dos clientes é **/** e a tela de retirada é **/retirada**.

As quantidades de combos são independentes. Separe o estoque que irá para combos do estoque de itens avulsos; o sistema não calcula fichas técnicas de ingredientes.

## 5. Perfis e funcionamento

| Perfil | Pode fazer |
| --- | --- |
| Administração | Cardápio, fotos, estoque, equipe, configurações, caixa e cozinha |
| Caixa | Pedidos, pagamentos, recibos, cancelamentos, retirada, entradas, sangrias e fechamento |
| Cozinha | Ler pedidos pagos e avançar: na fila → em preparo → pronto → entregue |
| Cliente sem login | Consultar cardápio, criar pedido pendente e acompanhar apenas o próprio link |

O cliente recebe uma senha sequencial e um link com token aleatório. O painel público de retirada mostra **senhas**, sem expor o nome das pessoas.

O pedido baixa o estoque ao ser registrado, inclusive quando ainda falta pagar. A cozinha só recebe pedidos pagos. Pedidos pendentes não expiram automaticamente: a equipe revisa e cancela os abandonados para liberar o estoque. Há limite de 60 pedidos online pendentes por atendimento, até 20 linhas e 20 unidades por produto em cada pedido.

O sistema é destinado à operação do café da igreja, com o link/QR divulgado à comunidade. O limite de pendências não substitui proteção contra bots. Se houver divulgação ampla na internet, será necessário acrescentar proteção de criação de pedidos no servidor, como CAPTCHA validado em Edge Function.

## 6. Pagamentos, comprovantes e cancelamentos

**Este sistema registra recebimentos. Ele não é uma operadora de pagamento.**

- Dinheiro: confirme o valor recebido. O recibo mostra o troco. O relatório considera o valor da venda, sem inflar o total pelo troco.
- Pix: o cliente pode copiar o Pix ou escanear o QR. O caixa confere no banco e confirma no sistema. A imagem de comprovante, sozinha, não substitui a conferência do recebimento.
- Cartão: use a maquininha da igreja e confirme no sistema depois da aprovação.
- Pedido pendente gera **comanda**, sem afirmar que foi pago.
- Pedido pago gera **recibo de controle interno**, com itens, total, meio, data, recebido/troco quando aplicável. Não é nota fiscal.
- O botão de impressão abre um formato para papel de aproximadamente 80 mm; o navegador também permite Salvar em PDF. Impressão automática sem diálogo e integração com impressoras de rede não fazem parte desta versão.
- Cancelamento de pedido pago exige confirmar que a devolução real foi feita. O sistema registra o estorno no controle, mas não transfere Pix nem estorna uma maquininha. Depois, devolve o estoque uma única vez.

## 7. Encerrar um domingo

1. Pause os pedidos pelo celular nas Configurações.
2. Entregue os pedidos prontos, resolva os restantes e cancele comandas abandonadas.
3. Registre entradas extras e sangrias que de fato aconteceram.
4. Clique em **Fechar caixa**, conte o dinheiro físico e informe o valor.
5. O sistema calcula: fundo inicial + vendas em dinheiro − devoluções em dinheiro + entradas − sangrias. Pix e cartão ficam separados.
6. O fechamento grava o esperado, o contado e a diferença.
7. Consulte o atendimento pelo seletor de **Caixa e relatórios**. Exporte o CSV se desejar.

Não há exclusão de histórico financeiro pelo painel. Produtos deixam de aparecer quando a administração desmarca “Visível no cardápio”.

## 8. Enviar ao GitHub

Crie um repositório novo, preferencialmente privado, sem inicializar README nem .gitignore. Na pasta do projeto, execute:

```bash
git init
git branch -M main
git add .
git commit -m "Cria Espaco Cafe PAES Cabo"
```

Substitua SEU-USUARIO pelo seu usuário do GitHub e use o nome correto do repositório:

```bash
git remote add origin https://github.com/SEU-USUARIO/espaco-cafe.git
git push -u origin main
```

O `.gitignore` já exclui `.env.local`, `node_modules`, `dist` e arquivos locais da Vercel. Confira com `git check-ignore .env.local` antes de enviar. Não envie senhas ou chaves secretas junto ao projeto.

## 9. Publicar na Vercel

1. Na Vercel, clique em **Add New → Project** e importe esse repositório.
2. Use o preset **Vite**, comando `npm run build` e pasta de saída **dist**. Configure Node **22.x** quando disponível.
3. Adicione as duas variáveis, com nome e valor em campos separados:

| Key | Value |
| --- | --- |
| VITE_SUPABASE_URL | Project URL completa, com https:// |
| VITE_SUPABASE_PUBLISHABLE_KEY | Publishable key pública do mesmo projeto |

Selecione **Config**, se houver escolha entre Config e Secret. Mantenha o prefixo VITE_. Selecione Production e os outros ambientes em que pretende usar o sistema.

4. Faça o deploy. Se adicionar ou alterar variáveis depois, faça **Redeploy**.
5. Abra o endereço publicado, entre em **/login** e teste com um alimento e uma quantidade pequenos antes do culto.
6. No Supabase, em **Authentication → URL Configuration**, configure a Site URL com o domínio publicado e adicione `https://SEU-DOMINIO/nova-senha` aos redirecionamentos permitidos. Para desenvolvimento, adicione `http://localhost:5173/nova-senha`. Substitua SEU-DOMINIO pelo endereço real da Vercel.
7. Em Authentication, desative novos cadastros públicos se a opção estiver ativa. As contas da equipe são criadas pelo administrador no painel do Supabase.
8. O botão **QR do cardápio** usa o domínio onde você estiver. Baixe o QR a partir da versão online, e não de localhost, antes de imprimir e divulgar.

Celulares, caixa e cozinha precisam de internet. Eles podem estar em redes diferentes, desde que acessem o mesmo projeto e domínio. Atualização da equipe usa Realtime e uma atualização periódica de apoio. O cliente e a tela de retirada conferem o status a cada 6 segundos.

## 10. Recuperação de senha

O link “Esqueci minha senha” usa o envio de e-mail do Supabase. Confira URL Configuration e a configuração de SMTP/Auth da sua conta para entregabilidade e limites. Se não receber o e-mail, confira spam e os logs de Authentication. Nunca compartilhe senhas nos grupos ou em capturas de tela.

## 11. Verificação técnica

```bash
npm test
npm run build
```

Os testes incluem um Postgres local em memória (PGlite). Não conectam ao projeto real nem alteram dados externos. A lista do que foi verificado está em **VERIFICACAO.md**.

## Arquivos principais

- `src/main.js`: telas e interações.
- `src/styles.css`: tema roxo, componentes e regras responsivas.
- `src/core.js`: valores, totais, exportação e geração do Pix.
- `src/api.js`: autenticação, funções do banco, fotos e Realtime.
- `src/demo.js`: simulação somente no desenvolvimento, sem Supabase.
- `src/receipt.js`: comanda e recibo para impressão/PDF.
- `supabase/`: estrutura, autorização inicial e exemplos opcionais.
- `tests/`: testes de regras e banco.
- `public/images/`: identidade visual e imagens incluídas.

## Referências de implantação

- https://supabase.com/docs/guides/database/functions
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/realtime/postgres-changes
- https://supabase.com/docs/guides/api/api-keys
- https://vercel.com/docs/frameworks/frontend/vite
- https://vercel.com/docs/environment-variables

## Limites desta entrega

Integração com banco, maquininha, emissão fiscal, delivery, receitas/insumos e impressora automática exigem serviços adicionais. Não estão conectados nesta versão. O funcionamento real depende de executar os SQLs e configurar seu próprio Supabase e a Vercel; nenhum acesso da sua conta foi utilizado para instalar ou publicar a aplicação.
