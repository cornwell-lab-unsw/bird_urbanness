


download_phylo <- function() {
  require(ape)
  if (!exists("Data/phylo/"))
    dir.create("Data/phylo/", showWarnings = FALSE)
  download.file(
    "https://data.vertlife.org/birdtree/Stage2/EricsonStage2_0001_1000.zip",
    "Data/phylo/EricsonStage2_0001_1000.zip"
  )
  
}

read_one_tree<-function(path,x=1){
  unzip(path,overwrite=TRUE,exdir="Data/phylo")
  one_bird_tree <- ape::read.tree(file = "Data/phylo/mnt/data/projects/birdphylo/Tree_sets/Stage2_full_data/CombinedTrees/AllBirdsEricson1.tre")[[x]]
  #drop tips to get down to Aus species here
  return(one_bird_tree)
}

read_all_trees<-function(path){
  unzip(path,overwrite=TRUE,exdir="Data/phylo")
  ape::read.tree(file = "Data/phylo/mnt/data/projects/birdphylo/Tree_sets/Stage2_full_data/CombinedTrees/AllBirdsEricson1.tre")
}





plot_bird_tree <- function(aus_bird_tree) {
  pdf("figures/bird_plot.pdf")
  plot(
    aus_bird_tree,
    type = "r",
    show.tip.label = TRUE,
    cex = 0.4,
    show.node.label = TRUE
  )
  dev.off()
}


subset_tree <- function(bird_trees, traits) {
  non_aus_sp <- bird_trees$tip.label[!bird_trees$tip.label %in% traits$binom]
  aus_bird_tree <- drop.tip(bird_trees, non_aus_sp)
  return(aus_bird_tree)
}


plot_bird_tree_traits <-
  function(aus_bird_tree,
           ms,
           response_variables) {
    trait <- as.array(ms$mean_body_size)
    row.names(trait) <- row.names(ms)
    trait <- subset(trait, trait != "NaN")
    trait <- subset(trait, names(trait) %in% aus_bird_tree$tip.label)
    tree_plotting <-
      drop.tip(aus_bird_tree, aus_bird_tree$tip.label[!aus_bird_tree$tip.label %in%
                                                        row.names(trait)])
    
    rv <-
      filter(response_variables,
             SCIENTIFIC_NAME_tree %in% tree_plotting$tip.label)
    median_rv <- as.array(rv$urban_median)
    row.names(median_rv) <- rv$SCIENTIFIC_NAME_tree
    median_rv2 <- median_rv #- mean(median_rv)
    
    
    tree_plotting_2 <-
      drop.tip(tree_plotting, tree_plotting$tip.label[!tree_plotting$tip.label %in%
                                                        row.names(median_rv2)])
    trait <- subset(trait, names(trait) %in% tree_plotting_2$tip.label)
    
    obj <-
      contMap(
        tree_plotting_2,
        median_rv2,
        fsize = c(0.6, 1),
        outline = FALSE,
        plot = FALSE,
        type = "fan"
      )
    
    pdf("figures/bird_urbanness_phylo.pdf",width=8.5,height=8.5)
    plotTree.wBars(
      obj$tree,
      median_rv2,
      method = "plotSimmap",
      colors = obj$cols,
      type = "fan",
      scale = 5,
      tip.labels = FALSE
    )
    add.color.bar(100, obj$cols, title = "trait value", lims = obj$lims, prompt = FALSE,x = 0.9 * par()$usr[1], y = 0.9 * par()$usr[3])
    dev.off()
    pdf("figures/ref_tree.pdf",width=8.5,height=8.5)
    plot(tree_plotting_2, type = "f", cex = 0.2)
    dev.off()
  }


run_many_phylo_models<-function(analysis_data,list_bird_trees,n=1000){
  bird_trees_ss<-list_bird_trees[1:n]
  ss_trees<-lapply(bird_trees_ss,subset_tree,analysis_data)
  list_o<-lapply(ss_trees,run_one_phylo_model,analysis_data=analysis_data)
  return(list_o)
}

extract_brain<-function(mod,term_to_extract="brain_residual"){
  nn<-names(mod$coefficients)
  return(mod$coefficients[nn==term_to_extract])
}

