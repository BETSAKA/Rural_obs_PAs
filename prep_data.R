prep_data <- function(input_path, output_path) {
  # First delete existing output directory if it exists
  if (dir.exists(output_path)) {
    unlink(output_path, recursive = TRUE)
  }
  # Now creates
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE)
  }

  # Extract the .7z file
  archive::archive_extract(input_path, dir = output_path)

  # Get the name of the extracted subdirectory
  extracted_dirs <- list.dirs(output_path, full.names = TRUE, recursive = FALSE)

  # Rename the first subdirectory to "cspro_files"
  cspro_dir <- file.path(output_path, "cspro_files")
  if (length(extracted_dirs) > 0) {
    file.rename(extracted_dirs[1], cspro_dir)
  }

  # Preprocess .DAT files in the "cspro_files" directory
  dat_files <- list.files(cspro_dir, pattern = "\\.DAT$", full.names = TRUE)
  for (dat_file in dat_files) {
    tryCatch(
      {
        # Read and preprocess the .DAT file
        file_content <- readLines(dat_file, encoding = "latin1")
        file_content <- iconv(
          file_content,
          from = "latin1",
          to = "UTF-8",
          sub = ""
        )
        writeLines(file_content, dat_file)
      },
      error = function(e) {
        warning(paste(
          "Failed to preprocess .DAT file:",
          dat_file,
          "due to:",
          e$message
        ))
      }
    )
  }

  # Update paths and replace `rec.type` in .R files within the "cspro_files" directory
  r_files <- list.files(cspro_dir, pattern = "\\.R$", full.names = TRUE)
  for (r_file in r_files) {
    tryCatch(
      {
        # Read the content of the R file with encoding handling
        file_content <- readLines(r_file, encoding = "UTF-8")
        file_content <- iconv(
          file_content,
          from = "latin1",
          to = "UTF-8",
          sub = ""
        )

        # Replace the path in read.fortran with the correct output path
        file_content <- gsub(
          pattern = "read\\.fortran\\(\".*?MODULE_",
          replacement = paste0("read.fortran(\"", cspro_dir, "/MODULE_"),
          x = file_content,
          fixed = FALSE
        )

        # Replace `rec.type` with `rec_type`
        file_content <- gsub(
          pattern = "\\brec\\.type\\b",
          replacement = "rec_type",
          x = file_content
        )

        # Write the updated content back to the file
        writeLines(file_content, r_file, useBytes = TRUE)
      },
      error = function(e) {
        warning(paste(
          "Failed to process .R file:",
          r_file,
          "due to:",
          e$message
        ))
      }
    )
  }

  # Create the output directory for data files
  stata_files_dir <- file.path(output_path, "stata_files")
  if (!dir.exists(stata_files_dir)) {
    dir.create(stata_files_dir, recursive = TRUE)
  }

  # Execute all .R files in the cspro_files directory and save their content
  for (r_file in r_files) {
    tryCatch(
      {
        # Source the R file
        source(r_file, local = TRUE)

        # Save all data frames created by the R file
        objs <- ls()
        for (obj in objs) {
          if (is.data.frame(get(obj))) {
            # Sanitize column names
            df <- get(obj)
            names(df) <- make.names(names(df), unique = TRUE)

            # Save as .dta file
            haven::write_dta(
              df,
              path = file.path(stata_files_dir, paste0(obj, ".dta"))
            )
          }
        }
      },
      error = function(e) {
        warning(paste("Failed to execute file:", r_file, "due to:", e$message))
      }
    )
  }
}

# Example usage
input_path <- "data/VersionR.7z"
output_path <- "data/ROS_MDG_microdata/2025"
prep_data(input_path, output_path)
