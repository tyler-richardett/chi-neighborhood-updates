from abc import ABC
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import List, Optional

import numpy as np
import pandas as pd
from sodapy import Socrata

SOCRATA_URL = "data.cityofchicago.org"


class SocrataDatasets(ABC):
    """
    Contains constants representing Socrata dataset IDs for various open
    datasets.

    Attributes:
        BUSINESS_LICENSES (str): Dataset ID for business licenses.
        FOOD_INSPECTIONS (str): Dataset ID for food inspections.
        FILMING_PERMITS (str): Dataset ID for filming permits.
        BUILDING_PERMITS (str): Dataset ID for building permits.

    """

    BUSINESS_LICENSES = "uupf-x98q"
    FOOD_INSPECTIONS = "4ijn-s7e5"
    FILMING_PERMITS = "c2az-nhru"
    BUILDING_PERMITS = "ydr8-5enu"


@dataclass
class SearchArea:
    """
    Represents a geographic search area.

    Attributes:
        lat (float): The latitude of the center point.
        lng (float): The longitude of the center point.
        radius (int): The radius in meters to search around the center point.

    """

    lat: float
    lng: float
    radius: int


def _init_client() -> Socrata:
    """
    Initializes a Socrata client object.

    Returns:
        Socrata: Socrata client instance.

    """
    return Socrata(SOCRATA_URL, None)


def _within_circle(search_area: SearchArea, field: str = "location") -> str:
    """
    Generates a within circle filter string.

    Args:
        search_area (SearchArea): The search area to filter on.
        field (str, optional): The location field name. Defaults to "location".

    Returns:
        str: The filter string.

    """
    return f"within_circle({field}, {search_area.lat}, {search_area.lng}, {search_area.radius})"


def _date_between(field: str, last_n_days: int = 7) -> str:
    """
    Generates a date range filter string for the last/next N days.

    Args:
        field (str): The date field name.
        last_n_days (int, optional): The number of days. Defaults to 7.

    Returns:
        str: The filter string.

    """
    current_datetime = datetime.now()
    n_days_ago = current_datetime - timedelta(days=last_n_days)

    current_datetime_str = current_datetime.strftime("%Y-%m-%dT%H:%M:%S.000")
    n_days_ago_str = n_days_ago.strftime("%Y-%m-%dT00:00:00.000")

    min_datetime = min(n_days_ago_str, current_datetime_str)
    max_datetime = max(n_days_ago_str, current_datetime_str)

    return f"{field} >= '{min_datetime}' AND {field} < '{max_datetime}'"


def _value_in(field: str, values: List[str], negate: bool = False) -> str:
    """
    Generates a IN filter string.

    Args:
        field (str): The field name.
        values (List[str]): The values to filter on.
        negate (bool, optional): Whether to negate the filter. Defaults to False.

    Returns:
        str: The filter string.

    """
    values_str = "', '".join(values)
    return f"{field} {'NOT' if negate else ''} IN ('{values_str}')"


def get_business_licenses(
    search_area: SearchArea,
    application_type: List[str],
) -> Optional[pd.DataFrame]:
    """
    Fetches business license data from Socrata.

    Args:
        search_area (SearchArea): The geographic area to search within.
        application_type (List[str]): Filter by application type.

    Returns:
        Optional[pd.DataFrame]: A DataFrame of business license records,
            or None if no records found.

    """
    # Construct where clause
    where_location = _within_circle(search_area=search_area)
    where_date = _date_between(field="date_issued")
    where_application_type = _value_in(
        field="application_type", values=application_type
    )
    where = " AND ".join([where_location, where_date, where_application_type])

    # Retrieve results
    client = _init_client()
    results = client.get_all(SocrataDatasets.BUSINESS_LICENSES, where=where)
    results_df = pd.DataFrame.from_records(results)

    if len(results_df) > 0:
        # Concatenate legal and DBA names
        results_df["Business Name"] = np.where(
            results_df["legal_name"] == results_df["doing_business_as_name"],
            results_df["legal_name"],
            results_df.apply(
                lambda x: f"{x['legal_name']} (DBA: {x['doing_business_as_name']})",
                axis=1,
            ).values,
        )

        # Trim date column(s)
        results_df["Start Date"] = results_df["license_start_date"].str[0:10]
        results_df["End Date"] = results_df["expiration_date"].str[0:10]

        # Rename remaining fields
        results_df = results_df.rename(
            columns={"address": "Address", "business_activity": "License Type"}
        )

        # Select relevant columns and sort
        results_df = results_df.loc[
            :,
            results_df.columns.isin(
                ["Business Name", "Address", "Start Date", "End Date", "License Type"]
            ),
        ]
        results_df = results_df.sort_values(
            by=["Start Date", "End Date"], ascending=False
        )

        return results_df

    else:
        return None


