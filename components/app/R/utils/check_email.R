##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##

check_personal_email <- function(auth, pgx_dir, title=NULL, text=NULL) {
  email <- auth$email()
  is_personal_email <- grepl("gmail|ymail|outlook|yahoo|hotmail|mail.com$|icloud",email)
  existing_user_dirs <- basename(list.dirs(pgx_dir))
  user_exists <- (email %in% existing_user_dirs)

  if(is.null(text)) {
    text <- "You are using a personal email adress. Please provide a business, academic or institutional email."
  }
  if(is.null(title)) {
    title <- "Please change your email"
  }
  
  if(is_personal_email && user_exists) {
    shinyalert::shinyalert(
      inputId = "new_email",                        
      title = title,
      text = text,
      type = "input",
      callbackR = function(new_email) {
        ## check if new email is valid
        newemail_is_personal <- grepl("gmail|ymail|outlook|yahoo|hotmail|mail.com$|icloud",new_email)
        valid_email <- grepl(".*@.*[.].*",new_email)
        dbg("[check_personal_email] newemail_is_personal = ", newemail_is_personal)
        dbg("[check_personal_email] valid_email = ", valid_email)        
        if(!valid_email) {
          dbg("[check_personal_email] ERROR!!",new_email,"is invalid")
          title = "Invalid email"
          text <- "Please provide a valid business, academic or institutional email."
          check_personal_email(auth, pgx_dir, title=title, text=text)
          return()
        }
        if(newemail_is_personal) {
          dbg("[check_personal_email] ERROR!!",new_email,"is personal")
          title = "Please change email"
          text <- "No personal email adresses. Please provide a business, academic or institutional email."
          check_personal_email(auth, pgx_dir, title=title, text=text)
          return()
        }
 
        
        ## copy old data to new data
        old_dir_exists <- (email %in% existing_user_dirs)
        new_dir_exists <- (new_email %in% existing_user_dirs)
        dbg("[check_personal_email] old_dir_exists = ", old_dir_exists)
        dbg("[check_personal_email] new_dir_exists = ", new_dir_exists)        

        if(old_dir_exists && !new_dir_exists) {
          dbg("[check_personal_email] moving data from",email,"to",new_email)
          old_dir <- file.path( pgx_dir, email)
          new_dir <- file.path( pgx_dir, new_email)
          base::file.rename(old_dir, new_dir)
          
          shinyalert::shinyalert(title="", text="Your login name has been changed and your data have been moved. Please login again with your new email.")          
          shinyjs::runjs("logoutInApp()")
        } else if(!old_dir_exists && !new_dir_exists) {
          shinyalert::shinyalert(title="", text="Your login name has been changed. Please login again with your new email.")
          shinyjs::runjs("logoutInApp()")          
        } else if(new_dir_exists) {
          dbg("[check_personal_email] ERROR!!",new_email,"exists")
          title = "Email already exists"
          text <- "This email already exists. Please provide a different business, academic or institutional email."
          check_personal_email(auth, pgx_dir, title=title, text=text)
        }
      }
    )
  } ## end if user_exists

}
