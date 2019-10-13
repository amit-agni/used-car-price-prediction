------------------------------------------------------------------------

### Objective

The Used Cars dataset from Kaggle has over 370K ads scraped with Scrapy
from Ebay-Kleinanzeigen. The objective of this task is to create a
machine learning model to predict which of the cars listed in the future
are cheap

------------------------------------------------------------------------

### Process

The overall process that was followed is shown in the below diagram

-   The `autos.csv` file was modified to create an `is_cheap` column,
    which would be used as a **target** variable
-   The first 10000 rows were kept as held-out test set, rest were used
    for model building
-   The code was executed for 100 iterations. In every iteration :
    -   1000 lines were read at random from the training set which were
        then processed using the data processing functions
        (`functions_data-processing.R`)
    -   Three models were trained using glmnet (elastic net), Xgboost
        and Random forest algorithms (`functions_modeling.R`)
    -   Models were saved on the disk
-   This markdown document reads the saved models, evaluates their
    performance and creates prediction probabilities on the held-out
    test set

![](/Mac%20Backup/OneDrive/R/Kaggle%20Used%20Car%20Prediction/400_extras/20191012_user-cars-process-map.png)

------------------------------------------------------------------------

### Assumptions

#### Data

-   The entire dataset was loaded in memory as the average price of the
    car was needed to create the `is_cheap` flag. (Alternative methods
    were not explored)
    -   This is the only part of the modeling code that doesn’t obey the
        1000 row limitation
    -   The columns nrOfPictures,seller and offerType either had only
        one value or did not have much variability and hence were
        dropped during the creation of `autos2.csv` file
-   Cars that were registered prior to year 1950 were capped to 1900 and
    1950
-   Due to time constraints, only basic methods were utilised for
    missing value imputation, outlier treatment and feature engineering
-   Columns with textual information like model name, car name and brand
    name could possibly have had predictive power but were also not
    explored in depth for same reason
-   Cars with ad price of zero were included in the average price
    calculation. Excluding them would have made the dataset highly
    imbalanced

#### Modeling

-   Simple random grid was used for hyperparameter tuning. Algorithms
    like Bayesian Optimisation, Genetic Algorithm, etc could have given
    better results
-   Stratified K-fold CV was used, other resampling methods were not
    explored
-   AUC was used as the metric for CV evaluation. F-score (F1) was tried
    for few iterations but the results were not significantly different
    hence did not pursue
-   Error handling was included for the functions
-   `set.seed()` was used for reproducibility but may not give correct
    results due to the use of parallelisation

------------------------------------------------------------------------

### Steps to reproduce

1.  Clone the github repo :
    <a href="https://github.com/amit-agni/used-car-price-prediction.git" class="uri">https://github.com/amit-agni/used-car-price-prediction.git</a>
