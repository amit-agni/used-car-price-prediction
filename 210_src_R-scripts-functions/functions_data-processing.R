######## DATA PROCESSING FUNCTIONS ########
# Contents :
# fn_read_n_rows
# fn_data_processing_wrapper
# fn_clean_data
# fn_impute_missing
# fn_engineer_features
# fn_drop_cols
# fn_get_mode


fn_data_processing_wrapper <- function(DT){
  #Summary : wrapper for data processing functions
  DT <- DT %>%
  fn_clean_data() %>%
    fn_engineer_features() %>%
    fn_scale_and_center(except_cols = c("is_cheap","carAge_is_outlier")) %>%
    fn_impute_missing(cols_to_impute = c("fuelType","gearbox"),impute_type = "mode") %>%
    fn_impute_missing(cols_to_impute = c("vehicleType","notRepairedDamage"),impute_type = "new_level") %>%
    fn_drop_cols(cols_to_drop = c("dateCrawled","lastSeen","dateCreated")) %>%
    fn_drop_cols(cols_to_drop = c("model","name","brand")) %>%
    fn_drop_cols(cols_to_drop = c("yearOfRegistration","monthOfRegistration"))
  
}

fn_read_n_rows <- function(file,n,total_csv_rows,col_names){
  #Summary : Load from CSV. The first 10K rows will will used for validation. 
  
  lapply(1:(n/100) #100 consecutive rows at a time (reading speed)
         ,function(x) {
           fread(file = file
                 ,nrows = 100  #100 consecutive rows at a time (reading speed)
                # Ignore the first 10000 rows as they will be used as validation set
                # skip>0 means ignore the first skip rows 
                ,skip = sample(10001L:total_csv_rows,size =1) 
                ,col.names = col_names
                ,quote = ""
                ,na.strings = "NA")
           }
         ) %>% data.table::rbindlist()
}



               
fn_clean_data <- function(DT){
  #Summary : Basic cleaning of data
  
  #Replace NULLs with NA
  DT <- DT[,lapply(.SD,function(x) na_if(x,''))]
  
  #Convert date cols to DATE (Time part ignored)
  date_cols <- c("dateCrawled","lastSeen","dateCreated")
  DT[,(date_cols) := lapply(.SD,function(x) as.Date(lubridate::ymd_hms(x)))
     ,.SDcols=date_cols]
  
  #convert char cols to factor
  char_cols <- names(which(lapply(DT,is.character) == TRUE))
  DT[,(char_cols) := lapply(.SD,as.factor),.SDcols=char_cols]
  
  #there are cars with registration year in 18th century
  DT[,yearOfRegistration := case_when(yearOfRegistration <= 1900 ~ 1900L
                                      ,yearOfRegistration <= 1950 ~ 1950L
                                      ,TRUE ~ yearOfRegistration)]
  
  #Some records had 0 as month of registration
  DT[monthOfRegistration ==0 , monthOfRegistration := 1]
  
}


fn_get_mode <- function(col) {
  # Summary : helper to find the majority class
  var_table <- table(col)
  return(names(var_table)[which.max(var_table)])
}


fn_impute_missing <- function(DT,cols_to_impute,impute_type){
  #Summary : Impute using mode or create a new level 'unknown'
  if(impute_type =='mode'){
    for(i in cols_to_impute){
      mode_value <- fn_get_mode(DT[,get(i),.SDcols = i])
      DT[is.na(get(i)),(i) := mode_value]  
      
      #DT[is.na(get(i)),(i) := fn_get_mode(DT[,..i])]  # was giving i,..i scoping warning 
    }
  }
  
  if(impute_type =='new_level'){
    for(i in cols_to_impute){
      DT[is.na(get(i)),(i) := "unknown"]  
    }
  }
  
  DT
}


