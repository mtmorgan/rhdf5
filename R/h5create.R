
h5createFile <- function(file) {
  res <- FALSE
  if (is.character(file)) {
    file = normalizePath(file,mustWork = FALSE)
    if (file.exists(file)) {
      message("file '", file, "' already exists.")
    } else {
      h5loc <- H5Fcreate(file)
      if (is(h5loc, "H5IdComponent")) {
        H5Fclose(h5loc)
        res <- TRUE
      }
    }
  } else {
    stop("file has to be a valid filename.")
  }

  res
}

h5createGroup <- function(file, group) {
  loc = h5checktypeOrOpenLoc(file)

  res <- FALSE
  if (is.character(group)) {
    if (H5Lexists(loc$H5Identifier,group)) {
      message("Can not create group. Object with name '",group,"' already exists.")
    } else {
      gid <- H5Gcreate(loc$H5Identifier, group)
      if (is(gid, "H5IdComponent")) {
        H5Gclose(gid)
        res <- TRUE
      }
    }
  }

  h5closeitLoc(loc)
  res
}

h5createDataset <- function(file, dataset, dims, maxdims = dims, storage.mode = "double", H5type = NULL, size=NULL, chunk=dims, level=6, fillValue, showWarnings = TRUE) {
  loc = h5checktypeOrOpenLoc(file)

  res <- FALSE
  if (is.character(dataset)) {
    if (H5Lexists(loc$H5Identifier,dataset)) {
      message("Can not create dataset. Object with name '",dataset,"' already exists.")
    } else {
      if (is.numeric(dims) & is.numeric(maxdims)) {
        if (length(maxdims) != length(dims)) {
          stop('"maxdims" has to have the same rank as "dims".')
        }
        if (any(maxdims != dims) & is.null(chunk)) {
          stop('If "maxdims" is different from "dims", chunking is required.')
        }
        if (any(maxdims < dims)) {
          stop('All elements of "maxdims" have to be equal or larger than "dims".')
        }
        if (any(dims < 0)) {
          stop('All elements of "dims" must be non-negative.')
        }
        if ((level > 0) & (is.null(chunk))) {
          warning("Compression (level > 0) requires chunking. Set chunk size to activate compression.")
        }
        if (length(chunk) > 0) {
          chunk[which(chunk == 0)] = 1
        }
        dcpl = NULL
        if ((level > 0) & (length(chunk) > 0)) {
          if (showWarnings & (prod(dims) > 1000000L) & (all(dims == chunk))) {
            warning("You created a large dataset with compression and chunking. The chunk size is equal to the dataset dimensions. If you want to read subsets of the dataset, you should test smaller chunk sizes to improve read times. Turn off this warning with showWarnings=FALSE.")
          }
          if (is.null(dcpl)) { dcpl = H5Pcreate("H5P_DATASET_CREATE") }
          H5Pset_fill_time( dcpl, "H5D_FILL_TIME_ALLOC" )
          H5Pset_chunk( dcpl, chunk)
          if (level > 0) { H5Pset_deflate( dcpl, level ) }
        }
        if(!missing(fillValue)) {
          if (is.null(dcpl)) { dcpl = H5Pcreate("H5P_DATASET_CREATE") }
          H5Pset_fill_value(dcpl, fillValue)
        }
        sid <- H5Screate_simple(dims, maxdims)
        if (!is(sid, "H5IdComponent")) {
          message("Can not create dataset. 'dims' or 'maxdims' argument invalid.")
        } else {
          if (is.null(H5type)) {
            if (is.character(storage.mode)) {
              tid <- switch(storage.mode[1],
                            double = h5constants$H5T["H5T_NATIVE_DOUBLE"],
                            integer = h5constants$H5T["H5T_NATIVE_INT32"],
                            logical = h5constants$H5T["H5T_NATIVE_INT32"],
                            character = {
                              tid <- H5Tcopy("H5T_C_S1")
                              if (!is.numeric(size)) {
                                stop("parameter 'size' has to be defined for storage.mode character.")
                              }
                              H5Tset_size(tid, size)
                              tid
                            },
                            { stop("datatype ",storage.mode," not yet implemented. Try 'double', 'integer', or 'character'.") } )
            } else {
              stop("Can not create dataset. 'storage.mode' has to be a character.")
            }
          } else {
            tid <- h5checkConstants("H5T", H5type)
          }
          if (!is.numeric(tid)) {
            message("Can not create dataset. H5type unknown. Check h5const('H5T') for valid types.")
          } else {
            did <- H5Dcreate(loc$H5Identifier, dataset, tid, sid, dcpl = dcpl)
            if (is(did, "H5IdComponent")) {
              if (storage.mode[1] == "logical") {
                x = "logical"
                h5writeAttribute(attr = x, h5obj = did, name="storage.mode")
              }
              H5Dclose(did)
              res <- TRUE
            }
          }
          H5Sclose(sid)
        }
        if (!is.null(dcpl)) { H5Pclose(dcpl) }
      } else {
        message("Can not create dataset. 'dims' and 'maxdims' have to be numeric.")
      }
    }
  }

  h5closeitLoc(loc)
  res
}

