# Data

The raw data is **not** stored in this repository.

Download `hotels.csv` (119,390 rows, 32 columns) from the TidyTuesday repository (week 7, 2020-02-11) and save it as `data/hotels.csv`:

<https://raw.githubusercontent.com/rfordatascience/tidytuesday/main/data/2020/2020-02-11/hotels.csv>

From R you can also run:

```r
download.file("https://raw.githubusercontent.com/rfordatascience/tidytuesday/main/data/2020/2020-02-11/hotels.csv",
              "data/hotels.csv", mode = "wb")
```

To keep the file somewhere else, set the `HOTELS_CSV` environment variable to its path before running the script.

**Source:** Antonio N, de Almeida A, Nunes L (2019) Hotel booking demand datasets. *Data in Brief* 22:41–49. <https://doi.org/10.1016/j.dib.2018.11.126>

**Watch out:** missing values in `agent`, `company` and `country` are stored as the text `"NULL"`, which `is.na()` does not detect. The script counts them explicitly.