def get_food_inspections(
    search_area: SearchArea,
    facility_type: List[str],
    results: List[str],
) -> Optional[pd.DataFrame]:
    """
    Fetches food inspection data from Socrata.

    Args:
        search_area (SearchArea): The geographic area to search within.
        facility_type (List[str]): Filter by facility type.
        results (List[str]): Filter by inspection result.

    Returns:
        Optional[pd.DataFrame]: A DataFrame of food inspection records,
            or None if no records found.

    """
    # Construct where clause
    where_location = _within_circle(search_area=search_area)
    where_date = _date_between(field="inspection_date")
    where_facility_type = _value_in(field="facility_type", values=facility_type)
    where_results = _value_in(field="results", values=results)
    where = " AND ".join(
        [where_location, where_date, where_facility_type, where_results]
    )

    # Retrieve results
    client = _init_client()
    results = client.get_all(SocrataDatasets.FOOD_INSPECTIONS, where=where)
    results_df = pd.DataFrame.from_records(results)

    if len(results_df) > 0:
        # Concatenate legal and DBA names
        results_df["Business Name"] = np.where(
            results_df["dba_name"] == results_df["aka_name"],
            results_df["dba_name"],
            results_df.apply(
                lambda x: f"{x['dba_name']} (AKA: {x['aka_name']})", axis=1
            ).values,
        )

        # Trim date column(s)
        results_df["Inspection Date"] = results_df["inspection_date"].str[0:10]

        # Create violations column if not exists
        results_df["Violations"] = (
            results_df["violations"] if "violations" in results_df.columns else None
        )

        # Rename remaining fields
        results_df = results_df.rename(
            columns={
                "address": "Address",
                "inspection_type": "Inspection Type",
                "results": "Results",
                "risk": "Risk Level",
            }
        )

        # Select relevant columns and sort
        results_df = results_df.loc[
            :,
            results_df.columns.isin(
                [
                    "Business Name",
                    "Address",
                    "Inspection Date",
                    "Inspection Type",
                    "Results",
                    "Risk Level",
                    "Violations",
                ]
            ),
        ]
        results_df = results_df.sort_values(
            by=["Inspection Date", "Business Name"], ascending=False
        )

        return results_df

    else:
        return None


def get_filming_permits(
    search_area: SearchArea,
    application_status: List[str],
) -> Optional[pd.DataFrame]:
    """
    Fetches filming permit data from Socrata.

    Args:
        search_area (SearchArea): The geographic area to search within.
        application_status (List[str]): Filter by application status.

    Returns:
        Optional[pd.DataFrame]: A DataFrame of filming permit records,
            or None if no records found.

    """
    # Construct where clause
    where_location = _within_circle(search_area=search_area)
    where_date = _date_between(field="applicationstartdate", last_n_days=-7)
    where_application_status = _value_in(
        field="currentmilestone", values=application_status, negate=True
    )
    where = " AND ".join([where_location, where_date, where_application_status])

    # Retrieve results
    client = _init_client()
    results = client.get_all(SocrataDatasets.FILMING_PERMITS, where=where)
    results_df = pd.DataFrame.from_records(results)

    if len(results_df) > 0:
        # Concatenate address components
        results_df["street_numbers"] = results_df.apply(
            lambda x: f"{x['streetnumberfrom']}-{x['streetnumberto']}", axis=1
        ).values
        results_df["Address"] = results_df.apply(
            lambda x: x[
                ["street_numbers", "direction", "streetname", "suffix"]
            ].str.cat(sep=" "),
            axis=1,
        )

        # Trim date column(s)
        results_df["Start Date"] = results_df["applicationstartdate"].str[0:10]
        results_df["End Date"] = results_df["applicationenddate"].str[0:10]

        # Rename remaining fields
        results_df = results_df.rename(
            columns={
                "primarycontactlast": "Contact Name",
                "applicationname": "Application Name",
                "detail": "Details",
                "comments": "Comments",
            }
        )

        # Select relevant columns and sort
        results_df = results_df.loc[
            :,
            results_df.columns.isin(
                [
                    "Contact Name",
                    "Application Name",
                    "Address",
                    "Start Date",
                    "End Date",
                    "Details",
                    "Comments",
                ]
            ),
        ]
        results_df = results_df.sort_values(by=["Start Date", "End Date"])

        return results_df

    else:
        return None
