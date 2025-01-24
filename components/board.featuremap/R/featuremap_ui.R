##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

FeatureMapInputs <- function(id) {
  ns <- shiny::NS(id) ## namespace
  bigdash::tabSettings(
    shiny::br(),
    ## data set parameters
    withTooltip(shiny::selectInput(ns("sigvar"), "Show phenotype:", choices = NULL, multiple = FALSE),
      "Select the phenotype to show in the signatures plot.",
      placement = "top"
    ),
    hr(),        
    withTooltip(
      shiny::selectInput(ns("filter_genes"), "Annotate genes:",
        choices = NULL, multiple = FALSE
      ),
      "Filter the genes to highlight on the map.",
      placement = "right", options = list(container = "body")
    ),
    withTooltip(
      shiny::selectInput(ns("filter_gsets"), "Annotate genesets:",
        choices = NULL, multiple = FALSE
      ),
      "Filter the genesets to highlight on the map.",
      placement = "right", options = list(container = "body")
    ),
    shiny::hr(),
    withTooltip(
      shiny::checkboxInput(ns("show_fulltable"), "Show full table", FALSE),
      "Show full table. Not filtered."
    ),
    shiny::br(),
    shiny::br(),
    withTooltip(shiny::actionLink(ns("options"), "Advanced options", icon = icon("cog", lib = "glyphicon")),
      "Toggle advanced options.",
      placement = "top"
    ),
    shiny::br(), br(),
    shiny::conditionalPanel(
      "input.options % 2 == 1",
      ns = ns,
      shiny::tagList(
        withTooltip(
          shiny::selectInput(ns("ref_group"), "Reference:", choices = NULL),
          "Reference group. If no group is selected the average is used as reference.",
          placement = "right", options = list(container = "body")
        ),
        hr(),
        withTooltip(
          shiny::radioButtons(ns("umap_type"), "UMAP datatype:",
            choices = c("logCPM", "logFC"), inline = TRUE
          ),
          "The UMAP can be computed from the normalized log-expression (logCPM), or from the log-foldchange matrix (logFC). Clustering based on logCPM is the default, but when batch/tissue effects are present the logFC might be better.",
          placement = "right", options = list(container = "body")
        )
      )
    )
  )
}

FeatureMapUI <- function(id) {
  ns <- shiny::NS(id) ## namespace

  height1 <- c("calc(60vh - 100px)", "70vh")
  height2 <- c("calc(40vh - 100px)", "70vh")

  div(
    boardHeader(title = "Cluster features", info_link = ns("info")),
    bs_alert("Visually explore and compare expression signatures on UMAP plots. Feature-level clustering is based on pairwise co-expression between genes (or genesets). This is in contrast to sample-level clustering which clusters samples by similarity of their expression profile. Feature-level clustering allows one to detect gene modules, explore gene neighbourhoods, and identify potential drivers. By coloring the UMAP with the foldchange, one can visually compare the global effect between different conditions."),
    shiny::tabsetPanel(
      id = ns("tabs"),
      shiny::tabPanel(
        "Gene",
        bslib::layout_column_wrap(
          width = 1,
          heights_equal = "row",
          bslib::layout_column_wrap(
            width = 1/2,
            featuremap_plot_gene_map_ui(
                ns("geneUMAP"),
                title = "Gene UMAP",
                info.text = "UMAP clustering of genes colored by standard-deviation of log-expression(sd.X), or standard-deviation of the fold-change (sd.FC). The distance metric is covariance of the gene expression. Genes that are clustered nearby have high covariance.The colour intensity threshold can be set with the Settings icon.",
                caption = "Gene UMAP coloured by level of variance. Shades of red indicate high variance.",
                height = height1,
                width = c("auto", "100%")
            ),
            featuremap_plot_gene_sig_ui(
                ns("geneSigPlots"),
                title = "Gene signatures",
                info.text = "UMAP clustering of genes colored by relative log-expression of the phenotype group. The distance metric is covariance. Genes that are clustered nearby have high covariance.",
                caption = "Gene signature maps coloured by differential expression.",
                height = height1,
                width =  c("auto", "100%")
            )
          ),
          featuremap_table_gene_map_ui(
              ns("geneUMAP"),
              title = "Gene table",
              info.text = "The contents of this table can be subsetted by selecting (by click&drag) on the Gene map plot.",
              caption = "",
              height = height2,
              width = c("auto", "100%")
          )
        )
      ),
      shiny::tabPanel(
        "Geneset",
        bslib::layout_column_wrap(
          width = 1,
          heights_equal = "row",
          bslib::layout_column_wrap(
            width = 1/2,
            featuremap_plot_geneset_map_ui(
                ns("gsetUMAP"),
                title = "Geneset UMAP",
                info.text = "UMAP clustering of genesets colored by standard-deviation of log-expression(sd.X), or standard-deviation of the fold-change (sd.FC). The distance metric is covariance of the geneset expression. Genesets that are clustered nearby have high covariance. The colour intensity threshold can be set with the Settings icon.",
                caption = "Geneset UMAP coloured by level of variance. Shades of red indicate high variance.",
                height = height1,
                width = c("auto", "100%")
            ),
            featuremap_plot_gset_sig_ui(
                ns("gsetSigPlots"),
                title = "Geneset signatures",
                info.text = "UMAP clustering of genesets colored by relative log-expression of the phenotype group. The distance metric is covariance. Genesets that are clustered nearby have high covariance.",
                caption = "Geneset signature maps coloured by differential expression.",
                height = height1,
                width = c("auto", "100%")
            )
          ),
          featuremap_table_geneset_map_ui(
              ns("gsetUMAP"),
              title = "Geneset table",
              info.text = "The contents of this table can be subsetted by selecting an area (by click&drag) on the Geneset map plot.",
              caption = "",
              height = height2,
              width = c("auto", "100%")
          )
        )
      )
    )
  )
}
