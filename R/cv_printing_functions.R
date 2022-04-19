# This file contains all the code needed to parse and print various sections of your CV
# from data. Feel free to tweak it as you desire!


#' Create a CV_Printer object.
#'
#' @param data_location Path of the spreadsheets holding all your data. This can be
#'   either a URL to a Google Sheet with multiple sheets containing the four
#'   data types or a path to a folder containing four `.csv`s with the neccesary
#'   data.
#' @param source_location Where is the code to build your CV hosted?
#' @param pdf_mode Is the output being rendered into a pdf? Aka do links need
#'   to be stripped?
#' @param sheet_is_publicly_readable If you're using google sheets for data,
#'   is the sheet publicly available? (Makes authorization easier.)
#' @return A new `CV_Printer` object.
#' @export
create_CV_object <-  function(data_location,
                              pdf_mode = TRUE,
                              sheet_is_publicly_readable = TRUE) {

  cv <- list(
    pdf_mode = pdf_mode,
    links = c()
  )

  is_google_sheets_location <- stringr::str_detect(data_location, "docs\\.google\\.com")

  if(is_google_sheets_location){
    if(sheet_is_publicly_readable){
      # This tells google sheets to not try and authenticate. Note that this will only
      # work if your sheet has sharing set to "anyone with link can view"
      googlesheets4::gs4_deauth()
    } else {
      # My info is in a public sheet so there's no need to do authentication but if you want
      # to use a private sheet, then this is the way you need to do it.
      # designate project-specific cache so we can render Rmd without problems
      options(gargle_oauth_cache = ".secrets")
    }

    read_gsheet <- function(sheet_id){
      googlesheets4::read_sheet(data_location, sheet = sheet_id, skip = 1, col_types = "c")
    }
    cv$entries_data  <- read_gsheet(sheet_id = "entries")
    cv$skills        <- read_gsheet(sheet_id = "language_skills")
    cv$text_blocks   <- read_gsheet(sheet_id = "text_blocks")
    cv$contact_info  <- read_gsheet(sheet_id = "contact_info")
  } else {
    # Want to go old-school with csvs?
    cv$entries_data <- readr::read_csv(paste0(data_location, "entries.csv"), skip = 1)
    cv$skills       <- readr::read_csv(paste0(data_location, "language_skills.csv"), skip = 1)
    cv$text_blocks  <- readr::read_csv(paste0(data_location, "text_blocks.csv"), skip = 1)
    cv$contact_info <- readr::read_csv(paste0(data_location, "contact_info.csv"), skip = 1)
  }


  extract_year <- function(dates){
    date_year <- stringr::str_extract(dates, "(20|19)[0-9]{2}")
    date_year[is.na(date_year)] <- lubridate::year(lubridate::ymd(Sys.Date())) + 10

    date_year
  }

  parse_dates <- function(dates){

    date_month <- stringr::str_extract(dates, "(\\w+|\\d+)(?=(\\s|\\/|-)(20|19)[0-9]{2})")
    date_month[is.na(date_month)] <- "1"

    paste("1", date_month, extract_year(dates), sep = "-") %>%
      lubridate::dmy()
  }

  # Clean up entries dataframe to format we need it for printing
  cv$entries_data %<>%
    tidyr::unite(
      tidyr::starts_with('description'),
      col = "description_bullets",
      #sep = "\n- ",
      sep = "",
      na.rm = TRUE
    ) %>%
    dplyr::mutate(
      description_bullets = ifelse(description_bullets != "", paste0("", description_bullets), ""),
      start = ifelse(start == "NULL", NA, start),
      end = ifelse(end == "NULL", NA, end),
      start_year = extract_year(start),
      end_year = extract_year(end),
      no_start = is.na(start),
      has_start = !no_start,
      no_end = is.na(end),
      has_end = !no_end,
      timeline = dplyr::case_when(
        no_start  & no_end  ~ "N/A",
        no_start  & has_end ~ as.character(end),
        #has_start & no_end  ~ paste("Current", "-", start),
        has_start & no_end  ~ paste(start),
        TRUE                ~ paste(start, "-", end)
      )
    ) %>%
    dplyr::arrange(desc(parse_dates(start))) %>%
    dplyr::arrange(desc(parse_dates(end))) %>%
    dplyr::mutate_all(~ ifelse(is.na(.), 'N/A', .))

  cv
}


