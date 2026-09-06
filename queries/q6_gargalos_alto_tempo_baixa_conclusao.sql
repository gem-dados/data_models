-- =============================================================================
-- Pergunta 6 (Bônus): Cursos com Alto Tempo de Estudo e Baixa Conclusão (Gargalos)
-- =============================================================================
-- Objetivo: Identificar cursos onde os alunos dedicam muito tempo mas apresentam
-- baixa taxa de conclusão, sinalizando possíveis barreiras pedagógicas ou conteúdos
-- desatualizados/muito extensos.

WITH metricas_curso AS (
  SELECT
    course_id,
    coursename,
    COALESCE(technology, 'Outros') AS tecnologia,
    COUNT(DISTINCT user_id) AS total_alunos,
    COUNTIF(is_completed = TRUE) AS total_conclusoes,
    ROUND(
      SAFE_DIVIDE(COUNTIF(is_completed = TRUE) * 100.0, COUNT(*)),
      2
    ) AS taxa_conclusao_pct,
    ROUND(AVG(duration_minutes), 1) AS media_duracao_minutos,
    ROUND(AVG(duration_minutes) / 60.0, 1) AS media_horas_estudo,
    ROUND(AVG(totalcoursexpearned), 1) AS media_xp_obtido,
    ROUND(AVG(coursecompletionrate) * 100.0, 2) AS media_progresso_medio_pct
  FROM `gem-dados-lake-prd.marts.fct_progresso_cursos`
  WHERE startedcourse IS NOT NULL
  GROUP BY course_id, coursename, tecnologia
),

medias_gerais AS (
  SELECT
    AVG(media_duracao_minutos) AS media_global_duracao,
    AVG(taxa_conclusao_pct) AS media_global_conclusao
  FROM metricas_curso
  WHERE total_alunos >= 2
)

SELECT
  m.course_id,
  m.coursename,
  m.tecnologia,
  m.total_alunos,
  m.total_conclusoes,
  m.taxa_conclusao_pct,
  m.media_horas_estudo,
  m.media_progresso_medio_pct,
  m.media_xp_obtido,
  -- Flag de alerta: duração acima da média geral e conclusão abaixo da média
  CASE
    WHEN m.media_duracao_minutos > g.media_global_duracao AND m.taxa_conclusao_pct < g.media_global_conclusao
      THEN 'Alto Tempo e Baixa Conclusão (Gargalo Crítico)'
    WHEN m.taxa_conclusao_pct < g.media_global_conclusao
      THEN 'Baixa Conclusão'
    WHEN m.media_duracao_minutos > g.media_global_duracao
      THEN 'Curso Extenso'
    ELSE 'Desempenho Saudável'
  END AS classificacao_gargalo
FROM metricas_curso m
CROSS JOIN medias_gerais g
WHERE m.total_alunos >= 2
ORDER BY m.media_duracao_minutos DESC, m.taxa_conclusao_pct ASC;
