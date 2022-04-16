# datadrivencv

*The package is under development.*

This is a slightly rewritten version of [`{datadrivencv}`](https://github.com/nstrayer/datadrivencv) by
[Nick Strayer](https://github.com/nstrayer) combined with the [CV template](http://svmiller.com/blog/2016/03/svm-r-markdown-cv/) made by [Steven V. Miller](https://github.com/svmiller) as part of the [`{stevetemplates}`](http://svmiller.com/stevetemplates/) package. 

This package is written for personal use.

## Installation

The development version from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("eirikberger/datadrivencv")
```

As of now, you also have to install the [`{stevetemplates}`](http://svmiller.com/stevetemplates/) package.

``` r
devtools::install_github("svmiller/stevetemplates")
```

# Using it

Copy [this](https://docs.google.com/spreadsheets/d/1bBlRkTPyPXkxHUzBo7H6xJm33vnP-qv0sJ5rI1eCRO4/edit?usp=sharing) Google Sheet document to your own Google drive. Open Eirik's academic CV template from the Rstudio menu, and replace the Google Drive link with a ling to your own document. Make sure that the document is made public.

``` r
CV <- datadrivencv::create_CV_object(
  data_location = "https://docs.google.com/spreadsheets/d/1bBlRkTPyPXkxHUzBo7H6xJm33vnP-qv0sJ5rI1eCRO4/edit?usp=sharing"
)
```

You are now ready to compile the CV.
