# Econometric Review: Marovoay–Ankarafantsika Impact Analysis

> Review of `documentation/04_Marovoay-Ankarafantsika.qmd`  
> Perspective: impact evaluation econometrics  
> Reference: Imbens (2024) *Causal Inference in the Social Sciences*, Annu. Rev. Stat. Appl. 11:123–152

---

## 1. Summary of the Current Approach

The analysis uses a quasi-experimental design to estimate the socio-economic impact of the 2002 reclassification of Ankarafantsika forest reserves into a national park. The treatment group consists of two survey sites (Bepako, Madiromiongana) on the same side of the Betsiboka river as the newly expanded protected area. Two sites on the opposite bank (Ampijoroa, Maroala) serve as controls. The natural barrier created by the river motivates the geographic discontinuity in treatment assignment.

The primary estimator is **Xu's (2017) Generalized Synthetic Control (gsynth)**, implemented via the `gsynth` R package. This is an interactive fixed-effects (IFE) model that factors out unobserved time-varying confounders shared across units. The analysis is first run on the four Marovoay sites, then extended to a broader donor pool drawing on all other Rural Observatory Survey (ROS) sites with both pre- and post-2002 observations.

---

## 2. Strengths

### 2.1 Identification strategy
The Betsiboka river as a natural treatment boundary is substantively compelling. The geographic separation reduces the plausibility of spillovers from treated to control units (SUTVA is more credible than in many conservation impact studies). The historical documentation of the PA creation and the forest reserve regime is thorough and supports the narrative that the 2002 reclassification represented a meaningful change in access restrictions, not just a relabelling.

### 2.2 Choice of estimator
The gsynth method is well-suited to this setting. It generalizes the synthetic control method (Abadie, Diamond & Hainmueller 2010) to allow multiple treated units and uses a low-rank factor structure to model unobserved common shocks. It avoids the convex-hull constraint of classical SC, and its cross-validated factor selection (r = 0–3) provides some robustness to over-fitting. This is broadly consistent with the "matrix completion" family of counterfactual estimators reviewed in Liu, Wang & Xu (2022) and Athey et al. (2021).

### 2.3 Panel design
The heatmap visualization of panel coverage is useful and transparent. The decision to restrict the pre-treatment window to post-1998 (when both control sites entered the survey) is methodologically sound and acknowledged.

### 2.4 Multiple outcomes
Examining income composition (agricultural vs. non-agricultural), household activity patterns, food self-sufficiency, and schooling rates provides a richer picture than income alone and allows cross-checking for consistency.

---

## 3. Weaknesses and Methodological Issues

### 3.1 Unit of analysis: site-level aggregation severely limits power

The analysis aggregates household-level outcomes to site-year means before estimation. With **only 2 treated sites** (Bepako, Madiromiongana), inference is fundamentally constrained:

- The number of treated units in gsynth determines the number of permutation placebo tests available; with 2, the minimum achievable permutation p-value is 0.50 (or lower only with many control units).
- The `se = TRUE, inference = "parametric"` option relies on asymptotic normality of the IFE estimator, which requires a non-trivial number of treated units. With 2, these are not reliable.
- The code merges Bepako and Madiromiongana via `site_id2 = ifelse(site_id == "032", "031", site_id)` in one part of the code, which effectively reduces to **1 treated unit** in that version of the analysis. This is noted neither in the text nor in the call to `gsynth`.

**Recommendation**: Work at the household level within Marovoay. With ~100–150 households per site per year, a household-level two-way FE DiD has substantially more power. Site fixed effects can substitute for the geographic aggregation.

### 3.2 Absence of pre-trend tests

No formal parallel trends test is reported. The `panelView` figure shows the panel structure but not outcome trends. The gsynth gap plots provide an informal visual check, but:

- The pre-treatment period within the final sample (1998–2002) spans only **4–5 years**, limiting the diagnostic power of pre-trend tests.
- There is no discussion of whether the linear (additive TWFE) parallel trends assumption or the more general IFE parallel trends assumption is plausible.
- The `force = "two-way"` argument in gsynth imposes two-way FE as a baseline, so the residuals after removing unit and time means should exhibit flat pre-treatment gaps if PTA holds; this is not shown.

**Recommendation**: Add a formal event-study specification (TWFE with leads and lags) for the pre-treatment period. Report both visual gap plots and the pre-MSPE ratio (post-MSPE / pre-MSPE), which is the standard SC diagnostic.

### 3.3 Treatment definition ambiguity

The treatment indicator is coded `year >= 2003`, but several issues arise:

