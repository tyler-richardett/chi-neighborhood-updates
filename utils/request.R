# Imports ----------------------------------------------------------------
library(magrittr)

# Constants --------------------------------------------------------------
BASE_URL <- "https://data.cityofchicago.org/resource"

# Boilerplate query strings ----------------------------------------------
construct_url <- function(base_url = BASE_URL, view_id) {
    url <- glue::glue("{base_url}/{view_id}.json")
    return(url)
}

within_circle <- function(field = "location", latitude, longitude, radius) {
    query_string <- glue::glue("within_circle({field}, {latitude}, {longitude}, {radius})")
    return(query_string)
}

get_previous_sunday <- function() {
    current_date <- Sys.time() %>% lubridate::with_tz("America/Chicago") %>% lubridate::as_date()
    previous_sunday <- lubridate::floor_date(current_date, "week")
    if (current_date == previous_sunday) previous_sunday <- previous_sunday - 7
    return(previous_sunday)
}

date_between <- function(field, previous_sunday) {
    following_sunday <- previous_sunday + 7
    query_string <- glue::glue("{field} >= '{previous_sunday}T00:00:00.000' AND {field} < '{following_sunday}T00:00:00.000'")
    return(query_string)
}

value_in <- function(field, values) {
    values_sql <- paste0("('", paste0(values, collapse = "', '"),"')")
    query_string <- glue::glue("{field} IN {values_sql}")
    return(query_string)
}

construct_where_string <- function(...) {
    strings <- list(...)
    where_string <- paste0(strings, collapse = " AND ")
    return(where_string)
}

# Check whether response contains zero records ---------------------------
check_empty_response <- function(response) {
    return(!"data.frame" %in% class(response) || nrow(response) == 0)
}

# Get business licenses --------------------------------------------------
get_business_licenses <- function(application_type = "ISSUE", search_area) {
    where_location <- within_circle(
        latitude = search_area$latitude,
        longitude = search_area$longitude,
        radius = search_area$radius
    )

    where_date <- date_between(
        field = "date_issued",
        previous_sunday = get_previous_sunday()
    )

    where_application_type <- value_in(
        field = "application_type",
        values = application_type
    )

    query <- list(
        `$where` = construct_where_string(
            where_location,
            where_date,
            where_application_type
        )
    )

    url <- construct_url(view_id = "uupf-x98q")

    r <- httr::GET(url = url, query = query)
    httr::stop_for_status(r)
    response <- r %>%
        httr::content(as = "text", encoding = "UTF-8") %>%
        jsonlite::fromJSON()

    if (check_empty_response(response)) return(response)

    licenses <- response %>%
        dplyr::arrange(dplyr::desc(date_issued), dplyr::desc(expiration_date)) %>%
        dplyr::mutate(
            collapsed_name = toupper(ifelse(legal_name == doing_business_as_name, legal_name, glue::glue("{legal_name} (DBA: {doing_business_as_name})"))),
            license_start_date = strtrim(license_start_date, 10),
            expiration_date = strtrim(expiration_date, 10)
        ) %>%
        dplyr::select(
            `Business Name` = collapsed_name,
            `Address` = address,
            `Start Date` = license_start_date,
            `End Date` = expiration_date,
            `License Type` = business_activity
        )

    return(licenses)
}

# Get food inspection results --------------------------------------------
get_food_inspections <- function(facility_type = "Restaurant", search_area) {
    where_center <- rgeos::readWKT(glue::glue("POINT ({search_area$longitude} {search_area$latitude})"))
    where_radius <- rgeos::gBuffer(where_center, width = search_area$radius / 111139)

    where_date <- date_between(
        field = "inspection_date",
        previous_sunday = get_previous_sunday()
    )

    where_facility_type <- value_in(
        field = "facility_type",
        values = facility_type
    )

    query <- list(
        `$where` = construct_where_string(
            where_date,
            where_facility_type
        )
    )

    url <- construct_url(view_id = "4ijn-s7e5")

    r <- httr::GET(url = url, query = query)
    httr::stop_for_status(r)
    response <- r %>%
        httr::content(as = "text", encoding = "UTF-8") %>%
        jsonlite::fromJSON()

    if (check_empty_response(response)) return(response)

    inspections <- response %>%
        dplyr::rowwise() %>%
        dplyr::mutate(
            within_radius = rgeos::gContains(
                where_radius,
                rgeos::readWKT(glue::glue("POINT ({longitude} {latitude})"))
            )
        ) %>%
        dplyr::ungroup() %>%
        dplyr::filter(within_radius) %>%
        dplyr::arrange(dplyr::desc(inspection_date)) %>%
        dplyr::mutate(
            collapsed_name = toupper(ifelse(dba_name == aka_name, dba_name, glue::glue("{dba_name} (AKA: {aka_name})"))),
            inspection_date = strtrim(inspection_date, 10)
        ) %>%
        dplyr::select(
            `Business Name` = collapsed_name,
            `Address` = address,
            `Inspection Date` = inspection_date,
            `Inspection Type` = inspection_type,
            `Result` = results,
            `Risk Level` = risk,
            `Violations` = violations
        )

    return(inspections)
}

# Get filming permits ----------------------------------------------------
get_filming_permits <- function(search_area) {
    where_location <- within_circle(
        latitude = search_area$latitude,
        longitude = search_area$longitude,
        radius = search_area$radius
    )

    where_date <- date_between(
        field = "applicationissueddate",
        previous_sunday = get_previous_sunday()
    )

    query <- list(
        `$where` = construct_where_string(
            where_location,
            where_date
        )
    )

    url <- construct_url(view_id = "c2az-nhru")

    r <- httr::GET(url = url, query = query)
    httr::stop_for_status(r)
    response <- r %>%
        httr::content(as = "text", encoding = "UTF-8") %>%
        jsonlite::fromJSON()

    if (check_empty_response(response)) return(response)

    permits <- response %>%
        dplyr::arrange(applicationstartdate, applicationenddate) %>%
        dplyr::mutate(
            primarycontactlast = toupper(primarycontactlast),
            street_numbers = glue::glue("{streetnumberfrom}-{streetnumberto}"),
            applicationstartdate = strtrim(applicationstartdate, 10),
            applicationenddate = lubridate::ymd(strtrim(applicationenddate, 10)) + 1
        ) %>%
        tidyr::unite("address", street_numbers, direction, streetname, suffix, na.rm = TRUE, sep = " ") %>%
        dplyr::select(
            `Contact Name` = primarycontactlast,
            `Address` = address,
            `Start Date` = applicationstartdate,
            `End Date` = applicationenddate,
            `Details` = detail
        )

    return(permits)
}
