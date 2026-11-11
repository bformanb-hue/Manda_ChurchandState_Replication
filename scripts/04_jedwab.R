source('scripts/00_setup.R')
need_file('outputs/03_manda_wilfahrt_full.rds')
need_file('outputs/01_murdock_polygons.rds')
manda <- readRDS('outputs/03_manda_wilfahrt_full.rds')
eth <- readRDS('outputs/01_murdock_polygons.rds') %>% st_transform(4326)
original_n <- nrow(manda)

beach <- read_dta(find_jedwab('beach1903_complete.dta')) %>%
  transmute(mission_name=as.character(mission_loc), mission_year=as.numeric(year),
            denomination=as.character(mission_denom),
            lon=as.numeric(longitude),lat=as.numeric(latitude)) %>%
  filter(is.finite(lon),is.finite(lat),between(lon,-180,180),between(lat,-90,90))
beach_sf <- st_as_sf(beach, coords=c('lon','lat'),crs=4326)

# Roome counts are at geographic grid-cell centroids, not exact mission sites.
roome <- read_dta(find_jedwab('grid_africa_final.dta')) %>%
  transmute(lon=as.numeric(longitude),lat=as.numeric(latitude),
            mission_count=as.numeric(roome24_num)) %>%
  filter(is.finite(lon),is.finite(lat),is.finite(mission_count),mission_count>0,
         between(lon,-180,180),between(lat,-90,90))
roome_sf <- st_as_sf(roome, coords=c('lon','lat'),crs=4326)

beach_inside <- st_intersects(eth,beach_sf)
roome_inside <- st_intersects(eth,roome_sf)
bi <- st_nearest_feature(eth,beach_sf)
ri <- st_nearest_feature(eth,roome_sf)
min_km <- function(a,b,idx) as.numeric(st_distance(a,b[idx,],by_element=TRUE))/1000
first_year <- function(ids) {
  yrs <- beach_sf$mission_year[ids]; yrs <- yrs[is.finite(yrs)]
  if(length(yrs)) min(yrs) else NA_real_
}
eth_tbl <- st_drop_geometry(eth) %>%
  mutate(
    murdock_area_km2 = as.numeric(st_area(st_transform(eth,6933)))/1e6,
    beach1900_missions_in_polygon=lengths(beach_inside),
    beach1900_mission_density_per_1000km2=1000*beach1900_missions_in_polygon/murdock_area_km2,
    beach1900_nearest_distance_km=min_km(eth,beach_sf,bi),
    beach1900_nearest_mission=beach_sf$mission_name[bi],
    beach1900_nearest_mission_year=beach_sf$mission_year[bi],
    beach1900_earliest_mission_year_in_polygon=vapply(beach_inside,first_year,numeric(1)),
    beach1900_missions_founded_by_1850=vapply(beach_inside,function(i) sum(beach_sf$mission_year[i]<=1850,na.rm=TRUE),integer(1)),
    beach1900_missions_founded_by_1880=vapply(beach_inside,function(i) sum(beach_sf$mission_year[i]<=1880,na.rm=TRUE),integer(1)),
    beach1900_missions_founded_by_1900=vapply(beach_inside,function(i) sum(beach_sf$mission_year[i]<=1900,na.rm=TRUE),integer(1)),
    roome1924_mission_cells_in_polygon=lengths(roome_inside),
    roome1924_estimated_missions_in_polygon=vapply(roome_inside,function(i) sum(roome_sf$mission_count[i]),numeric(1)),
    roome1924_estimated_density_per_1000km2=1000*roome1924_estimated_missions_in_polygon/murdock_area_km2,
    roome1924_nearest_grid_distance_km=min_km(eth,roome_sf,ri)
  )
stopifnot(!anyDuplicated(eth_tbl$murdock_name))
assert_new_columns(manda, setdiff(names(eth_tbl),'murdock_name'))
manda <- manda %>% left_join(eth_tbl,by='murdock_name')
stopifnot(nrow(manda)==original_n)
verify_original_unchanged(manda)
saveRDS(manda,'outputs/mandaData_final.rds')
readr::write_csv(manda,'outputs/mandaData_final.csv',na='')
readr::write_csv(head(manda,10),'outputs/mandaData_final_head10.csv',na='')
print(manda %>% summarise(total=n(),murdock_matched=sum(!is.na(murdock_name)),
                           jedwab_matched=sum(!is.na(murdock_area_km2)),
                           beach_inside=sum(beach1900_missions_in_polygon>0,na.rm=TRUE),
                           roome_inside=sum(roome1924_estimated_missions_in_polygon>0,na.rm=TRUE)))
cat('Final merge saved to outputs/mandaData_final.rds and .csv\n')
