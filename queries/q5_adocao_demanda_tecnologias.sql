-- =============================================================================
-- Pergunta 5: Adoção e Demanda de Tecnologias (Cursos vs Certificações)
-- =============================================================================

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