- The park was created by decree in **August 2002**. If surveys are conducted late in the year, treatment effects could appear as early as 2002. The code drops 2002 from the pre-treatment window without explicit justification.
- The 1929 forest reserve was classified under Articles 50–52 of the 1913 Forest Code, but the text notes there was "no effective control over the forest reserve." The 2002 reclassification thus represents a shift from *de jure* to *de facto* restriction — but enforcement and ranger patrols may have ramped up gradually. This creates a **staggered or fuzzy treatment** rather than a clean binary switch.
- The 2015 boundary revision (Décret n° 2015-730) extended the PA. If this affected treated sites differently from controls, it creates a second treatment event that should be modelled.

**Recommendation**: Report results under alternative treatment timing assumptions (2002 vs. 2003 vs. gradual). Test for a second treatment event in 2015.

### 3.4 Income variable construction

The callout box explicitly flags that variable calculation needs refinement. Specific concerns:

- `revcou` is constructed as `coalesce(revcou, revppal + revsec + rev_riz + rev_cu + revel + revpeche)`, mixing two measurement approaches, which may introduce systematic differences across years or sites.
- Income variables in ROS data are subject to recall bias and seasonality — sites surveyed at different times of year will have systematically different recorded incomes. It is not clear whether the historical surveys were administered at the same point in the agricultural calendar across all sites.
- No outlier treatment or log transformation is applied before estimation. Agricultural income distributions are typically highly right-skewed; the gsynth level-specification will be sensitive to outliers.
- `rev_indep` is present in the 2025 data (see `03_habitat_niveau_de_vie.qmd`) but appears missing from the historical consolidated dataset's income construction.

**Recommendation**: Log-transform income outcomes. Apply outlier rules (e.g., winsorise at 99th percentile by year). Separately verify the `revcou` construction is consistent across the historical data vintages.

### 3.5 Education outcome is conceptually problematic

`any_schooling_rate` / `youth_schooling_rate` (share of household members ≥ 6 years with any schooling) is a problematic outcome for a 2002 treatment:

- School enrolment decisions are made annually for children of school age. Effects would not be visible until 2–3 years post-treatment.
- The outcome reflects the stock of education (having ever attended) rather than a flow, making interpretation of short-run changes difficult.
- The variable construction (`pct_with_schooling`) is only available as `youth_schooling_rate = coalesce(pct_with_schooling, NA_real_)`, suggesting non-trivial missing data.

**Recommendation**: Either drop this outcome pending better variable construction, or use annual school enrolment rates (if available) and restrict the horizon to 5+ years post-treatment.

### 3.6 No placebo / permutation inference

Permutation inference (applying the same estimator to each control unit as a pseudo-treated unit) is the canonical validity check for synthetic control methods (Abadie et al. 2010). The current code uses parametric bootstrap confidence intervals, which rely on asymptotic normality. With 2 treated units, the permutation p-value from iterating over the ~30 control sites would be more reliable.

**Recommendation**: Add in-space placebo tests via the `gsynth` `inference = "nonparametric"` option, or manually iterate the estimator over control units.

### 3.7 Donor pool heterogeneity

The expanded donor pool includes all ROS sites across Madagascar (Alaotra, Marovoay, and other observatories). Sites in different ecological and economic zones (irrigated rice plains vs. highland areas vs. coastal zones) may not constitute credible counterfactuals for Marovoay. The factor model in gsynth partially absorbs this through latent factors, but:

- Sites with very different time trends will receive low or zero weight in the synthetic control; their inclusion can still distort factor estimation.
- No assessment of synthetic control balance (predictor balance table, pre-treatment fit statistics) is reported.

**Recommendation**: Report predictor balance tables. Consider restricting the donor pool to sites with similar agro-ecological contexts (e.g., other lowland irrigated rice sites).

### 3.8 Absence of 2025 data

The analysis ends in 2015. The 2025 BETSAKA survey re-sampled the same four Marovoay sites and the Alaotra sites. This wave provides:

- A long-run observation 23 years post-treatment
- A test of whether any effects (positive or negative) have persisted or dissipated
- Additional pre-treatment variation for Alaotra (which was surveyed continuously 1999–2014)

However, integrating 2025 requires careful handling of the **10-year gap** (2015–2025), the **2015 boundary change**, and possible compositional changes in the panel (attrition over 10 years is likely to be non-random).

---

## 4. Assessment of Alternative Approaches

### 4.1 Two-Way Fixed Effects DiD (TWFE)

