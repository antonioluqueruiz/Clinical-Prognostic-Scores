install.packages("predRupdate")
install.packages("readxl")
install.packages(c("tidyverse", "mice", "naniar", "pROC", "rms", "gtsummary"))
install.packages("readr")
install.packages(c("tidyverse", "broom"))
install.packages( "glmnet")
install.packages("randomForest")
library(pROC)
library(predRupdate)
library(dplyr)
library(readxl)
library(naniar)
library(mice)
library(randomForest)
library(readr)
library(tidyverse)
library(broom)
library(glmnet)
df <- read.csv("C:/Users/luque/Documents/tfm/dat.csv")

# El objetivo de nuestro modelo. No puede ser un predictor.
TARGET <- "death.within.6.months"


vars_identificadores <- c(
  "X",  
  "inpatient.number"
)


vars_fuga_datos <- c(
  "DestinationDischarge",
  "outcome.during.hospitalization",
  "dischargeDay",
  "time.of.death..days.from.admission.",
  "death.within.28.days",
  "re.admission.within.28.days",
  "death.within.3.months",
  "re.admission.within.3.months",
  "re.admission.within.6.months",
  "return.to.emergency.department.within.6.months",
  "re.admission.time..days.from.admission.",
  "time.to.emergency.department.within.6.months"
)

vars_redundantes <- c(
  "eye.opening",
  "verbal.response",
  "movement"
)

vars_administrativas <- c(
  "admission.ward",
  "admission.way",
  "occupation",
  "discharge.department"
)

variables_a_quitar <- unique(c(
  vars_identificadores, 
  vars_fuga_datos, 
  vars_redundantes, 
  vars_administrativas
))

predictores_a_mantener <- setdiff(names(df), c(variables_a_quitar, TARGET))

df_limpio_inicial <- df %>%
  select(all_of(predictores_a_mantener), all_of(TARGET))

colnames(df_limpio_inicial)


colSums(is.na(df_limpio_inicial))
vars_eliminar <- c(
  "cholinesterase", "homocysteine", "apolipoprotein.A", "apolipoprotein.B", 
  "lipoprotein", "tricuspid.valve.return.pressure", "erythrocyte.sedimentation.rate",
  "myoglobin", "Inorganic.Phosphorus", "serum.magnesium", "EA", "mitral.valve.AMS",
  "glutamic.oxaliplatin", "LVEF", "left.ventricular.end.diastolic.diameter.LV",
  "mitral.valve.EMS", "tricuspid.valve.return.velocity", "high.sensitivity.protein",
  "pH", "standard.residual.base", "standard.bicarbonate", "partial.pressure.of.carbon.dioxide",
  "total.carbon.dioxide", "methemoglobin", "hematocrit.blood.gas", "reduced.hemoglobin",
  "potassium.ion", "chloride.ion", "sodium.ion", "glucose.blood.gas", "lactate",
  "measured.residual.base", "measured.bicarbonate", "carboxyhemoglobin", 
  "body.temperature.blood.gas", "oxygen.saturation", "partial.oxygen.pressure",
  "oxyhemoglobin", "anion.gap", "free.calcium", "total.hemoglobin"
)

df_na_grandes <- df_limpio_inicial %>%
  select(-any_of(vars_eliminar))
str(df_na_grandes)

binary_vars_as_int <- c(
  "myocardial.infarction", "congestive.heart.failure", "peripheral.vascular.disease",
  "cerebrovascular.disease", "dementia", "Chronic.obstructive.pulmonary.disease",
  "connective.tissue.disease", "peptic.ulcer.disease", "diabetes",
  "moderate.to.severe.chronic.kidney.disease", "hemiplegia", "leukemia",
  "malignant.lymphoma", "solid.tumor", "liver.disease", "AIDS", "acute.renal.failure"
)

df_limpiar <- df_na_grandes %>%
  mutate(
    across(where(is.character), as.factor),
    
    across(all_of(binary_vars_as_int), as.factor),
    
    death.within.6.months = as.factor(death.within.6.months)
  )
get_mode <- function(v) {
  uniqv <- unique(v[!is.na(v)])
  uniqv[which.max(tabulate(match(v, uniqv)))]
}



df_final <- df_limpiar %>%
  mutate(
  
    across(where(is.numeric), ~coalesce(., median(., na.rm = TRUE))),
    
    
    across(where(is.factor), ~coalesce(., get_mode(.)))
  )
colSums(is.na(df_final))

#ANÁLISIS UNIVARIADO

write_csv(df_final, "datos_final.csv")

predictores_iniciales <- setdiff(colnames(df_final), TARGET)

cat("--- Buscando variables con un solo nivel (constantes)... ---\n")

niveles_unicos <- sapply(df_final[predictores_iniciales], function(x) length(unique(x)))

variables_constantes <- names(niveles_unicos[niveles_unicos == 1])

