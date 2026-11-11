# =====================================================================
# Hotel Booking Demand: statistical analysis in R
# Author: Syeda Hafsa
# Data:   Hotel Booking Demand (Antonio et al. 2019), TidyTuesday 2020-02-11
#
# Run from the repository root:   Rscript R/hotel_analysis.R
# Data path: data/hotels.csv by default, or set the HOTELS_CSV environment
# variable. See data/README.md for the download link.
# Charts are saved to figures/ and the 30-row sample to outputs/.
# Written and run with R 4.6.1.
# =====================================================================

# ---- 0. Setup --------------------------------------------------------
# Install once, outside this script:  install.packages("tidyverse")
if (!requireNamespace("tidyverse", quietly = TRUE)) {
  stop("Package 'tidyverse' is missing. Run install.packages(\"tidyverse\") once, then re-run this script.")
}
suppressPackageStartupMessages(library(tidyverse))

author <- "Syeda Hafsa"
data_path <- Sys.getenv("HOTELS_CSV", "data/hotels.csv")
if (!file.exists(data_path)) {
  stop("Can't find ", data_path, ". Download hotels.csv as described in data/README.md, ",
       "or set HOTELS_CSV to its location.")
}
dir.create("figures", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)

banner <- function(label = "Output") cat("\n=== ", label, " produced by: ", author, " ===\n\n", sep = "")

# Consistent chart style: title, author subtitle, minimal theme
wm <- function(p, title) {
  p + labs(title = title, subtitle = author) +
    theme_minimal() +
    theme(plot.title = element_text(face = "bold"))
}
save_plot <- function(p, file, width = 8, height = 5) {
  print(p)
  ggsave(file.path("figures", file), p, width = width, height = height, dpi = 150)
}

# ---- 1. Load and first look -----------------------------------------
hotels <- read_csv(data_path, show_col_types = FALSE)
banner("Data overview")
cat("Rows and columns:", dim(hotels), "\n\n")
glimpse(hotels)

cat("\nMissing values per column (is.na only):\n")
na_counts <- colSums(is.na(hotels))
print(na_counts[na_counts > 0])

# ---- 2A. Investigate problems before cleaning -----------------------
banner("Block 2A: problems before cleaning")
cat("--- Hidden missing values stored as the TEXT 'NULL' ---\n")
cat("agent   = 'NULL':", sum(hotels$agent == "NULL"), "\n")
cat("company = 'NULL':", sum(hotels$company == "NULL"), "\n")
cat("country = 'NULL':", sum(hotels$country == "NULL", na.rm = TRUE), "\n")

cat("\n--- Five highest room rates (adr) ---\n")
print(sort(hotels$adr, decreasing = TRUE)[1:5])

cat("\nBookings with adr <= 0 (free or invalid rates):", sum(hotels$adr <= 0, na.rm = TRUE), "\n")
cat("\n--- Market segments of bookings with adr = 0 ---\n")
print(table(hotels$market_segment[hotels$adr == 0]))
cat("\nEmpty bookings (no adults, children or babies):",
    sum(hotels$adults + hotels$children + hotels$babies == 0, na.rm = TRUE), "\n")
cat("Stays with zero nights:",
    sum(hotels$stays_in_weekend_nights + hotels$stays_in_week_nights == 0), "\n")

# ---- 2B. Cleaning (every choice has a reason) ------------------------
hotels_clean <- hotels |>
  mutate(total_nights = stays_in_weekend_nights + stays_in_week_nights,
         total_guests = adults + children + babies) |>
  filter(!is.na(children),             # 4 rows: guest count unknown
         total_guests > 0,             # nobody stayed
         total_nights > 0,             # zero-night stays have no real stay
         adr > 0,                      # free stays and the one negative rate
         adr < 1000,                   # the 5,400 entry error
         market_segment != "Undefined") |>
  select(-agent, -company) |>          # mostly 'NULL' text, not needed for the objectives
  mutate(hotel = factor(hotel),
         deposit_type = factor(deposit_type),
         market_segment = factor(market_segment),
         customer_type = factor(customer_type),
         arrival_date_month = factor(arrival_date_month, levels = month.name),
         canceled = factor(is_canceled, levels = c(0, 1),
                           labels = c("Not cancelled", "Cancelled")))

banner("Block 2B: cleaning")
cat("Rows BEFORE cleaning:", nrow(hotels), "\n")
cat("Rows AFTER cleaning :", nrow(hotels_clean), "\n")
cat("Rows removed        :", nrow(hotels) - nrow(hotels_clean), "\n")
cat("Missing values left :", sum(is.na(hotels_clean)), "\n")

