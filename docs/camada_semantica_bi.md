# Camada Semântica do BI — Métricas Calculadas & Fórmulas

Este documento define formalmente a **Camada Semântica de Business Intelligence (BI)** para visualização em ferramentas analíticas (Looker Studio, Power BI, Metabase) conectadas ao BigQuery na camada `marts`.

---

## 1. Catálogo de Métricas Calculadas

### 1.1 Taxa de Retenção de Alunos (%)
- **Definição:** Percentual de alunos inscritos em uma coorte (mês de entrada) que permanecem realizando atividades na plataforma no período $N$.
- **Fórmula Matemática:**
  $$\text{Taxa de Retenção}_N (\%) = \left( \frac{\text{Alunos Ativos com Atividade no Mês } N}{\text{Total de Alunos Inscritos na Coorte}} \right) \times 100$$
- **Expressão Looker Studio:**
  ```sql
  COUNT_DISTINCT(CASE WHEN mes_atividade = mes_analise THEN user_id ELSE NULL END) / COUNT_DISTINCT(user_id)
  ```
- **Expressão DAX (Power BI):**
  ```dax
  Taxa_Retencao_Pct = 
  DIVIDE(
      DISTINCTCOUNT(fct_progresso_cursos[user_id]),
      CALCULATE(DISTINCTCOUNT(dim_usuarios[user_id]), ALL(dim_usuarios[dateuserleftgroup])),
      0
  ) * 100
  ```

---

### 1.2 Média de XP por Semana (XP/Semana)
- **Definição:** Volume médio de pontos de experiência (XP) gerados por aluno ativo em cada semana de atividade.
- **Fórmula Matemática:**
  $$\text{Média de XP/Semana} = \frac{\sum \text{XP Total Obtido na Semana}}{\text{Contagem de Alunos Distintos Ativos na Semana}}$$
- **Expressão Looker Studio:**
  ```sql
  SUM(totalcoursexpearned) / COUNT_DISTINCT(user_id)
  ```
- **Expressão DAX (Power BI):**
  ```dax
  Media_XP_Semanal = 
  DIVIDE(
      SUM(fct_progresso_cursos[totalcoursexpearned]),
      DISTINCTCOUNT(fct_progresso_cursos[user_id]),
      0
  )
  ```

---

### 1.3 Taxa de Conclusão de Cursos (%)
- **Definição:** Proporção de cursos concluídos com sucesso em relação ao total de matrículas/inícios de cursos.
- **Fórmula Matemática:**
  $$\text{Taxa de Conclusão de Cursos} (\%) = \left( \frac{\sum \text{Cursos Concluídos (is\_completed = TRUE)}}{\text{Total de Cursos Iniciados}} \right) \times 100$$
- **Expressão Looker Studio:**
  ```sql
  COUNT_DISTINCT(CASE WHEN is_completed = TRUE THEN CONCAT(user_id, CAST(course_id AS STRING)) ELSE NULL END) / COUNT_DISTINCT(CONCAT(user_id, CAST(course_id AS STRING)))
  ```
- **Expressão BigQuery SQL:**
  ```sql
  ROUND(SAFE_DIVIDE(COUNTIF(is_completed = TRUE) * 100.0, COUNT(*)), 2)
  ```

---

### 1.4 Taxa de Conclusão de Trilhas de Aprendizagem (%)
- **Definição:** Percentual de programas/trilhas completos pelos alunos.
- **Fórmula Matemática:**
  $$\text{Taxa de Conclusão de Trilhas} (\%) = \left( \frac{\sum \text{Trilhas Concluídas}}{\text{Total de Trilhas Iniciadas}} \right) \times 100$$
- **Expressão BigQuery SQL:**
  ```sql
  ROUND(SAFE_DIVIDE(COUNTIF(is_completed = TRUE) * 100.0, COUNT(DISTINCT CONCAT(user_id, CAST(track_id AS STRING)))), 2)
  ```

---

### 1.5 Média de Horas de Estudo por Aluno Ativo
- **Definição:** Média de dedicação horária de estudo dos alunos por período.
- **Fórmula Matemática:**
  $$\text{Média de Horas} = \frac{\sum \text{Horas Dedicadas (alltypes)}}{\text{Contagem de Alunos Ativos}}$$
- **Expressão BigQuery SQL:**
  ```sql
  ROUND(SAFE_DIVIDE(SUM(hours_alltypes), COUNT(DISTINCT user_id)), 2)
  ```

---

### 1.6 Taxa de Proficiência em Avaliações (%)
- **Definição:** Percentual de avaliações finalizadas em que o aluno atingiu nível técnico 'Intermediate' ou 'Advanced'.
- **Fórmula Matemática:**
  $$\text{Taxa de Proficiência} (\%) = \left( \frac{\text{Tentativas com Nível Intermediate/Advanced}}{\text{Total de Tentativas Realizadas}} \right) \times 100$$
- **Expressão BigQuery SQL:**
  ```sql
  ROUND(SAFE_DIVIDE(COUNTIF(is_proficient = TRUE) * 100.0, COUNT(*)), 2)
  ```

---

### 1.7 Taxa de Evasão (Churn Rate %)
- **Definição:** Percentual de alunos desligados ou inativos em relação à base total.
- **Fórmula Matemática:**
  $$\text{Taxa de Evasão} (\%) = 100\% - \text{Taxa de Retenção} (\%) = \left( \frac{\text{Alunos com } \text{user\_status} = \text{'inactive'}}{\text{Total de Alunos Cadastrados}} \right) \times 100$$
- **Expressão BigQuery SQL:**
  ```sql
  ROUND(SAFE_DIVIDE(COUNTIF(user_status = 'inactive') * 100.0, COUNT(*)), 2)
  ```

---

## 2. Tabelas & Fontes de Dados no Looker Studio

Para conectar o BI à plataforma de forma performática e segura:

1. **Dashboard de Visão Executiva & Ritmo Semanal:**
   - Fonte principal: `gem-dados-lake-prd.marts.mart_metricas_semanais`
   - Gráficos recomendados:
     - Gráfico de Linhas: `media_xp_por_aluno_semana` e `alunos_ativos_semana` por `semana_inicio`.
     - Scorecards: `xp_total_semana`, `cursos_concluidos_semana`, `trilhas_concluidas_semana`.

2. **Dashboard de Conteúdo & Cursos:**
   - Fonte principal: `gem-dados-lake-prd.marts.fct_progresso_cursos` combinada com `gem-dados-lake-prd.marts.dim_conteudo`.
   - Gráficos recomendados:
     - Tabela dinâmica: `coursename`, `technology`, `taxa_conclusao_pct`, `tempo_medio_conclusao_horas`.
     - Gráfico de Barras: `totalcoursexpearned` por `technology`.

3. **Dashboard de Habilidades & Avaliações:**
   - Fonte principal: `gem-dados-lake-prd.marts.fct_avaliacoes_habilidades`.
   - Gráficos recomendados:
     - Distribuição por Nível: Gráfico de Rosca de `reported_knowledge_level`.
     - Evolução de Pontuação: Gráfico de dispersão `attempt_number` vs `reported_score`.
