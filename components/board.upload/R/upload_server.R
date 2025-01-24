##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

UploadBoard <- function(id,
                        pgx_dir,
                        pgx,
                        auth,
                        limits = c(
                          "samples" = 1000, "comparisons" = 20,
                          "genes" = 20000, "genesets" = 10000,
                          "datasets" = 10
                        ),
                        enable_userdir = TRUE,
                        enable_save = TRUE,
                        r_global) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns ## NAMESPACE

    phenoRT <- shiny::reactive(uploaded$samples.csv)
    contrRT <- shiny::reactive(uploaded$contrasts.csv)

    rv <- shiny::reactiveValues(contr = NULL, pheno = NULL)

    shiny::observe({
      rv$contr <- contrRT()
    })

    shiny::observe({
      rv$pheno <- phenoRT()
    })

    output$navheader <- shiny::renderUI({
      fillRow(
        flex = c(NA, 1, NA),
        ## h2(input$nav),
        shiny::div(
          id = "navheader-current-section",
          HTML("Upload data &nbsp;"),
          shiny::actionLink(
            ns("module_info"), "",
            icon = shiny::icon("info-circle"),
            style = "color: #ccc;"
          )
        ),
        shiny::br(),
        shiny::div(pgx$name, id = "navheader-current-dataset")
      )
    })

    shiny::observeEvent(input$module_info, {
      shiny::showModal(shiny::modalDialog(
        title = shiny::HTML("<strong>How to upload new data</strong>"),
        shiny::HTML(module_infotext),
        easyClose = TRUE,
        size = "xl"
      ))
    })

    module_infotext <- paste0(
      'Under the <b>Upload data</b> panel users can upload their transcriptomics and proteomics data to the platform. The platform requires 3 data files as listed below: a data file containing counts/expression (counts.csv), a sample information file (samples.csv) and a file specifying the statistical comparisons as contrasts (contrasts.csv). It is important to name the files exactly as shown. The file format must be comma-separated-values (CSV) text. Be sure the dimensions, row names and column names match for all files. On the left side of the panel, users need to provide a unique name and brief description for the dataset while uploading. N.B. Users can now create contrasts from the platform itself, so the contrasts.csv file is optional.

<br><br>
<ol>
<li>counts.csv: Count/expression file with gene on rows, samples as columns.
<li>samples.csv: Samples file with samples on rows, phenotypes as columns.
<li>contrasts.csv: Contrast file with conditions on rows, contrasts as columns.
</ol>

<br><br><br>
<center><iframe width="560" height="315" src="https://www.youtube.com/embed/elwT6ztt3Fo" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe><center>')

    module_infotext <- HTML('<center><iframe width="1120" height="630" src="https://www.youtube.com/embed/elwT6ztt3Fo" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe><center>')


    ## ================================================================================
    ## ====================== NEW DATA UPLOAD =========================================
    ## ================================================================================
    ## reload_pgxdir()

    getPGXDIR <- shiny::reactive({
      ## reload_pgxdir()  ## force reload

      email <- "../me@company.com"
      email <- auth$email()
      email <- gsub(".*\\/", "", email)
      pdir <- pgx_dir ## from module input

      ## USERDIR=FALSE
      if (enable_userdir) {
        pdir <- paste0(pdir, "/", email)
        if (!is.null(email) && !is.na(email) && email != "") pdir <- paste0(pdir, "/")
        if (!dir.exists(pdir)) {
          dbg("[LoadingBoard:getPGXDIR] userdir does not exists. creating pdir = ", pdir)
          dir.create(pdir)
          dbg("[LoadingBoard:getPGXDIR] copy example pgx")
          file.copy(file.path(pgx_dir, "example-data.pgx"), pdir)
        }
      }
      pdir
    })

    shiny::observeEvent(uploaded_pgx(), {
      dbg("[observe::uploaded_pgx] uploaded PGX detected!")

      new_pgx <- uploaded_pgx()

      dbg("[observe::uploaded_pgx] initializing PGX object")
      new_pgx <- playbase::pgx.initialize(new_pgx)

      savedata_button <- NULL
      if (enable_save) {
        ## -------------- save PGX file/object ---------------
        pgxname <- sub("[.]pgx$", "", new_pgx$name)
        pgxname <- gsub("^[./-]*", "", pgxname) ## prevent going to parent folder
        pgxname <- paste0(gsub("[ \\/]", "_", pgxname), ".pgx")

        pgxdir <- getPGXDIR()
        fn <- file.path(pgxdir, pgxname)
        fn <- iconv(fn, from = "", to = "ASCII//TRANSLIT")
        ## !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        ## switch 'pgx' as standard name. Actually saving as RDS
        ## would have been better...
        pgx <- new_pgx
        save(pgx, file = fn)
        remove(pgx)

        shiny::withProgress(message = "Scanning dataset library...", value = 0.33, {
          playbase::pgx.initDatasetFolder(
            pgxdir,
            new.pgx = pgxname,  ## force update
            force = FALSE,
            verbose = FALSE)
        })

##      r_global$reload_pgxdir <- r_global$reload_pgxdir+1
      }

      r_global$reload_pgxdir <- r_global$reload_pgxdir + 1
      ## beepr::beep(sample(c(3,4,5,6,8),1))  ## music!!
      beepr::beep(10) ## short beep

      load_my_dataset <- function() {
          if (input$confirmload) {
              r_global$load_data_from_upload <- new_pgx$name
              bigdash.selectTab(session, selected = 'load-tab')
          }
      }

      shinyalert::shinyalert(
          title = paste("Your dataset is ready!"),
          text = paste("Your dataset",new_pgx$name,"is ready for visualization. Happy discoveries!"),
          confirmButtonText = "Load my new data!",
          showCancelButton = TRUE,
          cancelButtonText = "Stay here.",
          inputId = 'confirmload',
          closeOnEsc = FALSE,
          callbackR = load_my_dataset
      )
    })

    # Some 'global' reactive variables used in this file
    uploaded <- shiny::reactiveValues()

    ## Hide/show tabpanels upon available data like a wizard dialog
    shiny::observe({
      has.upload <- Vectorize(function(f) {
        (f %in% names(uploaded) && !is.null(nrow(uploaded[[f]])))
      })
      need2 <- c("counts.csv", "samples.csv")
      need3 <- c("counts.csv", "samples.csv", "contrasts.csv")
      if (all(has.upload(need3))) {
        shiny::showTab("tabs", "Contrasts")
        shiny::showTab("tabs", "Compute")
        if (input$advanced_mode) {
          #shiny::showTab("tabs", "Normalize")
          shiny::showTab("tabs", "BatchCorrect")
        }
      } else if (all(has.upload(need2))) {
        if (input$advanced_mode) {
          #shiny::showTab("tabs", "Normalize")
          shiny::showTab("tabs", "BatchCorrect")
        }
        shiny::showTab("tabs", "Contrasts")
        shiny::hideTab("tabs", "Compute")
      } else {
        #shiny::hideTab("tabs", "Normalize")
        shiny::hideTab("tabs", "BatchCorrect")
        shiny::hideTab("tabs", "Contrasts")
        shiny::hideTab("tabs", "Compute")
      }
    })

    ## =====================================================================
    ## ======================= UI OBSERVERS ================================
    ## =====================================================================

    shiny::observeEvent(input$advanced_mode, {
      if (input$advanced_mode) {
        #shiny::showTab("tabs", "Normalize") ## NOT YET!!!
        shiny::showTab("tabs", "BatchCorrect")
      } else {
        #shiny::hideTab("tabs", "Normalize")
        shiny::hideTab("tabs", "BatchCorrect")
      }
    })

    ## =====================================================================
    ## ================== DATA LOADING OBSERVERS ===========================
    ## =====================================================================

    ## ------------------------------------------------------------------
    ## Observer for uploading data files using fileInput widget.
    ##
    ## Reads in the data files from the file names, checks and
    ## puts in the reactive values object 'uploaded'. Then
    ## uploaded should trigger the computePGX module.
    ## ------------------------------------------------------------------
    shiny::observeEvent(input$upload_files, {
      message("[upload_files] >>> reading uploaded files")
      message("[upload_files] upload_files$name=", input$upload_files$name)
      message("[upload_files] upload_files$datapath=", input$upload_files$datapath)

      ## for(i in 1:length(uploaded)) uploaded[[i]] <- NULL
      uploaded[["pgx"]] <- NULL
      uploaded[["last_uploaded"]] <- NULL

      ## read uploaded files
      pgx.uploaded <- any(grepl("[.]pgx$", input$upload_files$name))
      matlist <- list()

      if (pgx.uploaded) {
        message("[upload_files] PGX upload detected")

        ## If the user uploaded a PGX file, we extract the matrix
        ## dimensions from the given PGX/NGS object. Really?
        ##
        i <- grep("[.]pgx$", input$upload_files$name)
        pgxfile <- input$upload_files$datapath[i]
        uploaded[["pgx"]] <- local(get(load(pgxfile, verbose=0))) ## override any name
      } else {
        ## If the user uploaded CSV files, we read in the data
        ## from the files.
        ##
        message("[upload_files] getting matrices from CSV")

        ii <- grep("csv$", input$upload_files$name)
        ii <- grep("sample|count|contrast|expression",
          input$upload_files$name,
          ignore.case = TRUE
        )
        if (length(ii) == 0) {
          return(NULL)
        }

        inputnames <- input$upload_files$name[ii]
        uploadnames <- input$upload_files$datapath[ii]

        error_list <- playbase::PGX_CHECKS

        if (length(uploadnames) > 0) {
          for (i in 1:length(uploadnames)) {
            fn1 <- inputnames[i]
            fn2 <- uploadnames[i]
            matname <- NULL
            df <- NULL
            IS_COUNT <- grepl("count", fn1, ignore.case = TRUE)
            IS_EXPRESSION <- grepl("expression", fn1, ignore.case = TRUE)
            IS_SAMPLE <- grepl("sample", fn1, ignore.case = TRUE)
            IS_CONTRAST <- grepl("contrast", fn1, ignore.case = TRUE)
            if (IS_COUNT || IS_EXPRESSION) {
              ## allows duplicated rownames
              df0 <- playbase::read.as_matrix(fn2)
              
              COUNTS_check <- playbase::pgx.checkPGX(df0, "COUNTS")

              if(length(COUNTS_check$check)>0) {
                lapply(1:length(COUNTS_check$check), function(idx){
                  error_id <- names(COUNTS_check$check)[idx]
                  error_log <- COUNTS_check$check[[idx]]
                  error_detail <- error_list[error_list$error == error_id,]
                  error_length <- length(error_log)
                  ifelse(length(error_log) > 5, error_log <- error_log[1:5], error_log)

                  shinyalert::shinyalert(
                    title = error_detail$title,
                    text = paste(error_detail$message,"\n",paste(error_length, "cases identified, examples:"), paste(error_log, collapse = " "), sep = " "),
                    type = error_detail$warning_type,
                    closeOnClickOutside = FALSE
                  )
                })
              }

              if (COUNTS_check$PASS && IS_COUNT) {
                df <- as.matrix(COUNTS_check$df)
                matname <- "counts.csv"
              }

              if (COUNTS_check$PASS && IS_EXPRESSION) {
                df <- as.matrix(COUNTS_check$df)
                message("[UploadModule::upload_files] converting expression to counts...")
                df <- 2**df
                matname <- "counts.csv"
              }
            }

            if (IS_SAMPLE) {
              df0 <- playbase::read.as_matrix(fn2)
              
              SAMPLES_check <- playbase::pgx.checkPGX(df0, "SAMPLES")

              if(length(SAMPLES_check$check)>0) {
                lapply(1:length(SAMPLES_check$check), function(idx){
                  error_id <- names(SAMPLES_check$check)[idx]
                  error_log <- SAMPLES_check$check[[idx]]
                  error_detail <- error_list[error_list$error == error_id,]
                  error_length <- length(error_log)
                  ifelse(length(error_log) > 5, error_log <- error_log[1:5], error_log)
                  
                  shinyalert::shinyalert(
                    title = error_detail$title,
                    text = paste(error_detail$message,"\n",paste(error_length, "cases identified, examples:"), paste(error_log, collapse = " "), sep = " "),
                    type = error_detail$warning_type,
                    closeOnClickOutside = FALSE
                  )
                })
              }

              if (SAMPLES_check$PASS && IS_SAMPLE) {
                df <- as.data.frame(SAMPLES_check$df)
                matname <- "samples.csv"
              }
            }
            
            if (IS_CONTRAST) {
              df0 <- playbase::read.as_matrix(fn2)
              
              CONTRASTS_check <- playbase::pgx.checkPGX(df0, "CONTRASTS")

              if(length(CONTRASTS_check$check)>0) {
                lapply(1:length(CONTRASTS_check$check), function(idx){
                  error_id <- names(CONTRASTS_check$check)[idx]
                  error_log <- CONTRASTS_check$check[[idx]]
                  error_detail <- error_list[error_list$error == error_id,]
                  error_length <- length(error_log)
                  ifelse(length(error_log) > 5, error_log <- error_log[1:5], error_log)

                  shinyalert::shinyalert(
                    title = error_detail$title,
                    text = paste(error_detail$message,"\n",paste(error_length, "cases identified, examples:"), paste(error_log, collapse = " "), sep = " "),
                    type = error_detail$warning_type,
                    closeOnClickOutside = FALSE
                  )
                })
              }

              if (CONTRASTS_check$PASS && IS_CONTRAST) {
                df <- as.matrix(CONTRASTS_check$df)
                matname <- "contrasts.csv"
              }

            }

            if (!is.null(matname)) {
              matlist[[matname]] <- df
            }
          }
        }
      }

      ## put the matrices in the reactive values 'uploaded'
      files.needed <- c("counts.csv", "samples.csv", "contrasts.csv")
      if (length(matlist) > 0) {
        matlist <- matlist[which(names(matlist) %in% files.needed)]
        for (i in 1:length(matlist)) {
          colnames(matlist[[i]]) <- gsub("[\n\t ]", "_", colnames(matlist[[i]]))
          rownames(matlist[[i]]) <- gsub("[\n\t ]", "_", rownames(matlist[[i]]))
          if (names(matlist)[i] %in% c("counts.csv", "contrasts.csv")) {
            matlist[[i]] <- as.matrix(matlist[[i]])
          } else {
            matlist[[i]] <- type.convert(matlist[[i]])
          }
          m1 <- names(matlist)[i]
          message("[upload_files] updating matrix ", m1)
          uploaded[[m1]] <- matlist[[i]]
        }
        uploaded[["last_uploaded"]] <- names(matlist)
      }

      message("[upload_files] done!\n")
    })

    ## ------------------------------------------------------------------
    ## Observer for loading from local exampledata.zip file
    ##
    ## Reads in the data files from zip and puts in the
    ## reactive values object 'uploaded'. Then uploaded should
    ## trigger the computePGX module.
    ## ------------------------------------------------------------------
    shiny::observeEvent(input$load_example, {
      if (input$load_example) {
        zipfile <- file.path(FILES, "exampledata.zip")
        readfromzip1 <- function(file) {
          read.csv(unz(zipfile, file),
            check.names = FALSE, stringsAsFactors = FALSE,
            row.names = 1
          )
        }
        readfromzip2 <- function(file) {
          ## allows for duplicated names
          df0 <- read.csv(unz(zipfile, file), check.names = FALSE, stringsAsFactors = FALSE)
          mat <- as.matrix(df0[, -1])
          rownames(mat) <- as.character(df0[, 1])
          mat
        }
        uploaded$counts.csv <- readfromzip2("exampledata/counts.csv")
        uploaded$samples.csv <- readfromzip1("exampledata/samples.csv")
        uploaded$contrasts.csv <- readfromzip1("exampledata/contrasts.csv")
      } else {
        ## Remove files
        uploaded$counts.csv <- NULL
        uploaded$samples.csv <- NULL
        uploaded$contrasts.csv <- NULL
      }
    })

    ## ------------------------------------------------------------------
    ## Observer for loading CSV from local folder on
    ## host/server using URL. Reads the CSV files from folder
    ## and puts in the reactive values object 'uploaded'.
    ## ------------------------------------------------------------------

    if (ALLOW_URL_QUERYSTRING) {
      shiny::observeEvent(session$clientData$url_search, {
        ## -------------------------------------------------------------
        ## Parse URL query string
        ## -------------------------------------------------------------
        query <- parseQueryString(session$clientData$url_search)
        if (length(query) > 0) {
          dbg("[UploadModule:parseQueryString] names.query =", names(query))
          for (i in 1:length(query)) {
            dbg("[UploadModule:parseQueryString]", names(query)[i], "=>", query[[i]])
          }
        } else {
          dbg("[UploadModule:parseQueryString] no queryString!")
        }

        if (!is.null(query[["csv"]])) {
          qdir <- query[["csv"]]
          dbg("[UploadModule:parseQueryString] *** parseQueryString ***")
          dbg("[UploadModule:parseQueryString] qdir = ", qdir)

          counts_file <- file.path(qdir, "counts.csv")
          samples_file <- file.path(qdir, "samples.csv")
          if (!file.exists(counts_file)) {
            dbg("[SERVER:parseQueryString] ***ERROR*** missing counts.csv in dir = ", qdir)
          }
          if (!file.exists(samples_file)) {
            dbg("[SERVER:parseQueryString] ***ERROR*** missing samples.csv in dir = ", qdir)
          }
          if (!file.exists(counts_file) || !file.exists(samples_file)) {
            return(NULL)
          }

          FUN.readfromdir <- function() {
            dbg("[UploadModule:parseQueryString] *** loading CSV from dir = ", qdir, "***")

            readfromdir1 <- function(file) {
              read.csv(file,
                check.names = FALSE, stringsAsFactors = FALSE,
                row.names = 1
              )
            }
            readfromdir2 <- function(file) {
              ## allows for duplicated names
              df0 <- read.csv(file, check.names = FALSE, stringsAsFactors = FALSE)
              mat <- as.matrix(df0[, -1])
              rownames(mat) <- as.character(df0[, 1])
              mat
            }

            dbg("[UploadModule:parseQueryString] reading samples_csv = ", samples_file)
            uploaded$samples.csv <- readfromdir1(samples_file)

            dbg("[UploadModule:parseQueryString] reading samples_csv = ", samples_file)
            uploaded$counts.csv <- readfromdir2(counts_file)
            uploaded$contrasts.csv <- NULL

            meta_file <- file.path(qdir, "meta.txt")
            uploaded$meta <- NULL
            if (file.exists(meta_file)) {
              dbg("[UploadModule:parseQueryString] reading meta file = ", meta_file)
              ## meta <- read.table(meta_file,sep='\t',header=TRUE,row.names=1)
              meta <- read.table(meta_file, sep = "", header = TRUE, row.names = 1)
              meta <- as.list(array(meta[, 1], dimnames = list(rownames(meta))))
              uploaded$meta <- meta
            }
          }

          shinyalert::shinyalert(
            title = "Load CSV data from folder?",
            text = paste0("folder = ", qdir),
            callbackR = FUN.readfromdir,
            confirmButtonText = "Load!",
            type = "info"
          )

          dbg("[UploadModule:parseQueryString] dim(samples) = ", dim(uploaded$samples.csv))
          dbg("[UploadModule:parseQueryString] dim(counts) = ", dim(uploaded$counts.csv))

          ## focus on this tab
          updateTabsetPanel(session, "tabs", selected = "Upload data")
        }

        if (0 && !is.null(query[["pgx"]])) {
          qdir <- query[["pgx"]]
          dbg("[UploadModule:parseQueryString] pgx =>", qdir)

          pgx_file <- query[["pgx"]]
          pgx_file <- paste0(sub("[.]pgx$", "", pgx_file), ".pgx")
          dbg("[UploadModule:parseQueryString] pgx_file = ", pgx_file)

          if (!file.exists(pgx_file)) {
            dbg("[SERVER:parseQueryString] ***ERROR*** missing pgx_file", pgx_file)
            return(NULL)
          }

          dbg("[UploadModule:parseQueryString] 1:")

          FUN.readPGX <- function() {
            dbg("[UploadModule:parseQueryString] *** loading PGX file = ", pgx_file, "***")
            ##load(pgx_file) ## load NGS/PGX
            uploaded$pgx <- local(get(load(pgx_file, verbose=0))) ## override any name
            ##remove(ngs)
            uploaded$meta <- NULL
          }

          dbg("[UploadModule:parseQueryString] 2:")

          shinyalert::shinyalert(
            title = "Load PGX data from folder?",
            text = paste0("folder = ", qdir),
            callbackR = FUN.readPGX,
            confirmButtonText = "Load!",
            type = "info"
          )

          dbg("[UploadModule:parseQueryString] 3:")

          ## focus on this tab
          updateTabsetPanel(session, "tabs", selected = "Upload data")

          dbg("[UploadModule:parseQueryString] 4:")
        }
      })
    }

    ## =====================================================================
    ## ===================== checkTables ===================================
    ## =====================================================================

    checkTables <- shiny::reactive({
      ## check dimensions
      status <- rep("please upload", 3)
      files.needed <- c("counts.csv", "samples.csv", "contrasts.csv")
      names(status) <- files.needed
      files.nrow <- rep(NA, 3)
      files.ncol <- rep(NA, 3)

      for (i in 1:3) {
        fn <- files.needed[i]
        upfile <- uploaded[[fn]]
        if (fn %in% names(uploaded) && !is.null(upfile)) {
          status[i] <- "OK"
          files.nrow[i] <- nrow(upfile)
          files.ncol[i] <- ncol(upfile)
        }
      }

      has.pgx <- ("pgx" %in% names(uploaded))
      if (has.pgx) has.pgx <- has.pgx && !is.null(uploaded[["pgx"]])
      if (has.pgx == TRUE) {
        ## Nothing to check. Always OK.
      } else if (!has.pgx) {
        ## check rownames of samples.csv
        if (status["samples.csv"] == "OK" && status["counts.csv"] == "OK") {
          samples1 <- uploaded[["samples.csv"]]
          counts1 <- uploaded[["counts.csv"]]
          a1 <- mean(rownames(samples1) %in% colnames(counts1))
          a2 <- mean(samples1[, 1] %in% colnames(counts1))

          if (a2 > a1 && NCOL(samples1) > 1) {
            message("[UploadModuleServer] getting sample names from first column\n")
            rownames(samples1) <- samples1[, 1]
            uploaded[["samples.csv"]] <- samples1[, -1, drop = FALSE]
          }
        }

        ## check files: matching dimensions
        if (status["counts.csv"] == "OK" && status["samples.csv"] == "OK") {
          nsamples <- max(ncol(uploaded[["counts.csv"]]), nrow(uploaded[["samples.csv"]]))
          ok.samples <- intersect(
            rownames(uploaded$samples.csv),
            colnames(uploaded$counts.csv)
          )
          n.ok <- length(ok.samples)
          message("[UploadModule::checkTables] n.ok = ", n.ok)
          if (n.ok > 0 && n.ok < nsamples) {
            ## status["counts.csv"]  = "WARNING: some samples with missing annotation)"
          }

          if (n.ok > 0) {
            message("[UploadModule::checkTables] conforming samples/counts...")
            uploaded[["samples.csv"]] <- uploaded$samples.csv[ok.samples, , drop = FALSE]
            uploaded[["counts.csv"]] <- uploaded$counts.csv[, ok.samples, drop = FALSE]
          }

          if (n.ok == 0) {
            status["counts.csv"] <- "ERROR: colnames do not match (with samples)"
            status["samples.csv"] <- "ERROR: rownames do not match (with counts)"
          }
        }

        if (status["contrasts.csv"] == "OK" && status["samples.csv"] == "OK") {
          samples1 <- uploaded[["samples.csv"]]
          contrasts1 <- uploaded[["contrasts.csv"]]
          group.col <- grep("group", tolower(colnames(samples1)))
          old1 <- (length(group.col) > 0 &&
            nrow(contrasts1) < nrow(samples1) &&
            all(rownames(contrasts1) %in% samples1[, group.col[1]])
          )
          old2 <- all(rownames(contrasts1) == rownames(samples1)) &&
            all(unique(as.vector(contrasts1)) %in% c(-1, 0, 1, NA))

          old.style <- (old1 || old2)
          if (old.style && old1) {
            message("[UploadModule] WARNING: converting old1 style contrast to new format")
            new.contrasts <- samples1[, 0]
            if (NCOL(contrasts1) > 0) {
              new.contrasts <- playbase::contrastAsLabels(contrasts1)
              grp <- as.character(samples1[, group.col])
              new.contrasts <- new.contrasts[grp, , drop = FALSE]
              rownames(new.contrasts) <- rownames(samples1)
            }
            contrasts1 <- new.contrasts
          }
          if (old.style && old2) {
            message("[UploadModule] WARNING: converting old2 style contrast to new format")
            new.contrasts <- samples1[, 0]
            if (NCOL(contrasts1) > 0) {
              new.contrasts <- playbase::contrastAsLabels(contrasts1)
              rownames(new.contrasts) <- rownames(samples1)
            }
            contrasts1 <- new.contrasts
          }

          dbg("[UploadModule] 1 : dim.contrasts1 = ", dim(contrasts1))
          dbg("[UploadModule] 1 : dim.samples1   = ", dim(samples1))

          ok.contrast <- length(intersect(rownames(samples1), rownames(contrasts1))) > 0
          if (ok.contrast && NCOL(contrasts1) > 0) {
            ## always clean up
            contrasts1 <- apply(contrasts1, 2, as.character)
            rownames(contrasts1) <- rownames(samples1)
            for (i in 1:ncol(contrasts1)) {
              isz <- (contrasts1[, i] %in% c(NA, "NA", "NA ", "", " ", "  ", "   ", " NA"))
              if (length(isz)) contrasts1[isz, i] <- NA
            }
            uploaded[["contrasts.csv"]] <- contrasts1
            status["contrasts.csv"] <- "OK"
          } else {
            uploaded[["contrasts.csv"]] <- NULL
            status["contrasts.csv"] <- "ERROR: dimension mismatch"
          }
        }

        MAXSAMPLES <- 25
        MAXCONTRASTS <- 5
        MAXSAMPLES <- as.integer(limits["samples"])
        MAXCONTRASTS <- as.integer(limits["comparisons"])

        ## check files: maximum contrasts allowed
        if (status["contrasts.csv"] == "OK") {
          if (ncol(uploaded[["contrasts.csv"]]) > MAXCONTRASTS) {
            status["contrasts.csv"] <- paste("ERROR: max", MAXCONTRASTS, "contrasts allowed")
          }
        }

        ## check files: maximum samples allowed
        if (status["counts.csv"] == "OK" && status["samples.csv"] == "OK") {
          if (ncol(uploaded[["counts.csv"]]) > MAXSAMPLES) {
            status["counts.csv"] <- paste("ERROR: max", MAXSAMPLES, " samples allowed")
          }
          if (nrow(uploaded[["samples.csv"]]) > MAXSAMPLES) {
            status["samples.csv"] <- paste("ERROR: max", MAXSAMPLES, "samples allowed")
          }
        }

        ## check samples.csv: must have group column defined
        if (status["samples.csv"] == "OK" && status["contrasts.csv"] == "OK") {
          samples1 <- uploaded[["samples.csv"]]
          contrasts1 <- uploaded[["contrasts.csv"]]
          if (!all(rownames(contrasts1) %in% rownames(samples1))) {
            status["contrasts.csv"] <- "ERROR: contrasts do not match samples"
          }
        }
      } ## end-if-from-pgx

      e1 <- grepl("ERROR", status["samples.csv"])
      e2 <- grepl("ERROR", status["contrasts.csv"])
      e3 <- grepl("ERROR", status["counts.csv"])
      s1 <- "samples.csv" %in% uploaded$last_uploaded
      s2 <- "contrasts.csv" %in% uploaded$last_uploaded
      s3 <- "counts.csv" %in% uploaded$last_uploaded

      if (e1 || e2 || e3) {
        message("[checkTables] ERROR in samples table : e1 = ", e1)
        message("[checkTables] ERROR in contrasts table : e2 = ", e2)
        message("[checkTables] ERROR in counts table : e2 = ", e3)

        if (e1 && !s1) {
          uploaded[["samples.csv"]] <- NULL
          status["samples.csv"] <- "please upload"
        }
        if (e2 && !s2) {
          uploaded[["contrasts.csv"]] <- NULL
          status["contrasts.csv"] <- "please upload"
        }
        if (e3 && !s3) {
          uploaded[["counts.csv"]] <- NULL
          status["counts.csv"] <- "please upload"
        }
      }


      if (!is.null(uploaded$contrasts.csv) &&
        (is.null(uploaded$counts.csv) ||
          is.null(uploaded$samples.csv))) {
        uploaded[["contrasts.csv"]] <- NULL
        status["contrasts.csv"] <- "please upload"
      }


      ## check files
      description <- c(
        "Count/expression file with gene on rows, samples as columns",
        "Samples file with samples on rows, phenotypes as columns",
        ## "Gene information file with genes on rows, gene info as columns.",
        "Contrast file with conditions on rows, contrasts as columns"
      )
      df <- data.frame(
        filename = files.needed,
        description = description,
        nrow = files.nrow,
        ncol = files.ncol,
        status = status
      )
      rownames(df) <- files.needed

      ## deselect
      ## DT::selectRows(proxy = DT::dataTableProxy("pgxtable"), selected=NULL)
      return(df)
    })

    output$downloadExampleData <- shiny::downloadHandler(
      filename = "exampledata.zip",
      content = function(file) {
        zip <- file.path(FILES, "exampledata.zip")
        file.copy(zip, file)
      }
    )

    output$upload_info <- shiny::renderUI({
      upload_info <- "<h4>User file upload</h4><p>Please prepare the data files in CSV format as listed below. It is important to name the files exactly as shown. The file format must be comma-separated-values (CSV) text. Be sure the dimensions, rownames and column names match for all files. You can download a zip file with example files here: EXAMPLEZIP. You can upload a maximum of <u>LIMITS</u>."
      DLlink <- shiny::downloadLink(ns("downloadExampleData"), "exampledata.zip")
      upload_info <- sub("EXAMPLEZIP", DLlink, upload_info)

      limits0 <- paste(
        limits["datasets"], "datasets (with each up to",
        limits["samples"], "samples and",
        limits["comparisons"], "comparisons)"
      )
      upload_info <- sub("LIMITS", limits0, upload_info)
      shiny::HTML(upload_info)
    })

    ## =====================================================================
    ## ========================= SUBMODULES/SERVERS ========================
    ## =====================================================================

    ## correctedX <- shiny::reactive({
    #normalized_counts <- NormalizeCountsServerRT(
    #  id = "normalize",
    #  counts = shiny::reactive(uploaded$counts.csv),
    #  height = height
    #)

    ## correctedX <- shiny::reactive({
    correctedX <- upload_module_batchcorrect_server(
      id = "batchcorrect",
      X = shiny::reactive(uploaded$counts.csv),
      ## X = normalized_counts,  ## NOT YET!!!!
      is.count = TRUE,
      pheno = shiny::reactive(uploaded$samples.csv),
      height = height
    )

    corrected_counts <- shiny::reactive({
      counts <- NULL
      advanced_mode <- (length(input$advanced_mode) > 0 &&
        input$advanced_mode[1] == 1)
      if (advanced_mode) {
        out <- correctedX()
        counts <- pmax(2**out$X - 1, 0)
      } else {
        counts <- uploaded$counts.csv
      }
      counts
    })

    modified_ct <- upload_module_makecontrast_server(
      id = "makecontrast",
      phenoRT = shiny::reactive(uploaded$samples.csv),
      contrRT = shiny::reactive(uploaded$contrasts.csv),
      ## countsRT = shiny::reactive(uploaded$counts.csv),
      countsRT = corrected_counts,
      height = height
    )

    shiny::observeEvent(modified_ct(), {
      ## Monitor for changes in the contrast matrix and if
      ## so replace the uploaded reactive values.
      ##
      modct <- modified_ct()
      uploaded$contrasts.csv <- modct$contr
      uploaded$samples.csv <- modct$pheno
    })

    upload_ok <- shiny::reactive({
      check <- checkTables()
      all(check[, "status"] == "OK")
      all(grepl("ERROR", check[, "status"]) == FALSE)
    })

    batch_vectors <- shiny::reactive({
      correctedX()$B
    })

    computed_pgx <- upload_module_computepgx_server(
      id = "compute",
      ## countsRT = shiny::reactive(uploaded$counts.csv),
      countsRT = corrected_counts,
      samplesRT = shiny::reactive(uploaded$samples.csv),
      contrastsRT = shiny::reactive(uploaded$contrasts.csv),
      batchRT = batch_vectors,
      metaRT = shiny::reactive(uploaded$meta),
      enable_button = upload_ok,
      alertready = FALSE,
      lib.dir = FILES,
      pgx.dirRT = shiny::reactive(getPGXDIR()),
      max.genes = as.integer(limits["genes"]),
      max.genesets = as.integer(limits["genesets"]),
      max.datasets = as.integer(limits["datasets"]),
      height = height,
      r_global = r_global
    )

    uploaded_pgx <- shiny::reactive({
      if (!is.null(uploaded$pgx)) {
        pgx <- uploaded$pgx
      } else {
        pgx <- computed_pgx()
      }
      return(pgx)
    })

    ## =====================================================================
    ## ===================== PLOTS AND TABLES ==============================
    ## =====================================================================

    upload_plot_countstats_server(
        "countStats",
        checkTables,
        uploaded
    )

    upload_plot_phenostats_server(
        "phenoStats",
        checkTables,
        uploaded
    )

    upload_plot_contraststats_server(
        "contrastStats",
        checkTables,
        uploaded
    )

    buttonInput <- function(FUN, len, id, ...) {
      inputs <- character(len)
      for (i in seq_len(len)) {
        inputs[i] <- as.character(FUN(paste0(id, i), ...))
      }
      inputs
    }

    output$checkTablesOutput <- DT::renderDataTable({
      ## Render the upload status table
      ##
      if (!input$advanced_mode) {
        return(NULL)
      }
      df <- checkTables()
      dt <- DT::datatable(
        df,
        rownames = FALSE,
        selection = "none",
        class = "compact cell-border",
        options = list(
          dom = "t"
        )
      ) %>%
        DT::formatStyle(0, target = "row", fontSize = "12px", lineHeight = "100%")
    })

    upload_plot_pcaplot_server(
      "pcaplot",
      phenoRT = phenoRT,
      countsRT = corrected_counts,
      sel.conditions = sel.conditions,
      watermark = WATERMARK
    )

    ## ------------------------------------------------
    ## Board return object
    ## ------------------------------------------------
    res <- list(
      loaded = reactive(r_global$loadedDataset)
    )
    return(res)
  })
}
