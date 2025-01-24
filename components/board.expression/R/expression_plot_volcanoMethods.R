##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

#' Expression plot UI input function
#'
#' @description A shiny Module for plotting (UI code).
#'
#' @param id
#' @param label
#' @param height
#' @param width
#'
#' @export
expression_plot_volcanoMethods_ui <- function(
  id,
  title,
  info.text,
  caption,
  label = "",
  height,
  width) {
  ns <- shiny::NS(id)

  PlotModuleUI(
    ns("pltmod"),
    title = "Volcano plots for all methods",
    label = label,
    plotlib = "ggplot",
    info.text = info.text,
    caption = caption,
    options = NULL,
    download.fmt = c("png", "pdf", "csv"),
    height = height,
    width = width
  )
}

#' Expression plot Server function
#'
#' @description A shiny Module for plotting (server code).
#'
#' @param id
#'
#' @return
#' @export
expression_plot_volcanoMethods_server <- function(id,
                                                  pgx,
                                                  comp, # input$gx_contrast
                                                  features, # input$gx_features
                                                  fdr, # input$gx_fdr
                                                  lfc, # input$gx_lfc
                                                  watermark = FALSE) {
  moduleServer(id, function(input, output, session) {

    ## reactive function listening for changes in input
    plot_data <- shiny::reactive({
      comp <- comp()
      features <- features()

      dbg("[expression_plot_volcanoMethods.R] comp = ",comp)

      if (is.null(comp)) {
        return(NULL)
      }
      shiny::req(pgx)
      if (is.null(features)) {
        return(NULL)
      }

      fdr <- as.numeric(fdr())
      lfc <- as.numeric(lfc())
      sel.genes <- rownames(pgx$X)
      if (features != "<all>") {
        gset <- playdata::getGSETS(features)
        sel.genes <- unique(unlist(gset))
      }

      pd <- list(
          pgx = pgx,
          fdr = fdr,
          lfc = lfc,
          comp = comp,
          sel.genes = sel.genes
      )

      return(pd)
    })

    render_plots <- function(cex=NULL, base_size=11) {
      pd <- plot_data()
      shiny::req(pd)

      ## meta tables
      comp <- pd[["comp"]]
      mx <- pd[["pgx"]]$gx.meta$meta[[comp]]
      fc <- unclass(mx$fc)
      ## pv = unclass(mx$p)
      qv <- unclass(mx$q)
      nlq <- -log10(1e-99 + qv)
      ymax <- max(3, 1.2 * quantile(nlq, probs = 0.999, na.rm = TRUE)[1]) ## y-axis
      xlim <- c(-1.1, 1.1) * max(abs(fc))
      xlim <- 1.3 * c(-1, 1) * quantile(abs(fc), probs = 0.999)
      fc.genes <- pd[["pgx"]]$genes[rownames(mx), "gene_name"]
      nplots <- min(24, ncol(qv))

      ## methods = names(pgx$gx.meta$output)
      methods <- colnames(pd[["pgx"]]$gx.meta$meta[[1]]$fc)
      plt <- list()

      shiny::withProgress(message = "computing volcano plots ...", value = 0, {
        i <- 1
        for (i in 1:nplots) {
          fx <- fc[, i]
          qval <- qv[,i]
          is.sig <- (qval <= pd[["fdr"]] & abs(fx) >= pd[["lfc"]])
          sig.genes <- fc.genes[which(is.sig)]
          genes1 <- sig.genes[which(toupper(sig.genes) %in% toupper(pd[["sel.genes"]]))]
          genes2 <- head(genes1[order(-abs(fx[genes1]) * (-log10(qval[genes1])))], 10)

          xy <- data.frame(x = fx, y = -log10(qval))
          is.sig1 <- fc.genes %in% sig.genes
          is.sig2 <- fc.genes %in% genes2

          plt[[i]] <- playbase::pgx.scatterPlotXY.GGPLOT(
            xy,
            title = methods[i],
            cex.title = 0.85,
            var = is.sig1,
            type = "factor",
            col = c("#bbbbbb", "#1e60bb"),
            legend.pos = "none", ## plotlib="ggplot",
            hilight = genes1,
            hilight2 = genes2,
            xlim = xlim,
            ylim = c(0,ymax),
            xlab = "difference  (log2FC)",
            ylab = "significance  (-log10q)",
            hilight.lwd = 0,
            hilight.col = "#1e60bb",
            hilight.cex = 1.5,
            cex = cex,
            cex.lab = 1.7*cex,
            base_size = base_size
          ) + ggplot2::theme_bw(base_size = base_size)

          if (!interactive()) shiny::incProgress(1 / length(pd[["comp"]]))
        }
      })

      return(plt)
    }

    plot.RENDER <- function() {
      plt <- render_plots(cex=0.45, base_size=11)
      nplots <- length(plt)
      ## layout
      nr = 1
      nc = max(4,nplots)
      if(nplots > 5) {
        nr = 2
        nc = ceiling(nplots/nr)
      }
      if (nplots > 12) {
        nr = 3
        nc = ceiling(nplots/nr)
      }
      gridExtra::grid.arrange(grobs = plt, nrow = nr, ncol = nc)
    }

    modal_plot.RENDER <- function() {
      plt <- render_plots(cex=1, base_size=16)
      nplots <- length(plt)
      ## layout
      nr = 1
      nc = max(2,nplots)
      if(nplots > 3) {
        nr = 2
        nc = ceiling(nplots/nr)
      }
      if (nplots > 8) {
        nr = 3
        nc = ceiling(nplots/nr)
      }
      gridExtra::grid.arrange(grobs = plt, nrow = nr, ncol = nc)
    }

    PlotModuleServer(
      "pltmod",
##      plotlib = "ggplot",
      plotlib = "grid",
      func = plot.RENDER,
      func2 = modal_plot.RENDER,
      ## csvFunc = plot_data, ##  *** downloadable data as CSV
      res = c(80, 170), ## resolution of plots
      pdf.width = 12, pdf.height = 5,
      add.watermark = watermark
    )
  }) ## end of moduleServer
}
