# Queries Analíticas — Respostas às 5 Perguntas de Negócio (Sprint 0)

Este documento apresenta a especificação, lógica de negócio e queries SQL em formato Google BigQuery desenvolvidas para responder às 5 perguntas de negócio prioritárias definidas na Sprint 0 do projeto `gem-dados`.

Todas as queries consomem exclusivamente a camada dimensional higienizada (`marts`), garantindo total conformidade com a LGPD através do uso de `user_id` anonimizado (SHA-256).

---

## Índice das Perguntas de Negócio

1. [Pergunta 1: Ritmo de Aprendizado & Média de XP/Semana](#pergunta-1-ritmo-de-aprendizado--média-de-xpsemana)
2. [Pergunta 2: Taxa de Retenção & Churn (Cohorts de Alunos)](#pergunta-2-taxa-de-retenção--churn-cohorts-de-alunos)
3. [Pergunta 3: Eficiência & Gargalos de Conclusão de Cursos e Trilhas](#pergunta-3-eficiência--gargalos-de-conclusão-de-cursos-e-trilhas)
4. [Pergunta 4: Evolução de Proficiência & Habilidades (Skill Assessments)](#pergunta-4-evolução-de-proficiência--habilidades-skill-assessments)
5. [Pergunta 5: Adoção & Demanda de Tecnologias](#pergunta-5-adoção--demanda-de-tecnologias)

---

## Pergunta 1: Ritmo de Aprendizado & Média de XP/Semana

> **Objetivo:** *Qual é o ritmo de estudo dos alunos ao longo das semanas, medido pela média e distribuição de XP ganho por semana e horas dedicadas por aluno ativo?*

### Lógica de Negócio
- Agrupar atividades de estudo por semana de referência (`DATE_TRUNC(DATE(startedcourse), WEEK)`).
- Calcular o total de alunos únicos ativos na semana.
- Calcular a média de XP obtido por aluno ativo (`SUM(xp) / COUNT(DISTINCT user_id)`).
- Mensurar a dispersão de engajamento (percentis 25%, 50% / Mediana e 75%).

### Query SQL (BigQuery)

```sql
-- Pergunta 1: Ritmo de Aprendizado Semanal e Média de XP
WITH base_semanal AS (
  SELECT
    DATE_TRUNC(DATE(startedcourse), WEEK(MONDAY)) AS semana,
    user_id,
    SUM(totalcoursexpearned) AS xp_semanal,
    COUNT(DISTINCT course_id) AS cursos_cursados
  FROM `gem-dados-lake-prd.marts.fct_progresso_cursos`
  WHERE startedcourse IS NOT NULL
  GROUP BY semana, user_id
)

SELECT
  semana,
  COUNT(DISTINCT user_id) AS total_alunos_ativos,
  SUM(xp_semanal) AS xp_total_gerado,
  ROUND(AVG(xp_semanal), 2) AS media_xp_por_aluno,
  ROUND(APPROX_QUANTILES(xp_semanal, 100)[OFFSET(50)], 2) AS mediana_xp_por_aluno,
  ROUND(APPROX_QUANTILES(xp_semanal, 100)[OFFSET(25)], 2) AS p25_xp,
  ROUND(APPROX_QUANTILES(xp_semanal, 100)[OFFSET(75)], 2) AS p75_xp,
  SUM(cursos_cursados) AS total_cursos_em_andamento
FROM base_semanal
GROUP BY semana
ORDER BY semana DESC;
```

---

## Pergunta 2: Taxa de Retenção & Churn (Cohorts de Alunos)

> **Objetivo:** *Qual é a taxa de retenção dos alunos ao longo do tempo (por coorte de entrada) e qual a proporção de evasão/abandono?*

### Lógica de Negócio
- Identificar o mês de entrada do aluno na plataforma (`cohort_month = DATE_TRUNC(dateuserjoinedgroup, MONTH)`).
- Analisar a permanência ao longo dos meses subsequentes através da presença de atividades e data de desligamento (`dateuserleftgroup`).
- Taxa de Retenção = $(\text{Alunos Ativos no Mês } N / \text{Total da Coorte}) \times 100\%$.

### Query SQL (BigQuery)

```sql
-- Pergunta 2: Análise de Cohort e Taxa de Retenção Mensal
WITH cohort_alunos AS (
  SELECT
    user_id,
    DATE_TRUNC(DATE(dateuserjoinedgroup), MONTH) AS cohort_month,
    dateuserleftgroup,
    user_status
  FROM `gem-dados-lake-prd.marts.dim_usuarios`
  WHERE dateuserjoinedgroup IS NOT NULL
),

atividades_mensais AS (
  SELECT
    user_id,
    DATE_TRUNC(DATE(startedcourse), MONTH) AS mes_atividade
  FROM `gem-dados-lake-prd.marts.fct_progresso_cursos`
  WHERE startedcourse IS NOT NULL
  GROUP BY user_id, mes_atividade
),

cohort_tamanho AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT user_id) AS total_alunos_cohort
  FROM cohort_alunos
  GROUP BY cohort_month
)

SELECT
  c.cohort_month,
  s.total_alunos_cohort,
  DATE_DIFF(a.mes_atividade, c.cohort_month, MONTH) AS meses_desde_inicio,
  COUNT(DISTINCT a.user_id) AS alunos_retidos,
  ROUND(
    SAFE_DIVIDE(COUNT(DISTINCT a.user_id) * 100.0, s.total_alunos_cohort),
    2
  ) AS taxa_retencao_pct
FROM cohort_alunos c
JOIN cohort_tamanho s
  ON c.cohort_month = s.cohort_month
LEFT JOIN atividades_mensais a
  ON c.user_id = a.user_id
  AND a.mes_atividade >= c.cohort_month
GROUP BY c.cohort_month, s.total_alunos_cohort, meses_desde_inicio
HAVING meses_desde_inicio >= 0
ORDER BY c.cohort_month, meses_desde_inicio;
```

---

## Pergunta 3: Eficiência & Gargalos de Conclusão de Cursos e Trilhas

> **Objetivo:** *Quais cursos e trilhas apresentam as maiores e menores taxas de conclusão, tempo médio de término e identificação de gargalos de evasão?*

### Lógica de Negócio
- Calcular o volume de alunos que iniciaram vs completaram cada curso e trilha.
- Taxa de Conclusão (%) = $(\text{Total Concluídos} / \text{Total Iniciados}) \times 100\%$.
- Identificar tempo médio de conclusão em horas/dias para identificar conteúdos com atrito.

### Query SQL (BigQuery)

```sql
-- Pergunta 3: Desempenho e Gargalos por Curso
SELECT
  c.course_id,
  c.coursename,
  c.technology,
  COUNT(DISTINCT c.user_id) AS total_inscritos,
  COUNTIF(c.is_completed = TRUE) AS total_concluidos,
  COUNTIF(c.is_completed = FALSE AND c.coursecompletionrate > 0) AS em_progresso,
  COUNTIF(c.coursecompletionrate = 0 OR c.coursecompletionrate IS NULL) AS nao_iniciados,

  ROUND(
    SAFE_DIVIDE(COUNTIF(c.is_completed = TRUE) * 100.0, COUNT(DISTINCT c.user_id)),
    2
  ) AS taxa_conclusao_pct,

  ROUND(AVG(c.coursecompletionrate) * 100, 2) AS progresso_medio_pct,
  ROUND(AVG(c.duration_minutes) / 60.0, 2) AS tempo_medio_conclusao_horas,
  ROUND(AVG(c.totalcoursexpearned), 0) AS xp_medio_gerado

FROM `gem-dados-lake-prd.marts.fct_progresso_cursos` c
GROUP BY c.course_id, c.coursename, c.technology
HAVING total_inscritos >= 5
ORDER BY taxa_conclusao_pct DESC, total_inscritos DESC;
```

---

## Pergunta 4: Evolução de Proficiência & Habilidades (Skill Assessments)

> **Objetivo:** *Como os alunos evoluem nas avaliações de competência (score e nível de proficiência) entre diferentes tentativas por tecnologia?*

### Lógica de Negócio
- Comparar o `reported_score` e `reported_knowledge_level` da primeira tentativa (`attempt_number = 1`) com a tentativa mais recente de cada aluno.
- Calcular o delta médio de pontuação ($\Delta \text{Score} = \text{Score Final} - \text{Score Inicial}$).
- Mensurar o percentual de alunos que atingiram o nível 'Proficient' / 'Advanced'.

### Query SQL (BigQuery)

```sql
-- Pergunta 4: Evolução de Habilidades entre Tentativas de Avaliação
WITH primeira_tentativa AS (
  SELECT
    user_id,
    assessment_slug,
    assessment_name,
    reported_score AS score_inicial,
    reported_knowledge_level AS nivel_inicial,
    reported_percentile AS percentil_inicial,
    date_completed AS data_inicial
  FROM `gem-dados-lake-prd.marts.fct_avaliacoes_habilidades`
  WHERE attempt_number = 1
),

ultima_tentativa AS (
  SELECT
    user_id,
    assessment_slug,
    attempt_number AS total_tentativas,
    reported_score AS score_final,
    reported_knowledge_level AS nivel_final,
    reported_percentile AS percentil_final,
    date_completed AS data_final
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (PARTITION BY user_id, assessment_slug ORDER BY attempt_number DESC) AS rn
    FROM `gem-dados-lake-prd.marts.fct_avaliacoes_habilidades`
  )
  WHERE rn = 1
)

SELECT
  p.assessment_slug,
  p.assessment_name,
  COUNT(DISTINCT p.user_id) AS total_alunos_avaliados,
  ROUND(AVG(p.score_inicial), 1) AS media_score_inicial,
  ROUND(AVG(u.score_final), 1) AS media_score_final,
  ROUND(AVG(u.score_final - p.score_inicial), 1) AS evolucao_media_pontos,
  ROUND(AVG(u.total_tentativas), 1) AS media_tentativas_por_aluno,

  COUNTIF(LOWER(p.nivel_inicial) = "beginner") AS iniciantes_primeira_tentativa,
  COUNTIF(LOWER(u.nivel_final) IN ("intermediate", "advanced", "proficient")) AS proficientes_ultima_tentativa,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(LOWER(u.nivel_final) IN ("intermediate", "advanced", "proficient")) * 100.0,
      COUNT(DISTINCT p.user_id)
    ), 2
  ) AS taxa_proficiencia_final_pct

FROM primeira_tentativa p
JOIN ultima_tentativa u
  ON p.user_id = u.user_id
  AND p.assessment_slug = u.assessment_slug
GROUP BY p.assessment_slug, p.assessment_name
ORDER BY total_alunos_avaliados DESC;
```

---

## Pergunta 5: Adoção & Demanda de Tecnologias

> **Objetivo:** *Quais tecnologias (Python, SQL, R, BI, etc.) concentram o maior engajamento em horas de estudo, conclusões de cursos e obtenção de certificações?*

### Lógica de Negócio
- Cruzar as horas dedicadas no catálogo de conteúdos, progresso nos cursos e certificações obtidas por tecnologia.
- Rankear as tecnologias mais populares e com maior taxa de sucesso na plataforma.

### Query SQL (BigQuery)

```sql
-- Pergunta 5: Demanda e Adoção por Tecnologia
WITH cursos_por_tech AS (
  SELECT
    COALESCE(technology, "Outros") AS tecnologia,
    COUNT(DISTINCT user_id) AS alunos_engajados,
    COUNT(*) AS total_matriculas_cursos,
    COUNTIF(is_completed = TRUE) AS total_cursos_completados,
    SUM(totalcoursexpearned) AS xp_acumulado,
    ROUND(SUM(duration_minutes) / 60.0, 1) AS total_horas_estimadas
  FROM `gem-dados-lake-prd.marts.fct_progresso_cursos`
  GROUP BY tecnologia
),

certificacoes_por_tech AS (
  SELECT
    CASE
      WHEN LOWER(certificationname) LIKE "%python%" THEN "Python"
      WHEN LOWER(certificationname) LIKE "%sql%" THEN "SQL"
      WHEN LOWER(certificationname) LIKE "%r%" THEN "R"
      WHEN LOWER(certificationname) LIKE "%data%" THEN "Data Science / Analytics"
      ELSE "Geral / Outros"
    END AS tecnologia,
    COUNTIF(is_certified = TRUE) AS certificacoes_emitidas
  FROM `gem-dados-lake-prd.marts.fct_certificacoes`
  GROUP BY tecnologia
)

SELECT
  c.tecnologia,
  c.alunos_engajados,
  c.total_matriculas_cursos,
  c.total_cursos_completados,
  ROUND(
    SAFE_DIVIDE(c.total_cursos_completados * 100.0, NULLIF(c.total_matriculas_cursos, 0)),
    2
  ) AS taxa_conclusao_tech_pct,
  c.xp_acumulado,
  c.total_horas_estimadas,
  COALESCE(cert.certificacoes_emitidas, 0) AS total_certificacoes_emitidas
FROM cursos_por_tech c
LEFT JOIN certificacoes_por_tech cert
  ON c.tecnologia = cert.tecnologia
ORDER BY c.total_matriculas_cursos DESC;
```
