#' Filter data for a 2-month period with a 2-month offset from a starting month
#'
#' @param data A dataframe in long format with a month column.
#' @param start_month_name The full name of the starting month in Thai (e.g., "มกราคม").
#' @param month_col The name of the column containing full month names. Defaults to "month".
#' @return A dataframe filtered to include only the 2-month period (offset by 2 months).
#' @examples
#' # To use this function, first run the script to create the `risk_data` dataframe.
#' # Then you can call the function like this:
#' # filtered_df <- filter_by_month_range(risk_data, "ธันวาคม")
#' # filtered_df <- filter_by_month_range(risk_data, "มกราคม")
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