plot_dist_parameter<-function(list_phy_models){
  df<-data.frame(`Feeding habitat generalism`=sapply(list_phy_models,extract_brain,term_to_extract="feeding_habitat_generalism"),
                 `log(Clutch size)`=sapply(list_phy_models,extract_brain,term_to_extract="clutch_size_logged"),
                 `Diet generalism`=sapply(list_phy_models,extract_brain,term_to_extract="diet_generalism"),
                 `Breeding habitat generalism`=sapply(list_phy_models,extract_brain,term_to_extract="breeding_habitat_generalism"))
                 #`Granivore`=sapply(list_phy_models,extract_brain,term_to_extract="granivoreYes"))
  df_long<-gather(df,key="Trait",value="Coefficient estimate")               
  p<-ggplot(df_long,aes(x=`Coefficient estimate`,fill=Trait))+geom_density(alpha=0.5)+theme_bw()+ylab("Density")
  pdf("figures/accounting_for_phylo_uncertainty.pdf")
  print(p)
  dev.off()
}


run_one_phylo_model<-function(aus_bird_tree, analysis_data){
  #non_aus_sp <- aus_bird_tree$tip.label[!aus_bird_tree$tip.label %in% analysis_data$binom]
  #aus_bird_tree_ss <- diversitree:::drop.tip.fixed(aus_bird_tree, non_aus_sp)
  row.names(analysis_data) <- analysis_data$binom
  
  phy_mod <- phylolm(response ~ body_size_logged + clutch_size_logged + feeding_habitat_generalism + brain_residual + 
                     Habitat_agricultural + breeding_habitat_generalism + granivore + insectivore + 
                     carrion_eater + plant_eater + diet_generalism + migrate + nomadic_irruptive +
                     ground_nesting + hollow_nesting + nest_generalism + breeding + 
                     nest_aggregation + feeding_aggregation + Habitat_grass_shrubland + range_size +
                     Habitat_tree_forest, data=analysis_data, phy=aus_bird_tree,
                     na.action = "na.fail", weights=(analysis_data$N/analysis_data$unique_localities))
  
  phy_mod_rescaled <- phylolm(response ~ rescale(body_size_logged) + rescale(clutch_size_logged) + 
                                rescale(feeding_habitat_generalism) + rescale(brain_residual) + 
                                rescale(Habitat_agricultural) + rescale(breeding_habitat_generalism) + 
                                rescale(granivore) + rescale(insectivore) + 
                                rescale(carrion_eater) + rescale(plant_eater) + rescale(diet_generalism) + 
                                rescale(migrate) + rescale(nomadic_irruptive) +
                                rescale(ground_nesting) + rescale(hollow_nesting) + 
                                rescale(nest_generalism) + rescale(breeding) + 
                                nest_aggregation + feeding_aggregation + 
                                rescale(Habitat_grass_shrubland) + rescale(range_size) +
                                rescale(Habitat_tree_forest), data=analysis_data, phy=aus_bird_tree,
                                na.action = "na.fail", 
                                weights=(analysis_data$N/analysis_data$unique_localities))
  
  return(phy_mod)
}

standard_phylo_model <- function(aus_bird_tree, analysis_data) {
  
  row.names(analysis_data) <- analysis_data$binom
  
  phy_mod_rescaled <- phylolm(response ~ rescale(body_size_logged) + rescale(clutch_size_logged) + 
                                rescale(feeding_habitat_generalism) + rescale(brain_residual) + 
                                rescale(Habitat_agricultural) + rescale(breeding_habitat_generalism) + 
                                rescale(granivore) + rescale(insectivore) + 
                                rescale(carrion_eater) + rescale(plant_eater) + rescale(diet_generalism) + 
                                rescale(migrate) + rescale(nomadic_irruptive) +
                                rescale(ground_nesting) + rescale(hollow_nesting) + 
                                rescale(nest_generalism) + rescale(breeding) + 
                                nest_aggregation + feeding_aggregation + 
                                rescale(Habitat_grass_shrubland) + rescale(range_size) +
                                rescale(Habitat_tree_forest), data=analysis_data, phy=aus_bird_tree,
                                na.action = "na.fail", 
                                weights=(analysis_data$N/analysis_data$unique_localities))
  
  return(phy_mod_rescaled)
  
}