write_csv(head(hotels_clean, 30), "outputs/hotels_sample_rows.csv")

# ---- 2C. Descriptive statistics --------------------------------------
banner("Block 2C: descriptive statistics")
desc <- hotels_clean |>
  group_by(hotel) |>
  summarise(n = n(),
            mean_adr = mean(adr), median_adr = median(adr), sd_adr = sd(adr),
            mean_lead = mean(lead_time), median_lead = median(lead_time), sd_lead = sd(lead_time),
            cancel_pct = mean(is_canceled) * 100)
print(desc, width = Inf)

cat("\nOverall summary of key numeric variables:\n")
print(summary(hotels_clean[, c("adr", "lead_time", "total_nights", "total_guests")]))

cat("\nMarket segments (counts and %):\n")
print(table(hotels_clean$market_segment))
print(round(prop.table(table(hotels_clean$market_segment)) * 100, 1))

# ---- 2D. Charts -------------------------------------------------------
p_lead <- ggplot(hotels_clean, aes(x = lead_time)) +
  geom_histogram(bins = 40, fill = "steelblue", colour = "white") +
  labs(x = "Lead time (days between booking and arrival)", y = "Number of bookings")
save_plot(wm(p_lead, "Distribution of Booking Lead Time"), "01_lead_time.png")

p_adr <- ggplot(hotels_clean, aes(x = adr)) +
  geom_histogram(bins = 50, fill = "steelblue", colour = "white") +
  geom_vline(xintercept = mean(hotels_clean$adr), colour = "red", linetype = "dashed") +
  geom_vline(xintercept = median(hotels_clean$adr), colour = "darkgreen", linetype = "dotted") +
  labs(x = "Average daily rate, ADR (euros). Red = mean, green = median", y = "Number of bookings")
save_plot(wm(p_adr, "Distribution of Average Daily Rate"), "02_adr.png")

p_hotel <- ggplot(hotels_clean, aes(x = hotel, y = adr, fill = hotel)) +
  geom_boxplot(show.legend = FALSE, alpha = 0.7) +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 4, fill = "white") +
  labs(x = "Hotel type", y = "ADR (euros). Diamond = mean")
save_plot(wm(p_hotel, "Room Rate by Hotel Type"), "03_adr_by_hotel.png")

# Plot 3 (built once; also used for the chi-square test below)
cancel_dep <- hotels_clean |>
  group_by(deposit_type) |>
  summarise(cancel_pct = mean(is_canceled) * 100, n = n())
print(cancel_dep)
p_cancel <- ggplot(cancel_dep, aes(x = deposit_type, y = cancel_pct, fill = deposit_type)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(round(cancel_pct, 1), "%")), vjust = -0.4) +
  ylim(0, 110) +
  labs(x = "Deposit type", y = "Cancellation rate (%)")
save_plot(wm(p_cancel, "Cancellation Rate by Deposit Type"), "04_cancellation_by_deposit.png")

# Plot 4 (built once; label rotation applied after the theme so it is kept)
by_month <- hotels_clean |>
  group_by(arrival_date_month, hotel) |>
  summarise(mean_adr = mean(adr), .groups = "drop")
p_season <- ggplot(by_month, aes(x = arrival_date_month, y = mean_adr, colour = hotel, group = hotel)) +
  geom_line(linewidth = 1) + geom_point() +
  labs(x = "Arrival month", y = "Mean ADR (euros)", colour = "Hotel")
save_plot(wm(p_season, "Seasonal Pattern in Room Rates") +
            theme(axis.text.x = element_text(angle = 45, hjust = 1)),
          "05_seasonality.png")

# ---- 3. Inferential analysis (alpha = .05, effect sizes reported) ----

# TEST 1: Welch independent t-test
# H0: mean ADR is equal for City Hotel and Resort Hotel; H1: the means differ
banner("TEST 1: Welch t-test")
print(t.test(adr ~ hotel, data = hotels_clean))
g <- hotels_clean |> group_by(hotel) |> summarise(m = mean(adr), s = sd(adr), n = n())
sp <- sqrt(((g$n[1] - 1) * g$s[1]^2 + (g$n[2] - 1) * g$s[2]^2) / (g$n[1] + g$n[2] - 2))
cat("Cohen's d (effect size) =", round((g$m[1] - g$m[2]) / sp, 3), "\n")