**Relevance**: High. Standard TWFE is the natural baseline. With a single treatment time (2002) and binary treatment, there is no staggered-adoption problem (the pathological case documented by de Chaisemartin & d'Haultfœuille 2020 and Goodman-Bacon 2021). TWFE should be reported as the baseline alongside gsynth.

**Recommendation**: Implement at household level with unit FE, year FE, and clustered standard errors at the site level. Also include a distributed-lag / event-study specification (`fixest::feols` with `i()` interaction).

### 4.2 Callaway–Sant'Anna DiD (2020)

**Relevance**: Moderate. With a single treatment cohort (all treated units adopt in 2003), the Callaway-Sant'Anna estimator reduces to a standard "clean" DiD. Its main advantage here is the doubly-robust semiparametric efficiency relative to TWFE when the treated and control units have different pre-treatment covariate distributions. The `did` package implementation is straightforward.

**Recommendation**: Implement at household level. Useful primarily as a robustness check against TWFE.

### 4.3 Synthetic DiD (Arkhangelsky, Athey, Hirshberg, Imbens & Wager 2021)

**Relevance**: High. The synthetic DiD (SDiD) combines SC weights (which reweight control units to match treated pre-treatment trends) with a TWFE estimator. It has better large-sample properties than pure SC when the number of control units and pre-treatment periods are both large. It is directly applicable at the site-year level using the `synthdid` R package.

**Recommendation**: Implement as a direct complement to gsynth. SDiD provides confidence intervals via bootstrap. The pre-treatment weights plot and the time weights plot are informative diagnostics.

### 4.4 Augmented Synthetic Control (Ben-Michael, Feller & Rothstein 2021)

**Relevance**: High. The Ridge-Augmented SC adjusts for poor pre-treatment fit by adding a ridge-regularised outcome model correction. When the treated unit lies outside the convex hull of the controls (common with aggregated site-level data), the augmentation term reduces bias. The `augsynth` R package implements this. The Python `pysyncon` library offers an equivalent implementation for Python workflows.

The key advantage over plain gsynth in this setting is that `augsynth` is designed specifically for the single-treated-aggregate case (or a small number of treated units), which fits the Marovoay design at the site level better than the IFE model.

**Recommendation**: Implement for the total income outcome as a robustness check to gsynth. The `augsynth` package provides jackknife confidence intervals via the `conformal_inf` argument.

### 4.5 Matrix Completion (Athey, Bahati, Doudchenko, Imbens & Khosravi 2021)

**Relevance**: Moderate. The MC-NNM (nuclear norm minimised matrix completion) approach imputes missing counterfactuals by finding the minimum-nuclear-norm matrix completion of the observed outcomes. It is available via the `MCPanel` R package. With a relatively small and unbalanced panel (variable sample sizes per year, some sites dropping out), the matrix completion approach may underperform relative to gsynth or SDiD.

**Feasibility**: Moderate. Requires a reasonably balanced panel. The unbalanced years in the Marovoay historical panel may cause issues.

### 4.6 Spatial Regression Discontinuity Design

**Relevance**: High conceptually; low practical feasibility. The Betsiboka river creates a geographic discontinuity that could support a spatial RDD (comparing households just inside vs. just outside the PA expansion boundary, or just on either side of the river). However:

- Individual household GPS coordinates are not publicly available in the current dataset.
- Site-level centroids are too coarse to implement a local linear RDD.
- The river creates a hard administrative/geographic barrier, not a smooth running variable.

**Recommendation**: Flag as a future research direction if GPS data becomes available. A fuzzy spatial RDD using distance from the river as the running variable would provide strong identification.

### 4.7 Regression Discontinuity in Time

**Relevance**: Low. An RD in time (using the decree date as the cutoff) would require high-frequency data around 2002. Annual surveys do not provide this.

### 4.8 Causal Forest / CATE Estimation

**Relevance**: Low for the main question; moderate for heterogeneity analysis. With binary treatment at the site level (2 treated vs. ~30 control sites), there is no within-treatment heterogeneity to estimate. However, at the household level within treated sites, causal forests could identify which households were most affected (by wealth, land tenure, primary activity). This is only meaningful if household-level panel identifiers are consistent.

### 4.9 Spatial Spillover / SUTVA Violations

**Relevance**: Moderate. Even if the Betsiboka river limits physical spillovers, there may be general-equilibrium effects: if the PA restriction reduces rice output in treated sites, rice prices rise region-wide, affecting real incomes in control sites. This would violate SUTVA and downward-bias estimated impacts. Currently not addressed.

---

## 5. Extending the Analysis to 2025

### 5.1 What the 2025 wave adds

The BETSAKA 2025 survey covers all four Marovoay sites and both Alaotra sites. This creates a 23-year post-treatment observation and a long-run welfare follow-up. For the impact evaluation:

- The treatment group (Bepako, Madiromiongana) has been living adjacent to the national park for 23 years.
- If there were negative access-restriction effects, households may have adapted (through diversification, migration, or intensification) or deteriorated further.
- The control group (Ampijoroa, Maroala) provides the 2025 counterfactual.

### 5.2 Complications for the 2025 extension

**Gap in the panel (2015–2025)**: A 10-year gap in the panel is a major structural break. Two-way FE estimators that rely on continuous panel variation will either need to treat the gap as missing data or interpolate. The gsynth IFE model can in principle be estimated on the unbalanced panel with the gap, but the factor loadings will be identified only from 1998–2015 and then extrapolated 10 years forward — a strong assumption.

**Selective attrition**: Panel households may have changed substantially over 10 years (death, migration, household fission/fusion). The 2025 panel is explicitly described as a best-effort reconstruction of the original panel. Non-random attrition correlated with treatment status would bias estimates.

**2015 boundary revision**: The PA boundary was extended in 2015. If this further restricted access in Bepako/Madiromiongana but not in Ampijoroa/Maroala, then from 2015 onwards there are effectively two treatment events. This needs to be modelled as a second dose of treatment.

**Survey instrument changes**: The 2025 questionnaire was adapted from the Makay 2022/2024 instruments. Income variable construction may differ from the historical modules, creating measurement discontinuities.

### 5.3 Recommended approach for 2025

The most defensible use of the 2025 wave in this analysis is:

1. **Descriptive**: Plot the 2025 outcome observations alongside the historical trend, with the gap clearly indicated (as done for habitat indicators in `03_habitat_niveau_de_vie.qmd`). Use a dotted line for the gap segment.

2. **Long-run DiD**: Estimate a simple 2×2 DiD using only pre-treatment (1998–2001) and the 2025 wave, ignoring the intermediate years. This is robust to intermediate dynamics and avoids the panel-gap problem. This gives an ATT for the 23-year treatment horizon.

3. **Gsynth with gap**: Re-estimate gsynth allowing the gap, treating 2016–2024 as missing. Report sensitivity to this approach.

4. **Narrative comparator**: Use the habitat trends from `03_habitat_niveau_de_vie.qmd` (electricity access, improved water) to triangulate whether treated and control sites show similar or divergent trajectories by 2025.

---

## 6. Summary Recommendations

| Priority | Issue | Recommendation |
|----------|-------|----------------|
| High | No pre-trend test | Add event-study TWFE with leads/lags; report pre-MSPE ratio |
| High | Site-level aggregation | Run household-level TWFE as baseline; use site-level only for SC/SDiD |
| High | No placebo tests | Add in-space permutation tests (`gsynth` non-parametric) |
| High | Income variable quality | Log-transform; winsorise; verify cross-vintage consistency |
| Medium | 2015 boundary change | Add second treatment event; test for discontinuity |
| Medium | SDiD not implemented | Add `synthdid` as methodological complement |
| Medium | Augmented SC not implemented | Add `augsynth` as robustness check for site-level SC |
| Medium | 2025 wave not used | Add long-run 2×2 DiD; descriptive trajectory plots |
| Low | Education outcome | Remove or respecify as annual enrolment rate |
| Low | Donor pool | Assess balance; consider restricting to agro-ecologically similar sites |

---

## 7. References

- Abadie, Diamond & Hainmueller (2010). Synthetic control methods. *JASA* 105(490):493–505.
- Arkhangelsky, Athey, Hirshberg, Imbens & Wager (2021). Synthetic difference-in-differences. *AER* 111(12):4088–118.
- Athey, Bahati, Doudchenko, Imbens & Khosravi (2021). Matrix completion methods for causal panel data. *JASA* 116(536):1716–30.
- Ben-Michael, Feller & Rothstein (2021). The augmented synthetic control method. *JASA* 116(536):1789–803.
- Callaway & Sant'Anna (2020). Difference-in-differences with multiple time periods. *J. Econometrics* 225(2):200–30.
- de Chaisemartin & d'Haultfœuille (2020). Two-way fixed effects estimators with heterogeneous treatment effects. *AER* 110(9):2964–96.
- Goodman-Bacon (2021). Difference-in-differences with variation in treatment timing. *J. Econometrics* 225(2):254–77.
- Imbens (2024). Causal inference in the social sciences. *Annu. Rev. Stat. Appl.* 11:123–152.
- Liu, Wang & Xu (2022). A practical guide to counterfactual estimators for causal inference with TSCS data. *Am. J. Pol. Sci.*
- Sun & Abraham (2021). Estimating dynamic treatment effects in event studies. *J. Econometrics* 225(2):175–99.
- Xu (2017). Generalized synthetic control method. *Political Analysis* 25(1):57–76.
