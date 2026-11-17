-- OPCIONAL: cadastre exemplos OCULTOS. Depois edite preços, estoque e disponibilidade.
insert into public.cafe_products(id,name,category,description,price_cents,stock,active,featured,image_url) values
('10000000-0000-4000-8000-000000000001','Coxinha da casa','Salgados','Massa douradinha e recheio de frango. Ajuste a descrição à receita da igreja.',700,0,false,true,'/images/salgados.svg'),
('10000000-0000-4000-8000-000000000002','Pão de queijo','Salgados','Porção para compartilhar. Defina o tamanho da porção.',500,0,false,true,'/images/salgados.svg'),
('10000000-0000-4000-8000-000000000003','Fatia de bolo','Doces','Receita do domingo. Informe o sabor e os alergênicos.',600,0,false,false,'/images/doces.svg'),
('10000000-0000-4000-8000-000000000004','Café quentinho','Bebidas','Informe o tamanho do copo.',300,0,false,true,'/images/bebidas.svg'),
('10000000-0000-4000-8000-000000000005','Suco natural','Bebidas','Informe o sabor e o tamanho.',500,0,false,false,'/images/bebidas.svg'),
('10000000-0000-4000-8000-000000000006','Combo encontro','Combos','Exemplo de produto independente. O estoque do combo deve ser separado dos itens avulsos.',1000,0,false,false,'/images/combos.svg') on conflict(id) do nothing;
select 'Exemplos ocultos adicionados. Confira informações e ajuste o estoque no painel.' as resultado;
