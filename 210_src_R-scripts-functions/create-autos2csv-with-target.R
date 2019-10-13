if(!require(pacman)) { install.packages("pacman"); library(pacman)}
p_load(here,data.table)

if("autos2.csv" %in% list.files(path=here('100_data_raw-input'))){
  message("autos2.csv already exists. Please proceed with modeling")
}else{
  
  DT <- fread(here('100_data_raw-input','autos.csv'))
  
  #Target variable : Cars cheaper than 10% of the average price are marked 1 
  DT[,`:=`(avg_price = mean(price)
           ,is_cheap = if_else(price <= 0.1 * mean(price,na.rm = T),1,0)),name]
  
  #Process the blanks as NA
  DT <- DT[,lapply(.SD,function(x) na_if(x,''))]
  
  #Create new CSV file that will be used in the further process
  fwrite(DT[,-c("price","avg_price","nrOfPictures","seller","offerType")]
         ,here('100_data_raw-input','autos2.csv'))

  write(nrow(DT),here('100_data_raw-input','total_csv_rows.txt'))

  }



