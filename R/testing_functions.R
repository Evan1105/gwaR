#' function for fitting a  \code{\link{gblup}} model followed by \code{\link{gwas}} analysis.  
#' @title GBLUP and GWA computation 
#' @param rsp a string with the name of the response variable if a vector, first element is used. 
#' @param data either a gpData object from synbreed or a dataframe containing records for response variable and classification factors used as fixed or random effects  
#' @param design a list or a vector with formulas for fixed and random effects
#' @param vdata a list with proportional covariance matrices of additional random effects (not included in data)
#' @param G a proportional covariance for genetics effects being predicted. 
#' @param vdata a list with proportional covariance matrices of additional random effects (not included in data)
#' @param wt a vector of weigths (proportional to diagonals of residual covariance matrix), or a matrix of weights with anmimals in rows and response variables in columns
#' @param LRT logical indicating if a LRT is performed to test for h2 before performing GWA
#' @param threshold the significance threshold of LRT
#' @param returnz a logical value. If T the t-statistics for each SNP is returned, if F estimated SNP effects and variances are returnes
#' @param ... additional parameters for regress function
#' @param x A matrix of standardized genotypes with animals in columns and markers in rows
#' @return if {\code{returnz=F}}, an object of the class GWAS: a list with two vectors
#' \itemize{ 
#'    \item {\code{ghat}} {estimated SNP effects} 
#'    \item{\code{varg}} {estimated SNP effect variances}
#'}
#' @return if {\code{returnz=F}} the t-statistic {\code{t=ghat/sqrt(varg)}} 
#' @seealso \code{\link{gblup}} \code{\link{gwas}} \code{\link{lrt}}
#' @export

run.gwa <- function(rsp, data, design, G, vdata = NULL, wt = NULL, x, LRT = F, threshold = 0.01, returnz = T, saveblup = F, 
    basename = "", ...) {
    
    rstI <- gblup(rsp = rsp, data = data, design = design, G = G, vdata = vdata, wt = wt, ...)
    pv <- 0
    if (saveblup) {
        tosave <- summary(rstI, fe = T, sigma = T)
        fname <- paste(basename, tosave$name, ".RData", sep = "_")
        save(tosave, file = fname)
    }
    cat("done with gblup...\n")
    if (LRT) {
        cat("performing LRT...\n")
        pv <- lrt(rstI)$pvalue
    }
    if (pv <= threshold) {
        cat("performing association...\n")
        gw <- gwas(rstI, x)
        if (returnz) {
            zscore <- gw[, 1]/sqrt(gw[, 2])
            names(zscore) <- rownames(gw)
        } else {
            zscore <- gw
        }
    } else {
        zscore <- NULL
    }
    
    return(zscore)
}

#' function for performing likelihood ratio test for  \code{h^2=0} of a \code{\link{gblup}} model   
#' @title Likelihood ratio tests for GBLUP models 
#' @param gb a gblup model 
#' @return a list with elements
#' \itemize{ 
#'    \item {\code{pvalue}} {the pvalue of the LRT} 
#'    \item{\code{llik}} {Log-likelihood of full model, reduced model and their difference}
#'    \item{\code{VARS}} {a dataframe with variance component estimates under reduced and full model}
#'}
#' @seealso \code{\link{gblup}} \code{\link{gwas}}
#' @export

lrt <- function(gb) {
    strt <- gb$sigma[names(gb$sigma) != "G"]
    
    s1 <- gb$sigma
    md <- gb$model
    md$formula <- NULL
    md$Vformula <- NULL
    rg <- regress(gb$mod$formula, update(gb$mod$Vformula, ~. - G), identity = F, start = strt, data = md)
    tst <- gb$llik - rg$llik
    s2 <- s1
    s2[["G"]] <- NA
    s2[names(strt)] <- rg$sigma
    p1 <- s1/sum(s1)
    pvalue <- pchisq(2 * tst, 1, lower.tail = F)/2
    likelihoods <- data.frame(full = gb$llik, red = rg$llik, dif = tst)
    return(list(pvalue = pvalue, llik = likelihoods, vars = data.frame(full = s1, reduced = s2, perc.full = p1)))
}

#' function for performing likelihood ratio test  \code{h_peak^2=0} of QTL peak using a \code{\link{gblup}} model   
#' @title Likelihood ratio tests for QTL peaks 
#' @param gb a gblup model 
#' @param x A matrix of standardized genotypes with animals in columns and markers in rows 
#' @param peak_pos an index vector used to select the rows (markers) of x that capture the QTL peak. if NULL: the whole x matrix is used.
#' @return a list with elements
#' \itemize{ 
#'    \item {\code{pvalue}} {the pvalue of the LRT} 
#'    \item{\code{llik}} {Log-likelihood of full model, reduced model and their difference}
#'    \item{\code{VARS}} {a dataframe with variance component estimates under reduced and full model}
#'}
#' @seealso \code{\link{gblup}} \code{\link{lrt}}
#' @export
test.peak <- function(gb, x, peak_pos = NULL) {
    if (is.null(peak_pos)) {
        z <- x
    } else {
        z <- x[peak_pos, ]
    }
    md <- gb$model
    md$formula <- NULL
    md$Vformula <- NULL
    md$G_bkg <- md$G
    Gpeak <- t(z) %*% z
    Gpeak <- Gpeak/mean(diag(Gpeak)) * mean(diag(md$G_bkg))
    md$G <- Gpeak
    new_form <- update(gb$mod$Vformula, ~. + G_bkg)
    strt <- gb$sigma
    strt[["G_bkg"]] <- strt[["G"]] * 0.75
    strt[["G"]] <- strt[["G"]] * 0.25
    
    rg <- regress(gb$mod$formula, new_form, identity = F, data = md)
    lt <- lrt(rg)
    return(lt)
} 