# Remove links from a text block and add to internal list
sanitize_links <- function(cv, text){
  if(cv$pdf_mode){
    link_titles <- stringr::str_extract_all(text, '(?<=\\[).+?(?=\\])')[[1]]
    link_destinations <- stringr::str_extract_all(text, '(?<=\\().+?(?=\\))')[[1]]

    n_links <- length(cv$links)
    n_new_links <- length(link_titles)

    if(n_new_links > 0){
      # add links to links array
      cv$links <- c(cv$links, link_destinations)

      # Build map of link destination to superscript
      link_superscript_mappings <- purrr::set_names(
        paste0("<sup>", (1:n_new_links) + n_links, "</sup>"),
        paste0("(", link_destinations, ")")
      )

      # Replace the link destination and remove square brackets for title
      text <- text %>%
        stringr::str_replace_all(stringr::fixed(link_superscript_mappings)) %>%
        stringr::str_replace_all('\\[(.+?)\\]', "\\1")
    }
  }

  list(cv = cv, text = text)
}


#' Create a markdown code with given content and layout
#'
#' @description Take a position data frame and the section id desired and prints the section to markdown.
#' @param section_id ID of the entries section to be printed as encoded by the `section` column of the `entries` table
#' @param regex_expression Expression defining the output based on input from google drive og csv files. For example, use `{title}` to insert title. Use `print_var_names` to get a list of availible variable names.
#' @return Markdown code with data from defined input.
#' @export
print_section <- function(cv, section_id, regex_expression='{title} {description_bullets} \\hfill {start}', title = '# Title'){

  glue_template <- paste0(regex_expression, "\n\n\n")

  section_data <- dplyr::filter(cv$entries_data, section == section_id)

  if (nrow(section_data)!=0){
    cat(paste0(title, '\n'))

    # Take entire entries data frame and removes the links in descending order
    # so links for the same position are right next to each other in number.
    for(i in 1:nrow(section_data)){
      for(col in c('title', 'description_bullets')){
        strip_res <- sanitize_links(cv, section_data[i, col])
        section_data[i, col] <- strip_res$text
        cv <- strip_res$cv
      }
    }

    print(glue::glue_data(section_data, glue_template))
    cat('\\vspace{0.3cm}')

    invisible(strip_res$cv)
  }
}



#' Print text block
#'
#' @description Prints out text block identified by a given label.
#' @param label ID of the text block to print as encoded in `label` column of `text_blocks` table.
#' @export
print_text_block <- function(cv, label){
  text_block <- dplyr::filter(cv$text_blocks, loc == label) %>%
    dplyr::pull(text)

  strip_res <- sanitize_links(cv, text_block)

  cat(strip_res$text)

  invisible(strip_res$cv)
}


#' Get list of variable names
#'
#' @description Print available variable names.
#' @param cv Enter name of dataframe where cv data is loaded. `CV` is default in the markdown template.
#' @param list_name List name (name of tab in Google Sheet). Default is `pdf_mode`, `links`, `entries_data`, `skills`, `text_block` and `contact_info`.
#' @export
print_var_names <- function(cv, list_name) {
  colnames(dplyr::filter(cv$list_name))
}



#' Steve's Academic CV Template
#'
#' A template for academic CVs. For more information, see here:
#' <http://svmiller.com/blog/2016/03/svm-r-markdown-cv/>.
#'
#' # About YAML header fields
#'
#' This section documents some of the YAML fields to know
#' for this template.
#'
#'
#' | FIELD  | DESCRIPTION |
#' | ------ | ----------- |
#' | `author` | name of the author |
#' | `jobtitle` | appears as first row in the CV |
#' | `address` |appears as second row in the CV |
#' | `fontawesome` | logical, defaults to `TRUE`. If `TRUE`, use fontawesome icons |
#' | `email` | your email, for the third row |
#' | `github` | optional, displays Github user name on third row |
#' | `orcid` | optional, displays ORCID ID on third row |
#' | `phone` | optional, displays your phone number on third row |
#' | `web` | optional, displays your domain name on third row |
#' | `updated` | optional, displays (on third row) when file was last updated |
#' | `keywords` | not terribly useful, but some keywords to embed in PDF so Google may find it |
#'
#' @inheritParams rmarkdown::pdf_document
#' @param ... Arguments to [`rmarkdown::pdf_document`].
#' @md
#' @export
#'

cv <- function(...){
  templ <- system.file("rmarkdown", "templates", "cv", "resources", "template.tex", package = "datadrivencv")
  rmarkdown::pdf_document(template = templ,
                          ...)
}



#' Print path to tex template
#'
#' @rdname cv
#' @exports
templ_cv <- function() {
  print(system.file("rmarkdown", "templates", "cv", "resources", "template.tex", package = "datadrivencv"))
}