plot_params_phymod <- function(phy_mod_rescaled) {
  
  results <- data.frame(estimate = phy_mod_rescaled$coefficients, 
                        lwr = confint(phy_mod_rescaled)[,1],
                        upr = confint(phy_mod_rescaled)[,2],
                        p_value = summary(phy_mod_rescaled)$coefficients[,4],
                        stringsAsFactors = FALSE)
  
  pdf("figures/param_plot_phylo_model.pdf", height=11, width=9)
  
  print( 
    results %>%
      rownames_to_column("term") %>%
      filter(term != "(Intercept)") %>%
      arrange(desc(estimate)) %>%
      mutate(term2 = c("Feeding habitat generalism",
                       "Diet generalism",
                       "log(Clutch size)",
                       "Habitat - agricultural",
                       "Brain residual",
                       "Breeding habitat generalism",
                       "log(Body size)",
                       "Plant eater",
                       "Nest generalism",
                       "Feeding aggregation \n (solitary, pairs, & flocks)",
                       "Movement - nomadic/irruptive",
                       "Movement - migratory",
                       "Feeding aggregation \n (pairs & flocks)",
                       "Ground-nesting",
                       "Feeding aggregation \n (solitary & pairs)",
                       "Habitat - tree/forest",
                       "Nest aggregation \n (solitary)",
                       "Range size (1000s km2)",
                       "Cooperative breeding",
                       "Carrion eater",
                       "Nest aggregation \n (colonial)",
                       "Hollow-nesting",
                       "Feeding aggregation \n (solitary & flocks)",
                       "Granivore",
                       "Feeding aggregation \n (solitary)",
                       "Nest aggregation \n (none)",
                       "Insectivore",
                       "Habitat - grass/shrubland",
                       "Feeding aggregation \n (pairs)")) %>%
      arrange(estimate) %>%
      mutate(trend=ifelse(.$estimate >0, "positive", "negative")) %>%
      mutate(significance=ifelse(.$p_value <= 0.05, "Significant", "Non-significant")) %>%
      ggplot(., aes(x=fct_inorder(term2), y=estimate, color=trend))+
      geom_point()+
      geom_errorbar(aes(ymin=lwr, ymax=upr, color=trend))+
      ylab("Parameter estimates")+
      xlab("")+
      coord_flip()+
      theme_classic()+
      guides(color=FALSE)+
      geom_hline(yintercept=0, color="black")
  )
  
  dev.off()
  
  rm(list = ls())
}

## this pulls in the dredged model results which was
## done out of the workflow (currently takes about 24 hours to run)
## will likely have to alter this once we have a finalized
## set of predictor variables
phylomodel_averaging_results <- function() {
  
  model_results <- readRDS("Data/PHYLO_dredged_model_averaged_param_est.rds")
  summary <- readRDS("Data/PHYLO_dredged_model_summary_results.rds")
  
  p_values <- data.frame(p_value=summary$coefmat.full[,4]) %>%
    rownames_to_column("variable")
  
  pdf("figures/phylo_param_plot_averaged_results.pdf")
  print(
    model_results %>%
      inner_join(., p_values, by="variable") %>%
      filter(variable != "(Intercept)") %>%
      droplevels() %>%
      arrange(desc(estimate)) %>%
      mutate(variable2 = c("Feeding habitat generalism",
                           "Brain residual",
                           "log(Body size)",
                           "log(Clutch size)",
                           "Breeding habitat generalism",
                           "Nest aggregation \n (colonial)",
                           "Diet generalism",
                           "Plant eater",
                           "Habitat - agricultural",
                           "Insectivore",
                           "Nest aggregation \n (solitary)",
                           "Movement - migratory",
                           "Habitat - tree/forest",
                           "Ground-nesting",
                           "Movement - nomadic/irruptive",
                           "Habitat - grass/shrubland",
                           "Hollow-nesting",
                           "Granivore",
                           "Nest generalism",
                           "Cooperative breeding",
                           "Carrion eater",
                           "Range size (1000s km2)",
                           "Nest aggregation \n (none)")) %>%
      arrange(estimate) %>%
      mutate(trend=ifelse(.$estimate >0, "positive", "negative")) %>%
      mutate(significance=ifelse(.$p_value <= 0.05, "Significant", "Non-significant")) %>%
      ggplot(., aes(x=fct_inorder(variable2), y=estimate, color=trend))+
      geom_point()+
      geom_errorbar(aes(ymin=lwr, ymax=upr, color=trend))+
      ylab("Parameter estimates")+
      xlab("")+
      coord_flip()+
      theme_classic()+
      guides(color=FALSE)+
      geom_hline(yintercept=0, color="black")
  )
  
  dev.off()
  
}




