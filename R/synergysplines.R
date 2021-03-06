#' Bayesian semi-parametric modelling for in-vitro drug combination experiments
#' 
#' @description 
#' The function \code{synergysplines} is the main function of the synergysplines package. It will fit a Bayesian semi-parametric model for in-vitro drug combination experiments to estimate synergistic and antagonistic effects. 
#' 
#' Open the package vignette for more details:
#' 
#' \code{vignette("synergysplines", package = "synergysplines")}
#' 
#' 
#'
#' @param y_mat A matrix of responses, measured as share of viable cells after treatment. 
#' Each row corresponds to a unique concentration (x1,x2), while columns represents replicates.
#' @param x_mat A matrix of drug concentrations, each row corresponds to a unique concentration (x1,x2)
#' of the two drugs.
#' @param drug_names vector; a character vector containing the names of the drugs involved
#' @param experiment_ID character; name of cell line or other identifier of experiment
#' @param log10_conc logical; if true, concentrations must be given on the log10 scale, and monotherapies must have value -Inf for the drug with concentration zero.
#' @param lower_asymptote logical; if true, lower asymptotes are estimated for the monotherapies
#' @param Alg_param A list of parameters for the adaptive MCMC algorithm. See *Details* for more information.
#' @param Hyper_param A list of hyper parameters for the model. See *Details* for more information.
#' @param var_prior Indicating which hyper-prior to put on variance terms. Either 1 (Inverse-Gamma) or 2 (Half-Cauchy)
#' @param ... Additional parameters passed
#' 
#' @details
#'
#' The argument \strong{Alg_param} is a list specifying any changes to the default values of the adaptive MCMC sampler. Any element passed will overwrite the defaults.
#' The list elements are:
#' \tabular{ll}{
#'  n_burn: \tab number of burn-in iterations for the MCMC sampler \cr
#'  thin: \tab amount of thinning \cr
#'  n_save: \tab number of final iterations returned to the user \cr
#'  g0: \tab adaptive burn-in \cr
#'  wg: \tab exponent of the adaptive function \cr 
#'  opt_rate: \tab optimal acceptance rate \cr
#'  eps: \tab parameter used for numerical stability \cr
#' }
#' 
#' The argument \strong{Hyper_param} specifies hyperparameters for the parametric part of the model. Any elements passed will overwrite the defaults.
#' All parameters are prefixed with either 'a_' and 'b_' for the Gamma or Inverse-Gamma option, or 'h_' for the Half-Cauchy prior. The table below gives the parameter names, list of valid priors, and a description of the parameter.
#' \tabular{lll}{
#' Slope_1: \tab G \tab Hyper-parameters for monotherapy slope of drug 1 \cr
#' Slope_2: \tab G \tab Hyper-parameters for monotherapy slope of drug 2 \cr
#' La_1: \tab G \tab Hyper-parameters for monotherapy lower asymptote of drug 1 \cr
#' La_2: \tab G \tab Hyper-parameters for monotherapy lower asymptote of drug 2 \cr
#' b1: \tab G \tab Hyper-parameters regulating the behaviour of the transformation g() \cr
#' b2: \tab G \tab Hyper-parameters regulating the behaviour of the transformation g() \cr
#' s2_Ec50_1: \tab IG,HC \tab Hyperparameters for the variance of the EC-50 for drug 1 \cr
#' s2_Ec50_2: \tab IG,HC \tab Hyperparameters for the variance of the EC-50 for drug 2 \cr
#' s2_gamma_0: \tab IG,HC \tab Hyperparameters for the variance of the gamma_0 parameter \cr
#' s2_gamma_1: \tab IG,HC \tab Hyperparameters for the variance of the gamma_1 parameter \cr
#' s2_gamma_2: \tab IG,HC \tab Hyperparameters for the variance of the gamma_2 parameter \cr
#' s2_eps: \tab IG,HC \tab Hyperparameters for the noise term \cr
#' }
#' For example, 'h_s2_eps' is a valid parameter name for a half-Cauchy prior on the noise term. This must be used in conjunction with \code{var_prior=2} for the half-cauchy option.
#' 
#' 
#' 
#' @return An object of S3 class “\code{BayeSyneRgy}”, which is a list with the following components:
#' \tabular{ll}{
#' OUTPUT \tab a list containing samples from the posterior distribution.  \cr 
#' data \tab the original data used to fit the model \cr
#' Alg_param \tab the parameters used for the MCMC sampler \cr
#' Hyper_param \tab the hyperparameters used for the prior distributions \cr
#' experiment_ID \tab the experiment identifier \cr
#' drug_names \tab the name of the drugs used in the experiment, taken from the column names of the concentration matrix. Used for plotting. \cr
#' Summary_Output \tab a list containing summary statistics calculated from the MCMC chains \cr
#' p_ij_mean \tab the response matrix \cr
#' p_0_mean \tab the calculated non-interaction matrix \cr
#' Delta_mean \tab the average posterior mean of the interaction \cr
#' }
#' 
#' @examples
#' library(synergysplines)
#' data("mathews_DLBCL")
#' y_mat <- mathews_DLBCL$`ispinesib + ibrutinib`[[1]]
#' x_mat <- mathews_DLBCL$`ispinesib + ibrutinib`[[2]]
#' fit <- synergysplines(y_mat,x_mat)
#' 
#' 
#' @references 
#' Cremaschi A, Frigessi A, Taskén K, Zucknick M. (2019) A Bayesian approach for the study of synergistic interaction effects in in-vitro drug combination experiments. arXiv.org. https://arxiv.org/abs/1904.04901. 
#' 
#' @export
#' 
#' @import utils plot3D viridis rgl grDevices graphics stats coda mvnfast caTools stringr

