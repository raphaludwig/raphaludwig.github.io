# ADR 0001 — usar a família `rjd3` em vez do `RJDemetra`

**Data:** 2026-08-17 · **Status:** aceito · **Escopo:** post 0002 (ajuste sazonal / crédito)

## Contexto

O post 0002 monta uma rotina de ajuste sazonal sobre o JDemetra+ e a aplica nas 73
séries de concessão de crédito do BCB. A primeira versão, escrita e publicada em
agosto de 2026, usava o pacote `RJDemetra` 0.2.8 — a interface conhecida do
JDemetra+ no R, e a escolha default de quem faz ajuste sazonal em R.

O `RJDemetra` 0.2.8 embute o JDemetra+ **2.x** (`demetra-tstoolkit-2.2.5.jar`) e
roda em Java 8. O README do `jdemetra/jdemetra-app` é explícito sobre o destino
dessa linha:

> JDemetra+ v2 is in maintenance mode
>
> JDemetra+ v2 will reach its end of life in December 2026, which coincides with
> the end of Java 8's official support.

A linha 3.x **não chegou ao `RJDemetra`** e não vai chegar: ela vive numa família
nova de pacotes (`rjd3toolkit` como base, mais `rjd3x13`, `rjd3tramoseats`,
`rjd3x11plus`, `rjd3highfreq`, `rjd3stl`, `rjd3sts`, entre outros), com API
própria e exigência de Java 21+.

## Decisão

Migrar o `sa_runner.R` e o post inteiro para `rjd3x13` / `rjd3tramoseats` 3.8.0,
sobre OpenJDK 25. Corte seco: o `RJDemetra` sai do código e sobrevive só como
assunto do texto.

## Alternativas consideradas

**Ficar no `RJDemetra` 0.2.8 e registrar um caveat.** Foi a decisão tomada numa
primeira rodada, e ela era defensável: os números já estavam validados, e o
argumento do post — X-11 vs SEATS — não depende da geração do motor, já que os
dois métodos existem inteiros no 2.x. Foi revertida porque o post é sobre uma
rotina de produção, e publicar uma rotina de produção sobre um runtime com EOL a
poucos meses de distância contradiz o próprio post.

**Migrar só o runner, mantendo o texto.** Inviável: a mudança de API força
reescrever cinco chunks do `.qmd`, e a migração mexeu em números que o texto
reporta nominalmente.

## Consequências

**O motor, sozinho, não muda praticamente nada.** O lote foi congelado sob o 2.x
antes de trocar o Java e re-rodado no 3.x com os regressores entrando do mesmo
jeito. As 73 séries dão veredito idêntico (56 `Present` / 10 `ProbablyNone` /
7 `None`, 0 mudanças), a série ajustada tem desvio mediano de 0,000%, e só duas
séries trocam o método escolhido. **A migração se justifica pelo prazo de
validade, não por correção de resultado** — e é bom que seja assim, porque
significa que os números publicados antes não estavam errados.

**O que mudou de verdade foi um bug de configuração que a API nova expôs.** No
2.x os seis fatores de calendário do IBC-BR entravam como regressores genéricos
do usuário, e conviviam com o bloco de dias úteis que o próprio RSA5c estima:
doze regressores de calendário disputando o mesmo sinal. O `rjd3toolkit` recusa,
por documentação, alocar variável do usuário ao componente de calendário — o
caminho é `set_tradingdays(option = "UserDefined")`, que **substitui** o bloco em
vez de empilhar. Corrigido isso:

| série com gabarito oficial | corr. MoM antes | corr. MoM depois |
|---|---|---|
| Capital de giro - Total | 0,8955 | **0,9861** |
| Aquisição de veículos | 0,6051 | **0,9695** |
| Cartão de crédito - À vista | 0,8623 | **0,9591** |
| Total não rotativo | 0,6465 | **0,9674** |

A rotina ficou dramaticamente mais próxima do ajuste oficial do BCB, que é a
única evidência externa disponível no post. Esse é o ganho real da migração, e
ele veio de carona.

**Custos aceitos.** Exige Java 21+ instalado e `JAVA_HOME` apontado (o
`sa_runner.R` falha cedo e com mensagem útil se a JVM for velha). O `rjd3jars`
emite um aviso de `sun.misc.Unsafe` no stderr a cada init da JVM — ruído, não
erro. E o `_freeze`/`*_cache` do post tem de ser purgado a cada mudança de
motor, porque o knitr indexa pelo texto do chunk e não enxerga que o
`sa_runner.R` mudou por baixo.

**O degrau 3 não foi tocado.** Os testes clássicos continuam no `seastests`, de
propósito: eles são o voto independente do motor que faz o ajuste, e trocá-los
por equivalentes do `rjd3toolkit` destruiria essa independência.
