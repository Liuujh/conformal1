
#' Linear regression training and prediction functions, and special
#'   leave-one-out fitting function.
#'
#' Construct the training and prediction functions for linear regression, and 
#'   a special function to quickly compute leave-one-out fitted values.
#'
#' @param intercept Should an intercept be included in the linear model? Default
#'   is TRUE.
#' @param lambda A value or sequence of lambda values to be used in ridge
#'   regression. Default is 0, which means ordinary linear regression.
#'
#' @return A list with four components: train.fun, predict.fun, special.fun,
#'   active.fun. The last function is designed to take the output of train.fun,
#'   and reports which features are active for each fitted model contained in
#'   this output. Trivially, here, all features are generically active in ridged
#'   linear models.
#'
#' @details The train.fun function constructed here leverages an optional third
#'   argument (in addition to the usual x,y): out, whose default is NULL. If
#'   non-NULL, it is assumed to be the result of a previous call to train.fun,
#'   on the \emph{same} features x as we are currently considering. This is done
#'   for efficiency, and to perform the regression, it uses the saved Cholesky
#'   decomposition instead of computing a new one from scratch. 
#'
#' @example examples/ex.lm.funs.R
#' @export lm.funs

# RJT note to self: when p > n, and we are fitting ridge regression with an 
# unpenalized intercept, it doesn't seem possible to use the "kernel trick" for
# quick ridge regression computation, in a way that's compatible with the 
# special leave-one-out formula. So none of the computations below employ this
# trick ... which is unfortunate

lm.funs = function(intercept=TRUE, lambda=0) {
  check.bool(intercept)
  m = length(lambda)
  for (j in 1:m) check.pos.num(lambda[j])

  # Training function
  train.fun = function(x,y,out=NULL) {
    n = nrow(x); p = ncol(x)
    v = rep(1,p)
    
    if (intercept) {
      x = cbind(rep(1,n),x)
      v = c(0,v)
    }

    # Compute Cholesky factorization, only if we need to
    if (!is.null(out)) {
      svd.R = out$svd.R
    }
    else {
      svd.R = vector(mode="list",length=m)
      for (j in 1:m) {
        A = crossprod(x) + lambda[j] * diag(v)
        A[is.na(A)] = 0
        A[is.infinite(A)] = 0
        svd.R[[j]] = svd(A)
      }
    }

    beta = matrix(0,p+intercept,m)
    for (j in 1:m) {
      U = svd.R[[j]]$u
      D = svd.R[[j]]$d
      V = svd.R[[j]]$v
      D_inv = diag(1 / pmax(D, 1e-8))
      beta[,j] = V %*% D_inv %*% t(U) %*% t(x) %*% y
    }
    
    return(list(beta=beta,svd.R=svd.R))
  }

  # Prediction function
  predict.fun = function(out,newx) {
    if (intercept) {
      newx = cbind(rep(1,nrow(newx)),newx)
    }
    return(newx %*% out$beta)
  }

  # Special leave-one-out function, uses Cholesky
  special.fun = function(x,y,out) {
    n = nrow(x); p = ncol(x)
    if (intercept) {
      x = cbind(rep(1,n),x)
    }
    
    res = y - x %*% out$beta
    for (j in 1:m) {
      s = diag(x %*% chol.solve(out$chol.R[[j]], t(x)))
      res[,j] = res[,j] / (1-s)
    }
    return(res)
  }

  # Active function
  active.fun = function(out) {
    p = ifelse(intercept, nrow(out$beta)-1, nrow(out$beta))
    m = ncol(out$beta)
    act.list = vector(length=m,mode="list")
    for (i in 1:m) act.list[[i]] = 1:p
    return(act.list)
  }
  
  return(list(train.fun=train.fun, predict.fun=predict.fun,
              special.fun=special.fun, active.fun=active.fun))
}

#' @export chol.solve

chol.solve = function(R, x) {
  return(backsolve(R, backsolve(R, x, transpose=T)))
}