if (length(variables_constantes) > 0) {
  cat("Se encontraron", length(variables_constantes), "variables constantes que serán eliminadas:\n")
  print(variables_constantes)
} else {
  cat("No se encontraron variables constantes.\n")
}

predictores_finales <- setdiff(predictores_iniciales, variables_constantes)

cat("\n--- Análisis Univariado Automático para", length(predictores_finales), "variables restantes... ---\n")

-
tabla_resumen_univariado <- tibble(predictor = predictores_finales) %>%
  mutate(
    modelo = map(predictor, ~ glm(
      as.formula(paste(TARGET, "~", .x)),
      data = df_final,
      family = "binomial"
    )),
    resultados = map(modelo, tidy, exponentiate = TRUE, conf.int = TRUE)
  ) %>%
  unnest(resultados) %>%
  filter(term != "(Intercept)") %>%
  select(
    predictor = term,
    odds_ratio = estimate,
    ci_low = conf.low,
    ci_high = conf.high,
    p_value = p.value
  ) %>%
  arrange(p_value)
print(tabla_resumen_univariado, n=116)

# LASSO
df_final <- df_final %>% select(all_of(predictores_finales), all_of(TARGET))
x <- model.matrix(as.formula(paste(TARGET, "~ . -1")), data = df_final)
y <- df_final[[TARGET]]
set.seed(123)
cv_lasso_model <- cv.glmnet(x, y, family = "binomial", alpha = 1)
best_lambda_lasso <- cv_lasso_model$lambda.min
coeficientes_lasso <- coef(cv_lasso_model, s = best_lambda_lasso)
variables_seleccionadas_lasso <- coeficientes_lasso[which(coeficientes_lasso != 0), ]
# print(variables_seleccionadas_lasso)
nombres_vars_lasso <- names(variables_seleccionadas_lasso)[-1]
print(nombres_vars_lasso)

#ELASTIC NET
# cv_elastic_net_model <- cv.glmnet(x, y, family = "binomial", alpha = 0.5)
# best_lambda_elastic_net <- cv_elastic_net_model$lambda.min
# coeficientes_elastic_net <- coef(cv_elastic_net_model, s = best_lambda_elastic_net)
# variables_seleccionadas_elastic_net <- coeficientes_elastic_net[which(coeficientes_elastic_net != 0), ]
# nombres_vars_elastic_net <- names(variables_seleccionadas_elastic_net)[-1]
# print(nombres_vars_elastic_net)

#Stepwise
# full_model <- glm(
#   as.formula(paste(TARGET, "~ .")),
#   data = df_final,
#   family = "binomial"
# )
# step_model <- step(full_model, direction = "backward", trace = 1)
# nombres_vars_stepwise <- names(coef(step_model))[-1]
# print(nombres_vars_stepwise)

#Random forest
# set.seed(123)
# rf_model <- randomForest(
#   as.formula(paste(TARGET, "~ .")),
#   data = df_final,
#   ntree = 500,
#   importance = TRUE
# )
# importancia_vars <- importance(rf_model)

# La convertimos a un dataframe para poder manejarla y visualizarla mejor
# importancia_df <- as.data.frame(importancia_vars) %>%
#   # Añadimos los nombres de las variables como una columna
#   rownames_to_column(var = "predictor") %>%
#   # Nos centramos en 'MeanDecreaseGini', una métrica común de importancia.
#   # Un valor más alto significa que la variable es más importante.
#   select(predictor, importancia = MeanDecreaseGini) %>%
#   # Ordenamos de mayor a menor importancia
#   arrange(desc(importancia))
# print(importancia_df)
# 
# ggplot(head(importancia_df, 20), aes(x = reorder(predictor, importancia), y = importancia)) +
#   geom_bar(stat = "identity", fill = "steelblue") +
#   coord_flip() + # Poner las barras en horizontal para que se lean mejor
#   labs(
#     title = "Top 20 Variables más Importantes (Random Forest)",
#     x = "Predictor",
#     y = "Importancia (Mean Decrease Gini)"
#   ) +
#   theme_minimal()

#MODELO 
predictores_originales <- setdiff(colnames(df_final), TARGET)

predictores_para_formula <- c()
for (variable_original in predictores_originales) {
  if (any(startsWith(nombres_vars_lasso, variable_original))) {
    predictores_para_formula <- c(predictores_para_formula, variable_original)
  }
}
predictores_para_formula <- unique(predictores_para_formula)

cat("--- Variables originales que se incluirán en el modelo final: ---\n")
print(predictores_para_formula)

formula_final <- as.formula(paste(TARGET, "~", paste(predictores_para_formula, collapse = " + ")))


modelo_final <- glm(formula_final, data = df_final, family = "binomial")



cat("\n\n--- RESUMEN ESTÁNDAR DEL MODELO FINAL ---\n")
print(summary(modelo_final))