2.  Download `autos.csv` from
    [Kaggle](https://www.kaggle.com/orgesleka/used-cars-database) and
    save it in `100_data_raw-input`
3.  Run the `main.R` script in the `210_src_R-scripts-functions` folder
    (If required, parameters like CV folds, Random grid rows and no of
    iterations can be modified in this file)
    -   This step creates all the models and saves them in `300_output`
4.  Knit the `README.Rmd` (this file) for model evaluation and
    prediction

------------------------------------------------------------------------

### Cross Validation Performance

-   The below chart shows the performance of 5-fold Cross validation for
    the 100 iterations
-   The Random Forest model performed the worst, overfitting the train
    set with a median AUC of 0.93 and test set AUC of 0.65
-   The glmnet and XGB performed better than RF

![](README_files/figure-markdown_github/unnamed-chunk-1-1.png)

-   The train and test AUC’s for CV are given below :
    <table class="table table-condensed" style="width: auto !important; ">
    <thead>
    <tr>
    <th style="text-align:left;">
    model
    </th>
    <th style="text-align:right;">
    CV\_train\_auc
    </th>
    <th style="text-align:right;">
    CV\_test\_auc
    </th>
    </tr>
    </thead>
    <tbody>
    <tr>
    <td style="text-align:left;">
    glmnet
    </td>
    <td style="text-align:right;">
    0.8261707
    </td>
    <td style="text-align:right;">
    0.7722195
    </td>
    </tr>
    <tr>
    <td style="text-align:left;">
    rf
    </td>
    <td style="text-align:right;">
    0.9299258
    </td>
    <td style="text-align:right;">
    0.6568018
    </td>
    </tr>
    <tr>
    <td style="text-align:left;">
    xgb
    </td>
    <td style="text-align:right;">
    0.8589564
    </td>
    <td style="text-align:right;">
    0.7779289
    </td>
    </tr>
    </tbody>
    </table>

<br>

### Held-out Validation Set Performance

-   There were total of 300 models generated (100 iterations x 3
    algorithms). We will use all the 300 models to predict the held-out
    validation set probabilities.

-   Below chart gives an overview of the predicted probabilities for
    some random observations.
-   To limit the effect of outliers on the probabilities, median (as
    opposed to mean) probability per observation would be used for
    evaluation/prediction

![](README_files/figure-markdown_github/unnamed-chunk-5-1.png)

<br>

#### Gain Curve

-   The Gain Curve was plotted using the median probabilities across
    iterations. It shows that all the 3 models would perform better than
    a random clasffier (dotted line)
-   Also, as indicated in the CV - AUC chart above, glmnet and xgb
    models perform better than Random Forest model
-   So, for the go-live model we will create a ensemble of both glmnet
    and xgb. The ensemble would further enhance the generalisation of
    the model

![](README_files/figure-markdown_github/unnamed-chunk-6-1.png)

<br>

#### Ensemble of glmnet and xgb

-   The median of the probabilities of all the 100 iterations of the xgb
    and glmnet model were used to create the ensemble
-   The resulting AUC on the 10000 row held-out validation set is 0.807

![](README_files/figure-markdown_github/unnamed-chunk-7-1.png)

<br>

#### Confusion Matrix

-   We will choose a threshold cutoff of **0.0325** which gives a good
    balance of Sensitivity (TPR) and Specificity (TNR) even though they
    are below par.

-   Out of the 311 car ads which were marked as Cheap in the held out
    validation set, the model correctly predicts 222 as cheap but also
    incorrectly predicts 2416 as cheap.
    -   This means the model can correctly predict only 8.5% of the
        times (Precision / PPV)
-   The model has a recall of 0.71 which indicates the model would be
    able to capture a wider breadth of cheap ads

-   The choice of the cutoff would be highly dependent on the problem
    that the business is trying to solve. If for example the company
    wants to send mailers to ad posters than this model with higher
    breadth would be good, as there will not be any associated cost to
    the business. But if there is a associated cost then the 2416 False
    Positive cases will incur a cost that is not justified.

<!-- -->

    ## Confusion Matrix and Statistics
    ## 
    ##           Reference
    ## Prediction    0    1
    ##          0 7273   89
    ##          1 2416  222
    ##                                          
    ##                Accuracy : 0.7495         
    ##                  95% CI : (0.7409, 0.758)
    ##     No Information Rate : 0.9689         
    ##     P-Value [Acc > NIR] : 1              
    ##                                          
    ##                   Kappa : 0.1005         
    ##                                          
    ##  Mcnemar's Test P-Value : <2e-16         
    ##                                          
    ##             Sensitivity : 0.71383        
    ##             Specificity : 0.75065        
    ##          Pos Pred Value : 0.08415        
    ##          Neg Pred Value : 0.98791        
    ##               Precision : 0.08415        
    ##                  Recall : 0.71383        
    ##                      F1 : 0.15056        
    ##              Prevalence : 0.03110        
    ##          Detection Rate : 0.02220        
    ##    Detection Prevalence : 0.26380        
    ##       Balanced Accuracy : 0.73224        
    ##                                          
    ##        'Positive' Class : 1              
    ## 

### Summary

-   The glmnet and xgboost algorithms with a training AUC of 0.83 and
    0.86 generalised well on the CV test set giving an AUC of approx
    0.78
-   The ensembling further helped in generalisation as the validation
    set AUC came at 0.81
-   The model could be further improved by conducting in-depth feature
    engineering, hyperparameter tuning using optimation algorithms,
    alternative data/model sampling strategy, etc.

------------------------------------------------------------------------