phy_v_non_phy<-function(global_model,phy_mod_rescaled){
  library(ggplot2)
  cc <- data.frame(phy_mod_coefs=coef(phy_mod_rescaled), 
                   non_phy_mod=coef(global_model)) %>%
    mutate(parameter = c("Intercept",
                         "log(Body size)",
                         "log(Clutch size)",
                         "Feeding habitat generalism",
                         "Brain residual", 
                         "Habitat - agricultural", 
                         "Breeding habitat generalism",
                         "Granivore", 
                         "Insectivore", 
                         "Carrion eater", 
                         "Plant eater", 
                         "Diet generalism",
                         "Movement - migratory", 
                         "Movement - nomadic/irruptive", 
                         "Ground-nesting", 
                         "Hollow-nesting", 
                         "Nest generalism", 
                         "Cooperative breeding", 
                         "Nest aggregation \n (colonial)",
                         "Nest aggregation \n (none)",
                         "Nest aggregation  \n (solitary)",
                         "Feeding aggregation \n (pairs)",
                         "Feeding aggregation \n (pairs & flocks)",
                         "Feeding aggregation \n (solitary)",
                         "Feeding aggregation \n (solitary & flocks)",
                         "Feeding aggregation \n (solitary & pairs)",
                         "Feeding aggregation \n (solitary, pairs, & flocks)",
                         "Habitat - grass/shrubland", 
                         "Range size (1000s km2)", 
                         "Habitat - tree/forest"))
  
  p <- ggplot(cc,aes(x=non_phy_mod,y=phy_mod_coefs))+
    geom_point(color="royalblue4")+
    theme_bw()+
    geom_abline(slope=1,intercept=0)+
    xlab("Non phylogenetic model")+
    ylab("Phylogenetic model")+
    geom_text_repel(aes(label = parameter), 
                    box.padding = unit(0.45, "lines"))
  
  pdf("figures/phy_v_non_phy.pdf", height=10, width=12)
  print(p)
  dev.off()
}



## phylosignal analysis
phylosignal_analysis <- function(analysis_data, aus_bird_tree){
  
  require(phylosignal)
  dplyr::select(analysis_data,body_size_logged,clutch_size_logged,response,range_size, #select appropriate rows
                nest_generalism,diet_generalism,breeding_habitat_generalism,feeding_habitat_generalism,brain_residual) ->dd
  
  row.names(dd)<-analysis_data$binom #name rows so that it matches the tree
  #dd$rand<-rnorm(dim(dd)[2]) #random numbers to test package
  p4d <- phylo4d(aus_bird_tree, dd) #create phylobase object
  
  ps <- phyloSignal(p4d,reps = 9999) #run calculation, p values a bit unstable at 999 reps
  
  
  Table1 <- ps$stat
  
  row.names(Table1) <- c("log(Body size)", "log(Clutch size)", "Urbanization index", "Range size (1000s km2)",
                         "Nest generalism", "Diet generalism", "Breeding habitat generalism",
                         "Feeding habitat generalism", "Brain residual")
  
  
  TableS2 <- ps$pvalue
  
  row.names(TableS2) <- c("log(Body size)", "log(Clutch size)", "Urbanization index", "Range size (1000s km2)",
                          "Nest generalism", "Diet generalism", "Breeding habitat generalism",
                          "Feeding habitat generalism", "Brain residual")
  
  write.csv(Table1, "Data/Table1.csv")
  write.csv(TableS2, "Data/TableS2.csv")
  
  is.num <- sapply(Table1, is.numeric)
  Table1[is.num] <- lapply(Table1[is.num], round, 2)
  pdf("tables/phylosignal_summary_stats.pdf")
  grid.table(Table1)
  dev.off()
  
  is.num <- sapply(TableS2, is.numeric)
  TableS2[is.num] <- lapply(TableS2[is.num], round, 2)
  pdf("tables/phylosignal_pvalues.pdf")
  grid.table(TableS2)
  dev.off()
  
}



