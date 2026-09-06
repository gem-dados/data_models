-- =============================================================================
-- Pergunta 3: Desempenho e Gargalos de Conclusão por Curso
-- =============================================================================

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
