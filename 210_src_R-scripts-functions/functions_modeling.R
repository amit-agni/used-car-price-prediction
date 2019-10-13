######## MODEL AND PREDICT FUNCTIONS ########
# contents :
# fn_train_models
# fn_predict


fn_train_models <- function(learner,param_set,k,random_grid_iters){
  #Function to train the models with the tuning parameters and random grid iterations. Returns trained model and CV stats
  
  param_rand <- makeTuneControlRandom(maxit = random_grid_iters) #Grid
  
  cv <- makeResampleDesc("CV"
                         ,iters = k #k fold CV
                         ,stratify = TRUE
                         ,predict = "both") # generate performance on the train data along with the validation/test data
  
  
  model_tune <- tuneParams(learner = learner
                           ,resampling = cv
                           ,task = train_task
                           ,par.set = param_set
                           ,control = param_rand
                           ,measures = list(auc, setAggregation(auc,train.mean)) #aggregate train and test auc
  )
  
  
  CV_train_auc <- as.numeric(model_tune$y["auc.train.mean"])
  CV_test_auc <- as.numeric(model_tune$y["auc.test.mean"])
  
  best_param <- setHyperPars(learner,par.vals = model_tune$x)
  model <- train(best_param,train_task)
  
  list(model = model
       ,CV_train_auc = CV_train_auc
       ,CV_test_auc = CV_test_auc)
  
  
}


fn_predict <- function(model,test_task){
  #Summary : Prediction function, takes in a model and the MLR test task and returns performance stats and probabilities
  
  pred <- predict(model,test_task)
  
  if(!exists("perf")){
    perf <- data.table(generateThreshVsPerfData(pred
                                                   ,measures = list(fpr, tpr,auc,f1)
                                                   ,gridsize = 500)$data)
  }else{
    perf <- rbind(perf
                     ,generateThreshVsPerfData(pred
                                               ,measures = list(fpr, tpr,auc,f1)
                                               ,gridsize = 500)$data)
  }
  
  if(!exists("probs")){
    probs <- data.table(obs_no = seq(1,test_task$task.desc$size,1)
                           ,probs=getPredictionProbabilities(pred,"1"))
  }else{
    probs <- rbind(probs
                      ,cbind(obs_no = seq(1,test_task$task.desc$size,1)
                             ,probs=getPredictionProbabilities(pred,"1")))    
  }
  
  
  list(perf = perf,probs = probs)
  
}

