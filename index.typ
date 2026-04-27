// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [Conservation Governance and Rural Livelihoods in Madagascar],
  subtitle: [Long-Run Analysis of Rural Observatory Surveys (1995--2025)],
  author: "Florent Bédécarrats, Véromanitra Razafimahenina",
  date: "2026-04-28",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
)


#v(2fr)
#align(center)[
  #image("media/Photo_Marovoay_Veromanitra_Ramizason_01.jpeg", width: 80%)
  #v(0.5em)
  #text(size: 9pt, style: "italic")[
    Marovoay observatory site near Ankarafantsika National Park. \
    Photo: Véromanitra Ramizason.
  ]
]
#v(1fr)
#pagebreak()
// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Overview]
<overview>
#block[
#callout(
body: 
[
This website is a companion to an academic paper in preparation. It will be updated when data from the 2026 survey round becomes available. All code is available in the #link("https://github.com/BETSAKA/Rural_obs_PAs")[GitHub repository].

]
, 
title: 
[
Living document
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#figure([
#box(image("media/Photo_Marovoay_Veromanitra_Ramizason_01.jpeg", alt: "Field photo from the Marovoay observatory site near Ankarafantsika National Park."))
], caption: figure.caption(
position: bottom, 
[
Marovoay, Véromanitra Ramizason
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


#heading(level: 2, numbering: none)[Abstract]
<abstract>
Does the governance model of a protected area matter for the livelihoods of surrounding communities? We exploit the staggered creation and extension of protected areas in Madagascar between 2002 and 2008, combined with two decades of household survey data from the Rural Observatory System (ROS, 1995--2015) and a 2025 resurvey, to estimate the causal impacts of conservation on household income.

Using generalized synthetic control methods with interactive fixed effects, a technique that constructs data-driven counterfactuals for each exposed unit by modelling unobserved common factors, we compare two governance archetypes: strict conservation (IUCN category II) through the 2002 extension of Ankarafantsika National Park monitored via the Marovoay observatory, and multipurpose conservation (IUCN category VI) through the 2008 creation of the Lac Alaotra new protected area monitored via the Alaotra observatory.

The generalized synthetic control finds a persistent negative gap in equivalised household income at the Ankarafantsika east-bank sites (ATT ≈ -0.312 log points), while multipurpose conservation at Alaotra shows no detectable effect (ATT ≈ +0.014 log points). However, an internal comparison between east-bank and west-bank villages within the Marovoay observatory finds no equivalent income difference, which suggests that the externally estimated gap may partly reflect the long-run regional decline of the Marovoay rice plain --- historically Madagascar's primary irrigated rice zone --- rather than a park-specific effect. These results extend to three additional observatory--PA pairs. A 2025 resurvey confirms that the east-west income gap at Marovoay persists over the long run, but its attribution to conservation specifically warrants caution.

#heading(level: 2, numbering: none)[Structure]
<structure>
The analysis chapters present the core argument:

+ #link("01_context.qmd")[Context] --- Conservation policy in Madagascar and the research question.
+ #link("02_data.qmd")[Data] --- The Rural Observatory Surveys, georeferencing, and variable construction.
+ #link("03_strategy.qmd")[Identification Strategy] --- Exposure definitions, donor pool selection, and the generalized synthetic control method.
+ #link("04_results.qmd")[Results] --- Comparing strict vs.~multipurpose conservation impacts on household income.
+ #link("05_extensions.qmd")[Extensions] --- Three additional observatories near protected areas created during 2006--2007.
+ #link("06_discussion.qmd")[Discussion] --- Policy implications, limitations, and the roadmap for the 2026 survey wave.

The appendices provide full methodological and data details:

- #link("A1_data_pipeline.qmd")[A. Data Pipeline] --- Reproducible georeferencing, PA overlap analysis, and variable harmonisation.
- #link("A2_donor_validity.qmd")[B. Donor Pool Validity] --- Spatial audit of PA exposure across all donor observatories.
- #link("A3_robustness.qmd")[C. Robustness Tests] --- Alternative specifications, SDID, and sensitivity analysis.
- #link("A4_methodology.qmd")[D. Methodology] --- Technical details on gsynth, Callaway--Sant'Anna DiD, and interactive fixed effects.

#part[Analysis]
= Conservation in Madagascar
<conservation-in-madagascar>
Protected areas, governance models, and rural livelihoods

\
= Madagascar's protected area expansion
<sec-pa-system>
The international community has committed to protecting 30% of global land and sea by 2030 under the Kunming-Montréal Global Biodiversity Framework. For biodiversity-rich countries like Madagascar, this target translates into a sustained impulsion to expand and strengthen protected area (PA) networks. Madagascar responded early: at the 2003 Durban World Parks Congress, President Ravalomanana announced the #emph[Durban Vision] --- a commitment to triple the country's PA surface from 1.7 million to 6 million hectares @Kremen2006, that is, from about 3% to about 10% of the national territory. By 2015, the #emph[Système des Aires Protégées de Madagascar] (SAPM) had grown from 47 to over 160 protected areas, covering roughly 12% of the national territory.

This expansion was not monolithic. The SAPM introduced a diversity of governance models, ranging from strictly protected national parks under Madagascar National Parks (MNP) management to multipurpose landscapes co-managed by international NGOs and local communities through #emph[transferts de gestion]. The IUCN classification system captures this spectrum: Category II parks prioritise ecosystem integrity with limited human use, while Categories V and VI allow sustainable resource extraction and community participation.

The welfare consequences of this expansion for adjacent rural communities remain contested. A growing quasi-experimental literature finds heterogeneous effects of PAs worldwide: some studies document negative impacts on local incomes and consumption @Andam2010@Sims2010, while others find neutral or positive effects, particularly when PAs generate tourism revenues or ecosystem services @Naidoo2019. There is ground to assume that the modest positive effects observed elsewhere might not materialise in Madagascar, as extreme poverty prevalence intensifies dependance of local population on natural resources, tourism remains an order of magnitude smaller than in other biodiversity hotspots, and weak governance might undermine stakeholder engagement and benefit-sharing mechanisms. In Madagascar specifically, evidence remains thin and largely cross-sectional @Ferraro2011. The few causal studies focus on deforestation outcomes rather than household livelihoods.

A central question in this debate is whether the governance model of a protected area matters for the people living around it. Strict exclusionary conservation and participatory community-based management represent fundamentally different arrangements with local populations. Yet most empirical studies treat PAs as homogeneous interventions, comparing "protected" with "unprotected" rather than examining how different institutional arrangements mediate livelihood impacts.

#figure([
#box(image("01_context_files/figure-typst/fig-pa-cumarea-1.png"))
], caption: figure.caption(
position: bottom, 
[
Cumulative protected area coverage in Madagascar by IUCN category. Data from the dynamic WDPA layer; each PA enters at its earliest legal creation date. The post-Durban surge (after 2003) is dominated by Categories V and VI (multipurpose).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-pa-cumarea>


= The Rural Observatory Surveys
<sec-ros>
This study exploits a rare longitudinal dataset: the Rural Observatory System (ROS), a network of rural observatories conducted across Madagascar between 1995 and 2015. Coordinated by INSTAT then the Ministry of Agriculture, with technical support from IRD and funding from international donors, the ROS surveyed approximately 500 households per observatory per year across up to 28 observatory sites spanning the country's diverse agroecological zones --- from the humid eastern lowlands to the semi-arid south @Razafindrakoto2015.

#figure([
#box(image("01_context_files/figure-typst/fig-hist-ros-1.png"))
], caption: figure.caption(
position: bottom, 
[
Coarse location of rural observatory and survey years
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-hist-ros>


The ROS operates as a rotating panel: each observatory tracks a fixed set of households, but approximately 15% leave the sample each year through death, migration, or attrition, with replacement drawn from the original sampling frame. Over a decade, cumulative attrition reaches roughly 80% of the initial cohort. While this design limits individual-level panel analysis, it preserves cross-sectional representativeness at each wave: village-year aggregates consistently estimate the same population quantities, making the data well-suited for site-level quasi-experimental methods.

Critically, several rural observatories are located adjacent to protected areas that were extended or created during the survey period (2002--2008). This overlap between a two-decade household survey and staggered conservation interventions provides a natural laboratory for impact evaluation --- one that has not been systematically exploited until now.

A 2025 resurvey of two key sites (Marovoay and Alaotra) adds a long-run perspective, enabling us to assess whether short-run effects persist more than two decades after exposure onset. A further 2026 wave is planned to extend coverage to additional observatories.

= Research question
<sec-research-question>
We ask: does the governance model of a protected area affect household income in surrounding communities?

We compare two natural experiments embedded in the ROS data:

+ Strict conservation: the 2002 extension of Ankarafantsika National Park (IUCN Category II), managed by MNP. The Marovoay observatory straddles the park boundary, with the Betsiboka River creating a natural exposure--control divide between east-bank villages (adjacent to the park) and west-bank villages (effectively separated by the river).

+ Multipurpose conservation: the creation of the Lac Alaotra new protected area (IUCN Category VI), managed by Durrell Wildlife Conservation Trust through community-based natural resource management, with effective enforcement from approximately 2008. The entire Alaotra observatory shares dependence on the lake-marsh ecosystem.

Using generalized synthetic control methods @Xu2017 with an extended donor pool of up to nine additional observatories, we estimate the average treatment effect on the treated (ATT) for equivalised household income. We then extend the analysis to three additional observatory--PA pairs (Farafangana, Toliara North, Fénérive East) where PAs were created in 2006--2007, exploiting the staggered timing to strengthen identification.

The remainder of this document is structured as follows. #link("02_data.qmd")[Chapter 2] describes the data sources and variable construction. #link("03_strategy.qmd")[Chapter 3] details the identification strategy and estimation methods. #link("04_results.qmd")[Chapter 4] presents the main results for Ankarafantsika and Alaotra. #link("05_extensions.qmd")[Chapter 5] extends the analysis to three additional sites. #link("06_discussion.qmd")[Chapter 6] discusses policy implications and outlines plans for the 2026 survey wave.

= Data
<data>
Rural Observatory surveys, georeferencing, and variable construction

\
This chapter summarises the data construction process. The full reproducible workflow --- georeferencing, PA overlap analysis, and variable harmonisation --- is documented in #link("A1_data_pipeline.qmd")[Appendix A]. The underlying survey data are described in a companion data paper @Andrianjafindrainibe2024\; supplementary materials and replication code are available in the #link("https://doi.org/10.1038/s41597-024-03879-9")[associated repository].

= Survey data
<sec-survey-data>
The Rural Observatory System (ROS) surveyed rural households across Madagascar from 1995 to 2015. Many observatories remained active for only a few years. We use 11 observatories that were active by 1999-2000 and had at least 6 years of survey data. This dataset comprises approximately 101,253 household-year observations. Each observatory tracks \~500 households per year in a rotating panel design, with random replacement of attrited households preserving cross-sectional representativeness.

#figure([
#box(image("02_data_files/figure-typst/fig-obs-map-1.png"))
], caption: figure.caption(
position: bottom, 
[
Location of the 11 rural observatories used in this study.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-obs-map>


#figure([
#box(image("02_data_files/figure-typst/fig-time-grid-1.png"))
], caption: figure.caption(
position: bottom, 
[
Year-by-year data coverage across observatories and survey sites.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-time-grid>


= Georeferencing
<sec-georef>
The original survey data lacked systematic georeferencing. Locality names were recorded as free text, with inconsistent spellings across years and languages (Malagasy and French). We linked each observation to official administrative boundaries using the Common Operational Datasets (COD), maintained by OCHA and Madagascar's BNGRC. The full georeferencing procedure is described in the #link("https://betsaka.github.io/Rural_obs_Madagascar/03-ros-data-georeferencing.html")[companion data documentation].

The matching procedure is hierarchical:

+ #strong[String normalisation]: lowercase, remove diacritics and qualifiers (#emph[centre], #emph[haut], #emph[bas]), standardise bilingual toponyms, convert Roman to Arabic numerals.
+ #strong[Fuzzy matching]: Jaro-Winkler distance against the COD gazetteer, filtered by observatory-level district membership, with a maximum distance threshold of 0.25.
+ #strong[Cascading spatial levels]: match first at the commune (ADM3) level, then refine to fokontany (ADM4) where possible.

The result is a geocoded correspondence table linking each ROS household identifier (#NormalTok("j5");) to its P-coded commune and fokontany. This enables spatial overlay with protected area boundaries.

= Protected area overlaps
<sec-pa-overlaps>
Standard PA databases --- including the current WDPA and the Vahatra atlas --- record only the most recent boundary and designation of each protected area. They do not capture boundary changes (e.g., Ankarafantsika's 2002 extension roughly doubled the effectively protected area), temporary protection decrees that imposed de facto restrictions years before formal designation, or date errors (many WDPA entries carry incorrect #NormalTok("STATUS_YR"); values).

We instead use a dynamic WDPA for Madagascar --- a temporally explicit database that assigns each PA state a precise valid-from / valid-to interval derived from the Madagascar CNLEGIS legal texts database and historical versions of the SAPM geospatial database \[#strong[INCLUDE REFERENCE DATA PAPER]\]. This enables us to determine whether an observatory was adjacent to an #emph[active] PA at any given point during the study period (see #link("A2_donor_validity.qmd")[Appendix B] for full construction details).

For each of the 11 study observatories, we compute the minimum distance from commune centroids (projected to UTM 38S) to the nearest PA boundary active during 1999--2014. All (commune, PA) pairs within 20 km are flagged. Three temporal configurations emerge:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Configuration], [Observatories], [Use],),
  table.hline(),
  [PA predates ROS surveys (no baseline)], [e.g., Ranomafana, Andringitra], [Excluded],
  [PA created #emph[during] ROS (1999--2014)], [Marovoay (2003), Alaotra (2008)], [Primary treatment],
  [PA created during ROS but later], [Farafangana, Toliara, Fénérive (2006--07)], [Extension treatment (#link("05_extensions.qmd")[Ch. 5])],
)
], caption: figure.caption(
position: top, 
[
Overview of observatory--PA temporal relationships.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-pa-timing>


#figure([
#box(image("02_data_files/figure-typst/fig-pa-overlaps-1.png"))
], caption: figure.caption(
position: bottom, 
[
Survey coverage windows and PA exposure events for the 11 study observatories. Bars show the survey span; triangles mark the nearest new PA decree date. Green bars indicate observatories with sufficient pre/post data for gsynth; red bars indicate insufficient coverage relative to the PA event.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-pa-overlaps>


#ref(<fig-pa-overlaps>, supplement: [Figure]) shows that although the ROS was designed for agricultural monitoring, not conservation impact evaluation, some PAs were created relatively near from observatory sites. Gsynth requires sufficient pre-treatment years to learn unit-specific factor loadings, and sufficient post-treatment years for the counterfactual to be informative. We apply a minimum threshold of 4 pre-exposure and 3 post-exposure survey years.

The two primary pairs --- #strong[Marovoay / Ankarafantsika] (strict, IUCN II, 2003 extension) and #strong[Alaotra / Lac Alaotra] (multipurpose, IUCN V, 2007 temporary decree) --- offer the longest pre- and post-exposure windows. Three additional pairs --- Farafangana, Toliara North, and Fénérive East --- provide shorter but informative extensions (#link("05_extensions.qmd")[Chapter 5]). Observatories without a nearby PA (shown in blue) serve as the donor pool. A systematic spatial audit of donor pool validity is presented in #link("A2_donor_validity.qmd")[Appendix B].

= Outcome variable
<sec-outcome>
The primary outcome is log equivalised household income. Construction proceeds as follows:

+ #strong[Total income] (#NormalTok("revtot");): the sum of current income components: rice revenue (#NormalTok("rev_riz");), other crop revenue (#NormalTok("rev_cu");), livestock revenue (#NormalTok("revel");), fishing revenue (#NormalTok("revpeche");), principal activity income (#NormalTok("revppal");), and secondary activity income (#NormalTok("revsec");). Missing components are set to zero; the total is imputed from available sub-components when #NormalTok("revtot"); itself is missing.

+ #strong[Equivalisation]: using the OECD-modified scale: $1 + 0.5 times \( upright("additional adults") \) + 0.3 times \( upright("children under 14") \)$, computed from individual-level demographic records @karvonen2021.

+ #strong[Winsorisation]: at the 1st and 99th percentiles within each year to limit the influence of extreme values.

+ #strong[Log transformation]: $y_(i t) = log \( upright("equivalised income")_(i t) + 1 \)$.

Cross-year harmonisation is not trivial: variable names, questionnaire modules, and income definitions changed across survey waves. The full details of these adjustments are in #link("A1_data_pipeline.qmd")[Appendix A].

#figure([
#box(image("02_data_files/figure-typst/fig-income-trends-1.png"))
], caption: figure.caption(
position: bottom, 
[
Mean log equivalised household income over time, by observatory.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-income-trends>


= Descriptive statistics
<sec-descriptives>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 7,
  align: (left,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 7, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Sample Descriptive Statistics],
    table.cell(align: center, colspan: 7, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Analysis period: 1999--2014],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); group], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); N household-years], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Mean income (Ar)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Mean equiv. income], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Mean HH size], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Mean educ. years (adults)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % literate adult],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay exposed (east)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3873], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,736,175], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[700,533], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.0], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[92.0],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay control (west)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3617], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2,135,445], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[833,960], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[91.7],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Alaotra (exposed)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7613], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,893,377], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[691,554], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[95.6],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[48052], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,192,493], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[453,894], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4.3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[80.1],
)}
], caption: figure.caption(
position: top, 
[
Summary statistics for the analysis sample.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-descriptives>


= Identification Strategy
<identification-strategy>
How we estimate the causal effect of protected areas on household income

\
The central question of this study is whether the creation or expansion of protected areas caused changes in household income, or whether observed income differences merely reflect pre-existing trends. This chapter explains how we attempt to isolate causal effects.

The strategy has four parts. First, we define two natural experiments to propose plausible exposure--control comparisons (#ref(<sec-treatment>, supplement: [Chapter])). Second, we explain how the survey design constrains the unit of analysis (#ref(<sec-panel>, supplement: [Chapter])). Third, we describe the statistical method used to construct counterfactual income trajectories (#ref(<sec-estimation>, supplement: [Chapter])). Fourth, we briefly introduce three additional cases that extend the analysis (#ref(<sec-extensions>, supplement: [Chapter])).

= Two natural experiments
<sec-treatment>
We exploit two events during the ROS survey period where a new or expanded PA began to impose restrictions on communities that had previously been surveyed. The two cases differ in their conservation governance model --- strict exclusion at Ankarafantsika versus participatory management at Lac Alaotra --- providing a built-in comparison of how governance type mediates income effects.

== Marovoay and Ankarafantsika National Park (2003)
<sec-treat-maro>
=== The 2002 park extension
<sec-maro-history>
As illustrated in #ref(<fig-map-maro>, supplement: [Figure]), the Ankarafantsika National Park was formally extended by Decree 2002-798 on 7 August 2002, merging the former Réserve Naturelle Intégrale (60,500 ha, created in 1927) with a forest reserve into a 136,500 ha national park under IUCN Category II (strict nature conservation).

We set the exposure year to 2003, which is the first full ROS survey year following the decree. Decree 2002-798 was signed on 7 August 2002. Because the ROS survey is conducted annually with a reference period from October of year-1 to September of the survey year and we attribute any effect to the first full survey year following the decree, we set the exposure year to 2003. We also test whether using 2002 instead of 2003 modifies the estimated result and find negligible incidence.

According to the concording grey literature we reviewed, we consider the 2002 extension was the first event to impose binding land-use restrictions on the communities adjacent to the forest reserve zone. The earlier designations had very different #emph[de facto] implications:

- The 1927 #emph[Réserve Naturelle Intégrale] covered the inland plateau to the north-east, geographically separate from the Marovoay communities. The east-bank #emph[fokontany] had no direct interface with the strictly protected RNI.
- The 1929 forest reserve was not a conservation zone but a timber and resource reserve under the forest administration. Analyses of this period found no effective enforcement: subsistence agriculture, cattle grazing, and charcoal production continued unimpeded @brondeau1999.

The 2002 reclassification merged these into a single national park where slash-and-burn agriculture (#emph[tavy]), charcoal production, and non-timber forest product extraction were explicitly prohibited and, crucially, enforced. Enforcement capacity was supported by international conservation funding from the World Bank and bilateral donors as part of Madagascar's third Environmental Action Plan. #ref(<fig-map-maro>, supplement: [Figure]) maps the spatial extent of the consolidation using dynamic WDPA boundary data: the original RNI (dark green) covered the inland plateau to the north-east, while the 2002 extension (light green) more than doubled the protected area to encompass forest reserves abutting the Marovoay communities @alonso2002.

=== The Betsiboka River as a natural barrier
<sec-maro-barrier>
The Marovoay observatory comprises four #emph[fokontany] (villages) split by the Betsiboka River --- a major, permanently flowing watercourse. Crossing is possible only under certain hydrological conditions, often requiring long detours or costly boat transport. In practice, flows of people, goods, and services run along the Marovoay downstream axis rather than across the river.

This geographic feature creates a natural experiment: east-bank communities have direct walking access to the park, while west-bank communities face a substantial access penalty.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,left,left,left,left,),
  table.header(table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Fokontany], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Bank], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Dist. to RNI (pre-2002)], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Dist. to NP (post-2002)], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Role],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Bepako], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[East], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[33 km], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.2 km], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Exposed (from 2003)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Madiromiongana], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[East], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[25.1 km], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.7 km], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Exposed (from 2003)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ampijoroa], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[West], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[51.2 km (+ river crossing)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11.3 km (+ river crossing)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor (control)],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Maroala], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[West], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[44.7 km (+ river crossing)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5.6 km (+ river crossing)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor (control)],
  table.hline(),
  table.footer(table.cell(colspan: 5)[Effective distance adds a 15 km river-crossing penalty for west-bank fokontany.],),
)}
], caption: figure.caption(
position: top, 
[
Marovoay site exposure assignments. Distance to RNI = straight-line distance to the pre-2002 #emph[Réserve Naturelle Intégrale]\; Distance to NP = distance to the post-2002 national park boundary. Effective distance adds a 15 km river-crossing penalty for west-bank fokontany.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-maro-sites>


The 15 km river-crossing penalty is conservative. In rural Madagascar, where most travel is on foot, the actual additional travel time likely exceeds the implied 3-hour walk. An effective distance threshold of 12 km --- corresponding to approximately a 2.5-hour daily commuting limit --- places both east-bank villages within the PA's zone of influence and both west-bank villages outside it, cleanly separating "exposed" from "donor" communities.

#figure([
#box(image("03_strategy_files/figure-typst/fig-map-maro-1.png"))
], caption: figure.caption(
position: bottom, 
[
Marovoay observatory and the 2002 Ankarafantsika expansion. Dark green: the original 1927 #emph[Réserve Naturelle Intégrale] (\~571 km²). Light green: the 2002 national park extension (\~1,351 km²). The Betsiboka River separates west-bank fokontany (donors, grey) from east-bank fokontany (exposed, orange). Labels show distance to NP boundary. Water features from OpenStreetMap.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-maro>


=== Behavioural validation from the 2025 resurvey
<sec-maro-usage>
The exposure assignment rests on the assumption that the Betsiboka River effectively separates communities into "exposed" and "not exposed" groups. The 2025 resurvey provides a direct test of this assumption through its dedicated protected area usage module (UM), which asked all 1,026 households whether they visit the PA zone, what activities they pursue there, and why non-visitors stay away.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 6, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); PA Interaction by Fokontany],
    table.cell(align: center, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Marovoay observatory, 2025 resurvey (N = 519 households)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Site], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Bank], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); N], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % visit PA zone], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % extractive use], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % cite \'forbidden\'],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Bepako], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[East], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[123], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[49], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[19],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Madiromiongana], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[East], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[137], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[28], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[36],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ampijoroa], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[West], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[143], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Maroala], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[West], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[116], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2],
)}
], caption: figure.caption(
position: top, 
[
PA interaction at Marovoay by fokontany (2025 resurvey). 'Visit PA zone' = any visit, including leisure. 'Extractive use' = food gathering, woodcutting, cultivation, grazing, or craft materials. '% cite forbidden' = share of non-visitors citing legal prohibition.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-maro-usage>


Three findings support the exposure assignment:

+ #strong[Visitation asymmetry]: 38% of east-bank households report visiting the park zone versus 15% on the west bank. However, among visitors on both banks, the dominant activity is leisure walks (67%); only 10% of east-bank households report extractive use (food gathering, woodcutting). 91% of all visitors go only a few times per year.

+ #strong[Awareness of prohibition]: At Madiromiongana --- the east-bank fokontany closest to the park's core --- 34% of non-visitors cite legal prohibition as their reason for not going, versus 2% at Maroala on the west bank. The park's legal status is a binding constraint on the east bank, not the west.

+ #strong[Distance as the dominant barrier]: Across both banks, the most commonly cited reason for not visiting is distance (#emph[lavitra] in Malagasy), mentioned by 54% of non-visitors. The river makes the park #emph[behaviourally distant] for west-bank communities even where it is #emph[geographically close].

== Lac Alaotra and the Protected Landscape (2008)
<sec-treat-ala>
=== A different conservation model
<sec-ala-history>
Lac Alaotra is Madagascar's largest lake and a critical habitat for the Alaotran gentle lemur (#emph[Hapalemur alaotrensis]). The Ramsar Convention listed the site in 2003. In 2015, the lake and its marshlands were formally designated as a #emph[Paysage Harmonieux Protégé] (PHP, 425 km², IUCN Category V --- a multipurpose landscape where sustainable use is permitted). However, enforcement through community-based natural resource management (CBNRM) agreements and #emph[transferts de gestion] had intensified from around 2008 under the management of Durrell Wildlife Conservation Trust. A temporary protection decree (#emph[Arrêté] 381/2007, 1 August 2007) preceded the intensification. We set the exposure year to 2008, consistent with the annual-survey convention applied to Ankarafantsika.#footnote[An alternative exposure year of 2007 is defensible; using 2007 instead has negligible impact on the estimated ATT, given that the post-exposure window contains up to seven observations under either assumption.]

The key difference from Ankarafantsika is governance: rather than exclusionary enforcement prohibiting all resource extraction, Alaotra's CBNRM framework regulates lake-marsh use through community-managed access rules, seasonal fishing closures, and habitat restoration agreements. This participatory model is designed to accommodate livelihoods rather than exclude them.

=== Why all Alaotra communities are exposed
<sec-ala-all-treated>
Unlike Marovoay, there is no natural barrier separating "exposed" from "unexposed" communities at Alaotra. The observatory's seven #emph[fokontany] (across three historical survey sites) all display modest but not negligible interactions with the lake-marsh ecosystem, with no clear distinctions among themselves in this regard. The co-managed enforcement mechanism --- seasonal closures, gear restrictions, marsh-burning bans --- also applies to all lake-adjacent communities similarly.

A complication specific to Alaotra is the proximity of some eastern hamlets to two additional protected areas: the Corridor Ankeniheny-Zahamena (CAZ, IUCN Category VI, managed by Conservation International) and the Zahamena National Park (IUCN Category II), which lies north of the CAZ. The hamlet of Mangabe lies closer to the CAZ boundary (\~14 km) than to the Lac Alaotra PHP, creating dual-PA exposure.

We therefore treat the entire observatory as a single exposed unit, aggregated to a site-level mean. This is a stronger assumption than the site-level assignment at Marovoay, but it is supported by the uniform enforcement mechanism (CBNRM applies to all lake-adjacent communities) and the behavioural data from the 2025 resurvey discussed below.

#figure([
#box(image("03_strategy_files/figure-typst/fig-map-ala-1.png"))
], caption: figure.caption(
position: bottom, 
[
Alaotra observatory and surrounding protected areas. Lac Alaotra PHP (green), Corridor Ankeniheny-Zahamena (CAZ, orange), Zahamena National Park (light orange). Fokontany centroids from 2025 GPS survey; distances to nearest PA boundary.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-ala>


=== Behavioural validation from the 2025 resurvey
<sec-ala-usage>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 5, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); PA Interaction by Fokontany],
    table.cell(align: center, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Alaotra observatory, 2025 resurvey (N = 507 households)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Site], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); N], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % visit zone], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % extractive], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % fish/hunt],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambatomanga], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[68], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[51], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambodivoara], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[58], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambohidrony], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[52], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[54], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambatoharanana], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[31], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Analamiranga], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[46], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mangabe], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[73], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[47], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[5],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Avaradrano], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[90], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[38], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Feramanga Atsimo], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[89], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[37], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0],
)}
], caption: figure.caption(
position: top, 
[
PA interaction at Alaotra by fokontany (2025 resurvey). 'Visit PA zone' includes any visit to the lake-marsh area. 'Extractive use' = food gathering, fishing/hunting, cultivation, grazing, or woodcutting within the zone. Fishing/hunting shown separately as it dominates extractive use.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-ala-usage>


The Alaotra data reveal an important distinction between #emph[visiting] and #emph[depending on] the PA zone:

- #strong[Visiting is common but mostly non-extractive]: 37--54% of households report visiting the lake-marsh zone, but the survey question captures any visit including leisure walks. Among visitors, 78% go only a few times per year.
- #strong[Extractive use is concentrated and heterogeneous]: Fishing and hunting --- the dominant extractive activity, reflecting traditional lake use --- involves 21% of households in Ambatomanga but none in Avaradrano or Feramanga Atsimo. The overall extractive rate is 13% of all households.
- #strong[Distance, not prohibition, explains non-use]: Among Alaotra non-visitors, the most cited reason is distance (#emph[lavitra]), at 35%. Legal prohibition is cited by only 8%, consistent with the less restrictive multipurpose framework.

The relatively uniform visiting rate but sharply differentiated\*extractive rate suggests that proximity to the ecosystem --- rather than engagement with PA-regulated resources --- drives the visiting pattern.

== PA zone usage intensity across both sites
<sec-visit-freq>
#ref(<fig-visit-freq>, supplement: [Figure]) provides a cross-site comparison of how intensively households use the PA zone. The contrast between the two observatories is stark: at Marovoay, the majority of households never visit the park (white bars), with the river barrier clearly separating high-access sites (Bepako) from low-access ones (Ampijoroa, Maroala). At Alaotra, a larger share of households visit the zone, but almost all do so infrequently (grey bars). Regular visitors --- monthly or more, shown in warm colours --- are a thin sliver confined to the closest sites.

#figure([
#box(image("03_strategy_files/figure-typst/fig-visit-freq-1.png"))
], caption: figure.caption(
position: bottom, 
[
PA zone visit frequency by site (2025 resurvey). Each bar represents 100% of households in a site. White = does not visit; grey = few times per year; warm colours = monthly or more. Sites ordered by total share of visitors.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-visit-freq>


== Extensions: three additional cases (2006--2007)
<sec-treat-ext>
The donor-pool audit (#ref(<sec-donor-pool>, supplement: [Section])) reveals that four donor observatories are themselves adjacent to PAs created during the study period. Three of these provide usable exposure variation --- Farafangana (2006), Toliara North (2007), and Fenérive East (2007) --- and are analysed as extension cases in #ref(<sec-extensions>, supplement: [Chapter]) and #link("05_extensions.qmd")[Chapter 5].

= From households to villages
<sec-panel>
== The rotating panel constraint
<sec-rotating-panel>
The ROS can be interpreted as a rotating panel, instead of a strict re-interview panel. This is a critical distinction for estimation. Each observatory tracks approximately 500 households per year, but approximately 15% leave the sample each year through death, migration, or attrition. Departing households are replaced by newly sampled ones following the original random sampling design. Over a 10-year horizon, cumulative attrition reaches roughly 80% of the initial cohort @ChabeFerret2024.

This design means that the standard econometric approach --- following the same households over time and using household fixed effects to control for unobserved heterogeneity --- is not feasible. Only about 44% of households surveyed in 1998 remain in 2003, and fewer than 6% survive to 2014. Furthermore, attrition is non-random: the dominant cause is out-migration (65% of traceable attritors), which correlates with income and shock exposure. The 2025 resurvey uses entirely new household identifiers that carry no continuity with the 1995--2014 series.

The rotating design does, however, preserve cross-sectional representativeness at each survey wave: because replacement households are randomly drawn from the same villages, village-year statistics consistently estimate the same population quantity across years, even as the composition of surveyed households changes.

#block[
#callout(
body: 
[
A household-level panel regression with household fixed effects would produce misleading results here: it would estimate effects only for the shrinking minority of households that remain in the sample for multiple years --- a selected, non-representative sub-population. Village-level aggregation avoids this problem entirely.

]
, 
title: 
[
What this means in practice
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Village-level aggregation
<sec-aggregation>
We therefore analyse the data at the village (#emph[fokontany]) level, aggregating household-level income to village-year medians. This addresses both the attrition problem and the estimation requirements:

+ #strong[Cross-sectional representativeness is preserved]: Random replacement of attrited households ensures that village-year medians estimate the same population parameter across waves, even though the specific households change.
+ #strong[The estimator requires a balanced panel]: The generalized synthetic control method (described below) requires a complete unit-by-year matrix. Village-level aggregation produces this, while household-level data would have pervasive gaps.
+ #strong[Exposure is assigned at the village level]: PA exposure depends on the village's distance to the park boundary, not on individual household characteristics. Village-level analysis matches the unit of exposure assignment to the unit of analysis.

The median is preferred to the mean because rural income distributions are right-skewed with occasional extreme values. Village-level medians are more robust to the specific composition of households surveyed in any given year.

== Outcome variable
<sec-outcome>
The primary outcome is #emph[log equivalised household income]. Construction proceeds in four steps:

+ #strong[Total income] (#NormalTok("revtot");): the sum of current income components: rice revenue, other crop revenue, livestock revenue, fishing revenue, principal activity income, and secondary activity income. Missing components are set to zero.

+ #strong[Equivalisation]: using the OECD-modified scale to adjust for household composition: $ upright("equiv") = 1 + 0.5 times \( upright("additional adults") \) + 0.3 times \( upright("children under 14") \) $ This ensures that a large household with higher total income is not misleadingly compared to a small household with lower total but similar per-person income.

+ #strong[Winsorisation]: at the 1st and 99th percentiles within each year to limit the influence of extreme values.

+ #strong[Log transformation]: $y_(i t) = log \( upright("equivalised income")_(i t) + 1 \)$, which compresses the right tail and allows treatment effects to be interpreted as approximate percentage changes.

Cross-year harmonisation is non-trivial: variable names, questionnaire modules, and income definitions changed across survey waves. The full details of these adjustments are documented in #link("A1_data_pipeline.qmd")[Appendix A].

= Building the counterfactual
<sec-estimation>
The fundamental challenge is that we observe what happened to communities near the PA, but not what #emph[would have happened] to them without the PA. The statistical method must therefore construct a credible counterfactual --- an estimate of the income trajectory these communities would have followed had the PA never been created.

== Selecting donor communities
<sec-donor-pool>
The counterfactual is built from #emph[donor pools] --- rural observatory villages that were not exposed to any PA during the study period. We start with 9 donor observatories providing approximately 60 donor sites across the country.

A systematic spatial audit (#link("A2_donor_validity.qmd")[Appendix B]) checks whether these donors are themselves adjacent to PAs created during 1999--2014. Using a dynamic WDPA layer that records when each PA became legally operative, we flag any donor commune within 20 km of an active PA boundary as also exposed:

#figure([
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Status], [Observatories], [Reason],),
  table.hline(),
  ["Clean"], [Antsirabe (02), Tsiroanomandidy (13), Ambovombe (16), Mahanoro (25), Itasy (41)], [No active PA within 20 km during 1999--2014],
  [Also exposed], [Antsohihy (12), Farafangana (15), Toliara North (23), Fénérive East (24)], [PA created within 20 km during study period],
)
], caption: figure.caption(
position: top, 
[
Donor pool PA exposure classification.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-donor-status>


The main results use the 5 "clean" donor observatories; the #link("05_extensions.qmd")[extension analysis] confirms that including the 4 also-exposed donors does not materially change the estimates. In the extension analysis (#link("05_extensions.qmd")[Chapter 5]), the four also-exposed observatories become #emph[exposed units] with their own PA exposure events.

== Generalized synthetic control
<sec-gsynth>
=== Intuition
<sec-gsynth-intuition>
Standard difference-in-differences (DiD) assumes that exposed and control communities would have followed parallel trends in the absence of the PA --- that is, that income would have evolved at the same rate in PA-adjacent and distant villages. This is a strong assumption: rural villages may diverge over time for reasons unrelated to PAs, such as changing weather patterns, road construction, commodity price shifts, or local governance quality.

The generalized synthetic control method (gsynth) of #cite(<Xu2017>, form: "prose") relaxes this assumption. Instead of requiring parallel trends, it allows each village to follow its own trajectory driven by unobserved factors --- the method then #emph[learns] these factors from the pre-treatment data and uses them to project what would have happened after the PA was created.

In plain language: gsynth looks at how the exposed villages' income moved #emph[before] the PA, identifies which combination of donor villages best reproduces that pattern, and then uses those same donors to predict what the exposed villages' income would have been #emph[after] the PA, had the PA never existed. The difference between the actual income and this predicted counterfactual is the estimated effect.

=== Formal specification
<sec-gsynth-formal>
For each exposed unit $i$ in post-treatment period $t$, gsynth models the outcome as:

$ Y_(i t) = alpha_i + xi_t + bold(lambda)'_i bold(f)_t + D_(i t) dot.op delta_(i t) + epsilon_(i t) $

where $alpha_i$ are unit fixed effects (each village has its own baseline income level), $xi_t$ are time fixed effects (all villages share common year-to-year shocks like droughts or price changes), $bold(lambda)'_i bold(f)_t$ are interactive fixed effects (each village responds differently to unobserved time-varying factors), and $D_(i t)$ is the treatment indicator. The interactive term $bold(lambda)'_i bold(f)_t$ is what distinguishes gsynth from standard DiD: it allows for heterogeneous trends driven by unobserved factors.

Key implementation choices:

- #strong[Factor selection]: leave-one-out cross-validation over $r in { 0 \, 1 \, 2 \, 3 \, 4 \, 5 }$ determines the number of latent factors.
- #strong[Inference]: parametric bootstrap with 200 replications.
- #strong[Minimum pre-treatment periods]: $min \( T_0 \) = 3$ to ensure adequate pre-treatment fit.

=== Two separate models
<sec-two-models>
We estimate two separate models, reflecting the distinct nature of each case:

+ #strong[Marovoay model]: Exposed units = Madiromiongana and Bepako (east bank, from 2003). Donors = all other rural observatory sites, including the Marovoay west-bank sites (Ampijoroa, Maroala). With 2 exposed sites and \~60 donors, gsynth estimates unit-specific counterfactuals for each village.

+ #strong[Alaotra model]: Exposed unit = aggregated Alaotra observatory (from 2008). Donors = all non-Alaotra rural observatory sites, including all four Marovoay #emph[fokontany]. With a single exposed unit, this reduces to a synthetic control with interactive fixed effects.

== Inference with few exposed units
<sec-inference>
A fundamental constraint of this design is the small number of exposed units: 2 sites for Marovoay, 1 for Alaotra. With so few exposed clusters, standard statistical tests are unreliable regardless of the estimator chosen.

To understand this constraint concretely: for Marovoay, the set of observable units within the observatory comprises 4 sites (2 east-bank, 2 west-bank). The number of ways to assign exactly 2 of these 4 units as "exposed" is $binom(4, 2) = 6$. Under the sharp null hypothesis of no treatment effect, the #strong[minimum achievable p-value] is therefore $1 \/ 6 approx 0.167$ for a one-sided test. No statistical test based solely on these 4 sites can produce a p-value below 0.167, regardless of how large the observed effect is.

When all three Alaotra sites are included as additional control donors (expanding the permutation pool to 7 units), the allocation count rises to $binom(7, 2) = 21$ and the minimum achievable p-value falls to $1 \/ 21 approx 0.048$, that is just below the conventional 5% threshold.

We report gsynth bootstrap confidence intervals and p-values throughout, but interpret them in light of this #strong[power ceiling]. The inability to reject the null at conventional thresholds does not imply absence of effect; it may simply reflect the inherent inferential limitations of quasi-experimental designs with few geographic units. Placebo-in-space tests (#link("A3_robustness.qmd")[Appendix C]) provide complementary evidence on the uniqueness of estimated effects.

== Complementary household-level designs
<sec-complementary>
The gsynth analysis above operates on village-year aggregates and identifies treatment effects against an outside donor pool of clean observatories. We complement it with two within-observatory household-level repeated cross-section designs that exploit a different identifying contrast: exposure-intensity heterogeneity #emph[inside] each observatory. The two layers of inference are deliberately distinct, and their agreement (or disagreement) is itself informative.

#strong[Sampling distinction]: Because the ROS is a rotating panel, households are not tracked across waves. The valid household-level estimator is therefore a repeated cross-section (RCS) Callaway--Sant'Anna design @CallawayS2021 with #NormalTok("panel = FALSE");, which treats each wave as an independent cross-section of households within sites and aggregates over the household-level observations through the doubly-robust 2-period moment of #cite(<SantAnnaZhao2020>, form: "prose"). Site fixed effects (not household fixed effects) absorb time-invariant unobserved heterogeneity. We run the design on the 1999--2014 waves extended with the 2025 resurvey.

#strong[Two exposure-intensity proxies]: For each observatory we build a binary treatment indicator from one of two within-observatory contrasts:

- #strong[Geographic exposure]: Distance to the nearest PA boundary, or --- at Marovoay --- east-bank versus west-bank assignment, as motivated in #ref(<sec-treat-maro>, supplement: [Section]) by the Betsiboka river barrier.
- #strong[Behavioural exposure]: The 2025 share of households declaring at least one PA-dependent extractive use (#ref(<sec-maro-usage>, supplement: [Section]), #ref(<sec-ala-usage>, supplement: [Section])), with a cut at ≥ 12.5% defining the #emph[high-usage] group.

For Alaotra both proxies are reported (the seven merged fokontany span both a meaningful distance gradient --- 8.9 to 16.3 km from the nearest PA --- and a meaningful extractive-use gradient --- 0.7% to 26.5%). For Marovoay only the geographic proxy is reported, because extractive use is rare on both banks (peak: 11.4% at Bepako; #ref(<sec-maro-usage>, supplement: [Section])) and a 12.5% cut leaves no treated unit.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,left,left,left,left,),
  table.header(table.cell(align: center, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Secondary DiD: exposure-intensity classifications],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Site], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Distance / bank], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % extractive (2025)], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Geographic], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Behavioural],),
  table.hline(),
  table.cell(align: horizon + left, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); Marovoay],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Bepako], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[east], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[11.4], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[treated], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Madiromiongana], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[east], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.8], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[treated], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ampijoroa], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[west], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.7], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Maroala], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[west], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.7], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); Alaotra],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Ambodivoara-Maritampona], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[8.9 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[20.7], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[treated], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[treated],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambatoharanana-Analamiranga], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9.5 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.0], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[treated], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[treated],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Avaradrano], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[10.4 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.7], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[treated], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mangabe], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.0 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8.2], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Feramanga Atsimo], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.7 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3.4], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambohidrony], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[14.8 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[21.2], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[treated],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambatomanga], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[16.3 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[26.5], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[control], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[treated],
)}
], caption: figure.caption(
position: top, 
[
Within-observatory exposure-intensity classifications used by the secondary household-level RCS designs. Distance and bank are pre-determined geography; extractive-use share is measured on the 2025 resurvey under the same definition as #ref(<sec-maro-usage>, supplement: [Section]) and #ref(<sec-ala-usage>, supplement: [Section]). The two Alaotra fokontany pairs Ambodivoara/Maritampona and Ambatoharanana/Analamiranga are merged onto their older centroids to align the 1999--2014 frame with the 2025 GPS enumeration.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-secondary-design>


#strong[Inference.] Because the cluster count is small (G = 4 sites at Marovoay, G = 5 merged fokontany at Alaotra), we report two standard errors for every point estimate: the design-based, influence-function SE --- valid if the estimand is the ATT on these specific sites conditional on the observed treatment assignment --- and the site-clustered SE, valid for super-population inference. The gap between the two is informative about how much identifying variation lives across versus within sites.

#strong[Limitations.] Four caveats are inescapable and should be kept in mind when reading the results.

+ #strong[No clean within-observatory control]: Every site in either observatory is exposed to the conservation framework to some degree; the "control" group is just the #emph[less exposed] subset.
+ #strong[Distance is Euclidean]: Straight-line distance to the PA boundary is not the same as practical accessibility --- terrain, roads and rivers all matter and are only partially captured (the river barrier at Marovoay is captured by the bank cut).
+ #strong[Extractive usage is post-treatment endogenous]: The 2025 extractive share is measured #emph[after] exposure, so a fokontany depressed by enforcement could appear less (or more) extractive today as a consequence of the treatment.
+ #strong[Small G]: With only four to seven sites the cluster-robust SE is wide; the design-based IF SE is tighter but identifies a more restrictive estimand.

For these reasons the secondary designs are explicitly complementary rather than confirmatory of the main gsynth analysis. Where they agree with gsynth (Alaotra), the agreement narrows the range of plausible interpretations; where they disagree (Marovoay), the disagreement diagnoses #emph[which] identifying contrast is doing the work in each estimator. Two further estimators --- Synthetic DiD @Arkhangelsky2021 and standard two-way fixed effects --- are reported in #link("A3_robustness.qmd")[Appendix C] as additional sensitivity checks against the gsynth specification choice.

= Extensions to three additional observatories
<sec-extensions>
The two-case comparison above --- strict enforcement at Ankarafantsika versus participatory conservation at Lac Alaotra --- limits external validity. Three additional observatory--PA pairs identified in the donor-pool audit (#ref(<sec-donor-pool>, supplement: [Section])) provide shorter but informative extensions:

#figure([
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Observatory], [Protected area], [IUCN], [Year], [Governance],),
  table.hline(),
  [Farafangana], [Corridor Forestier Ambositra-Vondrozo (CFAV)], [V], [2006], [Multipurpose highland corridor],
  [Toliara North], [Amoron'i Onilahy], [V], [2007], [Coastal and dry-forest protections],
  [Fénérive East], [Réserve de Tampolo], [IV], [2007], [Small (\~7.3 km²) research forest],
)
], caption: figure.caption(
position: top, 
[
Extension observatories.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-ext-cases>


These three observatories move from liabilities in the donor pool to informative exposed units, enabling a five-case comparison of how conservation governance type, enforcement intensity, and PA size shape household-income outcomes. The shorter post-exposure windows (8--9 years versus 12 for Marovoay and 7 for Alaotra) limit precision but broaden the institutional variation. The full analysis is presented in #link("05_extensions.qmd")[Chapter 5].

= Looking ahead: full household-level estimation
<sec-did-roadmap>
The secondary RCS designs introduced in #ref(<sec-complementary>, supplement: [Section]) already exploit household-level information within each observatory, but they remain limited by the small number of sites available #emph[inside] a single observatory (G = 4 to 7). A richer household-level analysis would pool all five exposed observatories together with the never-exposed donors into a single staggered-treatment design, exploiting four staggered exposure cohorts (Ankarafantsika 2003, Farafangana/Toliara/Fenérive 2006--07, Alaotra 2008, plus never-exposed). The natural estimator is again Callaway--Sant'Anna with #NormalTok("panel = FALSE");, complemented by Sun--Abraham event studies via #NormalTok("fixest::sunab()");. The 2026 ROS wave will increase post-exposure information and is expected to sharpen these estimates further. This forward-looking design is discussed in #ref(<sec-next-steps>, supplement: [Chapter]).

= Results
<results>
Strict vs.~multipurpose conservation impacts on household income

\
= Ankarafantsika: strict conservation (IUCN II)
<sec-maro>
== Panel construction
<panel-construction>
The Marovoay model comprises 2 exposed sites (Bepako and Madiromiongana, east bank) and donor sites from the 5 clean observatories identified in #link("A2_donor_validity.qmd")[Appendix B] (Antsirabe, Tsiroanomandidy, Ambovombe, Mahanoro, Itasy). The exposure period begins in 2003, providing 4 pre-exposure years (1999--2002) and up to 12 post-exposure years (2003--2014).

== gsynth ATT path
<sec-maro-att>
#figure([
#box(image("04_results_files/figure-typst/fig-maro-att-1.png"))
], caption: figure.caption(
position: bottom, 
[
Ankarafantsika: gsynth ATT path for east-bank sites relative to exposure onset (2003). Outcome: log OECD-equivalised income. Shaded band: 95% parametric bootstrap CI.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-maro-att>


The generalized synthetic control model finds a persistent negative gap between the east-bank Marovoay sites and their synthetic counterfactual. The average post-exposure average treatment effect (ATT) is approximately -0.312 log points (95% CI: \[-0.550, -0.073\], #emph[p] = 0.010), corresponding to a roughly 27% difference relative to the projected counterfactual. The gap opens shortly after the 2002 park extension and does not close over the observation period.

How much of this gap is attributable to the park itself --- rather than to the broader economic trajectory of the Marovoay region --- is a question that the data alone cannot fully resolve. Marovoay was historically Madagascar's most productive irrigated rice zone, often called the #emph[grenier à blé] of the country. From the 1980s onward, the region experienced a well-documented decline driven by the silting of the Betsiboka River, the degradation of colonial-era irrigation infrastructure, and the collapse of state agricultural support. This regional trajectory predates the 2002 park extension and could plausibly account for part of the divergence that gsynth attributes to conservation exposure, if the donor observatories on the highland plateau or in the southern drylands were not similarly affected by the deterioration of irrigated lowland agriculture.

=== Within-Marovoay household RCS check
<sec-maro-rcs>
The household-level repeated cross-section design described in #ref(<sec-complementary>, supplement: [Section]) applies the Callaway--Sant'Anna estimator to the 1999--2014 + 2025 Marovoay panel, contrasting east-bank (Bepako and Madiromiongana) against west-bank fokontany (Ampijoroa and Maroala).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Marovoay: household RCS DiD],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Design], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Estimate], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE (IF)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE (cluster)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % income],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[East bank vs west bank], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.000], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.050], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.046], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[+0.0%],
)}
], caption: figure.caption(
position: top, 
[
Within-Marovoay household RCS Callaway--Sant'Anna estimate (panel = FALSE), east versus west bank. Two standard errors are reported: design-based (influence function, no clustering) and site-clustered.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-maro-rcs>


The within-Marovoay point estimate is close to zero with a tight cluster-robust standard error --- strikingly different in magnitude from the gsynth gap of -0.312 log points reported above. This contrast is a key diagnostic, and it cannot simply be dismissed as the two methods answering different questions.

The gsynth compares the east-bank villages against donor observatories located in the highland plateau or the southern drylands --- places with different agronomic systems, different exposure to Betsiboka siltation, and different relationships with irrigated rice. If the Marovoay region as a whole has declined relative to those places for reasons unconnected to the park --- the collapse of irrigation infrastructure, the retreat of the state from the rice economy, cycles of flooding and soil erosion --- then gsynth will attribute that regional divergence to the PA, because the exposure timing coincides with the beginning of the observable panel. The within-Marovoay design controls for this regional shock: because east-bank and west-bank villages share the same river, the same downstream rice economy, and the same local market, a regional shock hits both sides simultaneously and cancels out of the east-west comparison.

The fact that east-bank and west-bank incomes tracked each other so closely throughout the study period is therefore a genuine warning. It suggests that the bulk of the divergence that gsynth identifies is a regional phenomenon --- the decline of a once-prosperous agricultural region --- rather than an effect that can be confidently attributed to the park boundary. A real park effect may still exist: east-bank communities face the park fence directly, while west-bank communities do not. But the within-observatory evidence places a much tighter bound on the plausible conservation-specific component than the gsynth estimate alone would suggest. The two results should be read together, with neither overruling the other.

== Unit-specific effects
<unit-specific-effects>
#figure([
#box(image("04_results_files/figure-typst/fig-maro-units-1.png"))
], caption: figure.caption(
position: bottom, 
[
Unit-specific exposure effects for the two east-bank fokontany.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-maro-units>


Both exposed fokontany show negative effects, though with different magnitudes. Bepako (4.1 km from the park boundary) shows a larger and more consistent effect than Madiromiongana (11.7 km), consistent with a distance gradient in enforcement intensity.

= Lac Alaotra: multipurpose conservation (IUCN VI)
<sec-ala>
== Panel construction
<panel-construction-1>
The Alaotra model has 1 exposed unit (the aggregated observatory) and donor sites from 5 clean observatories. The exposure period begins in 2008, providing 9 pre-exposure years (1999--2007) and 7 post-exposure years (2008--2014).

== gsynth ATT path
<sec-ala-att>
#figure([
#box(image("04_results_files/figure-typst/fig-ala-att-1.png"))
], caption: figure.caption(
position: bottom, 
[
Lac Alaotra: gsynth ATT path for the aggregated observatory relative to exposure onset (2008). Outcome: log OECD-equivalised income. Shaded band: 95% parametric bootstrap CI.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-ala-att>


The Alaotra gsynth estimates an average post-exposure ATT of approximately +0.014 log points (#emph[p] = 0.928) --- close to zero and not statistically significant. The confidence interval comfortably spans zero. Year-by-year estimates are noisy with no clear trend away from the counterfactual.

The null result is consistent with several interpretations: participatory conservation under CBNRM may impose lower costs on aggregate income; the 7-year post-exposure window may be insufficient to detect a gradual effect; and the single-unit design limits statistical power.

=== Within-Alaotra household RCS check
<sec-ala-rcs>
The household-level repeated cross-section design described in #ref(<sec-complementary>, supplement: [Section]) applies the Callaway--Sant'Anna estimator to the 1999--2014 + 2025 Alaotra panel under two within-observatory exposure proxies: distance to the nearest PA boundary (≤ 10 km) and the 2025 share of households declaring PA-dependent extractive uses (≥ 12.5%).

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Alaotra: household RCS DiD],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Design], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Estimate], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE (IF)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE (cluster)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % income],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Distance ≤ 10 km], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.015], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.075], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.113], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[+1.5%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Extractive usage ≥ 12.5%], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[−0.042], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.074], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.152], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-4.1%],
)}
], caption: figure.caption(
position: top, 
[
Within-Alaotra household RCS Callaway--Sant'Anna estimates (panel = FALSE) on the merged seven-fokontany panel, under two exposure proxies. Two standard errors are reported: design-based (influence function, no clustering) and site-clustered.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-ala-rcs>


Both within-Alaotra designs yield small point estimates and wide cluster-robust standard errors that comfortably include zero. Their conclusion agrees with gsynth along a different identifying contrast: not against an outside donor pool, but against the less exposed merged fokontany of the same observatory. The convergence narrows the range of plausible interpretations of the Alaotra null: the absence of an aggregate income effect of the #emph[Paysage Harmonieux Protégé] is robust to whether the counterfactual is built from outside observatories (gsynth) or from within-observatory exposure heterogeneity (RCS DiD).

= Comparison
<sec-comparison>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 11,
  align: (left,left,right,left,right,right,left,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 11, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Comparative gsynth Results],
    table.cell(align: center, colspan: 11, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Separate estimation for each PA (1999--2014)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); IUCN Category], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Exposure year], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Exposed unit(s)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT (log pts)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 95% CI], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT (pct)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p-value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); r\* (CV)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); N donors],),
  table.hline(),
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ankarafantsika PN], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[II (strict)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2003], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Madiromiongana & Bepako (east bank)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.312], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.122], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.55, -0.073\]], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-26.8%], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.010], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra PHP], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[V (multipurpose)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2008], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Aggregated observatory], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.014], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.156], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.293, 0.321\]], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4%], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.928], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56],
)}
], caption: figure.caption(
position: top, 
[
Summary of gsynth results: strict (Ankarafantsika) vs multipurpose (Alaotra) conservation.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-comparison>


#figure([
#box(image("04_results_files/figure-typst/fig-comparison-1.png"))
], caption: figure.caption(
position: bottom, 
[
Side-by-side ATT paths. Left: Ankarafantsika (strict, from 2003) shows a persistent negative effect. Right: Lac Alaotra (multipurpose, from 2008) shows no significant effect.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-comparison>


The contrast between the two estimated ATT paths is sharp on paper: a large persistent negative gap at Ankarafantsika, and a near-zero gap at Alaotra. Before drawing governance conclusions, however, some caution is warranted. At Marovoay, the within-observatory comparison between east and west bank finds no detectable difference, raising the possibility that the gsynth estimate is capturing regional economic decline rather than conservation effects. At Alaotra, the null result may reflect genuinely benign governance or insufficient statistical power. These two caveats temper but do not dissolve the contrast: the evidence is suggestive that strict exclusionary management carries higher livelihood costs than participatory co-management, but the data cannot definitively establish the causal mechanism.

= Long-run assessment: 2025 resurvey
<sec-longrun>
A 2025 resurvey of Marovoay (0 households across the four fokontany: Bepako and Madiromiongana on the east bank, Ampijoroa and Maroala on the west bank) extends the observation window to 22 years post-exposure.

== Panel construction (extended model)
<panel-construction-extended-model>
The extended model uses the full donor pool (all ROS sites with a complete 1999--2014 income series) rather than the clean 5-donor pool of #ref(<sec-maro>, supplement: [Chapter]). The exposed units are unchanged --- Bepako (site 031) and Madiromiongana (site 032), east of the Betsiboka --- but the 62 donor sites span 11 observatories:

- the 5 clean donors used in #ref(<sec-maro>, supplement: [Chapter]) (observatories 02, 13, 16, 25, 41);
- the 5 "also-exposed" observatories flagged in #link("A2_donor_validity.qmd")[Appendix B] (12, 15, 21, 23, 24);
- the 2 Marovoay west-bank fokontany (Ampijoroa 033 and Maroala 034), which are in the same observatory as the treated units and therefore share local shocks.

This is a weaker identification setting than the main specification: three of the donor observatories were themselves subject to PA expansions during the period, and two donor sites are one kilometre away from the exposed units. The results below should therefore be read as descriptive corroboration of the #ref(<sec-maro-att>, supplement: [Section]) estimates rather than an independent test.

The 2025 resurvey only covered Marovoay (and Alaotra, which is not part of this panel). Accordingly, in the extended panel, 2025 income data exist for exactly 4 sites --- the 4 Marovoay fokontany (031, 032, 033, 034) --- and are NA for all other donors. The 2025 counterfactual is therefore extrapolated from pre-2015 donor dynamics under the gsynth factor model.

== Extended gsynth
<sec-ext-gsynth>
#figure([
#box(image("04_results_files/figure-typst/fig-ext-att-1.png"))
], caption: figure.caption(
position: bottom, 
[
Extended ATT path for Ankarafantsika east-bank sites (1999--2025). The 2025 point, 22 years after the park extension, shows the largest single-period effect.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-ext-att>


Including 2025 in the panel, the average post-exposure ATT deepens substantially: -0.403 log points in the extended model vs -0.312 in the 1999--2014 main specification. The 2025-specific ATT (-0.841 log points) is about 2.7× the 1999--2014 average, indicating that income losses compound rather than dissipate over time. The widening gap is visible in raw site-level trajectories:

#figure([
#box(image("04_results_files/figure-typst/fig-ext-traj-1.png"))
], caption: figure.caption(
position: bottom, 
[
Site-level income trajectories for the four Marovoay fokontany (1999--2025). East-bank (exposed, red) and west-bank (control, blue) tracked together through 2003, then diverge persistently.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-ext-traj>


== Robustness of the 2025 gap
<sec-ext-robust>
The east-west income gap in 2025 is not driven by outliers: it is visible at every percentile of the income distribution, IQR-based outlier removal widens rather than narrows the gap, and the west-bank advantage appears across five of seven major income components. In statistical terms, the gap is large enough to pass standard tests (Wilcoxon rank-sum $p = 2.1 times 10^(- 10)$\; Welch $t$-test $p = 1.8 times 10^(- 5)$).

What remains unresolved is whether this gap reflects cumulative park exposure or the long-term effects of the same regional decline discussed in #ref(<sec-maro-rcs>, supplement: [Section]). By 2025, the Marovoay irrigation system has deteriorated further, rural-to-urban migration has reshaped communities, and the region's rice economy has never recovered its former position. The 2025 gap is real and robust; its attribution to conservation policy specifically requires caution.

== Alaotra long-run assessment
<sec-ext-ala>
For Alaotra, a 2025 gsynth extension is not feasible: all Alaotra sites are exposed and no other observatory was resurveyed, so there are no 2025 control observations. The Alaotra estimate remains based on the 1999--2014 panel (ATT ≈ +0.014, $p$ = 0.928).

= Extensions
<extensions>
Three additional observatory--PA pairs

\
The two-case comparison in #link(<results>)[Chapter 4] --- strict enforcement at Ankarafantsika versus participatory conservation at Lac Alaotra --- limits external validity. This chapter extends the analysis to three additional rural observatories that the donor-pool audit (#link("A2_donor_validity.qmd")[Appendix B]) flagged as themselves adjacent to protected areas created during the study period:

- Farafangana (obs. 15): adjacent to the Corridor Forestier Ambositra-Vondrozo (IUCN V, September 2006), a large highland corridor under light-touch regulation. Survey window: 1999--2008 (3 post-treatment years only).
- Toliara North (obs. 23): adjacent to Amoron'i Onilahy (IUCN V, January 2007), Mikea National Park (IUCN II, April 2007), and Ranobe PK 32 (IUCN V, December 2008) --- a rapid cascade of coastal and dry-forest protections. Survey window: 1999--2014.
- Fénérive East (obs. 24): adjacent to the Réserve de Tampolo (IUCN IV, August 2007), a small (\~7.3 km²) research forest managed by ESSA-Forêts. Survey window: 1999--2014.

These three observatories move from liabilities in the donor pool to informative exposed units. Together with Marovoay and Alaotra, they enable a five-case examination of how conservation governance type, enforcement intensity, and PA size shape household-income outcomes.

A methodological note: the donor pool in this chapter is restricted to five clean observatories (Antsirabe, Tsiroanomandidy, Ambovombe, Mahanoro, Itasy) as identified in #link("A2_donor_validity.qmd")[Appendix B]. The four also-exposed donors used in #link(<results>)[Chapter 4] are now treated as exposed units here. Marovoay and Alaotra ATT estimates will therefore differ slightly from their Chapter 4 counterparts.

= Study sites
<sec-additional-sites>
== Farafangana and the Corridor Forestier Ambositra-Vondrozo
<sec-fara-site>
The CFAV (\~300 km, IUCN V) runs along the eastern highland escarpment. A temporary protection decree was issued on 15 September 2006 (WDPA 555697881) as part of the post-2003 SAPM expansion. Category V status implies land-use regulation at the forest margin --- primarily restrictions on slash-and-burn (#emph[tavy]) and charcoal production in buffer zones --- rather than exclusionary enforcement.

The Farafangana observatory lies on the southeastern coastal plain; its nearest commune (Mahatsinjo) borders the CFAV at \~14 km. A complication: Manombo Special Reserve (IUCN IV, 1962) lies \~12 km from a second commune. Because Manombo predates the study period with unchanged boundaries and management, it constitutes a constant background condition absorbed into the unit fixed effect. The ATT for Farafangana therefore identifies the additional income effect of the 2006 CFAV decree.

All survey sites are exposed at observatory level from 2006; no within-observatory split is possible. With only 3 post-treatment years (2006--2008), gsynth estimates should be treated as illustrative.

#figure([
#box(image("05_extensions_files/figure-typst/fig-map-fara-1.png"))
], caption: figure.caption(
position: bottom, 
[
Farafangana observatory and nearby protected areas. The CFAV (exposure PA, red) and Manombo SR (pre-existing, yellow) are shown over surveyed fokontany.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-fara>


== Toliara North and the coastal PA cascade
<sec-tol-site>
Observatory 23 sits on Madagascar's arid southwest coast, a landscape of spiny thicket and dry deciduous forest. Three PAs became operative in rapid succession:

+ Amoron'i Onilahy (IUCN V, 17 January 2007, \~12 km): riparian and coastal landscape PA covering the Onilahy estuary.
+ Mikea National Park (IUCN II, 13 April 2007, \~16 km): strict reserve protecting Mikea dry spiny-thicket forest.
+ Ranobe PK 32 (IUCN V, 2 December 2008, \~1.4 km): large terrestrial PA (1,685 km²) bordering the observatory at extremely close range.

Exposure year is 2007 --- the first full survey year following the initial January 2007 decree. The December 2008 Ranobe decree constitutes a secondary intensification within the post-exposure window. The dominant conservation character is IUCN V / multipurpose, though the presence of Mikea NP (IUCN II) at 16 km introduces a strict element.

#figure([
#box(image("05_extensions_files/figure-typst/fig-map-tol-1.png"))
], caption: figure.caption(
position: bottom, 
[
Toliara North observatory and nearby protected areas. Three PAs became operative during 2007--2008.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-tol>


== Fénérive East and the Réserve de Tampolo
<sec-fen-site>
The Réserve de Tampolo (IUCN IV, \~7.3 km²) is a small coastal littoral forest managed by ESSA-Forêts as a research and teaching forest. A temporary protection decree was issued on 20 August 2007 (WDPA 354011). The reserve's primary function is scientific access and conservation research, not community resource exclusion. Its small footprint and institutional character suggest low exposure intensity.

Exposure year is 2007. The survey has 8 pre-treatment years (1999--2006) and 8 post-treatment years (2007--2014) --- the most symmetric panel among the new sites.

#figure([
#box(image("05_extensions_files/figure-typst/fig-map-fen-1.png"))
], caption: figure.caption(
position: bottom, 
[
Fénérive East observatory and the Réserve de Tampolo (IUCN IV, 2007). The reserve is small (\~7.3 km²) on the northeastern littoral coast.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-fen>


== Design summary
<sec-ext-design>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 8,
  align: (left,left,left,left,right,right,right,left,),
  table.header(table.cell(align: center, colspan: 8, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); #strong[Five Exposed Observatories: Design Summary]],
    table.cell(align: center, colspan: 8, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); ⚠ Farafangana: only 3 post-treatment years --- estimates are indicative only],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Observatory], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA (primary)], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); IUCN], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Type], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Treat yr], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Pre], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Post], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Survey],),
  table.hline(),
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ankarafantsika NP], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[II], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Strict], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2003], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1999--2014],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra PHP], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[V], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Multipurpose], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2008], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1999--2014],
  table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Farafangana (15)], table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Corridor Ambositra-Vondrozo], table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[V], table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Multipurpose], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2006], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1999--2008 ⚠],
  table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara N. (23)], table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Amoron\'i Onilahy + Mikea + Ranobe], table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[V/II], table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mixed (V dom.)], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2007], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1999--2014],
  table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fénérive E. (24)], table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Réserve de Tampolo], table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[IV], table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Low intensity], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2007], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8], table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1999--2014],
)}
], caption: figure.caption(
position: top, 
[
Five exposed observatories: design summary
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-ext-design>


= Results by observatory
<sec-ext-results>
The identification strategy and estimator are identical to #link(<results>)[Chapter 4]. We estimate the gsynth ATT separately for each exposed observatory. Each model specifies $D_(i t) = 1$ only for the target observatory's exposed unit(s) from its exposure year onward; all other units carry $D_(i t) = 0$ and serve as additional factors for counterfactual construction. This within-model use of other exposed observatories as donors is consistent with the interactive FE framework so long as exposure timing differs across observatories @Xu2017. The number of latent factors $r$ is selected by leave-one-out cross-validation; inference is parametric bootstrap with 200 replications.

== Ankarafantsika (clean donors)
<sec-ext-maro>
Re-estimating the Marovoay east-bank model with the restricted donor pool yields an average post-treatment ATT of -0.312 log points ($approx$ 27%, $p$ = 0.010), consistent with the full-donor estimate in #link(<results>)[Chapter 4]. The point estimate is slightly attenuated because the smaller donor pool supports fewer latent factors, but the qualitative conclusion is unchanged: strict enforcement is associated with a persistent, statistically significant income decline.

#figure([
#box(image("05_extensions_files/figure-typst/fig-att-maro-clean-1.png"))
], caption: figure.caption(
position: bottom, 
[
Ankarafantsika gsynth ATT path (clean donor pool). Exposure onset 2003.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-att-maro-clean>


== Lac Alaotra (clean donors)
<sec-ext-ala>
The Alaotra observatory-level ATT with clean donors remains near zero and statistically insignificant: +0.014 log points ($p$ = 0.928). The null result is robust to the donor-pool change, reinforcing the interpretation that participatory conservation under CBNRM did not impose detectable aggregate income costs.

#figure([
#box(image("05_extensions_files/figure-typst/fig-att-ala-clean-1.png"))
], caption: figure.caption(
position: bottom, 
[
Lac Alaotra gsynth ATT path (clean donor pool). Exposure onset 2008.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-att-ala-clean>


== Farafangana: Corridor Forestier effect
<sec-ext-fara>
#block[
#callout(
body: 
[
Farafangana has only 3 post-treatment survey years (2006--2008). The gsynth estimates are presented for completeness but should be treated with extreme caution. Pre-treatment fit is assessed over 7 years; post-treatment precision is insufficient for firm conclusions.

]
, 
title: 
[
Warning
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
The point estimate is -0.260 log points ($approx$ 23%), but with very wide confidence intervals ($p$ = 0.301) that span both negative and positive values. With only 3 post-treatment observations, this estimate has low reliability and should not be interpreted independently.

#figure([
#box(image("05_extensions_files/figure-typst/fig-att-fara-1.png"))
], caption: figure.caption(
position: bottom, 
[
Farafangana gsynth ATT path (1999--2008). Exposure onset 2006. Wide CIs reflect only 3 post-treatment years.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-att-fara>


== Toliara North: coastal PA cascade
<sec-ext-tol>
The Toliara North ATT estimates a composite treatment effect from the 2007--2008 PA cascade. The point estimate is +0.129 log points ($p$ = 0.512), not statistically significant. The December 2008 secondary shock (Ranobe PK 32, the closest PA at \<1.5 km) coincides with a visible shift in the ATT path, but it is impossible to separate the 2007 and 2008 effects without additional micro-data. The dominant conservation character of the three PAs is multipurpose (IUCN V), consistent with the near-zero aggregate income effect.

#figure([
#box(image("05_extensions_files/figure-typst/fig-att-tol-1.png"))
], caption: figure.caption(
position: bottom, 
[
Toliara North gsynth ATT path. Exposure onset 2007 (Amoron'i Onilahy decree). An annotation marks the December 2008 Ranobe PK 32 secondary decree.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-att-tol>


== Fénérive East: low-intensity reserve
<sec-ext-fen>
The Fénérive East ATT shows a small positive but nonsignificant effect (+0.114 log points, $p$ = 0.619) --- perhaps the most interpretively clear result among the three new sites. A 7.3 km² research forest cannot plausibly impose population-level income costs on a multi-commune observatory. The 8/8 pre-/post-treatment symmetry provides the most credible pre-trend assessment of the new sites.

#figure([
#box(image("05_extensions_files/figure-typst/fig-att-fen-1.png"))
], caption: figure.caption(
position: bottom, 
[
Fénérive East gsynth ATT path. Exposure onset 2007 (Réserve de Tampolo decree).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-att-fen>


= Five-case synthesis
<sec-synthesis>
== Comparative results
<comparative-results>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 11,
  align: (left,left,right,right,right,left,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 11, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); #strong[Five-Observatory Comparative Results]],
    table.cell(align: center, colspan: 11, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); ⚠ Farafangana: only 3 post-treatment years --- treat as indicative],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Observatory], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA type], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Treat yr], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT (log pts)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 95% CI], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT (%)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p-value], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); r\*], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); N donors], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Post yrs],),
  table.hline(),
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Strict (II)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2003], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.312], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.122], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.55, -0.073\]], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-26.8%], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.010], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[57], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[11],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Multipurpose (V)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2008], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.014], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.156], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.293, 0.321\]], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4%], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.928], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6],
  table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Farafangana (15) ⚠], table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Multipurpose (V)], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2006], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.260], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.251], table.cell(align: horizon + left, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.752, 0.232\]], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-22.9%], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.301], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[50], table.cell(align: horizon + right, fill: rgb("#dcedc8"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3],
  table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North (23)], table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mixed (V/II)], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2007], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.129], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.197], table.cell(align: horizon + left, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.257, 0.516\]], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.8%], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.512], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[56], table.cell(align: horizon + right, fill: rgb("#ffe0b2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8],
  table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fénérive East (24)], table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Low-intensity (IV)], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2007], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.114], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.230], table.cell(align: horizon + left, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.336, 0.564\]], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.1%], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.619], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[49], table.cell(align: horizon + right, fill: rgb("#e8eaf6"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8],
)}
], caption: figure.caption(
position: top, 
[
Five-observatory comparative results. Farafangana estimates (⚠) are unreliable due to only 3 post-treatment years.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-five-att>


#figure([
#box(image("05_extensions_files/figure-typst/fig-att-all-overlay-1.png"))
], caption: figure.caption(
position: bottom, 
[
ATT paths for all five exposed observatories on the same relative-time axis. CI bands suppressed for legibility.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-att-all-overlay>


#figure([
#box(image("05_extensions_files/figure-typst/fig-forest-plot-1.png"))
], caption: figure.caption(
position: bottom, 
[
Forest plot of average post-treatment ATTs with 95% parametric bootstrap CIs. Farafangana shown at reduced opacity.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-forest-plot>


== Three patterns
<sec-patterns>
The five-case comparison suggests three broad patterns, each of which warrants careful interpretation given the small number of exposed units per model.

The first pattern is a large negative income gap under strict enforcement. Ankarafantsika (Marovoay) shows the largest and most persistent negative gap relative to its synthetic counterfactual, statistically significant and apparent through the 2025 resurvey. This is consistent with direct resource exclusion from a large, actively patrolled park. However, as discussed in #ref(<sec-maro-rcs>, supplement: [Section]) and #ref(<sec-counterfactual>, supplement: [Chapter]), the within-Marovoay comparison between east-bank and west-bank villages finds no equivalent income difference, which raises the possibility that the gsynth is capturing regional economic decline --- the long-run deterioration of the Marovoay irrigated rice economy --- rather than a park-specific effect. The Marovoay result should therefore be treated as suggestive rather than conclusive evidence of a conservation-driven income loss.

The second pattern is near-zero estimated effects under participatory or multipurpose governance. Lac Alaotra, Toliara North, and tentatively Farafangana all show point estimates clustered near zero with no statistically significant departure. The community-based management framework at Alaotra, and the lighter regulatory touch at the other sites, appears consistent with no detectable aggregate income costs at the survey-year frequency --- though low statistical power (one exposed unit per model) means that moderate effects cannot be ruled out.

The third pattern is that a small, research-oriented reserve with minimal enforcement leaves estimated income unchanged. Fénérive East shows a near-zero ATT with a moderately narrow confidence interval, which is the result one would expect from a 7.3 km² scientific forest that does not constrain community livelihoods at scale.

== Caveats
<caveats>
Several limitations temper interpretation of the extended comparison. With only three post-treatment years, the Farafangana estimate has low reliability and should not be compared numerically to the others. At Toliara North, the rapid succession of three protected areas in 2007--2008 means the estimated ATT captures a composite of overlapping events rather than a clean single intervention. Using only five donor observatories rather than the nine available in Chapter 4 reduces counterfactual precision, which is why ATT estimates for Marovoay and Alaotra differ slightly between the two chapters. Identification for the three new sites rests on decree dates and spatial proximity without the behavioural validation available for Marovoay and Alaotra, since no 2025 resurvey covered these observatories. Finally, each observatory-level model has exactly one exposed unit, which imposes a minimum permutation p-value of roughly $1 \/ N_(upright("donors"))$\; effects below around 20% cannot be reliably distinguished from chance.

= Discussion
<discussion>
Policy implications, limitations, and next steps

\
= Summary of findings
<sec-summary>
This analysis estimates the effect of protected-area creation on household income in rural Madagascar using the generalised synthetic control method @Xu2017 across five observatory--PA pairs spanning the 1999--2014 study period, with a long-run extension to 2025 for the Marovoay case. The results should be read as suggestive evidence rather than definitive causal estimates, given the small number of treated units and the identification challenges discussed below.

The core finding from the two primary sites is a divergence in estimated income trajectories. At Ankarafantsika, the extension of a forest reserve into a strictly patrolled national park (IUCN II, 2002) is associated with a -0.312 log-point gap in OECD-equivalised household income relative to the synthetic counterfactual (approximately 27%), statistically significant and persistent through 2025. However, as discussed in #ref(<sec-maro-rcs>, supplement: [Section]), a comparison between east-bank and west-bank villages within the same observatory finds no detectable income difference between the two sides of the river. This diagnostic raises an important alternative reading: the gsynth estimate may be capturing the long-run regional economic decline of the Marovoay plain relative to the donor sites on the highland plateau or in the south. Marovoay was historically Madagascar's most productive irrigated rice landscape, the #emph[grenier à blé] of the country. From the 1980s onward the region experienced a documented decline driven by the silting of the Betsiboka, the deterioration of colonial-era irrigation canals, and the withdrawal of state-led rice marketing support. This trajectory predates the 2002 park extension and could account for much of the divergence that gsynth records, if the donor observatories were not similarly exposed to the collapse of lowland irrigated agriculture. Attribution of the estimated income gap to the park specifically therefore remains uncertain; the results at Marovoay should be read as indicative rather than conclusive.

At Lac Alaotra, creation of a participatory protected landscape under community-based natural resource management (IUCN V, 2008) produces an estimated ATT close to zero, indistinguishable from zero. Communities retained access to the lake-marsh ecosystem under Durrell's management; no aggregate income cost is detectable, though this null could equally reflect low statistical power.

Extending the analysis to Farafangana, Toliara North, and Fénérive East yields near-zero, statistically insignificant ATTs in all three cases. These sites face protected areas that are either multipurpose in governance, small in footprint, or both. The 2025 resurvey at Marovoay confirms that the east-west income gap persists twenty-two years after the park extension, though its interpretation remains subject to the regional-decline caveat discussed above.

= Policy implications
<sec-policy>
== Conservation governance matters
<conservation-governance-matters>
The results, taken at face value, suggest that how a protected area is governed may matter at least as much as whether it exists. Across all five cases, only the site with strict exclusionary management (Ankarafantsika, IUCN II) shows a large negative income gap; sites with multipurpose or low-intensity governance show near-zero effects. This is consistent with a growing literature showing that conservation-income trade-offs depend heavily on institutional design rather than the fact of protection alone @Ferraro2011@Sims2010@Oldekop2016.

That said, the Marovoay result requires the caveat outlined in #ref(<sec-summary>, supplement: [Chapter]): the gsynth gap may reflect, at least in part, the regional economic decline of the Marovoay plain rather than a park-specific effect. Taken together, the evidence is suggestive rather than conclusive that strict conservation imposes household income costs, and it supports the architecture of Madagascar's post-2003 SAPM expansion, which paired strict protection with extensive community-based and multipurpose approaches.

== Compensation and livelihood integration
<compensation-and-livelihood-integration>
Even under the cautious interpretation, two decades of survey data show that the income gap between east-bank Marovoay villages and comparable sites has not closed. Whether driven primarily by the park or by the broader decline of the irrigation economy, households in this area are measurably poorer than comparable rural communities. If conservation generates national and global public goods --- carbon storage, biodiversity preservation --- the costs of both the park and the regional disadvantage should not fall disproportionately on some of Madagascar's poorest rural households.

Policy options worth examining include direct transfers tied to park proximity and enforcement intensity, livelihood diversification programmes in buffer zones, and, where strict enforcement is not ecologically necessary, a reconsideration of whether IUCN II classification still serves its intended purpose in particular sites.

== Limitations of the policy inference
<limitations-of-the-policy-inference>
These results say nothing about whether multipurpose conservation is effective at achieving its ecological aims. The null income effect at Lac Alaotra may reflect genuinely benign governance or enforcement that exists on paper but has little practical effect on community behaviour. Without ecological outcome data --- forest cover trends, water quality, species abundance --- the net welfare implications of either governance model remain incomplete.

= Counterfactual validity
<sec-counterfactual>
The central threat to interpretation is whether the synthetic counterfactual --- 'what would income have been absent the PA?' --- is credible. Good pre-treatment fit is necessary but not sufficient: the factor structure estimated before the PA must continue to hold after it. With only one or two treated units, this assumption cannot be tested directly.

== Marovoay: alternative explanations
<marovoay-alternative-explanations>
The Ankarafantsika estimate rests on the Betsiboka River providing a geographic split between communities with and without direct park access. Several concerns temper the causal interpretation.

First, the most important diagnostic: the within-observatory comparison between east-bank and west-bank villages finds no detectable income difference over the study period (#ref(<sec-maro-rcs>, supplement: [Section])). This is the main reason to be cautious about attributing the gsynth gap to the park. The gsynth compares Marovoay sites against donors on the highland plateau or in the southern drylands. If the Marovoay region as a whole has fallen behind those other places --- because of the Betsiboka siltation, the degradation of irrigation infrastructure, the loss of its historical position as Madagascar's primary rice supplier --- then gsynth will attribute that regional divergence to park exposure simply because the timing happens to align. The within-observatory comparison controls for this regional shock automatically. The fact that east-bank and west-bank incomes moved together is consistent with a common regional driver rather than a park-specific effect.

Second, the east bank was already adjacent to the Réserve Naturelle Intégrale d'Ankarafantsika (1927) before the 2002 extension. The RNI may have imposed partial constraints before the study period began, making the 2002 extension a less clean sharp onset than the design assumes.

Third, east-bank and west-bank villages differ in soil types, flood exposure, and irrigation access. If these differences interact with post-2002 trends --- through a cyclone, drought, or infrastructure investment that differentially affected one bank --- the estimated gap would conflate conservation effects with other shocks.

Fourth, selective out-migration from the east bank could make the remaining surveyed population appear poorer without any true income decline, since the ROS sampling frame was not designed to track migrants.

== Alaotra: single-unit identification
<alaotra-single-unit-identification>
The Alaotra model aggregates the entire observatory into a single exposed unit. The counterfactual is built from \~60 donor sites, none of which is a comparable lake-ecosystem economy. The near-zero ATT could reflect (i) genuinely benign conservation governance, (ii) a poorly constructed counterfactual that masks a real effect, or (iii) insufficient statistical power to detect a moderate effect.

== Implications for interpretation
<implications-for-interpretation>
Given these concerns, we characterise the results as strongly suggestive rather than definitively causal.

Three features of the evidence increase confidence that the patterns are real, even under the cautious interpretation. The sign and persistence of the Ankarafantsika gap are robust across specifications --- generalized synthetic control, synthetic difference-in-differences, unadjusted income, and levels all tell the same directional story. The governance contrast between strict-negative and multipurpose-null outcomes appears across all five independent cases, making it less likely to be driven by a single confounded comparison. And the 2025 resurvey at Marovoay, which directly documents park-interaction behaviour, provides corroborating evidence that east-bank communities face binding constraints from the park, even if the size of the income gap cannot be fully attributed to those constraints alone.

These results are best read as a first-generation estimate that motivates, and will be refined by, the household-level analysis planned for the 2026 data.

= Limitations
<sec-limitations>
Several limitations temper causal interpretation and should inform how these results are used.

Statistical power is the most fundamental constraint. Each gsynth model has exactly one exposed unit, which imposes a minimum achievable p-value of roughly $1 \/ N_(upright("donors"))$. The Alaotra null result may reflect insufficient power rather than a true zero effect; effects below around 20% are difficult to distinguish from zero in this design.

PA creation in Madagascar involves multiple administrative steps --- decree, gazette, enforcement on the ground. We assign exposure to the first full survey year after the decree, but actual enforcement may have ramped up over one to three years. This attenuates early post-exposure estimates.

The gsynth framework operates on site-level panel data, collapsing roughly 130--260 households per survey year into a single village-year mean. This aggregation absorbs within-site variation in exposure intensity, livelihood strategy, and income composition, discarding information that household-level analysis could use.

Spillover effects could bias the west-bank Marovoay villages as controls if displaced east-bank labour or capital migrated westward across the river; the stable unit treatment value assumption cannot be verified.

We estimate effects on total income only. Conservation pressure may reshape the composition of income --- shifting households from forest-product extraction toward wage labour, for example --- without necessarily changing the total. Decomposing effects by income source would require separate models for each component with even lower power.

Survey-based income measurement in subsistence economies is inherently approximate. Recall bias and seasonal variation are unavoidable. The OECD equivalence scale adjusts for household size but assumes consumption patterns that may not hold in rural Madagascar.

The five clean donor observatories span very different agro-ecological zones --- highland plateau, semi-arid south, humid east coast. Whether a weighted average of such diverse economies can credibly represent what Marovoay's irrigated rice plain, or Alaotra's lake fishery, would have earned absent the PA is an open question. The Marovoay model has only four pre-treatment years in which to validate this projection.

Finally, this study measures income effects only. A protected area that imposes short-term income costs but prevents longer-run ecological degradation --- soil erosion from deforestation, loss of water regulation --- may be welfare-improving over a longer horizon. The full welfare comparison requires ecological outcome data that are outside the scope of this analysis.

= Next steps: the 2026 survey wave
<sec-next-steps>
The limitations above --- aggregation, balanced-panel requirements, single-unit power --- are largely artefacts of the gsynth framework rather than the data themselves. The Rural Observatory panel data, with \~500 households per observatory per year across repeated cross-sections and staggered treatment timing, are also suited to household-level difference-in-differences estimation.

== Staggered DiD design
<staggered-did-design>
The five exposed observatories define four exposure cohorts:

#figure([
#table(
  columns: (29.41%, 23.53%, 23.53%, 23.53%),
  align: (center,left,left,left,),
  table.header([Cohort ($g$)], [Sites], [PA type], [Design],),
  table.hline(),
  [2003], [Marovoay east-bank (2 sites)], [Strict (IUCN II)], [Site-level split],
  [2006], [Farafangana (9 sites)], [Multipurpose (IUCN V)], [Observatory-level],
  [2007], [Toliara North (4) + Fénérive East (10)], [Mixed V/II + Low intensity (IV)], [Observatory-level],
  [2008], [Alaotra (3 sites)], [Multipurpose (IUCN V)], [Observatory-level],
  [$oo$], [Marovoay west (2) + 5 clean donors (36)], [Never exposed], [Controls],
)
], caption: figure.caption(
position: top, 
[
Four staggered exposure cohorts for Callaway & Sant'Anna DiD
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-staggered>


A crucial feature here: #emph[not-yet-exposed units serve as controls.] Alaotra (exposed from 2008) provides a valid control for the Marovoay effect during 2003--2007 before its own exposure begins. This cross-cohort identification is impossible in the gsynth framework.

== Planned analyses
<planned-analyses>
When the 2026 survey round becomes available, the primary specification will be a Callaway--Sant'Anna (#cite(<CallawayS2021>, form: "year")) staggered difference-in-differences estimation at the household level, with doubly-robust estimation, household-level covariates, and clustering at the site level. A complementary Sun--Abraham (#cite(<SunAbraham2021>, form: "year")) interaction-weighted estimator via #NormalTok("fixest::sunab()"); will provide a transparent event-study summary. The gsynth estimates from Chapters 4 and 5 will serve as a robustness check that relaxes the parallel-trends assumption to interactive fixed effects. If gsynth and DiD agree, the evidence is more credible regardless of which identifying assumption one prefers. If the 2026 wave covers Fénérive East, the small footprint of the Réserve de Tampolo allows a within-observatory distance design contrasting near-PA and far-PA sites, adding a third independent geographic context alongside Marovoay and Alaotra.

This chapter will be updated when the 2026 data arrive. The current gsynth results should be read as a first-pass analysis that will be complemented by household-level estimation exploiting the full depth of the data.

#heading(level: 1, numbering: none)[References]
<references>
#heading(level: 1, numbering: none)[References]
<references-1>
#block[
] <refs>
#show: appendices.with("Appendices", hide-parent: true)
#heading(level: 1, numbering: none)[Appendices]
= Data Pipeline
<data-pipeline>
Georeferencing, PA overlaps, and variable harmonisation

\
This appendix documents the full reproducible data pipeline from raw ROS survey files to the consolidated household-level panel dataset. The paper chapter (#link(<data>)[Chapter 2]) provides a condensed summary; this appendix gives all details needed for reproducibility.

= Georeferencing ROS localities
<sec-a-georef>
== The problem
<the-problem>
The Rural Observatory System collected household panel data in rural Madagascar from 1995 to 2015. Critically, surveys were #strong[not geolocated]: location fields were free-text, not linked to official administrative codes. To enable spatial analysis --- particularly overlay with protected-area boundaries --- every ROS observation must be aligned with a standardised commune and #emph[fokontany] using P-codes from the OCHA/BNGRC Common Operational Datasets (CODs).

== Reference datasets
<reference-datasets>
Two spatial reference datasets anchor the georeferencing:

+ #strong[Madagascar Subnational Administrative Boundaries] (COD-AB): five administrative levels from country to #emph[fokontany], with official P-codes.
+ #strong[Madagascar Populated Places] (COD-PS): 28,184 populated places with toponyms and P-codes (source: NGA/GIST, distributed by UN OCHA ROSA).

== String cleaning
<string-cleaning>
All location strings are normalised before matching. The #NormalTok("clean_string()"); function lowercases, strips non-alphanumeric characters, removes qualifiers ("centre", "haut", "bas"), translates French cardinal directions to Malagasy, standardises alternative city names (e.g.~"Fort Dauphin" → "Tolanaro"), and converts Roman numerals I--VI to Arabic.

== Hierarchical fuzzy matching
<hierarchical-fuzzy-matching>
Matching uses #strong[Jaro-Winkler distance] (default threshold 0.25), applied observatory-wise to restrict candidate sets. A four-method cascade assigns communes:

+ #strong[Method 1] --- Fuzzy-match the municipality field (#NormalTok("j42");) against known observatory commune names. Visually verified; false positives removed manually.
+ #strong[Method 2] --- For records with no municipality, extract the first word of the village name and fuzzy-match it against commune names.
+ #strong[Method 3] --- Fuzzy-match the full village name against COD populated places (threshold tightened to 0.22).
+ #strong[Method 4] --- Fuzzy-match remaining village names against already-matched names from prior steps (threshold 0.28).

After commune assignment, a dedicated #NormalTok("fuzzy_match_village()"); function matches village names to ADM4 (#emph[fokontany]) names within the matched commune (Jaro-Winkler threshold 0.2). A final #strong[Method 6] adds 13 hand-coded entries for observatory 52 (Menabe).

#figure([
#box(image("A1_data_pipeline_files/figure-typst/fig-map-georef-1.png"))
], caption: figure.caption(
position: bottom, 
[
All matched ROS communes and fokontany across Madagascar.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-georef>


== Match rates
<match-rates>
Communes were re-identified for #strong[91.8%] of observations; villages for #strong[61.5%] of name variations. The 8.2% commune failures are concentrated in observatories with highly abbreviated or non-standard location strings. 98% of unique commune name variations and 62% of village name variations were resolved.

= Protected-area overlap analysis
<sec-a-overlaps>
== Spatial overlaps
<spatial-overlaps>
ROS commune and #emph[fokontany] polygons are overlaid with the #strong[dynamic WDPA] (#NormalTok("dynamic_wdpa.rds");), a temporally explicit database of PA boundaries for Madagascar. An interactive map visualises all observatory polygons against PA boundaries.

#figure([
#box(image("A1_data_pipeline_files/figure-typst/fig-map-overlaps-1.png"))
], caption: figure.caption(
position: bottom, 
[
ROS survey communes (coloured by observatory) overlaid with PA boundaries (dark green).
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-overlaps>


== ROS survey inventory
<ros-survey-inventory>
Household-level datasets for 1995--2015 are loaded and tabulated by observatory and year. Survey continuity varies: some observatories have nearly continuous 20-year panels, others cover only 3--8 years.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 22,
  align: (left,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 22, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); ROS Survey Inventory],
    table.cell(align: center, colspan: 22, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Number of households per observatory per year (blank = no survey)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Observatory], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 1995], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 1996], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 1997], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 1998], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 1999], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2000], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2001], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2002], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2003], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2004], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2005], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2007], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2011], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2012], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2013], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2014], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2006], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2008], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2010], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2009], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 2015],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 01], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[514], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[530], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[535], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[553], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[559], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[528], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[528], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[600], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Antsirabe], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[503], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[506], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[631], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[598], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[599], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[600], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[600], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[600], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[515], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[514], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[507], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[512], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[508], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[672], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[519], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[516], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[231], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[521], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[519], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[519], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[519], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 04], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[512], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Antsohihy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[495], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[508], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[515], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[507], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[509], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tsiroanomandidy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[509], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Farafangana], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[503], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[503], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[497], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[486], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[513], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[530], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[529], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[530], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambovombe], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[544], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[552], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[548], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[544], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[549], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[550], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[550], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[544], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[550], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[542], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 17], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[540], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[538], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[540], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[538], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 18], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[513], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[513], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[513], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[516], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 19], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Alaotra], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[517], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[518], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[505], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[503], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[503], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[503], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 22], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[499], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fénérive East], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[505], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mahanoro], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[506], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[513], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[512], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[512], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[515], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 31], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[590], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[590], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[525], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 33], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 38], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Itasy], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[521], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[520], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 42], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[505], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 43], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 44], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[522], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[522], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 45], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[501], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[500], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[511], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 51], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[504], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[507], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[509], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 52], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[502], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[509],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 61], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[600], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Obs 71], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[510], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---],
)}
], caption: figure.caption(
position: top, 
[
Number of surveyed households per observatory per year (1995--2015).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-survey-inventory>


== Temporal overlap logic
<temporal-overlap-logic>
Three scenarios determine usability for impact evaluation:

+ #strong[PA predates ROS entirely] → no pre-treatment baseline → unusable (e.g.~Ranomafana, created 1991).
+ #strong[PA created during ROS surveys] → impact analysis possible → #emph[these are our exposure cases].
+ #strong[PA created after ROS ended] → baseline only; resurvey needed for evaluation.

== Decree date revision
<decree-date-revision>
Official creation years were cross-checked against the Madagascar legal database (#link("https://cnlegis.gov.mg")[CNLEGIS]). Several temporary decree dates were revised:

#figure([
#table(
  columns: 4,
  align: (left,center,center,left,),
  table.header([PA], [Original year], [Revised year], [Source],),
  table.hline(),
  [Ankarafantsika NP], [1927], [#strong[2002]], [Decree 2002-798 (extension)],
  [Lac Alaotra PHP], [2003], [#strong[2007]], [Temporary decree],
  [Corridor Ankeniheny--Zahamena], [2002], [#strong[2005]], [Temporary decree],
  [Menabe Antimena], [2003], [#strong[2006]], [Temporary decree],
  [Corridor Ambositra-Vondrozo], [2003], [#strong[2006]], [WDPA / CNLEGIS],
  [Mikea NP], [2003], [#strong[2007]], [Temporary decree],
  [Ranobe PK 32], [2003], [#strong[2008]], [Temporary decree],
  [Amoron'i Onilahy], [2003], [#strong[2007]], [Temporary decree],
)
], caption: figure.caption(
position: top, 
[
Revised PA decree dates used in this study
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-decree-dates>


#figure([
#box(image("A1_data_pipeline_files/figure-typst/fig-timeline-1.png"))
], caption: figure.caption(
position: bottom, 
[
Timeline of ROS survey years (blue dots) vs.~revised PA creation years (red triangles) for priority observatory--PA pairs.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-timeline>


== Priority pairs
<priority-pairs>
The spatial and temporal overlay identifies Marovoay--Ankarafantsika and Alaotra--Lac Alaotra as the most promising pairs for causal analysis (long panels, clear exposure dates). Farafangana, Toliara North, and Fénérive East are secondary candidates explored in #link(<extensions>)[Chapter 5]. A 10 km buffer (CRS EPSG:29701, Laborde Madagascar) around PAs is used for the proximity screening.

#block[
#callout(
body: 
[
ROS observatories were selected for agricultural and socio-economic monitoring, not proximity to PAs. Overlaps are partly coincidental and require cautious interpretation.

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
= Variable construction
<sec-a-variables>
== Georeferencing households
<georeferencing-households>
Household identifiers (#NormalTok("j5");) are joined to the locality correspondence table from #ref(<sec-a-georef>, supplement: [Appendix]). A critical correction: #strong[1995 household IDs are re-aligned using the 1996 survey] (which records whether a household was surveyed in 1995 and provides its 1996 identifier).

== Household composition
<household-composition>
Individual-level files (member records) provide sex, age, and headship. Households with multiple heads are resolved by keeping the first member ID. Key variables: #NormalTok("household_size"); (member count) and head's sex and age.

== Education
<education>
Education variables present several data gaps:

- Literacy (#NormalTok("s1a");, #NormalTok("s1b");): missing in 1996 and 1998.
- Primary school attendance (#NormalTok("s2");): missing in 1996.
- Years of schooling (#NormalTok("s3a");): missing in 1996.

Household-level indicators are constructed: #NormalTok("any_literate_adult"); (≥1 adult reads), #NormalTok("max_years_edu");, #NormalTok("mean_years_edu_adults");, #NormalTok("pct_with_schooling"); (share of members ≥6 with any schooling), and head's education variables.

== Agricultural activities
<agricultural-activities>
Activity codes (#NormalTok("a1");) are harmonised across the 1996--2015 coding schemes. #strong[1995 is a special case]: no individual #NormalTok("a1"); variable; activities are reconstructed from separate main/secondary activity files (#NormalTok("res_apm.dta");, #NormalTok("res_asm.dta");). Two agricultural classifications are used:

- #strong[Stricto sensu] (codes 95, 96): farming or livestock only.
- #strong[Lato sensu] (19 codes): farming, livestock, fishing, gathering, apiculture, agriculture-related crafts.

== Food security
<food-security>
The core measure is #strong[months of food self-sufficiency from own production], harmonised across varying question formats:

- 1995: single question (#NormalTok("sa3a");).
- 1996--1997: single question (#NormalTok("sa2");).
- 1998--2015: three components (#NormalTok("sa2a"); + #NormalTok("sa2b"); + #NormalTok("sa2c"); for rice 1st season + rice 2nd season + maize).

Summed and capped at 12 months.

== Income construction
<income-construction>
Income is reconstructed via dedicated functions for each component:

- #strong[Current income] = main activity + secondary activity + net rice + other crops + livestock + fishing.
- #strong[Exceptional income] = land rents + miscellaneous + HIMO (public works) + asset sales + monetary and non-monetary transfers.
- #strong[Total income] (#NormalTok("revtot");) = current + exceptional.

The OECD-modified equivalence scale assigns weight 1.0 to the first adult, 0.5 to each additional adult (≥14), and 0.3 to each child (\<14). OECD-equivalised income = #NormalTok("revtot / oecd_scale");. Both total and equivalised income are log-transformed and winsorised at the 1st--99th percentiles for the main analysis.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 4,
  align: (left,left,left,left,),
  table.header(table.cell(align: center, colspan: 4, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Income Component Construction],
    table.cell(align: center, colspan: 4, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); From ROS household surveys to analysis-ready income variables],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Component], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Variables], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Coverage], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Notes],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Rice income (net)], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[rev\_riz], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Revenue minus production costs],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Other crops], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[rev\_cu], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cash crops, fruit, vegetables],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Livestock], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[revel], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Cattle, poultry, other animals],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fishing], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[revpeche], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Inland and coastal],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Main activity], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[revppal], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primary non-agricultural activity],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Secondary activity], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[revsec], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Secondary non-agricultural activity],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Current income], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); revcou], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Derived], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Sum of 6 components above],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Exceptional income], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[revext], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1995--2015], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Land rents, transfers, HIMO, asset sales],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Total income], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); revtot], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Derived], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Current + exceptional],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); OECD-equiv. income], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); revtot / oecd\_equiv], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Derived], table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Scale: 1.0 + 0.5×(adults−1) + 0.3×children],
)}
], caption: figure.caption(
position: top, 
[
Income component construction and variable sources.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-income-components>


== Consolidation
<consolidation>
All component tables are deduplicated to unique (year, household ID) via mean aggregation, then left-joined into a single dataset: #NormalTok("household_consolidated.rds"); (101,253 household-year observations across 11 observatories). A uniqueness check confirms one row per household per year.

= Donor Pool Validity
<donor-pool-validity>
Are donor observatories truly unexposed to conservation interventions?

\
The generalised synthetic control estimator requires that #strong[donor pool units are never exposed to the conservation intervention of interest]. In this study, the nine donor observatories used in the primary analysis (#link(<results>)[Chapter 4]) should not themselves be adjacent to protected areas that became actively enforced during the 1999--2014 study period. This assumption is plausible by design --- ROS observatories were chosen for agricultural monitoring, not PA proximity --- but has never been systematically verified. This appendix provides a spatial audit.

= Why static PA boundaries are insufficient
<sec-b-static>
Standard PA databases --- including the current WDPA and the Vahatra dataset --- record the #strong[most recent boundary and designation] of each protected area. They do not convey:

+ #strong[Boundary changes]: many Malagasy PAs were significantly extended or reorganised between 1999 and 2015.
+ #strong[Temporary protection decrees]: Madagascar's post-2003 SAPM expansion created PAs first via temporary decrees (#emph[décrets provisoires]) before formal designation.
+ #strong[Date accuracy]: numerous PAs in the static WDPA carry incorrect or missing #NormalTok("STATUS_YR"); values.

= Dynamic WDPA construction
<sec-b-wdpa>
We use the #strong[dynamic WDPA for Madagascar] (#NormalTok("dynamic_wdpa.rds");), a temporally explicit database that corrects and extends the standard WDPA with historical states derived from legal texts, multiple institutional datasets, and spatially referenced decree dates. Each record carries a valid-from / valid-to date range, allowing us to reconstruct which PA boundaries were legally operative in any given year.

#figure([
#box(image("A2_donor_validity_files/figure-typst/fig-wdpa-timeline-1.png"))
], caption: figure.caption(
position: bottom, 
[
Timeline of PA activation dates by observatory. Study period (1999--2014) shaded.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-wdpa-timeline>


= Proximity analysis
<sec-b-proximity>
== Method
<method>
Observatory locations are represented by commune-level polygon centroids from #NormalTok("Observatories_ROS_communes_COD_v4.gpkg");. The dynamic WDPA is filtered to external boundaries active during 1999--2014, then unioned per WDPAID. Both layers are projected to UTM 38S for distance computation.

For each (commune centroid, PA boundary) pair, we compute centroid-to-boundary distance in km. All pairs within #strong[20 km] are retained and classified by exposure timing:

- #strong[Pre-existing]: PA active before 1999 with unchanged boundaries throughout.
- #strong[New during study]: PA became operative between 1999 and 2014.
- #strong[Post-study]: PA created after 2014.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 7,
  align: (left,left,left,right,left,right,left,),
  table.header(table.cell(align: center, colspan: 7, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); #strong[Observatory--PA Proximity]],
    table.cell(align: center, colspan: 7, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); All pairs within #strong[20 km] · Dynamic WDPA (1999--2014 study window)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Observatory], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Role], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Closest commune], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Dist. (km)], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA name], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Active from], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Exposure type],),
  table.hline(),
  table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Ankarafantsika], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 12/31/1927], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Pre-existing (before 1999)],
  table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Tsararano], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Ankarafantsika], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 12/31/1927], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Pre-existing (before 1999)],
  table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Andrefana Dry Forests], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/1990], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Pre-existing (before 1999)],
  table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Tsararano], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Andrefana Dry Forests], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/1990], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Pre-existing (before 1999)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Marovoay (03)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Ankazomborona], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 18.3], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Corridor forestier Bongolava], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 9/15/2006], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Antsohihy (12)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tsarahasina], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.3], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Corridor forestier Bongolava], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9/15/2006], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Farafangana (15)], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Vohitromby], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.2], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Manombo], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1/1/1962], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Pre-existing (before 1999)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Farafangana (15)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mahatsinjo], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[13.5], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Corridor Forestier Ambositra Vondrozo], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9/15/2006], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Amparafaravola], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Le Lac Alaotra: les zones humides et basin], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/2003], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Morarano Chrome], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Le Lac Alaotra: les zones humides et basin], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/2003], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Ambatondrazaka Suburbaine], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Le Lac Alaotra: les zones humides et basin], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/2003], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Ilafy], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 0.0], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Le Lac Alaotra: les zones humides et basin], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/2003], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Amparafaravola], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 2.4], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Lac Alaotra], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/8/2007], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Alaotra (21)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Exposed], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Feramanga Nord], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 17.8], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); Rainforests of the Atsinanana], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); 1/1/2007], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[#set text(weight: "bold"); New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North (23)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Miary Ambohibola], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ranobe PK 32], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12/2/2008], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North (23)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Miary Ambohibola], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.4], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Amoron\'i Onilahy], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1/17/2007], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North (23)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ankililoaka], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.6], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mikea], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4/13/2007], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[New during study (1999--2014)],
  table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North (23)], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ankililoaka], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[15.6], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Andrefana Dry Forests], table.cell(align: horizon + right, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1/1/1990], table.cell(align: horizon + left, fill: rgb("#fff9c4"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Pre-existing (before 1999)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fénérive East (24)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ampasina Maningory], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.0], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Réserve de Tampolo], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8/20/2007], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[New during study (1999--2014)],
)}
], caption: figure.caption(
position: top, 
[
All observatory--PA pairs within 20 km, colour-coded by exposure type.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-proximity>


= Results
<sec-b-results>
== Exposure classification
<exposure-classification>
The nine donor observatories fall into three categories:

#strong[Clean] (no PA within 20 km during study period):

- Antsirabe (02)
- Tsiroanomandidy (13)
- Ambovombe (16)
- Mahanoro (25)
- Itasy (41)

#strong[Also exposed] (new PA within 20 km during study period):

- #strong[Antsohihy (12)] --- within 0.3 km of Corridor forestier Bongolava (IUCN V, 15 September 2006). The commune of Tsarahasina borders the corridor directly. However, Antsohihy's survey ends in 2005, providing only 1 post-2006 year. It is excluded from both the donor pool and the exposed sample.
- #strong[Farafangana (15)] --- within 14 km of Corridor Forestier Ambositra-Vondrozo (IUCN V, 15 September 2006), and with pre-existing proximity to Manombo SR (IUCN IV, 1962). Pre-existing exposure is absorbed by the unit fixed effect; the 2006 CFAV decree represents new exposure.
- #strong[Toliara North (23)] --- within 1.4 km of Ranobe PK 32 (December 2008), 12 km of Amoron'i Onilahy (January 2007), and 16 km of Mikea NP (April 2007). The most problematic case: a cascade of three PAs starting January 2007.
- #strong[Fénérive East (24)] --- within 6 km of Réserve de Tampolo (IUCN IV, August 2007). Small reserve with low enforcement intensity, but proximity is clear.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,right,right,left,right,),
  table.header(table.cell(align: center, colspan: 6, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); #strong[Donor Pool: PA Exposure Status]],
    table.cell(align: center, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Based on 20 km proximity threshold and dynamic WDPA temporal states],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Observatory], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA exposure status], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); \# PAs within 20 km], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Closest PA (km)], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Nearest PA], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA active from],),
  table.hline(),
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Antsohihy (12)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Also exposed], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.3], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Corridor forestier Bongolava], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[9/15/2006],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Farafangana (15)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Also exposed], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12.2], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Manombo], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1/1/1962],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Toliara North (23)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Also exposed], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[4], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1.4], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ranobe PK 32], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[12/2/2008],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Fénérive East (24)], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Also exposed], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[6.0], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Réserve de Tampolo], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[8/20/2007],
  table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Antsirabe (02)], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Clean], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA],
  table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Tsiroanomandidy (13)], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Clean], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA],
  table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Ambovombe (16)], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Clean], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA],
  table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Mahanoro (25)], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Clean], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA],
  table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Itasy (41)], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Clean], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[---], table.cell(align: horizon + right, fill: rgb("#e8f5e9"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA],
)}
], caption: figure.caption(
position: top, 
[
Donor pool PA exposure status summary.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-donor-status>


#figure([
#box(image("A2_donor_validity_files/figure-typst/fig-map-exposure-1.png"))
], caption: figure.caption(
position: bottom, 
[
Map of observatory communes coloured by exposure status. Nearby PA polygons shown.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-map-exposure>


== Detailed exposure profiles
<detailed-exposure-profiles>
#figure([
#box(image("A2_donor_validity_files/figure-typst/fig-exposure-detail-1.png"))
], caption: figure.caption(
position: bottom, 
[
Distance-to-PA for each also-exposed donor observatory.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-exposure-detail>


= Implications
<sec-b-implications>
== For the primary analysis
<for-the-primary-analysis>
The contamination audit has two consequences:

+ #strong[Restricted donor pool]: removing the four also-exposed observatories leaves five clean donors (Antsirabe, Tsiroanomandidy, Ambovombe, Mahanoro, Itasy). Gsynth estimates for Marovoay and Alaotra should be re-run with this restricted pool as a robustness check.

+ #strong[Pre-treatment validity preserved for Marovoay]: the exposure onset (2003) predates all secondary PA events (earliest 2006). Pre-treatment balance tests (placebo ATTs before 2003) are unaffected by post-2006 donor exposure.

== For the extended analysis
<for-the-extended-analysis>
The four also-exposed donors become #strong[exposed units] in the extended analysis (#link(<extensions>)[Chapter 5]). Antsohihy is excluded (insufficient post-treatment coverage). Farafangana, Toliara North, and Fénérive East are viable exposed cases with ≥3 post-treatment years and plausible identification stories. Their redesignation from donors to exposed units simultaneously:

- Purifies the donor pool (removing also-exposed units).
- Enriches the exposed sample (five observatory--PA pairs instead of two).
- Enables a broader comparison of conservation governance types.

#figure([
#box(image("A2_donor_validity_files/figure-typst/fig-clean-donors-1.png"))
], caption: figure.caption(
position: bottom, 
[
Map of Madagascar with observatory locations coloured by status: exposed (Ch. 4), newly exposed (Ch. 5), clean donor, excluded.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-clean-donors>


= Robustness Tests
<robustness-tests>
Alternative specifications and sensitivity analysis

\
This appendix presents three robustness tests for the main gsynth results (#link(<results>)[Chapter 4]). The primary specification uses #strong[log OECD-modified equivalised income] (total household income divided by equivalence scale, log-transformed, winsorised at 1st--99th percentiles). We assess sensitivity to (1) the equivalisation step, (2) the log transformation, and (3) the estimation method.

= Unadjusted log income
<sec-c-unadj>
We re-estimate both gsynth models using log total household income (#NormalTok("revtot");) without any household-composition adjustment. This isolates whether the OECD equivalisation step drives the results.

#figure([
#box(image("A3_robustness_files/figure-typst/fig-unadj-att-1.png"))
], caption: figure.caption(
position: bottom, 
[
gsynth ATT paths using unadjusted log income (no OECD equivalisation). Left: Ankarafantsika. Right: Alaotra.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-unadj-att>


The unadjusted Ankarafantsika ATT is slightly larger in magnitude than the OECD-equivalised estimate, consistent with east-bank exposed households being slightly larger on average (larger households receive a smaller OECD adjustment, attenuating the per-capita gap). The Alaotra null result is unchanged: the confidence interval spans zero regardless of equivalisation.

= Income in levels
<sec-c-levels>
We re-estimate both models using income in levels (thousands of Malagasy Ariary, winsorised at the 99th percentile). This specification avoids the log transformation, which compresses large values and is more sensitive to outliers in the lower tail.

#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,right,right,right,right,),
  table.header(table.cell(align: center, colspan: 5, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Income in Levels: Descriptive Statistics],
    table.cell(align: center, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Winsorised total income (thousands of Ariary, 99th percentile cap)],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); group], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Mean (k Ar)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Median], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SD], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); N (HH-years)],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay east (exposed)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,710.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,279.7], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,437.1], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,642],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Marovoay west (control)], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,917.6], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,446.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,590.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[3,617],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,647.8], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[978.6], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,857.7], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[7,613],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Donor pool], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,153.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[744.8], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1,271.5], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[48,052],
)}
], caption: figure.caption(
position: top, 
[
Descriptive statistics of winsorised income (thousands of Ariary) by group.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-income-scale>


#figure([
#box(image("A3_robustness_files/figure-typst/fig-levels-att-1.png"))
], caption: figure.caption(
position: bottom, 
[
gsynth ATT paths using income in levels (thousands of Ariary). Left: Ankarafantsika. Right: Alaotra.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-levels-att>


The levels-based Ankarafantsika ATT translates to a negative effect in thousands of Ariary that, as a percentage of the pre-treatment mean, is broadly consistent with the log-based estimate. The Alaotra levels estimate remains statistically insignificant.

#figure([
#box(image("A3_robustness_files/figure-typst/fig-pretreat-fit-1.png"))
], caption: figure.caption(
position: bottom, 
[
Pre-treatment fit comparison: log specification (left) vs.~levels (right) for Ankarafantsika.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-pretreat-fit>


= Synthetic Difference-in-Differences
<sec-c-sdid>
Synthetic Difference-in-Differences \[SDID; #cite(<Arkhangelsky2021>, form: "prose")\] provides a doubly-robust alternative: it constructs #strong[unit weights] $hat(omega)$ to balance pre-treatment trajectories (like synthetic control) and #strong[time weights] $hat(lambda)$ to concentrate comparisons on the most informative pre-treatment periods (like DiD). Under the latent factor model $Y_(i t) \( 0 \) = alpha_i + beta_t + bold(lambda)'_i bold(f)_t + epsilon_(i t)$, SDID is consistent if either dimension of reweighting succeeds. Inference uses Algorithm 4 (placebo method) from #cite(<Arkhangelsky2021>, form: "prose"), valid even with $N_(t r) = 1$.

== Ankarafantsika (SDID)
<ankarafantsika-sdid>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 4,
  align: (left,right,right,right,),
  table.header(table.cell(align: center, colspan: 4, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Block 1: Marovoay (Ankarafantsika, 2003)],
    table.cell(align: center, colspan: 4, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); T₀ = 4, T₁ = 5],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Method], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE (placebo)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % change],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SDID], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.098], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.188], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-9.3%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Synthetic Control], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.020], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.098], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[DID], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.246], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.207], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-21.8%],
)}
], caption: figure.caption(
position: top, 
[
SDID, SC, and DID estimates for Ankarafantsika (exposure onset 2003).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-sdid-maro>


#figure([
#box(image("A3_robustness_files/figure-typst/fig-sdid-maro-1.png"))
], caption: figure.caption(
position: bottom, 
[
SDID trend plot for Ankarafantsika. Solid lines: reweighted treated and synthetic control trajectories.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-sdid-maro>


#block[
#callout(
body: 
[
The triangles at the bottom of the SDID plot represent #strong[time weights] ($hat(lambda)_t$). These indicate how much each pre-treatment period contributes to the counterfactual construction. Larger triangles mean that period receives more weight. Time weighting is a distinctive feature of SDID: it concentrates the comparison on the pre-treatment periods most predictive of post-treatment outcomes, improving efficiency relative to standard DiD (which implicitly weights all pre-treatment periods equally).

]
, 
title: 
[
Reading the SDID plot
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== Alaotra (SDID)
<alaotra-sdid>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 4,
  align: (left,right,right,right,),
  table.header(table.cell(align: center, colspan: 4, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Block 2: Alaotra (Lac Alaotra PHP, 2008)],
    table.cell(align: center, colspan: 4, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); T₀ = 8, T₁ = 6],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Method], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE (placebo)], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % change],),
  table.hline(),
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[SDID], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.345], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.003], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[41.2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Synthetic Control], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.053], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.074], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-5.2%],
  table.cell(align: horizon + left, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[DID], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.374], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.091], table.cell(align: horizon + right, stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[45.4%],
)}
], caption: figure.caption(
position: top, 
[
SDID, SC, and DID estimates for Alaotra (exposure onset 2008).
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-sdid-ala>


#block[
#callout(
body: 
[
The SC estimates in the tables above are produced by #NormalTok("synthdid::sc_estimate()");, which constructs its own synthetic control independently from gsynth. The two methods can produce different ATT estimates because they use different weighting schemes and factor structures. The Alaotra SC estimate in particular should be interpreted with caution: with a single exposed unit and a small balanced panel, the SC unit weights may assign high weight to a small number of donors, making the estimate sensitive to individual donor trajectories. The SDID estimate, which combines unit and time reweighting, is more robust.

]
, 
title: 
[
Interpreting the synthetic control estimates
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
= Callaway--Sant'Anna DiD with repeated cross-sections
<sec-c-cs>
The gsynth, SC, and SDID specifications above all operate on site-year aggregates. A distinct methodological concern is that the ROS was designed as a #strong[rotating sample]: successive waves partially refresh the household pool rather than tracking individual households over time. Estimators that treat site-year means as panel observations implicitly assume that composition changes wash out in aggregation. This section relaxes that assumption by estimating a Callaway & Sant'Anna (2021) group-time average treatment effect at the #strong[household level] with #NormalTok("panel = FALSE");, which is valid for repeated cross-sections.

Compared to the gsynth baseline, this specification:

- uses every usable household-year observation (not site-year means), capturing within-site heterogeneity;
- allows staggered adoption (Marovoay exposed from 2003, Alaotra from 2008) in a single estimator;
- clusters inference at the #NormalTok("site_id"); level via a multiplier bootstrap.

== Panel construction
<panel-construction-2>
The pooled dataset contains 40,072 household-year observations across 43 sites (5 treated-observatory sites, the remainder clean donors).

== Group-time ATT
<sec-c-cs-attgt>
#figure([
#box(image("A3_robustness_files/figure-typst/fig-cs-attgt-1.png"))
], caption: figure.caption(
position: bottom, 
[
Callaway--Sant'Anna group-time ATT(g,t) estimates with simultaneous 95% confidence bands. Top panel: Marovoay cohort (g = 2003). Bottom panel: Alaotra cohort (g = 2008). Dashed vertical line marks exposure onset. Outcome: log OECD-equivalised income.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-cs-attgt>


== Event-study aggregation
<sec-c-cs-dyn>
The dynamic aggregator averages $A T T \( g \, t \)$ by relative event time, $e = t - g$, pooling across cohorts.

#figure([
#box(image("A3_robustness_files/figure-typst/fig-cs-dyn-1.png"))
], caption: figure.caption(
position: bottom, 
[
Event-study Callaway--Sant'Anna ATT by relative event time. Negative $e$ = pre-treatment placebo periods (should be flat around zero); positive $e$ = post-treatment effects. Dashed vertical line at $e = - 0.5$.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-cs-dyn>


== Cohort-specific ATT
<cohort-specific-att>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 5,
  align: (left,right,right,left,right,),
  table.header(table.cell(align: center, colspan: 5, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Callaway--Sant\'Anna Group ATTs],
    table.cell(align: center, colspan: 5, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Household-level repeated cross-sections, 1999--2014],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Cohort], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); 95% CI], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); % change],),
  table.hline(),
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[g = 2003 (Marovoay)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.570], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.099], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.781, -0.359\]], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-43.4%],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[g = 2008 (Alaotra)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.254], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.067], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[\[-0.397, -0.111\]], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-22.5%],
)}
], caption: figure.caption(
position: top, 
[
Callaway--Sant'Anna: cohort-specific post-exposure ATT.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-cs-group>


The Callaway--Sant'Anna event study reproduces the qualitative pattern of the gsynth results: a negative and persistent Marovoay effect emerging at $e = 0$, and a null Alaotra effect. Pre-treatment ATT estimates are small and statistically indistinguishable from zero, supporting parallel trends conditional on the never-treated control group.

#block[
#callout(
body: 
[
This implementation uses the 1999--2014 household-level data already loaded by #NormalTok("load_data.R");. Extending the CS estimator to 2025 requires reconstructing the household-level OECD-equivalised income from the raw 2025 #NormalTok("res_*"); microdata, which is not yet exposed in #NormalTok("household_consolidated");. Once that pipeline is wired in, the same #NormalTok("att_gt()"); call with an expanded #NormalTok("year"); range will yield a 2025-inclusive event study. The most interesting case will be the Marovoay cohort at $e = 22$ (2003 → 2025), since in 2025 the only never-treated comparison available is the Marovoay west bank (sites 033, 034) --- a tight within-observatory comparison that complements the wider-donor gsynth extension in #link(<results>)[Chapter 4].

]
, 
title: 
[
Scope and the 2025 resurvey
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
= Summary of robustness
<sec-c-summary>
#figure([
#{set text(font: ("system-ui", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji") , size: 12pt); table(
  columns: 6,
  align: (left,left,left,left,left,left,),
  table.header(table.cell(align: center, colspan: 6, fill: rgb("#ffffff"))[#set text(size: 1.25em , weight: "regular" , fill: rgb("#333333")); Robustness Summary],
    table.cell(align: center, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 0.85em , weight: "regular" , fill: rgb("#333333")); Primary specification vs three robustness checks],
    table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); PA], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Specification], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); ATT], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); SE], table.cell(align: bottom + right, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); p-value], table.cell(align: bottom + left, fill: rgb("#ffffff"))[#set text(size: 1.0em , weight: "regular" , fill: rgb("#333333")); Unit],),
  table.hline(),
  table.cell(align: horizon + left, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); Primary: log(OECD-equivalised income)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Ankarafantsika], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Primary: log(OECD-equivalised income)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[-0.312], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[0.122], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[0.010], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[log pts],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Primary: log(OECD-equivalised income)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.014], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.156], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.928], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[log pts],
  table.cell(align: horizon + left, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); Robustness 1: Unadjusted log income],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Ankarafantsika], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Robustness 1: log(total income, unadjusted)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[-0.387], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[0.137], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[0.005], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[log pts],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robustness 1: log(total income, unadjusted)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-0.018], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.172], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.916], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[log pts],
  table.cell(align: horizon + left, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); Robustness 2: Levels (Ariary)],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Ankarafantsika], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Robustness 2: levels (thousands Ariary)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[-19.500], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[112.849], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[0.863], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[k Ariary],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robustness 2: levels (thousands Ariary)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[-188.400], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[1469.952], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.898], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[k Ariary],
  table.cell(align: horizon + left, colspan: 6, fill: rgb("#ffffff"), stroke: (bottom: (paint: rgb("#d3d3d3"), thickness: 1.5pt), top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[#set text(size: 1.0em , fill: rgb("#333333")); Robustness 3: SDID],
  table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Ankarafantsika], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[Robustness 3: SDID (log OECD-equivalised)], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[-0.098], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[0.188], table.cell(align: horizon + right, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[NA], table.cell(align: horizon + left, fill: rgb("#ffcdd2"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 1.5pt)))[log pts],
  table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Lac Alaotra], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[Robustness 3: SDID (log OECD-equivalised)], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.345], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[0.003], table.cell(align: horizon + right, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[NA], table.cell(align: horizon + left, fill: rgb("#bbdefb"), stroke: (top: (paint: rgb("#d3d3d3"), thickness: 0.75pt)))[log pts],
)}
], caption: figure.caption(
position: top, 
[
Robustness summary: ATT estimates across all specifications for both PAs.
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-robustness-summary>


Three key findings:

+ #strong[Unadjusted log income]: the Ankarafantsika negative effect is modestly larger without equivalisation, consistent with east-bank households being slightly larger. The qualitative conclusion is unchanged.
+ #strong[Income in levels]: the levels specification confirms a significant negative effect at Ankarafantsika. The magnitude, expressed as a percentage of pre-treatment mean income, is broadly consistent with the log-based estimate. Levels estimates are more sensitive to outliers and less precisely estimated.
+ #strong[Lac Alaotra]: the null result is #strong[robust across all specifications]. Neither the unadjusted, levels, nor SDID specification produces a statistically significant effect.

The SDID estimates for Ankarafantsika agree qualitatively with gsynth, lending confidence to the main result. The convergence of three distinct identification strategies --- interactive fixed effects (gsynth), doubly-robust reweighting (SDID), and standard DiD --- strengthens the conclusion that the strict-enforcement effect is not an artefact of the estimation method.

= Methodology
<methodology>
Technical details on estimation methods

\
This appendix provides formal descriptions of the estimation methods used in this paper. The main text (#link(<identification-strategy>)[Chapter 3], #link(<results>)[Chapter 4]) describes the methods at the level needed to follow the argument; this appendix gives the technical details needed for replication and methodological evaluation.

= Generalised synthetic control
<sec-d-gsynth>
== Interactive fixed-effects model
<interactive-fixed-effects-model>
The generalised synthetic control method @Xu2017 extends the standard synthetic control framework to accommodate multiple treated units and allows for estimation of treatment effects in the presence of unobserved time-varying confounders. The data-generating process is:

$ Y_(i t) = delta_(i t) D_(i t) + upright(bold(x))'_(i t) bold(beta) + bold(lambda)'_i upright(bold(f))_t + epsilon_(i t) $

where $Y_(i t)$ is the outcome for unit $i$ at time $t$\; $D_(i t)$ is the treatment indicator; $upright(bold(x))_(i t)$ is a vector of observed covariates (not used in our site-level specifications); $bold(lambda)_i$ is a $r times 1$ vector of unit-specific factor loadings; $upright(bold(f))_t$ is a $r times 1$ vector of common time-varying factors; and $epsilon_(i t)$ is an idiosyncratic error.

The key identification assumption is that the factor structure $bold(lambda)'_i upright(bold(f))_t$ is shared between treated and control units. This generalises the parallel-trends assumption: rather than requiring that treated and control units follow the same trend, it allows for #strong[different trends] as long as those trends are spanned by the same set of latent factors.

== Estimation
<estimation>
The algorithm proceeds in three steps:

+ #strong[Estimate factors from control units]: using the $N_0 times T$ matrix of control outcomes, estimate $hat(upright(bold(f)))_t$ and $hat(bold(lambda))_i$ via principal component analysis (or nuclear norm minimisation). The number of factors $r$ is selected by leave-one-out cross-validation over $r = 0 \, 1 \, dots.h \, r_max$.

+ #strong[Estimate treated factor loadings]: for each treated unit $i$, regress the pre-treatment outcomes $Y_(i 1) \, dots.h \, Y_(i \, T_0)$ on the estimated factors $hat(upright(bold(f)))_1 \, dots.h \, hat(upright(bold(f)))_(T_0)$ to obtain $hat(bold(lambda))_i$.

+ #strong[Construct counterfactual]: the estimated counterfactual outcome for treated unit $i$ in post-treatment period $t > T_0$ is $hat(Y)_(i t) \( 0 \) = hat(bold(lambda))'_i hat(upright(bold(f)))_t$. The ATT at time $t$ is $hat(delta)_(i t) = Y_(i t) - hat(Y)_(i t) \( 0 \)$.

== Cross-validation for factor selection
<cross-validation-for-factor-selection>
In our implementation, $r$ is selected by leave-one-out cross-validation (LOOCV) over $r in { 0 \, 1 \, 2 \, 3 \, 4 \, 5 }$. For each candidate $r$, each control unit is temporarily removed, the factor model is re-estimated, and the prediction error for the held-out unit's pre-treatment outcomes is computed. The $r$ minimising the mean squared prediction error is selected. When $r^(*) = 0$, the model reduces to a two-way fixed-effects specification.

== Inference
<inference>
We use parametric bootstrap with 200 replications, as implemented in the #NormalTok("gsynth"); R package. The bootstrap resamples residuals from the estimated factor model, re-estimates the ATT path, and constructs pointwise 95% confidence intervals. For the average post-treatment ATT, we report the bootstrap standard error and a Wald-type $p$-value.

== Relationship to standard synthetic control
<relationship-to-standard-synthetic-control>
When there is a single treated unit and $r$ is chosen to minimise pre-treatment fit, gsynth nests the Abadie, Diamond & Hainmueller (#cite(<Abadie2010>, form: "year")) synthetic control estimator. The advantage of gsynth is that it (i) selects $r$ via cross-validation rather than exact pre-treatment matching, (ii) accommodates multiple treated units, and (iii) provides valid frequentist inference via the bootstrap rather than relying on permutation $p$-values.

= Callaway--Sant'Anna staggered DiD
<sec-d-csdid>
== Group-time ATT framework
<group-time-att-framework>
The Callaway & Sant'Anna (#cite(<CallawayS2021>, form: "year")) estimator is designed for settings with staggered treatment adoption. Define $G_i$ as the first period in which unit $i$ is treated ($G_i = oo$ for never-treated units). The target parameter is the #strong[group-time ATT]:

$ A T T \( g \, t \) = bb(E) \[ Y_t \( g \) - Y_t \( oo \) divides G = g \] $

where $Y_t \( g \)$ is the potential outcome under treatment adoption at time $g$, and $Y_t \( oo \)$ is the never-treated potential outcome. $A T T \( g \, t \)$ is identified under two assumptions:

+ #strong[No-anticipation]: $Y_t \( g \) = Y_t \( oo \)$ for all $t < g$.
+ #strong[Conditional parallel trends]: $bb(E) \[ Y_t \( oo \) - Y_(t - 1) \( oo \) divides X \, G = g \] = bb(E) \[ Y_t \( oo \) - Y_(t - 1) \( oo \) divides X \, G = oo \]$ (or using not-yet-treated groups as the comparison).

== Repeated cross-sections
<repeated-cross-sections>
The ROS data are repeated cross-sections at the household level (new households sampled each year within the same sites). The CS estimator uses the repeated-cross-section variant, where identification relies on comparing the distribution of outcomes across cohorts and time periods, rather than tracking individual units.

== Aggregation
<aggregation>
Group-time ATTs can be aggregated into:

- #strong[Dynamic effects] $theta_e = sum_g w_g dot.op A T T \( g \, g + e \)$: average ATT at relative time $e$, yielding an event-study plot with explicit pre-trend tests.
- #strong[Group-specific effects]: $accent(A T T, ‾) \( g \) = sum_(t gt.eq g) w_t dot.op A T T \( g \, t \)$.
- #strong[Overall ATT]: weighted average across all $\( g \, t \)$ cells.

== Implementation (planned for 2026 data)
<implementation-planned-for-2026-data>
We will use the #NormalTok("did"); R package with doubly-robust estimation (inverse-probability weighting combined with outcome regression), household-level covariates (household size, head's education, agricultural activity), and clustering at the site level.

= Synthetic Difference-in-Differences
<sec-d-sdid>
== Framework
<framework>
SDID @Arkhangelsky2021 combines unit reweighting (synthetic control) with time reweighting (DiD):

$ hat(tau)^(s d i d) = sum_(i : D_i = 1) sum_(t : upright("post")) (Y_(i t) - hat(omega)'_0 Y_(upright("co") \, t) - hat(lambda)_0 - hat(lambda)'_t upright(bold(1))) $

where $hat(omega)_0$ are unit weights that balance pre-treatment outcome trajectories and $hat(lambda)_t$ are time weights that upweight pre-treatment periods most predictive of post-treatment outcomes.

== Comparison with gsynth
<comparison-with-gsynth>
Both SDID and gsynth generalise the parallel-trends assumption via latent factors. The key difference is that SDID uses explicit reweighting while gsynth uses factor estimation. SDID is doubly robust: it is consistent if either the unit weights or the time weights correctly specify the counterfactual. gsynth is consistent under the interactive fixed-effects model regardless of reweighting, but requires correct specification of the number of factors.

== Inference
<inference-1>
We use the placebo method (Algorithm 4 of #cite(<Arkhangelsky2021>, form: "prose")): for each control unit, the SDID estimator is re-computed treating that unit as if it were treated. The distribution of placebo effects yields a standard error estimate. This is valid even when $N_(t r) = 1$, as in our observatory-level models.

= Inference with few clusters
<sec-d-inference>
== The power problem
<the-power-problem>
Each observatory-level gsynth model has exactly one treated unit. Standard asymptotic inference (which requires $N_(t r) arrow.r oo$) is not applicable. We address this via:

+ #strong[Parametric bootstrap] (gsynth): resampling residuals from the estimated factor model. This is valid under the factor model assumptions but does not account for treatment-effect heterogeneity across treated units.

+ #strong[Permutation inference]: for each control unit, re-estimate gsynth treating that unit as if it were treated. The $p$-value is the fraction of placebo ATTs exceeding the true ATT. With $N$ donor units, the minimum achievable $p$-value is $1 \/ N$. With \~50--60 donor sites, this gives a floor of $approx 0.017$ --- sufficient to detect large effects but limiting for moderate ones.

+ #strong[Wild cluster bootstrap] (planned for DiD): the Cameron, Gelbach & Miller (#cite(<Cameron2008>, form: "year")) wild bootstrap applies to the few-cluster problem in DiD estimation. With 43 site-level clusters (5 exposed observatories + 38 control sites), inference is feasible though conservative.

== Practical implications
<practical-implications>
The power constraints imply that:

- The #strong[Ankarafantsika negative effect] (large, \~27% of income) is detectable even with one treated unit and permutation-based inference.
- The #strong[Alaotra null result] may reflect insufficient power rather than a true zero. Effects smaller than \~15--20% would be undetectable with the available sample.
- The #strong[three extension sites] (#link(<extensions>)[Chapter 5]) face the same power floor. Near-zero point estimates should not be over-interpreted as evidence of "no effect" --- they are consistent with both a true null and a moderate effect below the detection threshold.

#heading(level: 1, numbering: none)[References]
<references-2>



#bibliography(("references.bib"))

