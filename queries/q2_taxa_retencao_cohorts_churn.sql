-- =============================================================================
-- Pergunta 2: Análise de Cohort e Taxa de Retenção Mensal de Alunos
-- =============================================================================

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
