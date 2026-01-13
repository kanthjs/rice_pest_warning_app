# ui.R
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
