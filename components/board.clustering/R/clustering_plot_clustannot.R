##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

clustering_plot_clusterannot_ui <- function(
  id,
  label = "",
  title,
  info.text,
  caption,
  height,
  width)
{
  ns <- shiny::NS(id)

  clustannot_plots.opts <- shiny::tagList(
    withTooltip(
      shiny::selectInput(ns("xann_level"), "Reference level:",
        choices = c("gene", "geneset", "phenotype"),
        selected = "geneset", width = "80%"
      ),
      "Select the level of an anotation analysis.",
      placement = "left", options = list(container = "body")
    ),
    shiny::conditionalPanel(
      "input.xann_level == 'geneset'",
      ns = ns,
      withTooltip(shiny::checkboxInput(ns("xann_odds_weighting"), "Fisher test weighting"),
        "Enable weighting with Fisher test probability for gene sets. This will effectively penalize small clusters and increase robustness.",
        placement = "left", options = list(container = "body")
      )
    ),
    withTooltip(shiny::selectInput(ns("xann_refset"), "Reference set:", choices = "", width = "80%"),
      "Specify a reference set to be used in the annotation.",
      placement = "left", options = list(container = "body")
    )
  )

  PlotModuleUI(
    ns("pltmod"),
    label = label,
    plotlib = "plotly",
    title = title,
    info.text = info.text,
    caption = caption,
    options = clustannot_plots.opts,
    download.fmt = c("png", "pdf"),
    width = width,
    height = height
  )
}

