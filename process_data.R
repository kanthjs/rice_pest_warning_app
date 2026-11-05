# Build data/app_data.rds for the Shiny app.
#
# Inputs:
#   data/Pest_Risk_77_Provinces_ByPest_update2029.xlsx  one sheet per pest,
#       raw outbreak value (0-4) per province x month
#   data/pest_stage_weights.csv  yield-sensitivity weight per pest x crop stage
#       (row "default" is used for pests not listed)
#
# Scoring model (see notes/scoring-model-review.md):
#   Planting month s, crop stage k = 0..3 covers calendar month s + k
#   (assumes a ~120-day, non-photoperiod-sensitive variety, s = sowing month).
#   score = sum over pests and stages of raw * severity_factor * stage_weight
#   Levels come from percentiles of score over all province x planting-month
#   cases, and any High pest with raw >= 4 (the maximum) in a stage with weight >= 0.75
#   forces at least level 3 ("high").
#
# Run with: Rscript --vanilla process_data.R

library(dplyr, warn.conflicts = FALSE)
library(tidyr)
library(purrr)
library(readxl)

excel_path <- "data/Pest_Risk_77_Provinces_ByPest_update2029.xlsx"
weights_path <- "data/pest_stage_weights.csv"
out_path <- "data/app_data.rds"

months_th <- c(
  "มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน",
  "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"
)

# Override rule and percentile cut points
override_min_raw <- 4
override_min_weight <- 0.75
level_probs <- c(0.25, 0.75, 0.95)
level_labels <- c("เสี่ยงต่ำ", "เสี่ยงปานกลาง", "เสี่ยงสูง", "เสี่ยงสูงมาก")

# --- Pest severity groups ------------------------------------------------------
pest_severity <- tibble(
  severity_level = c(rep("High", 9), rep("Moderate", 7), rep("Low", 8)),
  pest = c(
    "เพลี้ยกระโดดสีน้ำตาล", "โรคใบไหม้", "หนอนกอ", "โรคขอบใบแห้ง", "หนู",
    "หอยเชอรี่", "บั่ว", "แมลงหล่า", "เพลี้ยกระโดดหลังขาว",
    "โรคใบจุดสีน้ำตาล", "โรคเมล็ดด่าง", "หนอนห่อใบข้าว", "แมลงสิง",
    "โรคถอดฝักดาบ", "โรคใบขีดสีน้ำตาล", "โรคดอกกระถิน",
    "เพลี้ยไฟ", "หนอนแมลงวันเจาะยอดข้าว", "หนอนปลอกข้าว", "แมลงดำหนาม",
    "โรคใบขีดโปร่งแสง", "เพลี้ยจั๊กจั่นปีกลายหยัก", "เพลี้ยจั๊กจั่นสีเขียว",
    "โรคใบแถบแดง"
  )
) %>%
  mutate(severity_factor = c(Low = 1, Moderate = 2, High = 3)[severity_level])

# --- Raw outbreak data (long format) ------------------------------------------
message("Reading Excel file...")
risk_data <- excel_path %>%
  excel_sheets() %>%
  set_names() %>%
  map_dfr(~ read_excel(excel_path, sheet = .x), .id = "pest") %>%
  pivot_longer(all_of(months_th), names_to = "month", values_to = "raw") %>%
  rename(province = `จังหวัด`) %>%
  select(pest, province, month, raw) %>%
  mutate(month_idx = match(month, months_th), raw = as.numeric(raw)) %>%
  inner_join(pest_severity, by = "pest")

missing <- setdiff(pest_severity$pest, unique(risk_data$pest))
if (length(missing) > 0) {
  stop("Pests without data: ", paste(missing, collapse = ", "))
}

# --- Stage weights -------------------------------------------------------------
w_raw <- read.csv(weights_path, encoding = "UTF-8", check.names = FALSE)
unknown <- setdiff(w_raw$pest, c("default", pest_severity$pest))
if (length(unknown) > 0) {
  stop("Unknown pests in ", weights_path, ": ", paste(unknown, collapse = ", "))
}
w_default <- w_raw[w_raw$pest == "default", -1]
stage_weights <- bind_rows(lapply(pest_severity$pest, function(p) {
  row <- w_raw[w_raw$pest == p, -1]
  if (nrow(row) == 0) row <- w_default
  data.frame(pest = p, stage = 0:3, weight = as.numeric(unlist(row)))
}))

# --- Score every province x planting month ------------------------------------
contrib <- bind_rows(lapply(1:12, function(s) {
  risk_data %>%
    mutate(start_idx = s, stage = (month_idx - s) %% 12)
})) %>%
  filter(stage <= 3) %>%
  inner_join(stage_weights, by = c("pest", "stage")) %>%
  mutate(
    points = raw * severity_factor * weight,
    severe = severity_level == "High" &
      raw >= override_min_raw &
      weight >= override_min_weight
  )

pest_contrib <- contrib %>%
  group_by(province, start_idx, pest) %>%
  summarise(points = sum(points), severe = any(severe), .groups = "drop")

scores <- pest_contrib %>%
  group_by(province, start_idx) %>%
  summarise(
    score = sum(points),
    severe_pests = list(pest[severe]),
    top_pests = list(head(pest[order(-points)][points[order(-points)] > 0], 3)),
    .groups = "drop"
  )

cutoffs <- unname(quantile(scores$score, level_probs))
scores <- scores %>%
  mutate(
    level_pct = findInterval(score, cutoffs) + 1,
    level = ifelse(lengths(severe_pests) > 0, pmax(level_pct, 3L), level_pct),
    start_month = months_th[start_idx]
  )

message("Cut points (P25/P75/P95): ", paste(round(cutoffs, 2), collapse = " / "))
message("Level share (%):")
print(round(prop.table(table(factor(level_labels[scores$level], level_labels))) * 100, 1))

# --- Save ---------------------------------------------------------------------
app_data <- list(
  risk_data = as.data.frame(risk_data),
  stage_weights = stage_weights,
  scores = as.data.frame(scores),
  cutoffs = cutoffs,
  level_labels = level_labels,
  months = months_th
)
saveRDS(app_data, out_path)
message("Saved ", out_path)
