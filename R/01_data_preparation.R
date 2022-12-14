# BIKE PRICING PREDICTION ----
# DATA PREPARATION SCRIPT ----
# # **** ----

# SETUP ----

# Working Dir ----
setwd(here::here("R"))

# * Libraries ----
library(tidyverse)
library(janitor)

# * Load Data ----
bikes_raw_tbl <- read_rds("../data/trekbikes_raw_data.rds") %>% 
    as_tibble() %>% 
    clean_names() 
    
# * Format Data ----
# - Drop "frameset"
# - Remove unwanted columns
bikes_raw_tbl <- bikes_raw_tbl %>% 
    filter(!str_detect(product_name, "Frameset")) %>% 
    select(-c(url, full_product_url, product_image_url, position, fork))

# * Bike Model ----
model_tbl <- bikes_raw_tbl %>% 
    select(product_name) %>% 
    separate(col = product_name, sep = " ", into = str_c("col_", 1:10), remove = FALSE) %>% 
    mutate(model_base = case_when(
        
        # top fuel
        str_detect(str_to_lower(col_1), "top") ~ str_c(col_1, col_2, sep = " "),
        
        # fuel ex
        str_detect(str_to_lower(col_1), "fuel") ~ str_c(col_1, col_2, sep = " "),
        
        # dual sport
        str_detect(str_to_lower(col_1), "dual") ~ str_c(col_1, col_2, sep = " "),
        
        # kakau
        str_detect(str_to_lower(col_1), "kakau") ~ str_c(col_1, col_2, sep = " "),
        
        # catch all
        TRUE ~ col_1
    )) %>% 
    
    # get model tier features
    mutate(model_tier = product_name %>% str_replace(model_base, replacement = "") %>% str_trim()) %>% 
    select(product_name, model_base, model_tier) %>% 
    rename(model_name = product_name)


# * Bike Weight ----
weight_tbl <- bikes_raw_tbl %>% 
    select(weight) %>% 
    separate(col = weight, sep = "/", into = c("kg", "lbs")) %>% 
    select(lbs) %>% 
    separate(col = lbs, sep = " ", into = str_c("col_", 1:10)) %>% 
    select(col_2) %>% 
    rename(weight = col_2) %>% 
    mutate(weight = as.numeric(weight))

# * Bike Tire ----
# tire_tbl <- bikes_data_raw_tbl %>% 
#     select(tire) %>% 
#     separate(col = tire, sep = " ", into = str_c("col_", 1:10)) %>% 
#     select(col_2) %>% 
#     rename(tire_spec = col_2)


# * Bike Frame Material ----
# - Flag "frame" feature for Carbon or Aluminum
frame_tbl <- bikes_raw_tbl %>% 
    select(frame) %>% 
    mutate(frame_material = case_when(
        
        # check for carbon
        str_detect(str_to_lower(frame), "carbon") ~ "Carbon",
        
        # check for aluminum
        str_detect(str_to_lower(frame), "aluminum") ~ "Aluminum",
        
        # catch all
        TRUE ~ "Other"
    )) %>% 
    select(frame_material)


# * Bike Other Features ----
# - Flag other features
other_features_tbl <- bikes_raw_tbl %>% 
    mutate(concat = paste(
        brake, chain, front_derailleur, rear_derailleur, rim, shifter,
        sep = " "
    )) %>% 
    select(concat) %>% 
    
    # create flags
    mutate(
        ultegra  = concat %>% str_to_lower() %>% str_detect("ultegra") %>% as.numeric(),
        dura_ace = concat %>% str_to_lower() %>% str_detect("dura-ace") %>% as.numeric(),
        disc     = concat %>% str_to_lower() %>% str_detect("disc") %>% as.numeric(),
        team     = concat %>% str_to_lower() %>% str_detect("team") %>% as.numeric(),
        shimano  = concat %>% str_to_lower() %>% str_detect("shimano") %>% as.numeric(),
        sram     = concat %>% str_to_lower() %>% str_detect("sram") %>% as.numeric(),
        bosch    = concat %>% str_to_lower() %>% str_detect("bosch") %>% as.numeric(),
    ) %>% 
    
    # remove unwanted columns
    select(-concat)


final_bikes_tbl <- bikes_raw_tbl %>% 
    
    # select features
    select(product_id, category, family, product_price, product_year, battery, charger, controller, motor, shock) %>% 
    
    # create flags for battery, charger, controller, motor and shock
    mutate(
        battery_flag    = ifelse(is.na(battery), 0, 1),
        charger_flag    = ifelse(is.na(charger), 0, 1),
        controller_flag = ifelse(is.na(controller), 0, 1),
        motor_flag       = ifelse(is.na(motor), 0, 1),
        shock_flag      = ifelse(is.na(shock), 0, 1)
    ) %>% 
    
    # remove unwanted columns and fix names
    select(-c(battery, charger, controller, motor, shock)) %>% 
    setNames(names(.) %>% str_remove_all("_flag")) %>% 
    
    # add other features
    bind_cols(model_tbl, weight_tbl, frame_tbl, other_features_tbl) %>% 
    
    # rearrange columns
    select(product_id, model_name, product_year, model_base, model_tier, category, family, frame_material, product_price,
           weight, ultegra, dura_ace, disc, team, shimano, sram, bosch, 
           battery, charger, controller, motor, shock) %>% 
    
    # fix price
    mutate(product_price = as.numeric(product_price)) %>% 
    
    # handle NAs
    mutate(product_year = case_when(
        model_base == "??monda" & is.na(product_year) ~ 2022,
        model_base == "Domane" & is.na(product_year) ~ 2022,
        model_base == "Top Fuel" & is.na(product_year) ~ 2022,
        model_base == "X-Caliber" & is.na(product_year) ~ 2022,
        TRUE ~ product_year
    )) %>% 
    
    # fix names
    rename(model_year = product_year) %>% 
    rename(model_price = product_price)

final_bikes_tbl %>% View()
final_bikes_tbl %>% glimpse()
final_bikes_tbl %>% sapply(function(x) sum(is.na(x)))


# # Handle NAs (Product Year) ----
# final_bikes_tbl %>% 
#     group_by(model_base) %>% 
#     summarise(mean_year = mean(product_year, na.rm = TRUE)) %>% 
#     View()

# Save Final Data Set ----
final_bikes_tbl %>% write_rds("../data/trekbikes_clead_data.rds")

