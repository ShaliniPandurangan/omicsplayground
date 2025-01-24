##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

featuremap_plot_gene_sig_ui <- function(
  id,
  label = "",
  title,
  caption,
  info.text,
  height,
  width) {
  ns <- shiny::NS(id)

  PlotModuleUI(
    ns("gene_sig"),
    title = title,
    label = "b",
    info.text = info.text,
    caption = caption,
    height = height, 
    width = width,
    download.fmt = c("png", "pdf")
  )
}

featuremap_plot_gene_sig_server <- function(id,
                                            pgx,
                                            getGeneUMAP,
                                            sigvar,
                                            ref_group,                                            
                                            plotFeaturesPanel,
                                            watermark = FALSE) {
  moduleServer(id, function(input, output, session) {

    geneSigPlots.plot_data <- shiny::reactive({
      shiny::req(pgx)

      pos <- getGeneUMAP()

      pheno <- "tissue"
      pheno <- sigvar()
      if (pheno %in% colnames(pgx$samples)) {
        y <- pgx$samples[, pheno]
        ref <- ref_group()
        if(ref == "<average>") {
          refX <- rowMeans(pgx$X)
        } else {
          kk <- which(y == ref)
          refX <- rowMeans(pgx$X[,kk])          
        }        
        X <- pgx$X - refX
        y <- pgx$samples[, pheno]
        F <- do.call(cbind, tapply(1:ncol(X), y, function(i) {
          rowMeans(X[, i, drop = FALSE])
        }))
      } else {
        F <- playbase::pgx.getMetaMatrix(pgx, level = "gene")$fc
      }
      if (nrow(F) == 0) {
        return(NULL)
      }
      return(list(F, pos))
    })

    geneSigPlots.RENDER <- function(){
      dt <- geneSigPlots.plot_data()
      F <- dt[[1]]
      pos <- dt[[2]]

      nc <- ceiling(sqrt(ncol(F)))
      nr <- ceiling(ncol(F) / nc)
      ##nr2 <- ifelse(nr <= 3, nc, nr)
      nr2 <- max(nr,2)
      par(mfrow = c(nr2, nc), mar = c(2, 1, 1, 0), mgp = c(1.6, 0.55, 0), las = 0)
      progress <- NULL
      if (!interactive()) {
        progress <- shiny::Progress$new()
        on.exit(progress$close())
        progress$set(message = "Computing feature plots...", value = 0)
      }
      plotFeaturesPanel(pos, F, ntop = ntop, nr, nc, sel = NULL, progress)
      # p <- grDevices::recordPlot()
      # p
    }

    PlotModuleServer(
      "gene_sig",
      plotlib = "base",
      func = geneSigPlots.RENDER,
      csvFunc = geneSigPlots.plot_data,
      pdf.width = 5, pdf.height = 5,
      res = c(80, 90),
      add.watermark = watermark
    )
  })
}
