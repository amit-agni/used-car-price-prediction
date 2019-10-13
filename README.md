### Kaggle Used Car Dataset Price Prediction

The Used Cars dataset from Kaggle has over 370K ads scraped with Scrapy
from Ebay-Kleinanzeigen. 

The objective of this task is to create a machine learning model to predict which of the cars listed in the future
are cheap


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
4.  Knit the `README.Rmd` for model evaluation and
    prediction

*The README.html file has the output of the model evaluation and predictions*
