# Imports ----------------------------------------------------------------

# Definition -------------------------------------------------------------
main <- function(args) {

}

# Run --------------------------------------------------------------------
if (!interactive()) {
    parser <- argparse::ArgumentParser()
    parser$add_argument("--smtp_server", default = "smtp.mailgun.org",
                        help = "Mailgun SMTP server address.")
    parser$add_argument("--smtp_port", type = "integer", default = 587,
                        help = "Mailgun SMTP server port.")
    parser$add_argument("--smtp_user", help = "Mailgun SMTP server username.")
    parser$add_argument("--smtp_password", help = "Mailgun SMTP server password.")

    args <- parser$parse_args()
    main(args)
}
