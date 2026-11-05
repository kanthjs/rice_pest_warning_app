## global.R  ####
# Load necessary libraries
# Kept minimal so the app starts quickly under webR / Shinylive
library(shiny)
library(bslib)
library(bsicons)
library(dplyr, warn.conflicts = FALSE)

# --- Data Loading ---
# Pre-processed by process_data.R (Excel -> long format with severity weights).
# Re-run process_data.R whenever the Excel file changes.
risk_data <- readRDS("data/risk_data.rds")

# Create a mapping from month abbreviations to full Thai month names
month_mapping_th <- c(
  "ม.ค." = "มกราคม",
  "ก.พ." = "กุมภาพันธ์",
  "มี.ค." = "มีนาคม",
  "เม.ย." = "เมษายน",
  "พ.ค." = "พฤษภาคม",
  "มิ.ย." = "มิถุนายน",
  "ก.ค." = "กรกฎาคม",
  "ส.ค." = "สิงหาคม",
  "ก.ย." = "กันยายน",
  "ต.ค." = "ตุลาคม",
  "พ.ย." = "พฤศจิกายน",
  "ธ.ค." = "ธันวาคม"
)

# Get list of provinces
provinces <- sort(unique(risk_data$`จังหวัด`))

filter_by_month_range <- function(data, start_month_name, month_col = "month") {
  all_months_th <- c(
    "มกราคม",
    "กุมภาพันธ์",
    "มีนาคม",
    "เมษายน",
    "พฤษภาคม",
    "มิถุนายน",
    "กรกฎาคม",
    "สิงหาคม",
    "กันยายน",
    "ตุลาคม",
    "พฤศจิกายน",
    "ธันวาคม"
  )
  
  start_index <- which(all_months_th == start_month_name)
  
  if (length(start_index) == 0) {
    stop(
      "Invalid month name. Please use full Thai month names (e.g., 'มกราคม')."
    )
  }
  
  # Calculate indices for the 2-month window (offset by 2 months), with wrap-around
  indices <- ((start_index + 1):(start_index + 2)) %% 12 + 1
  target_months <- all_months_th[indices]
  
  # Filter the dataframe
  filtered_data <- data %>%
    filter(.data[[month_col]] %in% target_months)
  
  return(filtered_data)
}