h5createAttribute <- function(obj, attr, dims, maxdims = dims, file, storage.mode = "double", H5type = NULL, size=NULL) {

  obj = h5checktypeOrOpenObj(obj, file)
  
  res <- FALSE
  ## closeFile <- FALSE
  ## closeGroup <- FALSE
  ## closeDataset <- FALSE
  ## if (is.character(obj)) {
  ##   if (missing(file)) {
  ##     stop("If the object is specified by name, you have to specify the file.")
  ##   }
  ##   if (is( file, "H5file" ) | is( file, "H5group" )) {
  ##     h5loc = file
  ##   } else {
  ##     if (is.character(file)) {
  ##       if (file.exists(file)) {
  ##         h5loc <- H5Fopen(file)
  ##         if (!is(h5loc, "H5file")) {
  ##           stop("file '",file,"' is not a valid HDF5 file.")
  ##         }
  ##         closeFile <- TRUE
  ##       } else {
  ##         stop("Can not open file '",file,"'.")
  ##       }
  ##     } else {
  ##       stop("File has to be either a valid file or an object of class H5file or H5group.")
  ##     }
  ##   }
  ##   if (!H5Lexists(h5loc, obj)) {
  ##     message("Object ",obj," not found in file.")
  ##   } else {
  ##     type = H5Lget_info(h5loc, obj)$type
  ##     if (type == "H5O_TYPE_GROUP") {
  ##       obj = H5Gopen(h5loc, obj)
  ##       closeGroup <- TRUE
  ##     } else {
  ##       if (type == "H5O_TYPE_DATASET") {
  ##         obj = H5Dopen(h5loc, obj)
  ##         closeDataset <- TRUE
  ##       } else {
  ##         message("Can not create attribute. Setting attributes for this type of link not supported.")
  ##       }
  ##     }
  ##   }
  ## } else {
  ##   if (!is( obj, "H5file" ) & !is( obj, "H5group" ) & !is( obj, "H5dataset" )) {
  ##     stop("object ",obj," has to be either a character name, or it has to be of class H5file, H5group, or H5dataset.")
  ##   }
  ## }

  if (is.numeric(dims) & is.numeric(maxdims)) {
    sid <- H5Screate_simple(dims, maxdims)
    if (!is(sid, "H5IdComponent")) {
      message("Can not create attribute. 'dims' or 'maxdims' argument invalid.")
    } else {
      if (is.null(H5type)) {
        if (is.character(storage.mode)) {
          tid <- switch(storage.mode[1],
                        double = h5constants$H5T["H5T_NATIVE_DOUBLE"],
                        integer = h5constants$H5T["H5T_NATIVE_INT32"],
                        character = {
                          tid <- H5Tcopy("H5T_C_S1")
                          if (!is.numeric(size)) {
                            stop("parameter 'size' has to be defined for storage.mode character.")
                          }
                          H5Tset_size(tid, size)
                          tid
                        },
                        { stop("datatype ",storage.mode," not yet implemented. Try 'double', 'integer', or 'character'.") } )
        } else {
          stop("Can not create dataset. 'storage.mode' has to be a character.")
        }
      } else {
        tid <- h5checkConstants("H5T", H5type)
      }
      if (!is.numeric(tid)) {
        message("Can not create attribute. H5type unknown. Check h5const('H5T') for valid types.")
      } else {
        if (H5Aexists(obj$H5Identifier,attr)) {
          message("Can not create attribute. Attribute with name '",attr,"' already exists.")
        } else {
          aid <- H5Acreate(obj$H5Identifier, attr, tid, sid)
          if (is(aid, "H5IdComponent")) {
            H5Aclose(aid)
            res <- TRUE
          }
        }
      }
      H5Sclose(sid)
    }
  } else {
    stop("Can not create attribute. 'dims' and 'maxdims' have to be numeric.")
  }

  h5closeitObj(obj)
  ## if (closeDataset) { H5Dclose(obj) }
  ## if (closeGroup) { H5Gclose(obj) }
  ## if (closeFile) { H5Fclose(h5loc) }
  res
}