cat("\n\n--- TABLA DE ODDS RATIOS (OR) E INTERVALOS DE CONFIANZA DEL 95% ---\n")
tabla_or <- as.data.frame(exp(cbind(OR = coef(modelo_final), confint(modelo_final))))
colnames(tabla_or) <- c("Odds Ratio", "CI 95% Inferior", "CI 95% Superior")
print(round(tabla_or, 3))


#CATEGORIZACION 
predictores_originales <- setdiff(colnames(df_final), TARGET)
predictores_padre_lasso <- c()
for (vo in predictores_originales) {
  if (any(startsWith(nombres_vars_lasso, vo))) {
    predictores_padre_lasso <- c(predictores_padre_lasso, vo)
  }
}
predictores_padre_lasso <- unique(predictores_padre_lasso)

vars_continuas_a_categorizar <- predictores_padre_lasso[
  sapply(df_final[predictores_padre_lasso], is.numeric)
]

cat("--- Se categorizarán las siguientes variables continuas: ---\n")
print(vars_continuas_a_categorizar)

df_categorizado <- df_final %>%
  mutate(
    GCS_cat = factor(case_when(
      GCS >= 13 ~ "1. Leve (13-15)",
      GCS >= 9  ~ "2. Moderado (9-12)",
      GCS < 9   ~ "3. Grave (3-8)"
    ), levels = c("1. Leve (13-15)", "2. Moderado (9-12)", "3. Grave (3-8)")),
    
    
    across(
      .cols = all_of(setdiff(vars_continuas_a_categorizar, "GCS")),
      .fns = ~ cut(
        .,
        breaks = unique(quantile(., probs = 0:4/4, na.rm = TRUE)),
        include.lowest = TRUE,
      ),
      .names = "{.col}_cat"
    )
  )
colnames(df_categorizado)

predictores_para_formula_final <- predictores_padre_lasso
for (var in vars_continuas_a_categorizar) {
  predictores_para_formula_final[predictores_para_formula_final == var] <- paste0(var, "_cat")
}

formula_final_categorizada <- as.formula(paste(TARGET, "~", paste(predictores_para_formula_final, collapse = " + ")))

modelo_final_categorizado <- glm(formula_final_categorizada, data = df_categorizado, family = "binomial")
coeficientes <- coef(modelo_final_categorizado)
coef_sin_intercepto <- coeficientes[names(coeficientes) != "(Intercept)"]
B <- min(abs(coef_sin_intercepto[coef_sin_intercepto != 0 & !is.na(coef_sin_intercepto)]))
puntos <- round(coeficientes / B)
score_final_tabla <- as.data.frame(puntos) %>%
  rownames_to_column(var = "Característica") %>%
  rename(Puntos = puntos) %>%
  filter(Puntos != 0) %>%
  mutate(Característica = if_else(Característica == "(Intercept)", "PUNTOS BASE", Característica))


library(tidyverse)


umbrales_de_riesgo_pct <- c(1, 2, 5, 10, 15, 20,25, 30,35, 40,45, 50,55, 60,65, 70,75, 80,85, 90, 95)

tabla_riesgo_clinica <- tibble(
  `Riesgo de Mortalidad Estimado (%)` = umbrales_de_riesgo_pct
) %>%
  mutate(
    
    Log_Odds = log(`Riesgo de Mortalidad Estimado (%)` / 100 / (1 - `Riesgo de Mortalidad Estimado (%)` / 100)),
    
   
    `Puntuación Requerida (Aprox.)` = round(Log_Odds / B)
  ) %>%

  select(-Log_Odds)


cat("--- TABLA DE RIESGO CLÍNICA (AGRUPADA) ---\n")
print(tabla_riesgo_clinica,n=Inf)


#VALIDACION 
predicciones_prob <- predict(modelo_final_categorizado, type = "response")


roc_obj <- roc(df_categorizado[[TARGET]], predicciones_prob)


auc_value <- auc(roc_obj)
cat("--- Capacidad de Discriminación del Modelo ---\n")
cat("El valor del AUC es:", round(auc_value, 4), "\n\n")


plot(roc_obj, main = paste("Curva ROC (AUC =", round(auc_value, 4), ")"), print.auc = TRUE)

#--- EVALUACIÓN DE LA CALIBRACIÓN ---
  

install.packages("ResourceSelection")
library(ResourceSelection)

hl_test <- hoslem.test(as.numeric(df_categorizado[[TARGET]]) - 1,
                       predicciones_prob,
                       g = 10) 

cat("--- Calibración del Modelo (Test de Hosmer-Lemeshow) ---\n")
print(hl_test)
library(rms)
val_results <- val.prob(predicciones_prob, as.numeric(df_categorizado[[TARGET]]) - 1)


install.packages("caret")
library(caret)
control <- trainControl(method = "cv", number = 10)
set.seed(123)

cv_model <- train(
  form = formula_final_categorizada, 
  data = df_categorizado,           
  method = "glm",                    
  family = "binomial",
  trControl = control
)
print(cv_model)
