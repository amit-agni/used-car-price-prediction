rm(list = ls()) #Remove existing objects
gc() #Free memory


if(!require(pacman)) { install.packages("pacman"); library(pacman)}
#pacman::p_load installs missing packages and loads them
p_load(data.table #data store and wrangling
       ,xgboost 
       ,randomForest
       ,glmnet
       ,mlr
       ,vtreat #  variable treat "'vtreat' defends against: 'Inf', 'NA', too many categorical levels, rare categorical levels, and new categorical levels"
       ,here # alternative to setwd(), helps in project portabilty as it automatically constructs the file path based on the R project directory structure
       ,magrittr # for the %>% piping operator
       ,dplyr # for na_if() function
       ,tictoc #display start-end times
       ,scales #for scale and center function
       ,tidyr
       ,parallelMap #parallelising
)

#This pre-processing step creates autos2.csv with the target variable. It creates a file with total number of rows
source(here::here("210_src_R-scripts-functions","create-autos2csv-with-target.R"))
total_csv_rows <- scan(here('100_data_raw-input','total_csv_rows.txt'))


#Functions for data processing and modeling
source(here::here("210_src_R-scripts-functions","functions_data-processing.R"))
source(here::here("210_src_R-scripts-functions","functions_modeling.R"))


# Create variable treatment plan (to be applied to train and test)
col_names <- colnames(fread(here('100_data_raw-input','autos2.csv'),nrows = 1))
DT_train <- fn_read_n_rows(file=here('100_data_raw-input','autos2.csv'),n=1000,total_csv_rows,col_names) %>%
    fn_data_processing_wrapper()
vars <- names(DT_train)
treatplan <- designTreatmentsC(DT_train,vars,outcomename = "is_cheap",outcometarget = 1,verbose = TRUE)
newvars <- setDT(treatplan$scoreFrame)[code %in% c("clean","lev")]$varName

saveRDS(treatplan,here('110_data_intermediate','vtreat-treatmentplan.Rds'))



# Modeling parameters
k <- 5L #K-fold Cross validation
random_grid_iters <- 100L #Hyperparameter tuning grid rows
iterations <- 100L



set.seed(2019)
parallelStartSocket(4) #for parallel operation

tic()

for(iter in 1:iterations) {
    
    print(paste("Iteration ========================> ",iter))
    
    # Read 1000 random lines and process
    DT_train <- fn_read_n_rows(file=here('100_data_raw-input','autos2.csv'),n=1000,total_csv_rows,col_names) %>%
        fn_data_processing_wrapper()
    
    #Apply treatment plan to train
    DT_train <- prepare(treatplan,DT_train,varRestriction = newvars)
    
    #Modeling using MLR package
    train_task <- makeClassifTask(data=DT_train
                                  ,target = "is_cheap" 
                                  ,positive = 1) 
    
    ### XGB Model
    learner <- makeLearner("classif.xgboost"
                           ,predict.type = "prob"
                           ,par.vals = list(
                               objective = "binary:logistic"
                               ,eval_metric = "auc"))
    param_set <- makeParamSet(makeIntegerParam("nrounds",lower=100,upper=500)
                              ,makeIntegerParam("max_depth",lower=3,upper=7)
                              #,makeNumericParam("lambda",lower=0.55,upper=0.60)
                              ,makeNumericParam("eta", lower = 0.01, upper = 0.3)
                              ,makeNumericParam("subsample", lower = 0.10, upper = 0.80)
                              ,makeNumericParam("min_child_weight",lower=1,upper=10)
                              ,makeNumericParam("colsample_bytree",lower = 0.2,upper = 0.8))
    
    mod_XGB <- fn_train_models(learner,param_set,k,random_grid_iters)
    
    
    ### glmnet model
    learner <- makeLearner("classif.glmnet",predict.type = "prob")
    
    param_set <- makeParamSet(makeNumericParam("alpha", lower = 0.0, upper = 1.0)
                              ,makeNumericParam("s", lower = 0.001, upper = 0.1))
    
    mod_GLMNET <- fn_train_models(learner,param_set,k,random_grid_iters)
    
    
    ### Random Forest model
    learner <- makeLearner("classif.randomForest",predict.type = "prob")
    param_set <- makeParamSet(makeIntegerParam("mtry",lower = 10,upper = 30)
                              ,makeIntegerParam("nodesize",lower = 80,upper = 100)
                              ,makeIntegerParam("ntree",lower = 100,upper = 500)
                              #,makeIntegerParam("maxnodes",lower = 10,upper = 40)
                              )
    mod_RF <- fn_train_models(learner,param_set,k,random_grid_iters)

    #Save model in a file
    saveRDS(list(xgb = mod_XGB,glmnet = mod_GLMNET, rf = mod_RF)
            ,here('300_output',paste("savedmodel_",iter,".Rds",sep = '')))
    
}

parallelStop()


toc()

