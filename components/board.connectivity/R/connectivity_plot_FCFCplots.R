##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

#' Importance plot UI input function
#'
#' @description A shiny Module for plotting (UI code).
#'
#' @param id
#' @param label
#' @param height
#'
#' @export
connectivity_plot_FCFCplots_ui <- function(
  id,
  title,
  caption,
  info.text,
  height,
  width, 
  label = ""
  ) {
  ns <- shiny::NS(id)

  plot_opts <- shiny::tagList(
    shiny::radioButtons(
      ns("fcfc_plottype"),
      "Plot type:",
      c("scatter", "enrichment"),
      inline = TRUE
    )
  )

  PlotModuleUI(
    ns("plot"),
    title = title,
    label = label,
    plotlib = "base",
    info.text = info.text,
    caption = caption,
    options = plot_opts,
    height = height,
    width = width
  )
}

#' Importance plot Server function
#'
#' @description A shiny Module for plotting (server code).
#'
#' @param id
#'
#' @return
#' @export
connectivity_plot_FCFCplots_server <- function(id,
                                               pgx,
                                               contrast,
                                               getCurrentContrast,
                                               getTopProfiles,
                                               getConnectivityScores,
                                               watermark = FALSE) {
  moduleServer(
    id, function(input, output, session) {

      FCFCscatter <- function(fc, F, mfplots, ylab) {
        ## get the foldchanges of selected comparison and neighbourhood
        F0 <- F
        F[is.na(F)] <- 0 ## really??
        names(fc) <- toupper(names(fc))
        gg <- intersect(names(fc), rownames(F)) ## uppercase for MOUSE
        fc <- fc[gg]

        ##mfplots <- c(2, 5)        
        nplots <- mfplots[1] * mfplots[2]
        F <- F[gg, 1:min(nplots, ncol(F)), drop = FALSE]
        F0 <- F0[gg, colnames(F), drop = FALSE]
        i <- 1
        par(
          mfrow = mfplots, mar = c(5.1, 1.6, 0.2, 0.5),
          mgp = c(2.6, 0.7, 0), oma = c(0, 3, 0, 0)
        )
        i <- 1
        for (i in 1:ncol(F)) {
          ct1 <- colnames(F)[i]
          ct1x <- sub("\\]", "]\n", ct1)
          nna <- (is.na(fc) | is.na(F0[, ct1]))
          col <- c("grey15", "grey70")[1 + nna]
          base::plot(F[, ct1], fc,
            pch = 20, cex = 0.5,
            cex.lab = 0.9, cex.axis = 0.9,
            xlab = ct1x, ylab = "", col = col
          )
          abline(v = 0, h = 0, lty = 2, lwd = 0.5)
          abline(lm(fc ~ F0[, ct1]), col = "red")
          if (i %% mfplots[2] == 1) {
            mtext(ylab, 2, line = 3, cex = 0.60)
          }
        }
      }

      FCFCenplot <- function(fc, F, mfplots, ylab, res) {
        names(fc) <- toupper(names(fc))
        nplots <- mfplots[1] * mfplots[2]
        i <- 1
        par(mfrow = mfplots, mar = c(0.1, 4, 2.6, 1))
        for (i in 1:min(ncol(F), nplots)) {
          j1 <- head(order(F[, i]), 100)
          j2 <- head(order(-F[, i]), 100)
          gset.dn <- rownames(F)[j1]
          gset.up <- rownames(F)[j2]
          gset.both <- c(gset.dn, gset.up)
          rnk <- fc
          pw <- colnames(F)[i]
          playbase::gsea.enplot(abs(rnk), gset.both,
            xlab = "",
            main = pw, cex.main = 0.8, len.main = 32
          )
          R <- res[match(pw, res$pathway), , drop = FALSE]
          legend("topright",
            cex = 0.75, y.intersp = 0.85, bty = "n",
            c(
              paste("NES=", round(R$NES[1], 3)),
              paste("padj=", round(R$padj[1], 4))
            )
          )
        }
      }

      plot_data <- shiny::reactive({

        res1 <- getCurrentContrast()
        F <- getTopProfiles()
        shiny::req(res1, F)
        
        res <- list(
          F = F,          
          contrast = contrast(),
          fc = res1$fc,
          ct = res1$name
        )
        return(res)
      })

      plot_RENDER <- function() {

        res <- plot_data()
        contrast <- res$contrast
        fc <- res$fc
        ct <- res$ct
        F <- res$F

        if (NCOL(F) == 0) {
          return(NULL)
        }
        F <- F[, 1:min(ncol(F), 12), drop = FALSE]

        if (input$fcfc_plottype == "scatter") {
          mfplots <- c(2, 5)
          FCFCscatter(fc, F, mfplots, ylab = ct)
        } else {
          mfplots <- c(3, 4)
          df <- getConnectivityScores()
          FCFCenplot(fc, F, mfplots, ylab, df)
        }
        
      }

      PlotModuleServer(
        "plot",
        plotlib = "base",
        func = plot_RENDER,
        func2 = plot_RENDER,
##      csvFunc = plot_data,
        res = c(90, 130),
        pdf.height = 4.5,
        pdf.width = 10,
        add.watermark = watermark
      )
    } ## end of moduleServer
  )
}
