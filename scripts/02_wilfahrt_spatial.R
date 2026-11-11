source('scripts/00_setup.R')
need_file('outputs/01_murdock_polygons.rds')
eth <- readRDS('outputs/01_murdock_polygons.rds') %>% st_transform(6933) %>% st_make_valid()
eth$ethnic_area_m2 <- as.numeric(st_area(eth))

# Polygon union provides the covered SHARE; largest single intersecting
# state provides a deterministic primary polity for attribute joins.
measure_level <- function(level) {
  path <- file.path(wilfahrt_dir, paste0('Atlas_', level, 'hr.shp'))
  need_file(path)
  states <- st_read(path, quiet = TRUE)
  if (!('Polity' %in% names(states))) stop('Missing Polity field: ', path)
  states <- states %>% st_transform(6933) %>% st_make_valid() %>%
    mutate(Polity = str_squish(as.character(Polity))) %>%
    filter(!is.na(Polity), Polity != '', !st_is_empty(geometry))
  if (nrow(states) == 0L) stop('No usable Wilfahrt polygons in ', path)
  intersections <- st_intersects(eth, states)
  result <- lapply(seq_len(nrow(eth)), function(i) {
    ids <- intersections[[i]]
    if (length(ids) == 0L) return(data.frame(share=0, state=NA_character_))
    # Intersect with each candidate state to determine the largest overlap.
    pieces <- lapply(ids, function(j) {
      p <- suppressWarnings(st_intersection(st_geometry(eth)[i], st_geometry(states)[j]))
      if (length(p) == 0L || all(st_is_empty(p))) return(NULL)
      p
    })
    good <- !vapply(pieces, is.null, logical(1))
    if (!any(good)) return(data.frame(share=0, state=NA_character_))
    pieces <- pieces[good]; ids <- ids[good]
    areas <- vapply(pieces, function(g) sum(as.numeric(st_area(g))), numeric(1))
    if (!any(areas > 0)) return(data.frame(share=0, state=NA_character_))
    # Union all covered pieces, so overlapping Wilfahrt states are not double counted.
    unioned <- st_union(do.call(c, pieces))
    covered_m2 <- as.numeric(st_area(unioned))
    data.frame(share = min(1, covered_m2 / eth$ethnic_area_m2[i]),
               state = as.character(states$Polity[ids[which.max(areas)]]))
  })
  tbl <- dplyr::bind_rows(result)
  names(tbl) <- paste0('wilfahrt_', level, 'hr_', c('share','state'))
  bind_cols(st_drop_geometry(eth)['murdock_name'], tbl)
}

levels <- c(6,8,10)
level_tables <- lapply(levels, measure_level)
spatial <- Reduce(function(a,b) left_join(a,b,by='murdock_name'), level_tables)
stopifnot(!anyDuplicated(spatial$murdock_name))
manda <- readRDS('outputs/01_manda_murdock.rds')
assert_new_columns(manda, setdiff(names(spatial),'murdock_name'))
manda <- left_join(manda, spatial, by='murdock_name')
verify_original_unchanged(manda)
saveRDS(manda, 'outputs/02_manda_wilfahrt_spatial.rds')
cat('Wilfahrt spatial measures complete. Rows:', nrow(manda), '\n')
