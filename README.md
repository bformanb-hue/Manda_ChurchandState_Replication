# African ethnicity merge pipeline
AI Disclosure: ChatGPT was used for programming assistance in the creation of the final dataset for this project

Run `scripts/00_setup.R` through `scripts/04_jedwab.R` in order, from this project folder. A fresh R session is fine: each stage reads the preceding stage's `.rds` output.

Jedwab Data: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/6XOWFT

Wilfahrt Data: https://github.com/martha-wilfahrt/atlas-precolonial-african-states/tree/main/data/3_Atlas%20of%20Africa's%20Centralized%20States/3a_Final%20Data

Use data/2_State_Data.csv and all files in data/3_Atlas of Africa's Centralized States/3a_Final Data/

## Put your original files here

```text
africa_merge_pipeline/
  data/
    original/
      mandaData.dta                 <-- original respondent Stata file
      murdock/                     <-- original Murdock polygon shapefile
        murdock.shp                 <-- any .shp filename is OK; update config if different
        murdock.shx
        murdock.dbf
        murdock.prj
      wilfahrt/
        Atlas_6hr.shp/.shx/.dbf/.prj/.cpg
        Atlas_8hr.shp/.shx/.dbf/.prj/.cpg
        Atlas_10hr.shp/.shx/.dbf/.prj/.cpg
        2_State_Data.csv
      Replication Files JOEG/
        ... original Jedwab replication folder, with its Stata subfolders ...
  config/
    crosswalk.csv                 <-- editable reviewed tribe-to-Murdock mappings
  scripts/
    00_setup.R
    01_murdock.R
    02_wilfahrt_spatial.R
    03_wilfahrt_attributes.R
    04_jedwab.R
  outputs/                     <-- intermediate .rds and final .csv/.rds files
```

Keep all shapefile companions with their matching `.shp`. Copy the **entire** `Replication Files JOEG` folder intact; the Jedwab script searches within it for the required `.dta` files, regardless of their subfolder.

## Setup and run

1. Install packages once: `install.packages(c('sf','dplyr','readr','haven','stringr','tidyr','units'))`.
2. Edit input paths near the top of `scripts/00_setup.R` if your filenames differ.
3. Open R from the **africa_merge_pipeline** directory (`setwd('/your/path/africa_merge_pipeline')`).
4. Run sequentially:

```r
source('scripts/00_setup.R')
source('scripts/01_murdock.R')
source('scripts/02_wilfahrt_spatial.R')
source('scripts/03_wilfahrt_attributes.R')
source('scripts/04_jedwab.R')
```

Final outputs: `outputs/mandaData_final.rds` and `outputs/mandaData_final.csv`.

## Important provenance and limitations

- `murdock_name` is matched with exact cleaned names and then **only reviewed mappings in `config/crosswalk.csv`**. Uncertain matches are never auto-assigned. With just these mappings, 44.9% of entries are mapped to Murdock names, which are then used for further merges. Review/extend the CSV if the new Murdock coverage differs.
- Wilfahrt polygons for 6/8/10 hours represent different state reach estimates. Each share is the **union of covered territory** divided by the ethnic territory area. The primary state is the polygon with the largest intersection with that ethnicity. 
- `beach1903_complete.dta`: individual recorded mission points; years can be missing. `grid_africa_final.dta`: Roome mission **counts at grid-cell centroids**. Roome territorial counts and distances are approximations. Distances from polygon to point are 0 when a point lies within the polygon. Missing Murdock matches stay `NA`; a matched territory with no recorded missions is 0.