synergysplines <- function(y_mat, x_mat, drug_names=NULL, experiment_ID = NULL, log10_conc = FALSE, lower_asymptote = T, Alg_param = list(), Hyper_param = list(), var_prior = 1, ...){

  model_spec <- list(lower_asymptote=lower_asymptote)
  
  
  # Setting default parameters
  Alg_param.default <- list(n_burn = 50000, thin = 10, n_save = 5000, g0 = 1000, wg = 0.7, opt_rate = 0.234, eps = 0.001)
  
  
  # Defaul prior for variances is IG(3,2)
  Hyper_param.default <- list(a_Slope_1 = 1, b_Slope_1 =  1, a_Slope_2 = 1, b_Slope_2 =  1, 
                              a_La_1 = 0.5, b_La_1 = 0.5, a_La_2 = 0.5, b_La_2 = 0.5,
                              a_s2_gamma_0 = 3, b_s2_gamma_0 =  2, a_s2_gamma_1 = 3, b_s2_gamma_1 =  2, 
                              a_s2_gamma_2 = 3, b_s2_gamma_2 =  2, a_s2_eps = 3, b_s2_eps = 2, 
                              a_s2_Ec50_1 = 3, b_s2_Ec50_1 = 2, a_s2_Ec50_2 = 3, b_s2_Ec50_2 = 2,
                              a_b1 = 1, b_b1 = 1, a_b2 = 1, b_b2 = 1)
  
  param_alg <- modifyList(Alg_param.default,Alg_param)
  param_hyper <- modifyList(Hyper_param.default,Hyper_param)
  
  
  if(var_prior==2){# HC
    Hyper_param.default <- list(a_Slope_1 = 1, b_Slope_1 = 1, a_Slope_2 = 1, b_Slope_2 = 1,
                                a_La_1 = 0.5, b_La_1 = 0.5, a_La_2 = 0.5, b_La_2 = 0.5,
                                h_s2_gamma_0 = 1, h_s2_gamma_1 = 1,
                                h_s2_gamma_2 = 1, h_s2_eps = 1,
                                h_s2_Ec50_1 = 1, h_s2_Ec50_2 = 1,
                                a_b1 = 1, b_b1 = 1, a_b2 = 1, b_b2 = 1)
    param_hyper <- modifyList(Hyper_param.default,Hyper_param)
  }
  
  # Completing the grid in case missing values
  # Complete the grid
  unqA = sort(unique(x_mat[,1]))
  unqB = sort(unique(x_mat[,2]))
  X = as.matrix(expand.grid(unqA,unqB))
  Y = matrix(NA,ncol=ncol(y_mat),nrow=nrow(X))
  ind = match(data.frame(t(x_mat)),data.frame(t(X)))
  Y[ind,] = y_mat
  
  if (is.null(drug_names)){
    drug_names <- colnames(x_mat)
  }
  if (is.null(experiment_ID)){
    experiment_ID = ""
  }
  
  
  x_mat = as.matrix(X)
  y_mat = as.matrix(Y)
  
  
  # Finally, check concentration scale (we want to use log10, but do a check on positive concentrations first)
  
  
  if(log10_conc){
    x_mat <- 10^x_mat
    log10_conc <- FALSE
  }
  if(!log10_conc){
    if(min(x_mat[,1]) > 0){
      print("Monotherapy data for the first drug is absent.")
      return()
    }
    if(min(x_mat[,2]) > 0){
      print("Monotherapy data for the second drug is absent.")
      return()
    }
    
    x_mat[x_mat[,1] == 0,1] <- min(x_mat[x_mat[,1] > 0,1])/100
    x_mat[x_mat[,2] == 0,2] <- min(x_mat[x_mat[,2] > 0,2])/100
    x_mat <- log10(x_mat)
  }
  
  OUTPUT <- BayeSynGibbs(y_mat, x_mat, model_spec, param_alg, param_hyper)
  
  #Use OUTPUT to compute quantities of interest directly
  MCMC_Output <- OUTPUT$MCMC_Output
  SLOPE_1 <- MCMC_Output$MONO$SLOPE_1
  SLOPE_2 <- MCMC_Output$MONO$SLOPE_2
  EC50_1 <- MCMC_Output$MONO$EC50_1
  EC50_2 <- MCMC_Output$MONO$EC50_2
  LA_1 <- MCMC_Output$MONO$LA_1
  LA_2 <- MCMC_Output$MONO$LA_2
  GAMMA_0 <- MCMC_Output$GAMMA_0
  GAMMA_1 <- MCMC_Output$GAMMA_1
  GAMMA_2 <- MCMC_Output$GAMMA_2
  C <- MCMC_Output$C
  B_K1 <- MCMC_Output$B_K1
  B_K2 <- MCMC_Output$B_K2
  B_K3 <- MCMC_Output$B_K3
  B1 <- MCMC_Output$B1
  B2 <- MCMC_Output$B2
  S2_EPS <- MCMC_Output$S2_EPS
  LPML <- MCMC_Output$LPML
  
  n_rep <- dim(y_mat)[2]
  x1 <- unique(x_mat[,1])
  x2 <- unique(x_mat[,2])
  max_c1 <- max(x1)
  max_c2 <- max(x2)
  min_c1 <- min(x1)
  min_c2 <- min(x2)
  
  n1 <- length(x1)
  n2 <- length(x2)
  id <- matrix(1, n1, n2)
  id[1,] <- 0
  id[,1] <- 0
  n_save <- param_alg$n_save
  
  #Mean surfaces and other quantities of interest
  p_0_mean <- matrix(0,n1,n2)
  Delta_mean <- matrix(0,n1,n2)
  DSS_1 <- rep(0,n_save)
  DSS_2 <- rep(0,n_save)
  rVUS_p <- rep(0,n_save) #1) rVUS(1-p); 
  rVUS_Delta <- rep(0,n_save) #2) rVUS(|Delta|); 
  rVUS_syn <- rep(0,n_save) #3) rVUS(Delta^+); 
  rVUS_ant <- rep(0,n_save) #4) rVUS(Delta^-)
  
  
  #Number of knots
  K1 <- dim(B_K3[[1,1]])[1]
  K2 <- dim(B_K3[[1,1]])[2]
  
  for(g in 1:n_save){
    f_1_g <- LA_1[g]+(1-LA_1[g])*(1 + 10^(SLOPE_1[g] * (x1 - EC50_1[g])))^(-1)
    f_1_g[1] <- 1
    f_2_g <- LA_2[g]+(1-LA_2[g])*(1 + 10^(SLOPE_2[g] * (x2 - EC50_2[g])))^(-1)
    f_2_g[1] <- 1
    p_0_g <- matrix(f_1_g, nrow = n1, ncol = n2) * matrix(f_2_g, nrow = n1, ncol = n2, byrow = TRUE)
    
    B_aux <- matrix(0, n1, n2)
    for(i in 1:n1){
      for(j in 1:n2){
        B_aux[i,j] <- sum(matrix(C[g,], K1, K2) * B_K3[[i,j]])
      }
    }
    Delta <- GAMMA_0[g] + GAMMA_1[g]*matrix(x1,n1,n2) + GAMMA_2[g]*matrix(x2,n1,n2, byrow = TRUE) + B_aux
    
    Delta_trans <- - p_0_g * (1 + exp(B1[g]*Delta))^(-1) + (1 - p_0_g) * (1 + exp(-B2[g]*Delta))^(-1)
    Delta_trans <- Delta_trans * id
    
    p_0_mean <- p_0_mean + p_0_g
    Delta_mean <- Delta_mean + Delta_trans
    
    #Compute DSS scores for the two drugs (the integral is always well-defined for this model)
    AUC1 = (max_c1 - min_c1) + (log10(1 + 10^(SLOPE_1[g] * (max_c1 - EC50_1[g]))) - log10(1 + 10^(SLOPE_1[g] * (min_c1 - EC50_1[g]))))*(LA_1[g]-1)/SLOPE_1[g];
    DSS_1[g] <- 100*(1 - AUC1/(max_c1 - min_c1))
    
    AUC2 = (max_c2 - min_c2) + (log10(1 + 10^(SLOPE_2[g] * (max_c2 - EC50_2[g]))) - log10(1 + 10^(SLOPE_2[g] * (min_c2 - EC50_2[g]))))*(LA_2[g]-1)/SLOPE_2[g];
    DSS_2[g] <- 100*(1 - AUC2/(max_c2 - min_c2))
    
    #Overall efficacy
    p_ij_g <- p_0_g + Delta_trans
    rVUS_p[g] <- trapz(x2, apply(1 - p_ij_g, 2, trapz, x = x1))/diff(range(x1))/diff(range(x2)) * 100
    #Overall interaction
    rVUS_Delta[g] <- trapz(x2, apply(abs(Delta_trans), 2, trapz, x = x1))/diff(range(x1))/diff(range(x2))/max(max(p_0_g),max(1 - p_0_g)) * 100
    #Synergistic part
    Delta_trans_syn <- -Delta_trans
    Delta_trans_syn[Delta_trans_syn < 0] <- 0
    rVUS_syn[g] <- trapz(x2, apply(Delta_trans_syn, 2, trapz, x = x1))/diff(range(x1))/diff(range(x2))/max(p_0_g) * 100
    #Antagonistic part
    Delta_trans_ant <- Delta_trans
    Delta_trans_ant[Delta_trans_ant < 0] <- 0
    rVUS_ant[g] <- trapz(x2, apply(Delta_trans_ant, 2, trapz, x = x1))/diff(range(x1))/diff(range(x2))/max(1 - p_0_g) * 100
  }
  #Average surfaces
  p_0_mean <- p_0_mean/n_save
  Delta_mean <- Delta_mean/n_save
  p_ij_mean <- p_0_mean + Delta_mean
  
  LPML <- MCMC_Output$LPML
  
  Summary_Output <- list()
  Summary_Output[[1]] <- EC50_1
  Summary_Output[[2]] <- EC50_2
  Summary_Output[[3]] <- SLOPE_1
  Summary_Output[[4]] <- SLOPE_2
  Summary_Output[[5]] <- LA_1
  Summary_Output[[6]] <- LA_2
  Summary_Output[[7]] <- DSS_1
  Summary_Output[[8]] <- DSS_2
  Summary_Output[[9]] <- S2_EPS
  Summary_Output[[10]] <- rVUS_p
  Summary_Output[[11]] <- rVUS_Delta
  Summary_Output[[12]] <- rVUS_syn
  Summary_Output[[13]] <- rVUS_ant
  
  
  names(Summary_Output) <- c(paste("EC50 (", drug_names[1], ")", sep = ""), paste("EC50 (", drug_names[2], ")", sep = ""),
                             paste("Slope (", drug_names[1], ")", sep = ""), paste("Slope (", drug_names[2], ")", sep = ""),
                             paste("LowAsymp (", drug_names[1], ")", sep=""), paste("LowAsymp (", drug_names[2], ")", sep=""),
                             paste("DSS (", drug_names[1], ")", sep = ""), paste("DSS (", drug_names[2], ")", sep = ""),
                             "S2_EPS", "rVUS_p", "rVUS_Delta", "rVUS_syn", "rVUS_ant")
  
  
  #Put everything in a list
  synergysplines_out <- list()
  synergysplines_out$OUTPUT <- OUTPUT
  synergysplines_out$data <- list("y_mat" = y_mat, "x_mat" = x_mat)
  synergysplines_out$lower_asymptote <- lower_asymptote
  synergysplines_out$Alg_param <- param_alg
  synergysplines_out$Hyper_param <- param_hyper
  synergysplines_out$drug_names <- drug_names
  synergysplines_out$experiment_ID <- experiment_ID
  synergysplines_out$Summary_Output <- Summary_Output
  synergysplines_out$p_ij_mean <- p_ij_mean
  synergysplines_out$p_0_mean <- p_0_mean
  synergysplines_out$Delta_mean <- Delta_mean
  
  class(synergysplines_out) <- "synergysplines"
  return(synergysplines_out)
}








