import argparse

from chi_updates.email import compile_html_body, send_email
from chi_updates.request import (
    SearchArea,
    get_business_licenses,
    get_filming_permits,
    get_food_inspections,
)


def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--search-area-latitude", type=float, help="Latitude of search area center."
    )
    parser.add_argument(
        "--search-area-longitude", type=float, help="Longitude of search area center."
    )
    parser.add_argument(
        "--search-area-radius",
        type=int,
        default=2750,
        help="Radius of search area (in meters).",
    )
    parser.add_argument("--from-address", help="Address of email sender.")
    parser.add_argument(
        "--to-addresses", help="Comma-separated addresses of email recipients."
    )
    parser.add_argument(
        "--smtp-server", default="smtp.mailgun.org", help="Mailgun SMTP server address."
    )
    parser.add_argument(
        "--smtp-port", type=int, default=587, help="Mailgun SMTP server port."
    )
    parser.add_argument("--smtp-user", help="Mailgun SMTP server username.")
    parser.add_argument("--smtp-password", help="Mailgun SMTP server password.")

    args = parser.parse_args()

    # Define search area
    search_area = SearchArea(
        lat=args.search_area_latitude,
        lng=args.search_area_longitude,
        radius=args.search_area_radius,
    )

    # Gather results
    business_licenses = get_business_licenses(
        search_area=search_area,
        application_type=["ISSUE"],
    )
    food_inspections = get_food_inspections(
        search_area=search_area,
        facility_type=["Restaurant"],
        results=["Pass", "Pass w/ Conditions", "Fail"],
    )
    filming_permits = get_filming_permits(
        search_area=search_area,
        application_status=["Cancelled"],
    )

    # Populate HTML body of email
    html_body = compile_html_body(
        results={
            "New Business Licenses": business_licenses,
            "New Food Inspection Results": food_inspections,
            "New Filming Permits": filming_permits,
        }
    )

    # Send email
    send_email(
        from_address=args.from_address,
        to_addresses=args.to_addresses,
        html_body=html_body,
        smtp_server=args.smtp_server,
        smtp_port=args.smtp_port,
        smtp_user=args.smtp_user,
        smtp_password=args.smtp_password,
    )