fn_engineer_features <- function(DT){
  #summary : create new features
  
  #Postalcode to factor
  DT[,postalarea := as.factor(round(postalCode/10000,0))]
  DT[,postalCode := NULL]
  
  #Date features
  lower_bound <- c(0,seq(1,30,7),45,60,75,90)
  DT$firstCrawled_dateCreated_bands <- as.factor(findInterval(as.numeric(DT$dateCrawled - DT$dateCreated), lower_bound))
  
  lower_bound <- c(0,seq(1,30,7))
  DT$lastSeen_firstCrawled_bands <- as.factor(findInterval(as.numeric(DT$lastSeen - DT$dateCrawled), lower_bound))
  
  #Length of ad name
  DT[,ad_length := length(name)]
  
  #Age of the car
  DT$dateOfRegistration <- lubridate::ymd(paste(DT$yearOfRegistration,DT$monthOfRegistration,'01',sep ='-'))
  DT$carAge <- as.numeric(DT$dateCreated - DT$dateOfRegistration)/365
  DT$dateOfRegistration <- NULL #will not be used
  
  #fix outliers in car age, create another field to track the outliers
  DT$carAge_is_outlier <- 0
  DT[carAge <0, `:=`(carAge=0,carAge_is_outlier = 1)]
  qnt <- quantile(DT$carAge, probs=c(.25, .75), na.rm = T)
  caps <- quantile(DT$carAge, probs=c(.05, .95), na.rm = T)
  cutoff <- 1.5 * IQR(DT$carAge, na.rm = T)
  DT[carAge < qnt[1]-cutoff,`:=`(carAge = caps[1],carAge_is_outlier = 1)]
  DT[carAge > qnt[2]+cutoff,`:=`(carAge = caps[2],carAge_is_outlier = 1)]
  DT$carAge_is_outlier <- as.factor(DT$carAge_is_outlier)
  
  
  #Ad age, fix outliers  and create another field to track
  DT$adAge <- as.numeric(DT$lastSeen - DT$dateCreated)
  DT$adAge_is_outlier <- 0
  qnt <- quantile(DT$adAge, probs=c(.25, .75), na.rm = T)
  caps <- quantile(DT$adAge, probs=c(.05, .95), na.rm = T)
  cutoff <- 1.5 * IQR(DT$adAge, na.rm = T)
  DT[adAge < qnt[1]-cutoff,`:=`(adAge = caps[1],adAge_is_outlier = 1)]
  DT[adAge > qnt[2]+cutoff,`:=`(adAge = caps[2],adAge_is_outlier = 1)]
  DT$adAge_is_outlier <- as.factor(DT$adAge_is_outlier)
  
  #Some ratio features
  DT$kms_by_carAge <- DT$kilometer / (DT$carAge + 1)
  DT$carAge_by_adAge <- DT$carAge / (as.numeric(DT$lastSeen - DT$dateCreated) +1)
  DT$kms_by_power <- DT$kilometer / (DT$powerPS + 1)
  DT$carAge_by_power <- DT$carAge /  (DT$powerPS + 1)
    
  
  # Create KMS outlier flag
  DT$km_is_outlier <- 0
  qnt <- quantile(DT$kilometer, probs=c(.25, .75), na.rm = T)
  caps <- quantile(DT$kilometer, probs=c(.05, .95), na.rm = T)
  cutoff <- 1.5 * IQR(DT$kilometer, na.rm = T)
  DT[kilometer < qnt[1]-cutoff,`:=`(km_is_outlier = 1)]
  DT[kilometer > qnt[2]+cutoff,`:=`(km_is_outlier = 1)]
  DT$km_is_outlier <- as.factor(DT$km_is_outlier)
  
  # Create powerPS outlier flag
  DT$powerPS_is_outlier <- 0
  qnt <- quantile(DT$powerPS, probs=c(.25, .75), na.rm = T)
  caps <- quantile(DT$powerPS, probs=c(.05, .95), na.rm = T)
  cutoff <- 1.5 * IQR(DT$powerPS, na.rm = T)
  DT[powerPS < qnt[1]-cutoff,`:=`(powerPS_is_outlier = 1)]
  DT[powerPS > qnt[2]+cutoff,`:=`(powerPS_is_outlier = 1)]
  DT$powerPS_is_outlier <- as.factor(DT$powerPS_is_outlier)
  
    
  return(DT)
  
}



fn_drop_cols <- function(DT,cols_to_drop){
  #Summary : drop cols that will not be used in modeling
  DT[,(cols_to_drop) := NULL]
}



fn_scale_and_center <- function(DT,except_cols=NULL){
  #Summary : Center and scale between 0 and 1
  #Dependencies  : scales package
  
  num_cols <- names(which(lapply(DT,is.numeric) == TRUE))
  num_cols <- num_cols[!num_cols %in% except_cols]
  DT[,(num_cols) := lapply(.SD,scales::rescale),.SDcols=num_cols]
  
}

