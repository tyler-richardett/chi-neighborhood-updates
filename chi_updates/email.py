from datetime import date
from email.message import EmailMessage
from smtplib import SMTP
from typing import Dict, Optional

import pandas as pd

STYLE_TAG = """
<style>
    table {
        font-family: Roboto, Arial, sans-serif;
        font-size: 0.9rem;
        font-weight: 400;
        border: none;
        margin-bottom: 3rem;
        border-spacing: 0;
    }

    thead {
        text-transform: uppercase;
        letter-spacing: 0.075rem;
        font-size: 0.75rem;
        background: #CCCCCC;
        border: none;
        text-align: left;
    }

    td {
        border-top: none;
        border-bottom: 1pt solid #CCCCCC;
        border-left: none;
        border-right: none;
        padding: 1rem 0.75rem;
    }

    th {
        border: none;
        padding: 0.75rem;
    }

    h1.table-title {
        font-family: Roboto, Arial, sans-serif;
        font-size: 1.5rem;
        font-weight: 700;
        margin-bottom: 1rem;
    }

    tr:nth-child(even) {
        background-color: #f2f2f2;
    }
</style>
"""


def compile_html_body(results: Dict[str, Optional[pd.DataFrame]]) -> str:
    """
    Compile HTML body containing results tables.

    Args:
        results (Dict[str, Optional[pd.DataFrame]]): Dictionary of results,
            where keys are section headings and values are Pandas DataFrames
            or None.

    Returns:
        str: HTML string containing results tables.

    """
    html = "<html><head>"
    html += STYLE_TAG
    html += "</head><body>"

    for key, value in results.items():
        if value is not None:
            html += f'<h1 class="table-title">{key}</h1>'
            html += value.to_html(
                classes="table-striped table-hover table", na_rep="", index=False
            ).replace('<tr style="text-align: right;">', "<tr>")

    html += "</body></html>"
    return html


def send_email(
    from_address: str,
    to_addresses: str,
    html_body: str,
    smtp_server: str,
    smtp_port: int,
    smtp_user: str,
    smtp_password: str,
) -> None:
    """
    Send email with HTML body.

    Args:
        from_address (str): Sender email address.
        to_addresses (str): List of comma-separated recipient email addresses.
        html_body (str): HTML string to send as email body.
        smtp_server (str): SMTP server hostname.
        smtp_port (int): SMTP server port.
        smtp_user (str): SMTP username.
        smtp_password (str): SMTP password.

    """
    email = EmailMessage()
    email[
        "Subject"
    ] = f"Summary of Local CDP Updates - {date.today().strftime('%B %-d, %Y')}"
    email["From"] = from_address
    email["To"] = to_addresses
    email.set_content(html_body, subtype="html")

    with SMTP(smtp_server, smtp_port) as smtp:
        smtp.login(smtp_user, smtp_password)
        smtp.send_message(email)