## server ####
server <- function(input, output, session) {
  
  
  
  
  
  
  
  # Reactive: Filter Data for Selected Province and Month Range (Algorithm for Score)
  risk_score_data <- reactive({
    req(input$start_month, input$province)
    
    # 1. Start with correct province
    prov_data <- risk_data %>% filter(`จังหวัด` == input$province)
    
    # 2. Use the standard filter function for the scoring window
    filter_by_month_range(prov_data, input$start_month)
  })
  
  # Reactive: Get list of pests for the 4-month timeline
  pests_timeline_data <- reactive({
    req(input$start_month, input$province)
    
    # All months vector
    all_months <- as.character(month_mapping_th)
    start_idx <- which(all_months == input$start_month)
    
    if (length(start_idx) == 0) {
      return(NULL)
    }
    
    # Calculate indices for 4 months (wrapping around 12)
    indices <- (start_idx:(start_idx + 3) - 1) %% 12 + 1
    target_months <- all_months[indices]
    
    # Filter for province and these 4 months
    timeline_data <- risk_data %>%
      filter(`จังหวัด` == input$province, month %in% target_months) %>%
      mutate(month = factor(month, levels = target_months)) # Order strictly
    
    list(months = target_months, data = timeline_data)
  })
  
  # --- Calculate Overall Risk Score ---
  overall_risk <- reactive({
    dat <- risk_score_data()
    req(dat)
    
    res <- dat %>%
      filter(severity_level == "High") %>%
      summarise(
        risk_val_degree = sum(risk_val, na.rm = TRUE) / 24,
        .groups = 'drop'
      ) %>%
      mutate(
        yield_loss_degree = case_when(
          risk_val_degree > 4 ~ 3,
          risk_val_degree > 2 ~ 2,
          risk_val_degree > 0 ~ 1,
          TRUE ~ 0
        ),
        desc = case_when(
          yield_loss_degree == 3 ~ "มีโอกาสผลผลิตสูญเสีย > 50%",
          yield_loss_degree == 2 ~ "มีโอกาสผลผลิตสูญเสีย ~ 20%",
          yield_loss_degree == 1 ~ "มีโอกาสผลผลิตสูญเสีย ~ 5%",
          TRUE ~ "มีโอกาสผลผลิตสูญเสียน้อย/ปกติ"
        ),
        color = case_when(
          yield_loss_degree == 3 ~ "danger",
          yield_loss_degree == 2 ~ "warning",
          yield_loss_degree == 1 ~ "info",
          TRUE ~ "success"
        ),
        icon_name = case_when(
          yield_loss_degree == 3 ~ "exclamation-triangle-fill",
          yield_loss_degree == 2 ~ "exclamation-circle-fill",
          yield_loss_degree == 1 ~ "info-circle-fill",
          TRUE ~ "shield-check"
        )
      )
    
    if (nrow(res) == 0) {
      return(list(
        risk_val_degree = 0,
        yield_loss_degree = 0,
        desc = "ไม่พบข้อมูล",
        color = "light",
        icon_name = "question-circle"
      ))
    }
    return(as.list(res))
  })
  
  # --- UI Output: Overall Risk Box ---
  output$overall_risk_box <- renderUI({
    risk <- overall_risk()
    
    value_box(
      title = "ผลผลิต",
      value = h4(risk$desc),
      showcase = bsicons::bs_icon(risk$icon_name),
      theme = risk$color,
      p(paste("ค่าดัชนีความเสี่ยง (Degree):", round(risk$risk_val_degree, 2)))
    )
  })
  
  # --- Helper to render pest list for a specific month index (1-4) ---
  render_pest_list <- function(month_idx) {
    renderUI({
      tl <- pests_timeline_data()
      req(tl)
      target_month <- tl$months[month_idx]
      
      # Filter for this month and High/Moderate Severity pests with Risk > 0
      # Updated to include more info or styling if needed
      pests_list <- tl$data %>%
        filter(
          month == target_month,
          risk_val > 0
        ) %>%
        arrange(desc(risk_val))
      
      # Separate high risk for highlighting
      high_risk <- pests_list %>% filter(severity_level == "High")
      mod_risk <- pests_list %>% filter(severity_level == "Moderate")
      
      tagList(
        if (nrow(high_risk) > 0) {
          div(
            strong("ถ้าพบควรรีบดำเนินการ:", class = "text-danger"),
            tags$ul(lapply(unique(high_risk$pest), tags$li))
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
  
  output$month1_pests <- render_pest_list(1)
  output$month2_pests <- render_pest_list(2)
  output$month3_pests <- render_pest_list(3)
  output$month4_pests <- render_pest_list(4)
}



## ui ####
ui <- page_sidebar(
  title = "ระบบเฝ้าระวังผลผลิตและศัตรูข้าว",
  theme = bs_theme(version = 5, bootswatch = "minty"),
  
  sidebar = sidebar(
    title = "กำหนดข้อมูลแปลงนา",
    selectInput(
      "province",
      "จังหวัด:",
      choices = provinces,
      selected = if (length(provinces) > 0) provinces[1] else NULL
    ),
    selectInput(
      "start_month",
      "เดือนที่เริ่มปลูก:",
      choices = setNames(
        as.character(month_mapping_th),
        as.character(month_mapping_th)
      )
    ),
    markdown(
      "
      **คำอธิบาย:**
      เพื่อประเมินว่าผลผลิตข้าวว่ามีความเสี่ยงที่จะเสียหายจากศัตรูข้าวเท่าใดอีกทั้งเตือนเกษตรกรให้ระวังการเกิดศัตรูข้าวในช่วงการเจริญของข้าว
      "
    )
  ),
  
  # Dashboard Layout
  layout_columns(
    col_widths = 12, # Full width for the main risk box
    uiOutput("overall_risk_box")
  ),
  
  div(style = "margin-top: 20px;"),
  h4("ศัตรูข้าวที่เสี่ยงอาจจะพบตามระยะการเจริญของข้าว", class = "mb-3"),
  
  layout_column_wrap(
    width = 1 / 4, # 4 columns per row for better timeline view
    card(
      card_header("ระยะกล้า", class = "bg-light"),
      card_body(uiOutput("month1_pests"), style = "min-height: 150px;")
    ),
    card(
      card_header("ระยะแตกกอ", class = "bg-light"),
      card_body(uiOutput("month2_pests"), style = "min-height: 150px;")
    ),
    card(
      card_header("ระยะออกดอก", class = "bg-light"),
      card_body(uiOutput("month3_pests"), style = "min-height: 150px;")
    ),
    card(
      card_header("ระยะเก็บเกี่ยว", class = "bg-light"),
      card_body(uiOutput("month4_pests"), style = "min-height: 150px;")
    )
  )
)

## run the app ####
shinyApp(ui, server)
