source('scripts/00_setup.R')
need_file('outputs/02_manda_wilfahrt_spatial.rds')
state_path <- file.path(wilfahrt_dir, '2_State_Data.csv')
need_file(state_path)
states <- read.csv(state_path, check.names = TRUE, stringsAsFactors = FALSE,
                   na.strings = c('', 'NA'))
stopifnot('Polity' %in% names(states))
states$Polity <- str_squish(as.character(states$Polity))
states <- states %>% filter(!is.na(Polity), Polity != '')
if (anyDuplicated(states$Polity)) stop('Duplicate Polity values in 2_State_Data.csv; review before merging')
manda <- readRDS('outputs/02_manda_wilfahrt_spatial.rds')
original_n <- nrow(manda)

for (level in c(6,8,10)) {
  state_col <- paste0('wilfahrt_', level, 'hr_state')
  key <- paste0('.polity_', level)
  attrs <- states
  names(attrs) <- paste0('wilfahrt_', level, 'hr_', names(attrs))
  # Preserve the original Wilfahrt Polity attribute as a separate output column.
  attrs[[key]] <- attrs[[paste0('wilfahrt_', level, 'hr_Polity')]]
  assert_new_columns(manda, setdiff(names(attrs),key))
  manda <- manda %>% left_join(attrs, by = setNames(key, state_col))
}
stopifnot(nrow(manda) == original_n)
verify_original_unchanged(manda)
saveRDS(manda, 'outputs/03_manda_wilfahrt_full.rds')
cat('Wilfahrt state attributes complete. Rows:', nrow(manda), '; columns:', ncol(manda), '\n')
