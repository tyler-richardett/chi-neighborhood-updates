# Imports ----------------------------------------------------------------
library(magrittr)
source("utils/request.R")

# Construct HTML body of email -------------------------------------------
compile_html_body <- function(...) {
    components <- list(...)
    html_body <- ""
    style <- "style=\"font-family: Chivo, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', 'Fira Sans', 'Droid Sans', Arial, sans-serif\""

    for (key in names(components)) {
        html_body <- paste0(html_body, glue::glue("<h2 {style}>{key}</h2>"))
        if (check_empty_response(components[[key]])) {
            html_body <- paste0(html_body, glue::glue("<p {style}>None.</p>"))
        } else {
            html_body <- paste0(html_body, gt::gt(components[[key]]) %>% gt_theme_538() %>% gt::as_raw_html())
        }
        html_body <- paste0(html_body, "<br>")
    }

    return(html_body)
}

# Send email using Mailgun -----------------------------------------------
send_email <- function(from_address, to_addresses, html_body,
                       smtp_server, smtp_port, smtp_user, smtp_password) {

    to_addresses <- strsplit(to_addresses, ",")

    previous_sunday <- get_previous_sunday()
    previous_sunday <- gsub(" 0", " ", format(previous_sunday, "%B %d, %Y"))

    subject <- as.character(glue::glue("Summary of Local CDP Updates - Week of {previous_sunday}"))

    for (to_address in to_addresses) {
        mailR::send.mail(
            from = from_address,
            to = to_address,
            subject = subject,
            body = html_body,
            html = TRUE,
            smtp = list(
                host.name = smtp_server,
                port = smtp_port,
                user.name = smtp_user,
                passwd = smtp_password,
                tls = FALSE
            ),
            authenticate = TRUE,
            send = TRUE
        )
    }

}

# GT theme ---------------------------------------------------------------
gt_theme_538 <- function(data,...) {
    data %>%
        gt::opt_all_caps()  %>%
        gt::opt_table_font(
            font = list(
                gt::google_font("Chivo"),
                gt::default_fonts()
            )
        ) %>%
        gt::tab_style(
            style = gt::cell_borders(
                sides = "bottom", color = "rgba(0, 0, 0, 0)", weight = gt::px(2)
            ),
            locations = gt::cells_body(
                columns = gt::everything(),
                # This is a relatively sneaky way of changing the bottom border
                # Regardless of data size
                rows = nrow(data$`_data`)
            )
        )  %>%
        gt::tab_options(
            column_labels.background.color = "white",
            table.border.top.width = gt::px(3),
            table.border.top.color = "rgba(0, 0, 0, 0)",
            table.border.bottom.color = "rgba(0, 0, 0, 0)",
            table.border.bottom.width = gt::px(3),
            column_labels.border.top.width = gt::px(3),
            column_labels.border.top.color = "rgba(0, 0, 0, 0)",
            column_labels.border.bottom.width = gt::px(3),
            column_labels.border.bottom.color = "black",
            data_row.padding = gt::px(10),
            heading.align = "left",
            ...
        )
}
