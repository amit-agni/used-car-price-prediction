Please download the README.html file as it has the details of the process that was followed and also the model evaluation

### Kaggle Used Car Dataset Price Prediction

The Used Cars dataset from Kaggle has over 370K ads scraped with Scrapy from Ebay-Kleinanzeigen.

The objective of this task is to create a machine learning model to predict which of the cars listed in the future are cheap

### Steps to reproduce

Clone the github repo : https://github.com/amit-agni/used-car-price-prediction.git
Download autos.csv from Kaggle and save it in 100_data_raw-input
Run the main.R script in the 210_src_R-scripts-functions folder (If required, parameters like CV folds, Random grid rows and no of iterations can be modified in this file)
This step creates all the models and saves them in 300_output
Knit the README.Rmd for model evaluation and prediction
