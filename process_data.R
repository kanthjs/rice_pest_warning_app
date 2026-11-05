# libraries
library(dplyr)
library(tidyr)
library(purrr)
library(readxl)

# --- Data Loading and Preprocessing ---

# Path to the data file
path <- "data/Pest_Risk_77_Provinces_ByPest_update2029.xlsx"

message("Reading Excel file...")
# Combine all sheets into one data frame
df <- path %>%
    excel_sheets() %>%
    set_names() %>%
    map_dfr(~ read_excel(path, sheet = .x), .id = "pest")

# Create a mapping table for pest severity
pest_severity <- tibble(
    severity_level = c(rep("High", 9), rep("Moderate", 7), rep("Low", 8)),
    pest = c(
        "เพลี้ยกระโดดสีน้ำตาล",
        "โรคใบไหม้",
        "หนอนกอ",
        "โรคขอบใบแห้ง",
        "หนู",
        "หอยเชอรี่",
        "บั่ว",
        "แมลงหล่า",
        "เพลี้ยกระโดดหลังขาว",
        "โรคใบจุดสีน้ำตาล",
        "โรคเมล็ดด่าง",
        "หนอนห่อใบข้าว",
        "แมลงสิง",
        "โรคถอดฝักดาบ",
        "โรคใบขีดสีน้ำตาล",
        "โรคดอกกระถิน",
        "เพลี้ยไฟ",
        "หนอนแมลงวันเจาะยอดข้าว",
        "หนอนปลอกข้าว",
        "แมลงดำหนาม",
        "โรคใบขีดโปร่งแสง",
        "เพลี้ยจั๊กจั่นปีกลายหยัก",
        "เพลี้ยจั๊กจั่นสีเขียว",
        "โรคใบแถบแดง"
    )
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

# Keep only the columns the app needs, as a plain data.frame so the RDS
# loads in webR without extra packages
risk_data <- risk_data %>%
    select(pest, `จังหวัด`, severity_level, month, risk_val) %>%
    as.data.frame()

message("Saving processed data to RDS...")
saveRDS(risk_data, "data/risk_data.rds")
message("Done.")
