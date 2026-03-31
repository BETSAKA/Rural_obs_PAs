# DiD with Rotating Panels: Synthesis for Ankarafantsika
*Based on systematic extraction from 5 key papers*
*Context: Ankarafantsika NP study, treatment = park designation 2003, ~16 annual waves 1998–2014, rotating panel at HH level, 4 sites (2 treated: Bepako/Madiromiongana; 2 controls: Ampijoroa/Maroala), site-level treatment assignment.*

---

## Part I: Paper-by-Paper Analysis

---

### Paper 1 — Clark, Katz & Alvarez (2025) — *didunit*
**SoftwareX preprint, Oct 2025 · 23 pp.**

#### (1) Core Methodological Contribution
R package `didunit` implements multi-period DiD at the **individual unit level** (rather than the group level used by Callaway & Sant'Anna's `did`). Two steps: (i) estimate a 2×2 DiD for each treated unit × time-period pair separately; (ii) aggregate by user-specified attribute (dose, region, etc.). Uses **conformal inference** (not influence functions) for validity when the number of treated units is very small (as few as 1 treated unit). Requires an exchangeability assumption on residuals across all observed units.

#### (2) Results on Repeated Cross-Sections vs. Balanced Panels
*Explicit limitation*: "`didunit` cannot be used in settings where the unit composition changes every time period such as in the Current Population Survey (CPS) or the American National Election Study (ANES)."

