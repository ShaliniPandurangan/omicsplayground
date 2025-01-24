##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

loading_table_datasets_ui <- function(
  id,
  title,
  info.text,
  caption,
  height,
  width) {
  ns <- shiny::NS(id)

  TableModuleUI(
    ns("datasets"),
    info.text = info.text,
    caption = caption,
    width = width,
    height = height,
    title = title
  )
}

loading_table_datasets_server <- function(id, rl, enable_pgxdownload=FALSE, enable_share=TRUE) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    pgxTable_DT <- reactive({

      df <- rl$pgxTable_data      
      shiny::req(df)      

      if (nrow(df) == 0) {
        shinyalert::shinyalert(
          title = "Empty?",
          text = paste("Your dataset library seems empty. Please upload new data or import",
            "a dataset from the shared folder."
            )
        )
      }
      validate(need(nrow(df)>0, 'Need at least one dataset!'))      

      ## need this, otherwise there is an error on user logout
      if (length(df$dataset) == 0) df <- NULL
      
      df$creator <- NULL
      target1 <- grep("date", colnames(df))
      target2 <- grep("description", colnames(df))
      target3 <- grep("conditions", colnames(df))
      target4 <- grep("dataset", colnames(df))

      # create action menu for each row
      menus <- c()
      for (i in 1:nrow(df)) {

        download_pgx_menuitem = NULL
        share_dataset_menuitem = NULL
        if(enable_pgxdownload) {
          download_pgx_menuitem <- shiny::actionButton(
            ns(paste0("download_pgx_row_",i)),
            label = "Download PGX",
            icon = shiny::icon('download'),
            class = "btn btn-outline-dark",
            style = "border: none;",
            onclick=paste0('Shiny.onInputChange(\"',ns("download_pgx"),'\",this.id,{priority: "event"})')
          )
        }
        if(enable_share) {
          share_dataset_menuitem <- shiny::actionButton(
            ns(paste0("share_dataset_row_", i)),
            label = "Share Dataset",
            icon = shiny::icon('share-nodes'),
            class = "btn btn-outline-info",
            style = 'border: none;',
            onclick=paste0('Shiny.onInputChange(\"',ns("share_pgx"),'\",this.id,{priority: "event"})')
          )
        }

        new_menu <- actionMenu(  ## ui-DrowDownMenu.R
          div(
            style = "width: 160px;",
            div(
              download_pgx_menuitem,
              shiny::actionButton(
                ns(paste0("download_zip_row_", i)),
                label = "Download ZIP",
                icon = shiny::icon("file-archive"),
                class = "btn btn-outline-dark",
                style = "border: none;",
                onclick=paste0('Shiny.onInputChange(\"',ns("download_zip"),'\",this.id,{priority: "event"})')
                ),
              share_dataset_menuitem,
              shiny::actionButton(
                ns(paste0("delete_dataset_row_",i)),
                label = "Delete Dataset",
                icon = shiny::icon("trash"),
                class = "btn btn-outline-danger",
                style = 'border: none;',
                onclick=paste0('Shiny.onInputChange(\"',ns("delete_pgx"),'\",this.id,{priority: "event"});')
              )
            )
          ),
          size = "sm",
          icon = shiny::icon("ellipsis-vertical"),
          status = "dark"
        )
        menus <- c(menus, as.character(new_menu))
      }
      observeEvent(input$download_pgx, { rl$download_pgx <- input$download_pgx })
      observeEvent(input$download_zip, { rl$download_zip <- input$download_zip })
      observeEvent(input$share_pgx, { rl$share_pgx <- input$share_pgx },
                   ignoreInit = TRUE)
      observeEvent(input$delete_pgx, {
          rl$delete_pgx <- input$delete_pgx;
      }, ignoreInit = TRUE)

      DT::datatable(
        df,
        class = "compact hover",
        rownames = menus,
        escape = FALSE,
        editable = list(
          target = 'cell',
          disable = list(columns = c(1,3:ncol(df)))
        ),
        extensions = c("Scroller"),
        selection = list(mode = "single", target = "row", selected = 1),
        fillContainer = TRUE,
        plugins = "scrollResize",
        options = list(
          dom = "ft",
          pageLength = 9999,
          scrollX = FALSE,
          scrollY = "55vh",
          scrollResize = TRUE,
          deferRender = TRUE,
          autoWidth = TRUE,
          columnDefs = list(
            list(width = "60px", targets = target1),
            list(width = "30vw", targets = target2),
            list(sortable = FALSE, targets = ncol(df))
          )
        ) ## end of options.list
      )
    })

    # make changes to pgxtable
    observeEvent(
      input[['datasets-datatable_cell_edit']], {
        row <- input[['datasets-datatable_cell_edit']]$row
        col <- input[['datasets-datatable_cell_edit']]$col
        val <- input[['datasets-datatable_cell_edit']]$value
        rl$pgxTable_data[row, col] <- val
        rl$pgxTable_edited <- rl$pgxTable_edited + 1
        rl$pgxTable_edited_row <- row
        rl$pgxTable_edited_col <- col
      }
    )

    pgxTable.RENDER <- function() {
      pgxTable_DT() %>%
        DT::formatStyle(0, target = "row", fontSize = "12px", lineHeight = "95%")
    }

    pgxTable_modal.RENDER <- function() {
      pgxTable_DT() %>%
        DT::formatStyle(0, target = "row", fontSize = "20px", lineHeight = "95%")
    }

    TableModuleServer(
      "datasets",
      func = pgxTable.RENDER,
      func2 = pgxTable_modal.RENDER,
      selector = "single"
    )
  })
}
