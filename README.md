# Página Flutuante

Site estático em HTML, CSS e JavaScript, com páginas animadas e progresso global de cliques armazenado no Supabase.

## Configuração do Supabase

1. Abra o projeto no painel do Supabase e acesse **SQL Editor**.
2. Execute todo o conteúdo atualizado de [`supabase-setup.sql`](./supabase-setup.sql). Ele configura o contador, os limites de estágio mantidos no banco, a tabela de eventos coloridos e as atualizações em tempo real.
3. A URL do projeto e a chave **Publishable** estão configuradas no início de `script.js`. Essa chave pode ser pública no navegador; nunca coloque uma chave **Secret** ou `service_role` neste projeto.

As imagens e os 26 ícones estão em pastas públicas do projeto para que a página consiga carregá-los sem login. Codificar imagens em Base64 não as protege: visitantes ainda podem obter os dados pelo código ou pelo navegador.

Os campos `PRIMEIRA_IMAGEM_BASE64`, `SEGUNDA_IMAGEM_BASE64`, `TERCEIRA_IMAGEM_BASE64` e `QUARTA_IMAGEM_BASE64`, no início de `script.js`, contêm as imagens embutidas. A primeira imagem codificada tem cerca de 13,5 MB, deixando `script.js` com aproximadamente 19 MB; isso aumenta o tempo e os dados necessários para abrir a página. Base64 não impede que visitantes recuperem as imagens.

## Publicar no GitHub Pages

1. Envie os arquivos deste diretório para um repositório GitHub.
2. No repositório, abra **Settings → Pages** e selecione **GitHub Actions** como origem de publicação.
3. Envie um commit para a branch `main` ou `master`. O workflow [`pages.yml`](./.github/workflows/pages.yml) publicará o site automaticamente. Também é possível iniciá-lo manualmente pela aba **Actions**.
4. Quando o workflow terminar, acesse o link exibido em **Settings → Pages**.

O workflow publica o site a partir da raiz do repositório, inclusive quando o projeto é servido em um subcaminho, como `https://usuario.github.io/nome-do-repositorio/`.

## Progressão

O botão **Clique** registra cada clique no contador global do Supabase. O total fica visível no topo e se atualiza em tempo real para todos os visitantes. O Supabase calcula o estágio atual usando os limites `stage_2_clicks`, `stage_3_clicks` e `stage_4_clicks` da linha `public.global_progress`. O script SQL usa 1.000, 2.500 e 5.000 como valores iniciais; para mudar os limites, execute no SQL Editor:

```sql
update public.global_progress
set stage_2_clicks = 1000,
    stage_3_clicks = 2500,
    stage_4_clicks = 5000
where singleton_id = 1;
```

Para escolher outros totais, substitua esses três números pelos que quiser, mantendo-os em ordem crescente, e execute o `UPDATE` no SQL Editor do Supabase. O estágio retornado pelo Supabase é a fonte usada pela página; editar os números no JavaScript não altera os limites oficiais do contador global.

Quando um clique é registrado, uma bolha colorida é transmitida em tempo real aos visitantes conectados, sem guardar cada bolha no banco. O Supabase mantém apenas um registro por navegador que já clicou, em `click_visitors`, para preservar a cor associada ao seu identificador aleatório local. Isso não identifica uma pessoa: limpar os dados do navegador ou usar outro dispositivo cria uma nova identidade e cor. Ao executar o SQL atualizado, a tabela antiga `click_events` e seu histórico serão removidos. As bolhas não são reproduzidas para quem abre a página depois; o contador global continua armazenando e contando cada clique.

A interface aceita no máximo um clique a cada 800 ms por aba e mantém o botão desabilitado enquanto aguarda o Supabase. Esse intervalo evita cliques acidentais repetidos; como o site não exige login, não bloqueia chamadas diretas feitas fora da página.

A música de fundo (`sounds/background-music.mp3`) toca apenas no Estágio 2. O site analisa o arquivo para pular o silêncio inicial e começar a música junto da transição da primeira para a segunda imagem; o fade-in começa nesse ponto e a música reinicia do trecho audível. Na fase final, `sounds/background-music-final.mp3` começa quando a quarta imagem aparece, parte de 0:30 e repete até o fim, com fade-in e fade-out e volume máximo de 18%. As reproduções são preparadas silenciosamente após a primeira interação, devido às restrições de autoplay dos navegadores. O efeito sonoro da transição para o Estágio 4 está em `sounds/transicao-final.mp3`.
