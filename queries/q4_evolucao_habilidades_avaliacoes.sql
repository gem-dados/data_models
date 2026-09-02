-- =============================================================================
-- Pergunta 4: Evolução de Proficiência e Habilidades entre Tentativas de Avaliação
-- =============================================================================

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