clustering_plot_clusterannot_server <- function(id,
                                                pgx,
                                                getClustAnnotCorrelation,
                                                watermark = FALSE) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    shiny::observe({

      shiny::req(pgx$X, pgx$gsetX, pgx$families)
      dbg("[clustering_plot_clustannot.R] observe : triggered ")

      if (is.null(input$xann_level)) {
        return(NULL)
      }
      ann.types <- sel <- NULL
      if (input$xann_level != "phenotype") {
        if (input$xann_level == "geneset") {
          ann.types <- names(playdata::COLLECTIONS)
          cc <- sapply(playdata::COLLECTIONS, function(s) length(intersect(s, rownames(pgx$gsetX))))
          ann.types <- ann.types[cc >= 3]
        }
        if (input$xann_level == "gene") {
          ann.types <- names(pgx$families)
          cc <- sapply(pgx$families, function(g) length(intersect(g, rownames(pgx$X))))
          ann.types <- ann.types[cc >= 3]
        }
        ann.types <- setdiff(ann.types, "<all>") ## avoid slow...
        ann.types <- grep("^<", ann.types, invert = TRUE, value = TRUE) ## remove special groups
        sel <- ann.types[1]
        if ("H" %in% ann.types) sel <- "H"
        j <- grep("^transcription", ann.types, ignore.case = TRUE)
        if (input$xann_level == "geneset") j <- grep("hallmark", ann.types, ignore.case = TRUE)
        if (length(j) > 0) sel <- ann.types[j[1]]
        ann.types <- sort(ann.types)
      } else {
        ann.types <- sel <- "<all>"
      }
      dbg("[clustering_plot_clustannot.R] observe : shiny::updateSelectInput ")
      shiny::updateSelectInput(session, "xann_refset", choices = ann.types, selected = sel)
    })

    plot_data <- function() {
      getClustAnnotCorrelation()
    }

    ##    clustannot_plots.PLOTLY <- shiny::reactive({
    createAnnotBarPlots <- function(fontsize=10) {

      rho <- plot_data()
      if(is.null(rho)) return(NULL)

      ## par(mfrow=c(2,3), mar=c(3.5,2,2,1), mgp=c(2,0.8,0))
      NTERMS <- 6
      NTERMS <- 12
      slen <- 40
      if (ncol(rho) >= 5) {
        slen <- 20
      }
      if (ncol(rho) > 6) {
        NTERMS <- 6
      }
      if (ncol(rho) <= 2) {
        NTERMS <- 22
      }

      klrpal <- omics_pal_d("muted_light")(ncol(rho))
      # klrpal <- paste0(klrpal, "B3")

      plot_list <- list()
      i <- 1
      for (i in 1:min(9, ncol(rho))) {
        x <- rev(head(sort(rho[, i], decreasing = TRUE), NTERMS))
        names(x) <- sub(".*:", "", names(x))
        names(x) <- gsub(playdata::GSET_PREFIX_REGEX, "", names(x))
        y <- names(x)
        y <- factor(y, levels = y)
        anntitle <- function(tt) {
          list(
            x = 0.5, y = 1.0,
            xref = "paper", yref = "paper",
            xanchor = "center", yanchor = "bottom",
            text = tt, font = list(size = fontsize*1.33),
            align = "center", showarrow = FALSE
          )
        }
        ## NOTE: The same plotly code (originally) as in `plot_clustannot.R`
        ##       -> Seems it uses the function from this file, not the other one
        ## TODO: clean-up; we should stick to the general setup of individual
        ##       scripts for the plotting functions, not inside the server scripts as agreed
        plot_list[[i]] <-
          plotly::plot_ly(
            x = x,
            y = y,
            type = "bar",
            orientation = "h",
            hoverinfo = "text",
            hovertemplate = ~ paste0(
              ## TODO: the cluster ID in the tooltip is assigned wrongly (it's always S4),
              ##       needs to be fixed (or that information to be removed)
              "Annotation: <b>%{y}</b><br>",
              "Cluster: <b>", colnames(rho)[i], "</b><br>",
              "Correlation (R): <b>", sprintf("%1.2f", x), "</b>",
              "<extra></extra>"
            ),
            ## NOTE: I suggest to not use a categorical palette for the different clusters;
            ##       the panels alone highlight the different groups and a single color would
            ##       allow for a fair comparison (in terms of visual weight), solve all
            ##       readability problems and would make the page much more calm
            ## TODO: if you agree, set to single color instead
            marker = list(color = klrpal[i])
          ) %>%
          ## labeling the y-axis inside bars
          plotly::add_annotations(
            x = .01,
            y = y,
            xref = "paper",
            yref = "y",
            xanchor = "left",
            text = playbase::shortstring(y, slen),
            font = list(size = fontsize),
            showarrow = FALSE,
            align = "right"
          ) %>%
          plotly::layout(
            ## TODO: check x axis ranges! while in the lower row x is scaled from 0 to .9,
            ##       in the upper it's ranging free (kinda; when you plot the axis,
            ##       the axis range is the same but the tooltip and axis are out of sync)
            xaxis = list(
              range = c(0, .9),
              titlefont = list(size = fontsize*1.2),
              tickfont = list(size = fontsize),
              showgrid = FALSE,
              title = "\ncorrelation (R)"
            ),
            yaxis = list(
              title = FALSE,
              showgrid = FALSE,
              showline = FALSE,
              showticklabels = FALSE,
              showgrid = FALSE,
              zeroline = FALSE
            ),
            showlegend = FALSE,
            annotations = anntitle(colnames(rho)[i]),
            bargap = .2,
            margin = list(l = 5, r = 0, b = 15, t = 42)
          ) %>%
          plotly_default() 
      }

      if (length(plot_list) <= 4) {
        nrows <- ceiling(length(plot_list) / 2)
      } else {
        nrows <- ceiling(length(plot_list) / 3)
      }

      p <- plotly::subplot(
        plot_list,
        nrows = nrows,
        shareX = TRUE,
        margin = c(0.01, 0.01, .05, .05)
      )

      p <- p %>%
        plotly::layout(
          margin = list(l = 5, r = 0, b = 15, t = 20)
        ) %>%
        plotly::config(displayModeBar = FALSE)
      p
    }

    clustannot_plots.PLOTLY <- function() {
      createAnnotBarPlots(fontsize=10)
    }

    clustannot_plots.PLOTLY_modal <- function() {
      createAnnotBarPlots(fontsize=15)
    }

    PlotModuleServer(
      "pltmod",
      plotlib = "plotly",
      func = clustannot_plots.PLOTLY,
      func2 = clustannot_plots.PLOTLY_modal,
      csvFunc = plot_data,   ##  *** downloadable data as CSV
      res = 80, ## resolution of plots
      remove_margins = FALSE,
      pdf.width = 8, pdf.height = 5,
      add.watermark = watermark
    )

    return(
      list(
        xann_level = shiny::reactive(input$xann_level),
        xann_odds_weighting = shiny::reactive(input$xann_odds_weighting),
        xann_refset = shiny::reactive(input$xann_refset)
      )
    )
  })
}