# TEST 2: One-way ANOVA + Welch ANOVA + Tukey
# H0: mean ADR is equal across market segments; H1: at least one differs
banner("TEST 2: one-way ANOVA")
a1 <- aov(adr ~ market_segment, data = hotels_clean)
print(summary(a1))
ss <- summary(a1)[[1]]$`Sum Sq`
cat("Eta-squared (effect size) =", round(ss[1] / sum(ss), 3), "\n")
cat("\nRobustness check (Welch ANOVA, does not assume equal variances):\n")
print(oneway.test(adr ~ market_segment, data = hotels_clean, var.equal = FALSE))
cat("\nTukey post-hoc comparisons:\n")
print(TukeyHSD(a1))
p_segment <- ggplot(hotels_clean, aes(x = reorder(market_segment, adr, median), y = adr, fill = market_segment)) +
  geom_boxplot(show.legend = FALSE) + coord_flip() +
  labs(x = "Market segment", y = "ADR (euros)")
save_plot(wm(p_segment, "Room Rate by Market Segment"), "06_adr_by_segment.png")

# TEST 3: Chi-square test of independence
# H0: cancellation is independent of deposit type; H1: they are associated
banner("TEST 3: chi-square")
tab <- table(hotels_clean$deposit_type, hotels_clean$canceled)
print(tab)
cat("\nRow percentages:\n")
print(round(prop.table(tab, 1) * 100, 1))
chi <- chisq.test(tab)
print(chi)
cat("\nExpected counts (all should be >= 5):\n")
print(round(chi$expected, 1))
cat("Cramer's V (effect size) =",
    round(sqrt(chi$statistic / (sum(tab) * (min(dim(tab)) - 1))), 3), "\n")
# The chart for this test is figures/04_cancellation_by_deposit.png (plot 3 above)

# TEST 4: Correlation + multiple regression
# Correlation H0: rho = 0. Regression H0: all slopes are zero.
banner("TEST 4: correlation and regression")
print(cor.test(hotels_clean$lead_time, hotels_clean$adr))
m1 <- lm(adr ~ lead_time + total_nights + total_guests + hotel, data = hotels_clean)
print(summary(m1))
cat("\n95% confidence intervals for the coefficients:\n")
print(confint(m1))

set.seed(123)
samp <- hotels_clean |> slice_sample(n = 5000)
p_scatter <- ggplot(samp, aes(x = lead_time, y = adr)) +
  geom_point(alpha = 0.2, colour = "steelblue") +
  geom_smooth(method = "lm", formula = y ~ x, colour = "red") +
  labs(x = "Lead time (days)", y = "ADR (euros)")
save_plot(wm(p_scatter, "Lead Time vs Room Rate (random sample of 5,000)"), "07_lead_time_vs_adr.png")

# TEST 4b: Season (Model 2) and hotel-specific season (Model 3)
banner("TEST 4b: improved regression")
m2 <- lm(adr ~ lead_time + total_nights + total_guests + hotel + arrival_date_month, data = hotels_clean)
print(summary(m2))
m3 <- lm(adr ~ lead_time + total_nights + total_guests + hotel * arrival_date_month, data = hotels_clean)

cat("\nModel comparison (adjusted R-squared):\n")
cat("Model 1 (no month)         :", round(summary(m1)$adj.r.squared, 3), "\n")
cat("Model 2 (+ month)          :", round(summary(m2)$adj.r.squared, 3), "\n")
cat("Model 3 (+ hotel x month)  :", round(summary(m3)$adj.r.squared, 3), "\n")
cat("\nF-test: does adding month significantly improve Model 1?\n")
print(anova(m1, m2))

# Assumption checks for Model 2 (random sample of 5,000 points)
set.seed(123)
diag_df <- tibble(fitted = fitted(m2), resid = resid(m2)) |> slice_sample(n = 5000)
p_resid <- ggplot(diag_df, aes(x = fitted, y = resid)) +
  geom_point(alpha = 0.25, colour = "steelblue") +
  geom_hline(yintercept = 0, colour = "red") +
  labs(x = "Fitted ADR (euros)", y = "Residual (euros)")
save_plot(wm(p_resid, "Residuals vs Fitted Values (Model 2)"), "08_residuals_vs_fitted.png")
p_qq <- ggplot(diag_df, aes(sample = resid)) +
  stat_qq(alpha = 0.3, colour = "steelblue") +
  stat_qq_line(colour = "red") +
  labs(x = "Theoretical quantiles", y = "Sample quantiles")
save_plot(wm(p_qq, "Normal Q-Q Plot of Residuals (Model 2)"), "09_qq_residuals.png")

banner("Done")
