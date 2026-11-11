library(sf)
library(dplyr)
library(readr)
library(haven)
library(stringr)
library(tidyr)

# Run from the project root, e.g. setwd('/Users/you/Manda_ChurchandState_Replication')
if (!file.exists('config/crosswalk.csv')) stop('Set working directory to africa_merge_pipeline')
dir.create('outputs', showWarnings = FALSE)

manda_path <- 'data/original/mandaData.dta'
murdock_path <- 'data/original/murdock/murdock.shp'
wilfahrt_dir <- 'data/original/wilfahrt'
jedwab_root <- 'data/original/Replication Files JOEG'

normalize_name <- function(x) toupper(str_squish(as.character(x)))
need_file <- function(x) if (!file.exists(x)) stop('Missing original file: ', x)
assert_new_columns <- function(existing, additions) {
  collisions <- intersect(names(existing), additions)
  if (length(collisions)) stop('Refusing to overwrite existing columns: ', paste(collisions, collapse=', '))
}
verify_original_unchanged <- function(result) {
  original <- readRDS('outputs/00_original_mandaData.rds')
  if (nrow(result) != nrow(original)) stop('Respondent row count changed')
  first <- seq_along(names(original))
  if (!identical(names(result)[first], names(original))) stop('Original column names/order changed')
  if (!identical(as.data.frame(result[names(original)]), as.data.frame(original))) {
    stop('One or more original mandaData variables or values changed')
  }
  invisible(TRUE)
}
find_jedwab <- function(filename) {
  if (!dir.exists(jedwab_root)) stop('Missing Jedwab folder: ', jedwab_root)
  paths <- list.files(jedwab_root, pattern = '\\.dta$', full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
  hits <- paths[tolower(basename(paths)) == tolower(filename)]
  if (length(hits) != 1L) stop('Expected one ', filename, ' under ', jedwab_root, '; found ', length(hits))
  hits
}
cat('Setup complete.\n')
