## this will read in trait data
## cut the trait data down to all those that
## are in eBird and then assign the "binom" to
## the scientific names of the tree so we get the best matches
read_trait_data_in <- function(){
  
  require(readr)

taxonomy_key <- read_csv("Data/Taxonomy/taxonomy_key.csv")
traits <- read_csv("Data/Raw trait data/Australian_Bird_Data_Version_1.csv")

traits$SCIENTIFIC_NAME_traits <- paste(traits$`4_Genus_name_2`, traits$`5_Species_name_2`,sep="_")

traits <- traits %>%
  inner_join(., taxonomy_key, by="SCIENTIFIC_NAME_traits") %>%
  rename(binom = SCIENTIFIC_NAME_tree) %>%
  mutate(binom = gsub(" ", "_", .$binom))

  return(traits)
}



Mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}


## This uses the trait data to collect all
## The necessary trait characteristics
read_process_trait_data <- function(){
  
  traits <- read_trait_data_in()
  
  ms <- traits %>%
    mutate(body_mass=ifelse(`99_Body_mass_average_8`=="NAV",NA,as.numeric(`99_Body_mass_average_8`))) %>%
    mutate(clutch_size=ifelse(`178_Clutch_size_average_12`=="NAV",NA,as.numeric(`178_Clutch_size_average_12`))) %>%
    mutate(iucn_status=`49_Australian_status_July_2015_5`) %>%
    mutate(brain_size=ifelse(`113_Brain_mass_8`=="NAV", NA, as.numeric(`113_Brain_mass_8`))) %>%
    mutate(brain_residual=ifelse(`114_Brain_mass_residual_8`=="NAV", NA, as.numeric(`114_Brain_mass_residual_8`))) %>%
    mutate(diet_generalism=rowSums(.[163:173], na.rm=TRUE)) %>%
    group_by(binom) %>%
    summarise(mean_body_size=mean(body_mass,na.rm=T), 
              clutch_size=mean(clutch_size,na.rm=T),
              iucn_status=Mode(iucn_status),
              brain_size=mean(brain_size, na.rm=T),
              brain_residual=mean(brain_residual, na.rm=T))
              
    
## calculate df for feeding habitat generalism
    feeding_habitat_generalism <- traits %>%
      dplyr::select(binom, 115:144) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(feeding_habitat_generalism = rowSums(.[2:31])) %>%
      dplyr::select(binom, feeding_habitat_generalism)
    
## calculate df for breeding habitat generalism
    breeding_habitat_generalism <- traits %>%
      dplyr::select(binom, 146:161) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(breeding_habitat_generalism = rowSums(.[2:17])) %>%
      dplyr::select(binom, breeding_habitat_generalism)
    
    
## df for specific habitat types (trees/forests and shrubs/grasslands and agricultural)
    tree_forest <- traits %>%
      dplyr::select(binom, 115:144, 146:161) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      dplyr::select(binom, 8:12, 38:42) %>%
      mutate(tree_forest = rowSums(.[2:11])) %>%
      dplyr::select(binom, tree_forest) %>%
      mutate(tree_forest = ifelse(.$tree_forest > 1, 1, .$tree_forest)) %>%
      mutate(Habitat_tree_forest = ifelse(.$tree_forest == 1, "Yes", "No")) %>%
      dplyr::select(-tree_forest)
    
    
    grass_shrubland <- traits %>%
      dplyr::select(binom, 115:144, 146:161) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      dplyr::select(binom, 1:2, 4:5, 32:33, 35:36) %>%
      mutate(grass_shrubland = rowSums(.[2:8])) %>%
      dplyr::select(binom, grass_shrubland) %>%
      mutate(grass_shrubland = ifelse(.$grass_shrubland > 1, 1, .$grass_shrubland)) %>%
      mutate(Habitat_grass_shrubland = ifelse(.$grass_shrubland == 1, "Yes", "No")) %>%
      dplyr::select(-grass_shrubland)
    
    
    agricultural <- traits %>%
      dplyr::select(binom, 115:144, 146:161) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      dplyr::select(binom, 31, 37) %>%
      mutate(agricultural = rowSums(.[2:3])) %>%
      dplyr::select(binom, agricultural) %>%
      mutate(agricultural = ifelse(.$agricultural > 1, 1, .$agricultural)) %>%
      mutate(Habitat_agricultural = ifelse(.$agricultural == 1, "Yes", "No")) %>%
      dplyr::select(-agricultural)
  
    habitat_types <- agricultural %>%
      inner_join(., grass_shrubland, by="binom") %>%
      inner_join(., tree_forest, by="binom")
      

## Diet generalism
    diet_generalism <- traits %>%
      dplyr::select(binom, 163:173) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(diet_generalism = rowSums(.[2:12])) %>%
      dplyr::select(binom, diet_generalism)

## diet categories of specific interest
    diet_types <- traits %>%
      dplyr::select(binom, 165, 166, 167, 168, 170) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      rename(granivore = `165_Food_Seeds_10`) %>%
      rename(insectivore = `168_Food_Terrestrial_invertebrates_10`) %>%
      rename(plants1 = `166_Food_Foliage_or_herbs_10`) %>%
      rename(plants2 = `167_Food_Corms_or_tubers`) %>%
      rename(carrion_eater = `170_Food_Carrion_10`) %>%
      mutate(plant_eater = plants1+plants2) %>%
      dplyr::select(-plants1, -plants2) %>%
      mutate(granivore = ifelse(granivore == 1, "Yes", "No")) %>%
      mutate(insectivore = ifelse(insectivore == 1, "Yes", "No")) %>%
      mutate(plant_eater = as.integer(as.character(gsub("2", "1", .$plant_eater)))) %>%
      mutate(plant_eater = ifelse(plant_eater == 1, "Yes", "No")) %>%
      mutate(carrion_eater = ifelse(carrion_eater == 1, "Yes", "No"))
    
## join diet
    diet <- inner_join(diet_types, diet_generalism, by="binom")

    
## Nesting generalism
    nest_generalism <- traits %>%
      dplyr::select(binom, 183:188) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(`183_Nest_location_Ground_level_12` = as.integer(as.character(gsub(2, 1, .$`183_Nest_location_Ground_level_12`)))) %>%
      mutate(`184_Nest_location_Supported_12` = as.integer(as.character(gsub(2, 1, .$`184_Nest_location_Supported_12`)))) %>%
      mutate(nest_generalism = rowSums(.[2:7])) %>%
      dplyr::select(binom, nest_generalism)
    
## nesting categories of specific interest
    nest_types <- traits %>%
      dplyr::select(binom, 183, 187) %>%
      replace(is.na(.), 0) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      rename(ground_nesting = `183_Nest_location_Ground_level_12`) %>%
      rename(hollow_nesting = `187_Nest_location_Hollow_12`) %>%
      mutate(ground_nesting = gsub(2, 1, .$ground_nesting)) %>%
      mutate(ground_nesting = ifelse(ground_nesting == "1", "Yes", "No")) %>%
      mutate(hollow_nesting = ifelse(hollow_nesting == 1, "Yes", "No"))
    
## join nesting
    nesting <- inner_join(nest_types, nest_generalism, by="binom")
    
## movement
    migrant <- traits %>%
      dplyr::select(binom, 194, 195) %>%
      replace(is.na(.), 0) %>%
      mutate_all(funs(str_replace(., "NAV", "0"))) %>%
      mutate(`194_National_movement_Partial_migrant_13` = as.integer(as.character(`194_National_movement_Partial_migrant_13`))) %>%
      mutate(`195_National_movement_Total_migrant_13` = as.integer(as.character(`195_National_movement_Total_migrant_13`))) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(migrate = `194_National_movement_Partial_migrant_13` + `195_National_movement_Total_migrant_13`) %>%
      mutate(migrate=ifelse(migrate == 0, "No", "Yes")) %>%
      dplyr::select(binom, migrate)
    
    opportunistic <- traits %>%
      dplyr::select(binom, 196, 197) %>%
      replace(is.na(.), 0) %>%
      mutate_all(funs(str_replace(., "NAV", "0"))) %>%
      mutate(`196_National_movement_Nomadic_or_opportunistic_13` = as.integer(as.character(`196_National_movement_Nomadic_or_opportunistic_13`))) %>%
      mutate(`197_National_movement_Irruptive_13` = as.integer(as.character(`197_National_movement_Irruptive_13`))) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(nomadic_irruptive = `196_National_movement_Nomadic_or_opportunistic_13` + `197_National_movement_Irruptive_13`) %>%
      mutate(nomadic_irruptive=ifelse(nomadic_irruptive == 0, "No", "Yes")) %>%
      dplyr::select(binom, nomadic_irruptive)
      
    movement <- opportunistic %>%
      inner_join(., migrant, by="binom")


## gregariousness
    cooperative_breeding <- traits %>%
      dplyr::select(binom, 192) %>%
      replace(is.na(.), 0) %>%
      mutate_all(funs(str_replace(., "NAV", "0"))) %>%
      rename(breeding = `192_Breeding_system_Cooperative_12`) %>%
      mutate(breeding = as.integer(as.character(.$breeding))) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(breeding = ifelse(breeding==0, "Not cooperative", "Cooperative"))
      
    
    
    nest_aggregation <- traits %>%
      dplyr::select(binom, 189:190) %>%
      replace(is.na(.), 0) %>%
      mutate_all(funs(str_replace(., "NAV", "0"))) %>%
      rename(solitary_nest = `189_Nest_aggregation_Solitary_12`) %>%
      rename(colonial_nest = `190_Nest_aggregation_Colonial_12`) %>%
      mutate(solitary_nest = as.integer(as.character(.$solitary_nest))) %>%
      mutate(colonial_nest = as.integer(as.character(.$colonial_nest))) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(solitary_nest = ifelse(solitary_nest == 0, "", "solitary")) %>%
      mutate(colonial_nest = ifelse(colonial_nest == 0, "", "colonial")) %>%
      unite("nest_aggregation", 2:3, sep=" and ") %>%
      mutate(nest_aggregation = gsub("solitary and colonial", "both", .$nest_aggregation)) %>%
      mutate(nest_aggregation = gsub("solitary and ", "solitary", .$nest_aggregation)) %>%
      mutate(nest_aggregation = gsub(" and colonial", "colonial", .$nest_aggregation)) %>%
      mutate(nest_aggregation = gsub(" and ", "none", .$nest_aggregation)) 
    
    feeding_aggregation <- traits %>%
      dplyr::select(binom, 174:176) %>%
      replace(is.na(.), 0) %>%
      mutate_all(funs(str_replace(., "NAV", "0"))) %>%
      rename(solitary = `174_Feeding_aggregation_Solitary_11`) %>%
      rename(pairs = `175_Feeding_aggregation_Pairs_11`) %>%
      rename(flocks = `176_Feeding_aggregation_Flocks_11`) %>%
      mutate(solitary = as.integer(as.character(.$solitary))) %>%
      mutate(pairs = as.integer(as.character(.$pairs))) %>%
      mutate(flocks = as.integer(as.character(.$flocks))) %>%
      group_by(binom) %>%
      summarise_all(sum) %>%
      mutate(solitary = ifelse(solitary == 0, "", "solitary")) %>%
      mutate(pairs = ifelse(pairs == 0, "", "pairs")) %>%
      mutate(flocks = ifelse(flocks == 0, "", "flocks")) %>%
      unite("feeding_aggregation", 2:4, sep=" and ") %>%
      mutate(feeding_aggregation = gsub("solitary and pairs and flocks", "solitary_pairs_flocks", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub("solitary and  and flocks", "solitary_and_flocks", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub("solitary and  and ", "solitary", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub("solitary and pairs and ", "solitary_and_pairs", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub(" and  and flocks", "flocks", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub(" and pairs and flocks", "pairs_and_flocks", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub(" and pairs and ", "pairs", .$feeding_aggregation)) %>%
      mutate(feeding_aggregation = gsub(" and  and ", "none", .$feeding_aggregation))
    
    gregariousness <- cooperative_breeding %>%
      inner_join(., nest_aggregation, by="binom") %>%
      inner_join(., feeding_aggregation, by="binom")
    
## creating final traits dataframe
    ms <- ms %>%
      inner_join(., feeding_habitat_generalism, by="binom") %>%
      inner_join(., breeding_habitat_generalism, by="binom") %>%
      inner_join(., diet, by="binom") %>%
      inner_join(., movement, by="binom") %>%
      inner_join(., nesting, by="binom") %>%
      inner_join(., gregariousness, by="binom") %>%
      inner_join(., habitat_types, by="binom")
    
    
    ms <- data.frame(ms)
    
    
   row.names(ms) <- ms$binom
   
  
  return(ms)  
}
