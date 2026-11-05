## global ####
# Kept minimal so the app starts quickly under webR / Shinylive
library(shiny)
library(bslib)
library(bsicons)
library(dplyr, warn.conflicts = FALSE)

# Built by process_data.R from the Excel file and data/pest_stage_weights.csv.
# Re-run process_data.R whenever either input changes.
app_data <- readRDS("data/app_data.rds")
risk_data <- app_data$risk_data
stage_weights <- app_data$stage_weights
scores <- app_data$scores
months_th <- app_data$months
level_labels <- app_data$level_labels

provinces <- sort(unique(risk_data$province))

level_style <- data.frame(
  level = 1:4,
  theme = c("success", "info", "warning", "danger"),
  icon = c(
    "shield-check", "info-circle-fill",
    "exclamation-circle-fill", "exclamation-triangle-fill"
  )
)

stage_names <- c("ระยะกล้า", "ระยะแตกกอ", "ระยะออกดอก", "ระยะสุกแก่")

# Raw outbreak level (1-4) shown next to each pest: chance of finding it,
# where finding it means action is needed
raw_badge_class <- c(
  "text-bg-secondary", "text-bg-info", "text-bg-warning", "text-bg-danger"
)
raw_badge <- function(raw) {
  span(class = paste("badge", raw_badge_class[raw]), paste("ระดับ", raw))
}

## server ####
server <- function(input, output, session) {
  start_idx <- reactive({
    req(input$start_month)
    match(input$start_month, months_th)
  })

  # Score row for the selected province and planting month
  current_score <- reactive({
    req(input$province)
    row <- scores[scores$province == input$province &
      scores$start_idx == start_idx(), ]
    validate(need(nrow(row) == 1, "ไม่พบข้อมูล"))
    row
  })

  # High-severity pests per crop stage, weighted by yield sensitivity
  stage_pests <- reactive({
    req(input$province)
    risk_data %>%
      filter(province == input$province, severity_level == "High") %>%
      mutate(stage = (month_idx - start_idx()) %% 12) %>%
      filter(stage <= 3, raw > 0) %>%
      inner_join(stage_weights, by = c("pest", "stage")) %>%
      filter(weight > 0) %>%
      arrange(stage, desc(raw), desc(weight))
  })

  output$overall_risk_box <- renderUI({
    s <- current_score()
    style <- level_style[s$level, ]
    severe <- s$severe_pests[[1]]
    top <- s$top_pests[[1]]

    value_box(
      title = "ความเสี่ยงต่อผลผลิต",
      value = level_labels[s$level],
      showcase = bs_icon(style$icon),
      theme = style$theme,
      p(sprintf(
        "คะแนน %.0f (ต่ำ < %.0f, ปานกลาง < %.0f, สูง < %.0f, สูงมาก ≥ %.0f)",
        s$score, app_data$cutoffs[1], app_data$cutoffs[2],
        app_data$cutoffs[3], app_data$cutoffs[3]
      )),
      if (length(top) > 0) {
        p("ส่งผลต่อคะแนนมากสุด: ", paste(top, collapse = ", "))
      },
      if (length(severe) > 0) {
        p(
          strong("ระบาดรุนแรงในระยะที่ไวต่อผลผลิต: "),
          paste(severe, collapse = ", ")
        )
      }
    )
  })

  render_stage <- function(k) {
    renderUI({
      sp <- stage_pests()
      sp <- sp[sp$stage == k, ]
      tagList(
        p(class = "text-muted small mb-2", months_th[(start_idx() + k - 1) %% 12 + 1]),
        if (nrow(sp) > 0) {
          div(
            strong("ถ้าพบควรรีบดำเนินการ:", class = "text-danger"),
            tags$ul(
              class = "list-unstyled mt-2",
              lapply(seq_len(nrow(sp)), function(i) {
                tags$li(
                  class = "d-flex justify-content-between align-items-center mb-1",
                  span(sp$pest[i]),
                  raw_badge(sp$raw[i])
                )
              })
            )
          )
        } else {
          div(
            class = "text-success",
            bs_icon("check-circle"),
            " เสี่ยงต่ำที่พบศัตรูข้าวระบาดรุนแรง"
          )
        }
      )
    })
  }

  output$stage0_pests <- render_stage(0)
  output$stage1_pests <- render_stage(1)
  output$stage2_pests <- render_stage(2)
  output$stage3_pests <- render_stage(3)
}

## ui ####
stage_card <- function(k) {
  card(
    card_header(stage_names[k + 1], class = "bg-light"),
    card_body(uiOutput(paste0("stage", k, "_pests")), style = "min-height: 150px;")
  )
}

ui <- page_sidebar(
  title = "ระบบเฝ้าระวังผลผลิตและศัตรูข้าว",
  theme = bs_theme(version = 5, bootswatch = "minty"),
  sidebar = sidebar(
    title = "กำหนดข้อมูลแปลงนา",
    selectInput(
      "province",
      "จังหวัด:",
      choices = provinces,
      selected = provinces[1]
    ),
    selectInput(
      "start_month",
      "เดือนที่หว่าน/ตกกล้า:",
      choices = months_th
    ),
    markdown(
      "
      **คำอธิบาย:**
      ประเมินความเสี่ยงที่ผลผลิตข้าวจะเสียหายจากศัตรูข้าว
      และเตือนให้ระวังศัตรูข้าวในแต่ละระยะการเจริญเติบโต

      **สมมติฐาน:** ข้าวไม่ไวแสง อายุประมาณ 120 วัน
      ระดับความเสี่ยงเป็นการเทียบกันระหว่างจังหวัดและเดือนปลูก
      ไม่ใช่ร้อยละผลผลิตที่สูญเสีย
      "
    )
  ),
  uiOutput("overall_risk_box"),
  h4("ศัตรูข้าวที่เสี่ยงอาจจะพบตามระยะการเจริญของข้าว", class = "mt-3 mb-1"),
  p(
    class = "text-muted small mb-3",
    "ระดับโอกาสพบ/ความเสี่ยง: ",
    raw_badge(1), " ", raw_badge(2), " ", raw_badge(3), " ", raw_badge(4),
    " (สูงขึ้นตามลำดับ)"
  ),
  layout_column_wrap(
    width = 1 / 4,
    stage_card(0),
    stage_card(1),
    stage_card(2),
    stage_card(3)
  )
)

## run the app ####
shinyApp(ui, server)
