# global.R
# Load necessary libraries
library(shiny)
library(tidyverse)
library(readxl)
library(conflicted)
library(bslib)
library(DT)
library(bsicons) # Added for better icons

# Set conflict preference
conflicts_prefer(dplyr::filter)
conflicts_prefer(dplyr::select)

# Source the function file
# You can also move the function definition here if preferred
if (file.exists("function.r")) {
    source("function.r")
}

# --- Data Loading and Preprocessing ---
# Check for processed data first for performance
rds_path <- "data/processed_risk_data.rds"
excel_path <- "data/Pest_Risk_77_Provinces_ByPest_update2029.xlsx"

if (file.exists(rds_path)) {
    message("Loading processed data from RDS...")
    risk_data <- readRDS(rds_path)
} else {
    message(
        "Processed data not found. Loading from Excel (this may take a moment)..."
    )

    # Combine all sheets into one data frame
    df <- excel_path %>%
        excel_sheets() %>%
        set_names() %>%
        map_dfr(~ read_excel(excel_path, sheet = .x), .id = "pest")

    # Create a mapping table for pest severity
    pest_severity <- tribble(
        ~severity_level , ~pest                                                                      ,
        "High"          , "เพลี้ยกระโดดสีน้ำตาล"             ,
        "High"          , "โรคใบไหม้"                                              ,
        "High"          , "หนอนกอ"                                                       ,
        "High"          , "โรคขอบใบแห้ง"                                     ,
        "High"          , "หนู"                                                                ,
        "High"          , "หอยเชอรี่"                                              ,
        "High"          , "บั่ว"                                                             ,
        "High"          , "แมลงหล่า"                                                 ,
        "High"          , "เพลี้ยกระโดดหลังขาว"                ,
        "Moderate"      , "โรคใบจุดสีน้ำตาล"                         ,
        "Moderate"      , "โรคเมล็ดด่าง"                                     ,
        "Moderate"      , "หนอนห่อใบข้าว"                                  ,
        "Moderate"      , "แมลงสิง"                                                    ,
        "Moderate"      , "โรคถอดฝักดาบ"                                     ,
        "Moderate"      , "โรคใบขีดสีน้ำตาล"                         ,
        "Moderate"      , "โรคดอกกระถิน"                                     ,
        "Low"           , "เพลี้ยไฟ"                                                 ,
        "Low"           , "หนอนแมลงวันเจาะยอดข้าว"       ,
        "Low"           , "หนอนปลอกข้าว"                                     ,
        "Low"           , "แมลงดำหนาม"                                           ,
        "Low"           , "โรคใบขีดโปร่งแสง"                         ,
        "Low"           , "เพลี้ยจั๊กจั่นปีกลายหยัก" ,
        "Low"           , "เพลี้ยจั๊กจั่นสีเขียว"          ,
        "Low"           , "โรคใบแถบแดง"
    )

    # Join severity to df
    df <- df %>%
        left_join(pest_severity, by = "pest")

    # Convert severity level to a numeric factor
    df <- df %>%
        mutate(
            severity_level_factor = case_when(
                severity_level == "Low" ~ 1,
                severity_level == "Moderate" ~ 2,
                severity_level == "High" ~ 3
            )
        )

    # Multiply each numeric column by the severity level factor
    df <- df %>%
        mutate(across(4:15, ~ .x * severity_level_factor))

    # Reshape data to long format by month
    risk_data <- df %>%
        pivot_longer(cols = 4:15, names_to = "month", values_to = "risk_val")
}

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
