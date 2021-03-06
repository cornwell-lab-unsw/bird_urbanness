### Calculating response variables for each species
### This script is used to create the response variables for all species included in the analysis


### load eBird data
load_ebird_data <- function() {
  load('Data/eBird data/Final eBird data for analysis/species_urban.RData')
  species_urban
}


### calculate response variable df
make_response_variables <- function(species_urban) {
  taxonomy_key <- read_csv("Data/Taxonomy/taxonomy_key.csv")
  response_variables <- species_urban %>%
    group_by(COMMON_NAME, SCIENTIFIC_NAME) %>%
    summarise(urban_mean = mean(avg_rad),
            urban_median = median(avg_rad),
            N = n(),
            unique_localities = length(unique(LOCALITY_ID))) %>%
    ungroup() %>%
    rename(SCIENTIFIC_NAME_ebird = SCIENTIFIC_NAME) %>%
    rename(COMMON_NAME_ebird = COMMON_NAME) %>%
    inner_join(., taxonomy_key, by=c("COMMON_NAME_ebird", "SCIENTIFIC_NAME_ebird")) %>%
    mutate(SCIENTIFIC_NAME_tree = gsub(" ", "_", .$SCIENTIFIC_NAME_tree))
  
  response_variables
  
}


### Plot the histogram of the response variables
distribution_response_variables <- function(response_variables) {
  
  pdf("figures/distribution_response_variables.pdf")
  
  print(response_variables %>%
    gather(key = "response_level", value = "value", urban_mean:urban_median) %>%
    ggplot(., aes(value))+
    geom_histogram(bins = 50, 
                   col="black", 
                   fill="green", 
                   alpha = .2)+
    theme_bw()+
    xlab("Value")+
    ylab("Count")+
    facet_wrap(~response_level, scales="free"))
  
  dev.off()
}