For the unbalanced-panel case `didunit` handles, it enforces **compositional balance** between pre- and post-treatment observations. The comparison package `did` (Callaway & Sant'Anna) assumes that units observed only post-treatment would have had pre-treatment outcomes similar to units observed in both periods — an assumption `didunit` does not require.

**Critical implication for Madagascar**: `didunit` *explicitly cannot handle* a rotating panel where household composition changes every wave. Must use group-level (site-level) DiD or RC DiD estimators instead.

#### (3) Efficiency / Consistency under Rotating / Unbalanced Panels
Not directly addressed, but the implication is that individual-unit-level estimators break down entirely under rotating panels: unit-level parallel trends cannot be tested or maintained when individuals are observed only once.

#### (4) Treatment Effect Heterogeneity
Unit-level estimates allow aggregation over any unit attribute — dose, geography, individual characteristics. In a balanced panel, `didunit` and `did` aggregates are numerically equal, confirming that heterogeneity-robust unit-level aggregation is available when the panel is complete.

#### (5) Pre-Trend Testing
Pre-treatment placebo checks at the unit level. Stronger requirement than group-level: tests must pass for every treated unit, not just on average.

#### (6) Empirical Recommendations
Use `did` (Callaway & Sant'Anna) or group-level methods for any data structure with rotating/incomplete panels. Reserve `didunit` for balanced or mildly unbalanced panels with a stable unit set.

---

### Paper 2 — Sant'Anna & Zhao (2020) — *Doubly Robust DiD*
**Journal of Econometrics · 35 pp.**

#### (1) Core Methodological Contribution
Derives **doubly robust (DR) DiD estimators** for the ATT. Valid if *either* the propensity score model *or* the outcome regression model is correctly specified (but not necessarily both). Derives semiparametric efficiency bounds for both panel and repeated cross-section (RC) data. Provides two RC-specific estimands (`τ_dr,rc_1`, `τ_dr,rc_2`) whose form differs but that identify the same ATT under stationarity.

#### (2) Results on Repeated Cross-Sections vs. Balanced Panels

**Identification under RC (Assumption 1b)**: iid draws from a mixture distribution, with a critical restriction: *"the joint distribution of (D, X) must be invariant to T"* (temporal stationarity of the covariate-treatment relationship). This rules out compositional change in who is treated or what their covariates look like. For Madagascar, since treatment is site-level and constant, and if the HH rotation produces a stable distribution of HH characteristics within each site, Assumption 1b is satisfied.

**Theorem 1**: Both DR RC estimands equal the ATT if either the propensity score or the outcome regression is correctly specified.

**Remark 1**: Standard TWFE implicitly imposes (i) homogeneous treatment effects, and (ii) no covariate-specific trends in either group. When violated, TWFE ≠ ATT. Recommendation: use DR estimator instead.

#### (3) Efficiency / Consistency under Rotating / Unbalanced Panels

**Proposition 1 (Efficient Influence Functions)**:
- Panel efficient influence function (eq. 2.11–2.12): does NOT require modelling treated-group outcome regression `m_{1,1}(·)` and `m_{1,0}(·)`.
- RC efficient influence function (eq. 2.13–2.14): DOES require modelling these regressions, adding variance terms.

**Corollary 1** (central result for Madagascar):
$$E[\eta_{e,rc}^2] - E[\eta_{e,p}^2] = [\text{positive expression}] \geq 0$$

*"Under the DID framework it is possible to form more efficient estimators for the ATT when panel data are available than when only repeated cross-section data are available."*

- The efficiency loss with RC vs. panel is **convex in λ** (ratio of post-treatment to total observations).
- Efficiency loss is **larger when pre- and post-treatment samples are imbalanced in size**.
- For Madagascar's balanced annual surveys (~equal n per wave), the efficiency penalty is minimised.
- With 16 waves of RC data, the large effective sample partially compensates for the per-wave efficiency loss.

#### (4) Treatment Effect Heterogeneity
The DR estimator targets the ATT as a marginal parameter; can be extended to conditional ATT(x) via reweighting. Covariate inclusion tightens efficiency bounds.

#### (5) Pre-Trend Testing
The DR framework extends naturally to placebo/pre-treatment periods. Use placebo versions of the DR estimand with pre-treatment period pairs to test parallel trends.

#### (6) Empirical Recommendations
- Use `DRDID` R package (GitHub: `pedrohcgs/DRDID`). Implements `drdid_rc()` for RC case and `drdid_panel()` for panel case.
- For RC: use `drdid_rc()` with the pre- and post-period data stacked as a cross-section.
- Specify both propensity score and outcome regression models; DR property provides robustness.
- With balanced annual surveys, use the `drdid_rc()` with each wave-pair as a separate pre/post comparison, then aggregate.

---

### Paper 3 — Roth, Sant'Anna, Bilinski & Poe (2023) — *What's Trending in DiD*
**arXiv · 58 pp.**

#### (1) Core Methodological Contribution
Comprehensive synthesis of recent DiD literature, organised around relaxing three canonical assumptions: (i) staggered/simultaneous treatment timing; (ii) parallel trends validity; (iii) sampling and inference framework. Table 1 = practitioner checklist; Table 2 = R/Stata packages.

#### (2) Results on Repeated Cross-Sections vs. Balanced Panels
Not the main focus. RC is handled via Callaway & Sant'Anna (2021), which implements "not-yet-treated" and "never-treated" comparisons. The review notes that RC data is addressed by methods in Abadie (2005) and Sant'Anna & Zhao (2020).

For staggered timing with RC, the `did` package supports a `panel = FALSE` option.

#### (3) Efficiency / Consistency under Rotating / Unbalanced Panels
Cites Roth & Sant'Anna (2021, 2023) as providing efficient estimators under as-good-as-random treatment timing. Emphasises that standard TWFE negative-weight problem does NOT arise in **single-cohort settings** (all treated at the same time) — precisely Madagascar's case.

#### (4) Treatment Effect Heterogeneity
**Single treatment cohort → TWFE is not contaminated by forbidden comparisons** (no "earlier treated units used as controls for later treated"). The standard TWFE event study is valid for single-cohort settings. For aggregate treatment effect summaries, can simply average all ATT(g,t) estimates.

**Section 4 — Conditional parallel trends**: When unconditional parallel trends fails, condition on pre-treatment covariates. TWFE with covariates is inconsistent if X-specific trends exist or treatment effects are heterogeneous in X. Recommended: Sant'Anna & Zhao (2020) DR estimator.

#### (5) Pre-Trend Testing

**Section 4.3 — Standard approach**: TWFE with leads and lags; test pre-treatment coefficients equal to zero. For single-cohort (non-staggered) settings, the standard TWFE event study is valid.

**Section 4.4 — Critical warnings** (highly relevant):
1. Pre-trend parallel trends does NOT guarantee post-treatment parallel trends
2. **Low power**: "Linear violations of parallel trends that conventional tests would detect only 50% of the time often produce biases as large as (or larger than) the estimated treatment effect" (Roth 2022)
3. **Pre-test bias**: Conditioning on passing pre-test introduces selection bias in post-treatment estimates

**Section 4.4.1 — Improved diagnostics**:
- Roth (2022) `pretrends` package: power analysis for pre-trend tests — ask "how large a violation could the test have missed?"
- Bilinski & Hatfield (2018): non-inferiority approach — test that pre-trend IS large; reject if data show it is small
- Dette & Schumann (2020): related approach

**Section 4.5 — Sensitivity analysis**:
- Rambachan & Roth (2022b): `honestDiD` package — bounds on post-treatment ATT if post-treatment parallel trends violation ≤ M × pre-treatment violation. Allows sensitivity analysis: how large must M be before conclusions change?

#### (6) Empirical Recommendations (Table 1 Checklist)

1. **Is everyone treated at the same time?** → YES for Madagascar. "Estimation with TWFE specifications yields easily interpretable estimates."
2. **Parallel trends?** → If questionable:
   - Condition on covariates (use DR estimator)
   - Construct event-study plot
   - Accompany with power diagnostics (`pretrends` package)
   - Report formal sensitivity analyses (`honestDiD`)
3. **Large number of treated and untreated clusters from a super-population?** → NO for Madagascar (only 4 sites). → "Consider using one of the alternative inference methods described in Section 5.1." → If can't imagine super-population, use design-based inference (cluster at level of independent treatment assignment = site level).

**Small-cluster inference (Section 5, pages 39–42)**:
- With only 2 treated and 2 control clusters: Standard clustered SEs are invalid
- Options:
  - **Conley & Taber (2011)**: Learn error distribution from many control units/households; valid when there are few treated clusters but many control clusters (not quite right here with 2 controls too)
  - **Ferman & Pinto (2019)**: Extension allowing heteroskedasticity from observable characteristics
  - **Cluster wild bootstrap** (Cameron, Gelbach, Miller 2008): works with as few as 5 clusters, requires homoskedasticity; Canay, Santos, Shaikh (2021) show reliability requires homogeneity
  - **Large-T permutation methods** (Canay, Romano, Shaikh 2017; Ibragimov & Müller 2016; Chernozhukov, Wüthrich, Zhu 2021): valid under large-T asymptotics, require parallel trends in many pre/post periods → **directly applicable to Madagascar with 16 waves**

**Design-based inference (Rambachan & Roth 2022a)**:
- Treatment as stochastic, units fixed. DiD unbiased for finite-population ATT.
- Cluster SEs valid if clustered at the level of independent treatment assignment.
- **For Madagascar: cluster at site level. With only 4 sites, use permutation inference (4 sites, 2 possible treatment assignments → exact p-value = 1/C(4,2) = 1/6 ≈ 0.17 one-sided), which is very conservative.**
- Solution: use the large-T dimension. With 16 time periods and 4 sites, time-series permutation tests have more power.

**Table 2 — Key packages**:
- `DRDID` / `drdid` (R/Stata): Sant'Anna & Zhao (2020)
- `honestDiD` (R/Stata): Rambachan & Roth (2022b)
- `pretrends` (R): Roth (2022)
- `did` / `csdid` (R/Stata): Callaway & Sant'Anna (2021)

---

### Paper 4 — Wooldridge (2025) — *TWFE, TWM, and DiD Estimators*
**Empirical Economics · 43 pp.**

#### (1) Core Methodological Contribution

**Theorem 3.1** (main result): The TWFE estimator equals the **Two-Way Mundlak (TWM) regression** — pooled OLS with unit-specific time averages (`x̄_i·`) and period-specific cross-sectional averages (`x̄_·t`) added as controls. This means unit fixed effects are not needed: they can be replaced by cohort dummies + covariates.

**Equation (5.16)** — The grand equivalence chain:
$$\text{Cohort Imputation} = \text{POLS} = \text{TWFE} = \text{RE} = \text{BJS Imputation}$$

Under no-anticipation + conditional parallel trends + linearity assumptions, all these estimators produce identical ATT estimates. "There is nothing inherently wrong with using TWFE — a conclusion reached by Sun and Abraham (2021)."

**Single cohort simplification (eq. 5.10)**: With common treatment timing (one cohort), need only one "ever treated" dummy `d_i` instead of N unit FEs. The POLS regression becomes:
$$y_{it} = \sum_{s=q}^{T} \tau_s (w_{it} \cdot d_i \cdot f_{st}) + \sum_s (w_{it} \cdot d_i \cdot f_{st}) \cdot \dot{x}_{i1} \delta_s + \sum_s \gamma_s f_{st} + \sum_s (f_{st} \cdot x_i) \pi_s + d_i \cdot [\text{selection terms}] + u_{it}$$

This avoids the incidental parameters problem and is computationally feasible even with thousands of observations.

#### (2) Results on Repeated Cross-Sections vs. Balanced Panels

**Section 10.2 — Unbalanced panels**: When the panel is unbalanced, POLS and TWFE are no longer numerically identical. POLS remains consistent if missingness depends only on observables `(d_g, x_i)`. **TWFE has an advantage**: allows selection to depend on unobserved heterogeneity `c_i`.

**Section 10.2 recommendation**: "It is easiest to estimate the flexible Eq. (5.6) by TWFE using the complete cases."

**Concluding remarks (p. 37 — key RC result)**:
> "the imputation and pooled OLS methods can be extended to the case of repeated cross sections, provided we impose essentially the same assumptions in Sect. 4 **along with a stable population over time**. See Deb et al. (2024) for details."

**Critical implication**: Wooldridge's POLS/ETWFE approach extends to RC under a **stable population** assumption — i.e., the same as Sant'Anna's stationarity requirement. **Deb et al. (2024)** is the key reference for the RC extension.

**Advantage of regression-based approach over CS(2021)/de Chaisemartin**: "The latter estimators require complete data in both time periods in order for a period to contribute to the estimation, whereas the regressions in levels use all available complete cases."

#### (3) Efficiency / Consistency under Rotating / Unbalanced Panels

**Section 5.3 — Efficiency**: The POLS/TWFE/RE estimator is BLUE (best linear unbiased) and asymptotically efficient when:
- No heteroskedasticity in `a_i` (unit effects) or `u_it` (idiosyncratic error)
- No serial correlation in `u_it`

**Including event-study leads (pre-treatment indicators)** adds regressors that are redundant under the null of parallel trends → reduces efficiency. But including them can **improve** efficiency when there is strong positive serial correlation in `u_it`.

**With many pre-treatment waves**: The "lags only" estimator (uses all pre-treatment periods as control) is more efficient than the "leads and lags" (event study) estimator, by avoiding redundant regressors under H₀. But the event study is more robust to pre-trend violations.

#### (4) Treatment Effect Heterogeneity

**Section 5**: The POLS regression (5.3) includes interactions `w_it · d_{gi} · f_{st} · ẋ_ig` that directly estimate **moderating effects** (how ATT varies with covariate `x`). ATTs can be aggregated by cohort, by exposure time, or overall (Section 7).

**Section 8 — Cohort-specific trends**: When parallel trends fails, add `d_{gi} · t` terms (linear cohort-specific trends) to the regression. This is the **DDD estimator** in the simple case (eq. 8.3): standard 2×2 DiD minus a pre-trend correction. Requires ≥2 pre-treatment periods. Generates different estimates that can be much smaller than naive DiD.

#### (5) Pre-Trend Testing

**Section 6.1**: "Provided we use the fully flexible regression in (6.4), there is no issue of contamination bias in testing for pre-trends." The choice of reference pre-treatment period does not affect the pre-trend test statistic (only the treatment effect estimate).

**Pre-trend test is equivalent** across "use period g−1 as reference" and "use period 1 as reference" specifications.

**Adding cohort-specific trends (Section 8)**: After including `d_g · t`, pre-treatment residuals (from the first-step imputation) should be flat. If they are, the linear trend specification adequately removes pre-existing differential trends.

#### (6) Empirical Recommendations

For single-cohort common treatment timing (Madagascar):
1. Estimate POLS: `y_it = α + d_i·β + Σ_s f_{st}·γ_s + Σ_s (f_{st}·d_i)·τ_s + [covariates and interactions] + ε_it`
   - `d_i` = ever-treated site indicator
   - `f_{st}` = time-period dummies
   - `τ_s` = ATT in wave s
2. Use heteroskedasticity/cluster-robust SEs (cluster at site level)
3. Aggregate exposure-time-specific effects `τ_s` to weighted average using `margins` command or equivalent
4. For robustness, add `d_i · t` to allow cohort-specific linear trend

**RC extension (from Deb et al. 2024)**: Under stable population assumption, replace the balanced-panel POLS with pooled cross-sections, including `d_site` + time dummies + treatment interaction. No unit FE needed (and not possible with rotating panel).

---

### Paper 5 — de Chaisemartin & D'Haultfœuille (2023) — *Causal Inference with Differences-in-Differences*
**Textbook · 384 pp.**

#### (1) Core Methodological Contribution

Comprehensive textbook. Key organising principle: move from the classical design outward, adding complexity only as needed. Heterogeneity-robust DID estimators (`did_multiplegt_dyn` in Stata/R) as the workhorse for complex designs.

**Chapter 2**: Data setup at **group level** (sites, regions, states) with panel of groups across time. Crucially, the data requirements are framed as group-level: each group-time cell has an average outcome. This is directly applicable to Madagascar with 4 sites × 16 waves as the data structure.

**Chapter 3 (classical design)**: Binary, absorbing treatment, one treatment date, group-level panel. TWFE estimators. Pre-trend tests (Section 3.4). Event study (Section 3.5). Heterogeneous effects (Section 3.6).

**Chapter 5**: TWFE outside the classical design — negative weights possible. Decomposition shows which 2×2 comparisons drive the TWFE estimate.

**Chapter 6**: Staggered treatment timing. Heterogeneity-robust estimators (`did_multiplegt_dyn`).

**Chapter 8.5 (Designs without stayers)**: About weather/continuous treatment designs where treatment changes every period — NOT directly applicable to Madagascar's binary absorbing treatment.

#### (2) Results on Repeated Cross-Sections vs. Balanced Panels
The textbook focuses on group-level panel data (Section 2.1). For Madagascar, the *group* is the survey site (4 sites), and the *panel* is the series of annual surveys of that site. Within each site, households rotate, but the group-level average is observed every wave → group-level panel is **balanced**.

The textbook does not address individual-level rotating panels per se. The key insight is: **analyse at group (site) level**, not household level. The household-level sampling variation contributes to within-group variance but doesn't affect identification.

#### (3) Efficiency / Consistency under Rotating / Unbalanced Panels
Using group-level averages as outcomes loses the information in within-group HH heterogeneity but is consistent. Gains from using individual-level data in POLS (pooled cross-sections at HH level, but clustering at site level) are the standard precision gains from larger N.

#### (4) Treatment Effect Heterogeneity
**Section 3.6**: Heterogeneous treatment effects over time = event-study effects. With single treatment date, these are the `ATT(t)` = average treatment effect in year t post-treatment. Reporting them as an event-study plot is the recommended approach.

**Section 6.4**: ATT disaggregated by groups and treatment exposure. For Madagascar with 2 treated sites, can report site-specific effects.

#### (5) Pre-Trend Testing
**Section 3.4 — Limitations of pre-trend tests** (pp. 67–73): Mirrors Roth et al.'s warnings. Pre-trend tests have limited power and do not rule out violations in the post-treatment period. Must accompany with sensitivity analyses.

#### (6) Empirical Recommendations — Chapter 9 Practitioners' Checklist

1. Lay out the causal effect to estimate (ATT of park designation on HH income).
2. State no-anticipation and parallel-trends assumption explicitly.
3. Test:
   - (a) Pre-trend/placebo estimators. "Those pre-trend estimators should be smaller than your actual treatment-effect estimators, and ideally, should allow you to rule out small differential trends."
   - (b) If pre-trends are small and precisely estimated with simple DiD → "you may not need to use more complicated estimators."
   - (e) Acknowledge threats: are there concomitant shocks affecting treated/control sites differentially?
4. Estimation:
   - Binary absorbing treatment, single treatment date → **Classical DiD design, Chapter 3**
   - "In a classical DID design, TWFE estimators are heterogeneity-robust estimators, so there is no need to use other estimators."
   - Use event-study effects (Section 3.5).
5. Inference:
   - Cluster at treatment assignment level = site level.
   - **"With less than 40 treated or less than 40 control groups, we recommend that you conduct simulations based on your data to assess if, in your data, confidence intervals relying on large-sample approximations have close-to-nominal coverage."**
   - Madagascar has 2 treated and 2 control groups → far below threshold → **must use alternative inference procedures (Section 3.3)**.
   - Section 3.3 options: permutation tests, Fisher exact tests, simulation-based.

---

## Part II: Synthesis for the Madagascar Context

### Design Summary

| Feature | Status | Implication |
|---|---|---|
| Treatment timing | Single cohort (2003) | No staggered DiD issues; no negative weights; TWFE valid |
| Treatment level | Site-level (4 sites) | Group-level DiD; cluster at site level |
| Panel structure | Rotating (HH-level) | Household FE invalid; use RC/group-level methods |
| Pre-treatment waves | ~5 years (1998–2002) | Event study + pre-trend testing feasible |
| Post-treatment waves | ~12 years (2003–2014, excl. 2005) | Dynamic treatment effects estimable |
| Total observations | ~16 waves × ~N HH/site | Large pooled cross-section |
| # Treated clusters | 2 (Bepako, Madiromiongana) | Few clusters → non-standard inference required |
| # Control clusters | 2 (Ampijoroa, Maroala) | Same |

---

### Q1: Can we use all 16 annual waves with a rotating panel?

**Yes, all waves are usable, but NOT through household fixed effects.**

The rotating panel structure means the data is a sequence of independent cross-sections at each site — a **repeated cross-section (RC)** design at household level. The appropriate framework is:

**Option A — Group-level analysis (cleanest)**:
Aggregate to site × year means. You have a 4 × 16 balanced panel at site level. Standard TWFE on site-level outcomes:
$$\bar{Y}_{st} = \alpha_s + \alpha_t + \tau \cdot D_s \cdot \mathbf{1}[t \geq 2003] + \epsilon_{st}$$
This is fully valid. Inference with 4 observations per period is problematic (see below), but the estimator itself is consistent under parallel trends.

**Option B — Pooled cross-section at HH level (recommended for efficiency)**:
Use all individual HH observations in a pooled OLS with **site dummies** (not HH dummies) + time dummies:
$$y_{it} = \alpha_{site(i)} + \sum_t \gamma_t \cdot \mathbf{1}[\text{year}=t] + \tau \cdot D_{site(i)} \cdot \mathbf{1}[t \geq 2003] + x_{it}\beta + \epsilon_{it}$$
This is precisely the RC DiD structure of Sant'Anna & Zhao (2020) and Wooldridge's POLS approach, extended to RC under the stable-population assumption (Deb et al. 2024). Each wave contributes an independent random sample from each site's population → pooling all waves is valid and increases precision.

**Validity conditions** (must verify):
1. **Stable population (stationarity)**: The distribution of HH characteristics within each site must be stable across waves (no secular drift in who lives near the park). If the HH rotation is truly random sampling from a stable population, this is satisfied.
2. **No anticipation**: HH income in treated sites was not affected before 2003. Test with pre-treatment waves.
3. **Parallel trends**: Counterfactual income trends in treated and control sites would have been parallel absent the park. Test with 1998–2002 data.

---

### Q2: Is the ATT consistently estimated with RC vs. panel data?

**Yes, under the stationarity assumption.** The ATT identified by RC DiD equals the same ATT as the panel DiD (Sant'Anna & Zhao 2020, Theorem 1). The rotating panel does NOT bias the estimate; it only affects efficiency.

The key formula (site-level TWFE with single cohort):
$$\hat{\tau}_{ATT} = (\bar{Y}_{\text{treated,post}} - \bar{Y}_{\text{treated,pre}}) - (\bar{Y}_{\text{control,post}} - \bar{Y}_{\text{control,pre}})$$
This estimand is the same whether households are the same or different across waves, as long as within-site sampling is random and stable.

---

### Q3: How large is the efficiency penalty from using RC vs. hypothetical panel data?

Moderate, but partially offset by large N per wave.

From Sant'Anna & Zhao Corollary 1:
- Variance(RC estimator) − Variance(panel estimator) ≥ 0
- The gap is convex in λ = N_post / (N_pre + N_post)
- For balanced surveys (equal n each wave), λ ≈ 0.5 → penalty is at its maximum
- For Madagascar: roughly 12 post / 16 total ≈ λ = 0.75 → some imbalance, modest additional penalty

However, with ~16 waves and substantial n per site per wave (~50–150 HH), the total effective sample is large (~2,000–10,000 HH observations), which compensates substantially for the per-wave efficiency loss.

**Wooldridge (2025, Section 5.3)**: Under ideal RE assumptions, POLS on pooled cross-sections with site and time dummies is **BLUE** — it fully exploits the cross-sectional information in each wave. If there is positive serial correlation in site-level shocks (likely for income), the RE approach may further improve efficiency.

---

### Q4: How should time-varying treatment effects (dynamics over 12 post-treatment years) be modelled?

Use **event-study / leads-and-lags regression** at site level:

$$y_{it} = \alpha_{site(i)} + \sum_{s \neq -1} \tau_s \cdot D_{site(i)} \cdot \mathbf{1}[\text{year}=t_0+s] + x_{it}\beta + \epsilon_{it}$$

where $s \in \{-5,-4,-3,-2,-1,0,1,2,...,12\}$ and $s = -1$ (2002) is the reference period.

**Pre-treatment coefficients** ($s < 0$): test of parallel trends (should be ~0)
**Post-treatment coefficients** ($s \geq 0$): $\tau_s$ = ATT $s$ years after park designation

**Wooldridge (2025) "lags only" vs "leads and lags"**:
- "Lags only" (drops pre-treatment indicators): more efficient under H₀ of parallel trends, uses all pre-treatment periods to identify trends
- "Leads and lags" (event study): adds pre-treatment indicators as controls; loses some efficiency under H₀ but allows contamination-free pre-trend test
- For Madagascar with only 2 treated sites, the pre-trend test will have very low power regardless — this is a fundamental limitation of the design

**Cohort-specific trends (Wooldridge Section 8)**: If pre-trends are detected or suspected, add `d_site · t` interaction to allow a different linear trend for treated vs. control sites before and after treatment:
$$\text{add: } \eta \cdot D_{site(i)} \cdot t$$
This gives the DDD estimator (eq. 8.3), adjusting the standard DiD for the measured pre-existing differential trend.

---

### Q5: How should pre-trend testing proceed with RC data?

**Valid approach**: The pre-treatment waves (1998–2002) provide a direct test. Construct event-study coefficients for years 1998–2001 (with 2002 as reference). Under parallel trends, these should be ~0.

**Specific challenges with Madagascar design**:
1. **Very low power**: With only 4 sites (2 treated, 2 control), even large pre-trends may not be statistically significant. The test has power roughly = 1/C(4,2) = 1/6 for a one-sided randomisation test.
2. **Must supplement statistical tests** with substantive arguments: Why would Bepako/Madiromiongana have parallel income trends to Ampijoroa/Maroala absent the park? Comparable geography, similar pre-2003 trends, similar economic base?

**Recommended approach (Roth et al. 2023 + Wooldridge 2025)**:
1. Plot the full event study (`τ_s` for s = -5 to +12).
2. Use `pretrends` R package (Roth 2022) to compute the **power of the pre-trend test** against a plausible linear violation. If the data would detect a 0.1 standard deviation differential trend only 30% of the time, the pre-trend test provides weak evidence.
3. Use `honestDiD` (Rambachan & Roth 2022b) to conduct sensitivity analysis: "How large would the post-treatment parallel trends violation need to be (relative to the largest observed pre-trend) before the ATT confidence interval covers zero?"
4. Do NOT over-rely on failure to reject pre-trends as validating the design. Document substantive arguments for parallel trends.

---

### Q6: What inference procedure is appropriate with 4 site-level clusters?

**Standard cluster-robust SEs are invalid with 4 clusters.**

Recommended options (in order of preference for Madagascar):

1. **Fisher/randomisation-based exact test** (design-based inference, Rambachan & Roth 2022a):
   - Under the null ATT = 0, permute treatment assignment across sites. With 4 sites, there are C(4,2) = 6 possible assignments → exact one-sided p-value = 1/6 ≈ 0.167 (if the observed DiD is the most extreme). Conservative but honest.
   - Can be made more powerful by conditioning on placebo pre-trends in the permutation distribution.

2. **Large-T permutation tests** (Canay, Romano, Shaikh 2017; Ibragimov & Müller 2016):
   - Valid when T is large (≥ 10 periods), N fixed. For Madagascar with T = 16, this is appropriate.
   - Ibragimov-Müller: compute DiD estimate separately for each pre-treatment and post-treatment year. Use the distribution of pre-treatment estimates as the reference distribution for inference. More powerful than cross-sectional randomisation.

3. **Conformal inference** (Chernozhukov, Wüthrich, Zhu 2021):
   - Exact finite-sample validity under exchangeability. The `didunit` paper uses this. Particularly relevant when treated unit count is very small.

4. **Wild cluster bootstrap** (Cameron, Gelbach, Miller 2008):
   - Works with as few as 5 clusters in simulations; with 4 clusters, coverage may not be nominal.
   - If used, implement in R via `fwildclusterboot` package with `B = 9999` replications.
   - Conservative: asymmetric WCB may over-reject; prefer `t(G-1)` critical values.

5. **Aggregation to site×period cells + cluster at site**:
   - Collapse to 4 × 16 = 64 observations, one per site per year.
   - Cluster at site (4 clusters). Very few clusters; SEs will be unreliable.
   - Can use HC3 SEs as an alternative (heteroskedasticity-robust, no clustering).

**Practical recommendation**: Use approach (1) + (2) together. Report Fisher randomisation p-values alongside point estimates and 95% CIs from wild bootstrap, noting the limitations.

---

### Q7: Recommended estimation strategy

**Step 1 — Primary specification** (pooled cross-section RC DiD at HH level):

```r
# Event-study TWFE equivalent via POLS (no HH FE, site FE instead)
library(fixest)

feols(
  log_income_winsor ~ i(year, treated_site, ref = 2002) + 
                      baseline_covariates | site + year,
  data = household_data,
  cluster = ~site,  # 4 clusters
  vcov = "twoway"   # site + year clustering
)
```

This gives ATT(t) for each year, with 2002 as reference. Standard TWFE with site + year FE, which is valid for this single-cohort binary absorbing design.

**Step 2 — Robustness with DR estimator** (Sant'Anna & Zhao 2020):

```r
library(DRDID)

# Stack pre and post years, compute DR DiD for each post-year
# or use the overall summary version
drdid(
  yname = "log_income_winsor",
  tname = "year_binary",  # 0 = pre (e.g. 2001-2002), 1 = post
  idname = "hh_id",       # HH identifier (new each wave -> treat as RC)
  dname = "treated_site",
  panel = FALSE,          # CRITICAL: use RC version
  estMethod = "tlogit",   # doubly robust
  xformla = ~baseline_covariates,
  data = did_data
)
```

**Step 3 — Sensitivity analysis**:

```r
library(honestDiD)
library(pretrends)

# Power analysis of pre-trend test
pretrends(
  betahat = event_study_coefs,  
  sigma = event_study_vcov,
  numPrePeriods = 5,            # 1998-2002
  numPostPeriods = 12           # 2003-2014
)

# Sensitivity to parallel trends violation
createSensitivityResults(
  betahat = event_study_coefs,
  sigma = event_study_vcov,
  numPrePeriods = 5,
  numPostPeriods = 12,
  Mvec = seq(0, 2, by = 0.25)  # range of M = ratio post/pre violation
)
```

**Step 4 — Alternative inference for few clusters**:

```r
library(fwildclusterboot)

# Wild cluster bootstrap with site-level clustering
boot_result <- boottest(
  feols_model,
  clustid = "site",
  param = "treated_site::1",  # overall ATT
  B = 9999,
  type = "rademacher",
  impose_null = TRUE
)

# Randomisation/permutation inference
# Permute treatment assignment across 4 sites, recompute DiD
# Under H0: all C(4,2)=6 permutations equally likely
```

---

## Part III: Key Additional References to Fetch

These papers are frequently cited and directly relevant to the Madagascar context but were not in the 5 primary PDFs:

### Essential

1. **Deb, P., Felkner, J., Gerber, E., Murtazashvili, I., & Pinto, P. (2024)** — RC extension of Wooldridge's POLS/ETWFE approach. Direct reference for "extending imputation/POLS to repeated cross sections under stable population." [Find preprint on SSRN or arXiv]

2. **Callaway, B., & Sant'Anna, P. H. C. (2021)** — "Difference-in-Differences with Multiple Time Periods." *Journal of Econometrics*, 225(2), 200–230. Core reference for heterogeneity-robust DiD. The `did` package implements RC DiD via `panel = FALSE`. [Already in `DRDID`/`did` package documentation]

3. **Rambachan, A., & Roth, J. (2022b)** — "A More Credible Approach to Parallel Trends." *Review of Economic Studies*. The `honestDiD` package. Sensitivity analysis for parallel trends violations relative to observed pre-trends. [GitHub: asheshrambachan/HonestDiD]

4. **Roth, J. (2022)** — "Pre-test with Caution: Event-Study Estimates After Testing for Parallel Trends." *American Economic Review: Insights*, 4(3), 305–322. Power analysis and pre-test bias. The `pretrends` R package. [GitHub: jonathandroth/pretrends]

5. **Conley, T. G., & Taber, C. R. (2011)** — "Inference with 'Difference in Differences' with a Small Number of Policy Changes." *Review of Economics and Statistics*, 93(1), 113–125. The standard reference for few treated clusters.

6. **Ibragimov, R., & Müller, U. K. (2016)** — "Inference with Few Heterogeneous Clusters." *Review of Economics and Statistics*, 98(1), 83–96. Large-T alternative inference with few clusters. Directly applicable with T = 16.

7. **Canay, I. A., Romano, J. P., & Shaikh, A. M. (2017)** — "Randomization Tests Under an Approximate Symmetry Assumption." *Econometrica*, 85(3), 1013–1030. Permutation-based inference valid under large T with few clusters.

### Highly Relevant

8. **Abadie, A., Athey, S., Imbens, G., & Wooldridge, J. (2023)** — "When Should You Adjust Standard Errors for Clustering?" *Quarterly Journal of Economics*, 138(1), 1–35. Definitive reference on clustering; recommends clustering at level of independent treatment assignment.

9. **Chernozhukov, V., Wüthrich, K., & Zhu, Y. (2021)** — "An Exact and Robust Conformal Inference Method for Counterfactual and Synthetic Controls." *JASA*, 116(536), 1849–1864. Exact inference with very few treated units.

10. **Ferman, B., & Pinto, C. (2019)** — "Inference in Differences-in-Differences with Few Treated Groups and Heteroskedasticity." *Review of Economics and Statistics*, 101(3), 452–467. Extension of Conley-Taber allowing heteroskedasticity.

11. **Borusyak, K., Jaravel, X., & Spiess, J. (2024)** — "Revisiting Event Study Designs: Robust and Efficient Estimation." *Review of Economic Studies*, 91(6), 3253–3285. Imputation estimator (BJS); equivalent to POLS per Wooldridge. `didimputation` R package.

12. **Abadie, A. (2005)** — "Semiparametric Difference-in-Differences Estimators." *Review of Economic Studies*, 72(1), 1–19. IPW DiD estimator. Direct precursor to Sant'Anna & Zhao's DR estimator.

### Methodologically Useful

13. **Rambachan, A., & Roth, J. (2022a)** — "Design-Based Uncertainty for Quasi-Experiments." [arXiv preprint]. Design-based justification for clustering at treatment assignment level; DiD unbiased under randomisation of treatment timing.

14. **Bilinski, A., & Hatfield, L. A. (2018)** — "Seeking Evidence of Absence: Reconsidering Tests of Model Assumptions." *arXiv:1805.03273*. Non-inferiority approach to pre-trend testing; test the null that a trend IS large.

15. **Caetano, C., Callaway, B., Payne, S., & Sant'Anna Rodrigues, H. (2022)** — "Difference in Differences with Time-Varying Covariates." *arXiv:2202.02903*. Handling time-varying controls in RC DiD. Relevant if within-site HH covariates vary by wave.

---

## Summary Table: Key Choices for Ankarafantsika

| Decision | Recommended Choice | Justification |
|---|---|---|
| Estimand | ATT (each year post-2003) | Single cohort, binary absorbing treatment |
| Estimator | POLS with site + year FE (TWFE equivalent) | Valid for single cohort; equivalent to ETWFE |
| RC extension | POLS on pooled HH cross-sections, site FE, cluster ~site | Wooldridge (2025)/Deb et al. (2024) |
| No HH FE | Site dummies replace unit dummies | Rotating panel → unit FE invalid |
| Covariates | Baseline HH characteristics (pre-2003 stable) | Strengthens parallel trends; use `f_st × x_i` interactions |
| Event study | Yes, all 16 waves | Visualise pre-trends and dynamics |
| Pre-trend test | Estimate + power diagnostics + sensitivity | `pretrends` + `honestDiD` packages |
| Primary inference | Randomisation/permutation (C(4,2)=6 permutations) | Only valid exact test with 4 clusters |
| Secondary inference | Wild cluster bootstrap (4 clusters, B=9999) | More powerful but approximate |
| Large-T supplement | Ibragimov-Müller (2016) or Canay et al. (2017) | Exploits 16-period dimension |
| Robustness | DR estimator via `DRDID::drdid_rc()` | Doubly robust to model misspecification |
| Trend robustness | Add `D_site × t` (DDD) | Tests robustness to pre-existing differential trends |
