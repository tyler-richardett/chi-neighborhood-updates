# Imports ----------------------------------------------------------------
source("utils/request.R")
source("utils/email.R")

# Definition -------------------------------------------------------------
main <- function(args) {
    search_area <- list(
        latitude = args$search_area_latitude,
        longitude = args$search_area_longitude,
        radius = args$search_area_radius
    )

    business_licenses <- get_business_licenses(search_area = search_area)
    food_inspections <- get_food_inspections(search_area = search_area)
    filming_permits <- get_filming_permits(search_area = search_area)

    html_body <- compile_html_body(
        `New Business Licenses` = business_licensess,
        `New Food Inspection Results` = food_inspections,
        `New Filming Permits` = filming_permits
    )

    send_email(
        from_address = args$from_address,
        to_addresses = args$to_addresses,
        html_body = html_body,
        smtp_server = args$smtp_server,
        smtp_port = args$smtp_port,
        smtp_user = args$smtp_user,
        smtp_password = args$smtp_password
    )
}

# Run --------------------------------------------------------------------
if (!interactive()) {
    parser <- argparse::ArgumentParser()
    parser$add_argument("--search_area_latitude", type = "double",
                        help = "Latitude of search area center.")
    parser$add_argument("--search_area_longitude", type = "double",
                        help = "Longitude of search area center.")
    parser$add_argument("--search_area_radius", type = "integer", default = 2750,
                        help = "Radius of search area (in meters).")
    parser$add_argument("--from_address", default = "updates@mailgun.org",
                        help = "Address of email sender.")
    parser$add_argument("--to_addresses", help = "Comma-separated addresses of email recipients.")
    parser$add_argument("--smtp_server", default = "smtp.mailgun.org",
                        help = "Mailgun SMTP server address.")
    parser$add_argument("--smtp_port", type = "integer", default = 587,
                        help = "Mailgun SMTP server port.")
    parser$add_argument("--smtp_user", help = "Mailgun SMTP server username.")
    parser$add_argument("--smtp_password", help = "Mailgun SMTP server password.")

    args <- parser$parse_args()
    main(args)
}
