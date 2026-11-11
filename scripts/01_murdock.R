source('scripts/00_setup.R')
need_file(manda_path)
manda <- haven::read_dta(manda_path)
stopifnot('tribe' %in% names(manda))
saveRDS(manda, 'outputs/00_original_mandaData.rds')

# The murdock package provides an sp::SpatialPolygonsDataFrame.
# Convert it to sf before applying sf spatial operations.
if (!requireNamespace('murdock', quietly = TRUE)) {
  stop("Install the 'murdock' R package before running this script.")
}
package_data <- new.env(parent = emptyenv())
utils::data('murdock', package = 'murdock', envir = package_data)
if (!exists('murdock', envir = package_data, inherits = FALSE)) {
  stop("Package 'murdock' did not expose a dataset named 'murdock'. Run data(package='murdock') to inspect available objects.")
}
murdock <- get('murdock', envir = package_data, inherits = FALSE)
murdock <- sf::st_as_sf(murdock) %>%
  sf::st_transform(4326) %>%
  sf::st_make_valid()
if (!('NAME' %in% names(murdock))) stop("Murdock data lack the expected 'NAME' column.")
murdock <- murdock %>% mutate(murdock_name = normalize_name(NAME)) %>%
  filter(!is.na(murdock_name), murdock_name != '', !st_is_empty(geometry)) %>%
  select(murdock_name) %>% group_by(murdock_name) %>% summarise(.groups = 'drop')
stopifnot(!anyDuplicated(murdock$murdock_name))

# Centroids from projected polygons, then transform back to lon/lat.
centroids <- st_transform(murdock, 6933) %>% st_centroid() %>% st_transform(4326)
coords <- st_coordinates(centroids)
lookup <- st_drop_geometry(centroids) %>%
  mutate(murdock_longitude = coords[,1], murdock_latitude = coords[,2])

crosswalk <- readr::read_csv('config/crosswalk.csv', show_col_types = FALSE) %>%
  mutate(tribe_match = normalize_name(tribe_match), murdock_match = normalize_name(murdock_match))
stopifnot(!anyDuplicated(crosswalk$tribe_match))
unknown <- crosswalk %>% filter(!murdock_match %in% lookup$murdock_name)
if (nrow(unknown)) {
  message('Skipping crosswalk targets absent in this shapefile: ', paste(unknown$murdock_match, collapse=', '))
  crosswalk <- crosswalk %>% filter(murdock_match %in% lookup$murdock_name)
}
stopifnot(!('DANGBE' %in% crosswalk$tribe_match))

assert_new_columns(manda, c('normalized_name','tribe_match','match_method','murdock_name',
                             'murdock_longitude','murdock_latitude'))
# Construct a one-to-one lookup, then append ONLY; no original values are modified.
tribes <- tibble(normalized_name=unique(tolower(str_squish(as.character(manda$tribe))))) %>%
  mutate(.key=toupper(normalized_name)) %>%
  left_join(crosswalk,by=c('.key'='tribe_match')) %>%
  mutate(murdock_name=case_when(
    .key %in% lookup$murdock_name ~ .key,
    !is.na(murdock_match) ~ murdock_match,
    TRUE ~ NA_character_),
    match_method=case_when(
      .key %in% lookup$murdock_name ~ 'Exact name',
      !is.na(murdock_match) ~ 'Manual crosswalk',
      TRUE ~ NA_character_),
    tribe_match=tolower(murdock_name)) %>%
  select(normalized_name,tribe_match,match_method,murdock_name) %>%
  left_join(lookup,by='murdock_name')
stopifnot(!anyDuplicated(tribes$normalized_name))
manda <- manda %>%
  mutate(.join_name=tolower(str_squish(as.character(tribe)))) %>%
  left_join(tribes,by=c('.join_name'='normalized_name')) %>%
  mutate(normalized_name=.join_name) %>%
  select(-.join_name)
verify_original_unchanged(manda)
saveRDS(manda, 'outputs/01_manda_murdock.rds')
saveRDS(murdock, 'outputs/01_murdock_polygons.rds')
cat('Murdock matched:', sum(!is.na(manda$murdock_name)), '/', nrow(manda), '\n')
