-- =============================================================================
-- Pergunta 1: Ritmo de Aprendizado Semanal e Média de XP por Aluno Ativo
-- =============================================================================

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
