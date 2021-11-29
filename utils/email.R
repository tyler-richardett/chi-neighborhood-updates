# Imports ----------------------------------------------------------------
library(magrittr)

# Construct HTML body of email -------------------------------------------
compile_html_body <- function(...) {
    components <- list(...)
    html_body <- ""

    for (key in names(components)) {
        html_body <- paste0(html_body, glue::glue("<h3>{key}</h3>"))
        if (check_empty_response(components[[key]])) {
            html_body <- paste0(html_body, htmlTable::htmlTable(components[[key]]))
        } else {
            html_body <- paste0(html_body, "<p>None.</p>")
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

    subject <- as.character(glue::glue("Summary of Local Updates - Week of {previous_sunday}"))

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
                tls = TRUE
            ),
            authenticate = TRUE,
            send = TRUE
        )
    }

}
