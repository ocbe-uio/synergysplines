#' Plot function for a synergysplines object
#' 
#' @description A function for plotting synergy surfaces and summary statistics of a \code{synergysplines} object.
#' 
#' @param x synergysplines object, the result of \code{\link{synergysplines}}.
#' @param add_contour logical; if TRUE, draws contour lines at specified levels
#' @param contour_levels the contour levels
#' @param plot_type which plots to display. Either "2D" for two-dimensional contour plots, "3D" for interactive three-dimensional plots of the surfaces, or "both" for both these options.
#' @param save_plot logical; if TRUE, plots are saved locally
#' @param path string; path for saving plots, if NULL default is work directory
#' @param ... further arguments passed to or from other methods.
#' 
#' @details 
#' This function extends \code{plot} to draw response and interaction surfaces of the fitted model. Both three-dimensional interactive plots, and two-dimensional contour plots can be displayed.
#' 
#' @examples
#' library(synergysplines)
#' data("mathews_DLBCL")
#' y_mat <- mathews_DLBCL$`ispinesib + ibrutinib`[[1]]
#' x_mat <- mathews_DLBCL$`ispinesib + ibrutinib`[[2]]
#' fit <- synergysplines(y_mat,x_mat)
#' plot(fit)
#' 
#' @export 


plot.synergysplines <- function(x, add_contour = TRUE, contour_levels = 0.5, plot_type = "2D", save_plot = FALSE, path=NULL, ...){
  
  # Removed attach here, so need to declare some variables properly
  drug_names <- x$drug_names
  drug_names_forplot <- drug_names
  for(i in 1:length(drug_names)){
    drug_names_forplot[i] <- str_replace(drug_names[i], " ", "_")
  }
  experiment_ID <- x$experiment_ID
  
  if (is.null(path)){
    path <- getwd()
  } else{
    # Check if supplied path exists
    if (!dir.exists(path)){
      print("Invalid path")
      stop()
    }
  }

  
  data <- x$data
  x_mat <- data$x_mat
  x1 <- unique(x_mat[,1])
  x2 <- unique(x_mat[,2])
  
  #Average surfaces and other quantities to plot
  p_ij_mean <- x$p_ij_mean
  p_0_mean <- x$p_0_mean
  Delta_mean <- x$Delta_mean
  DSS_1 <- x$Summary_Output[[7]]
  DSS_2 <- x$Summary_Output[[8]]
  rVUS_p <- x$Summary_Output$rVUS_p
  rVUS_Delta <- x$Summary_Output$rVUS_Delta
  rVUS_syn <- x$Summary_Output$rVUS_syn
  rVUS_ant <- x$Summary_Output$rVUS_ant
  
  S2_EPS <- x$OUTPUT$MCMC_Output$S2_EPS
  
  
  
  #Close all graphic tools open 
  graphics.off()
  
  #Interaction surface has a different color scale
  Delta_col_palette <- colorRampPalette(c("green", "yellow", "red"))
  
  
  if(plot_type == "2D"){#Default
    plot_2D = TRUE
    plot_3D = FALSE
  }
  if(plot_type == "3D"){
    plot_2D = FALSE
    plot_3D = TRUE
  }
  if(plot_type == "both"){
    plot_2D = TRUE
    plot_3D = TRUE
  }
  
  #################################
  ## We include a 3d-plot option ##
  #################################
  if(plot_3D){
    M <- mesh(x1,x2)
    
    mfrow3d(1, 3)
    
    #p_ij
    z <- p_ij_mean
    col <- viridis(20)[1 + round(19*(z - min(z))/diff(range(z)))]
    persp3d(M$x, M$y, z = z, col = col, zlab = "", main = "", xlab = "", ylab = "", cex.main = 4)
    title3d(main = expression(p[ij]), xlab = drug_names[1], ylab = drug_names[2], cex = 1.5)
    
    #p_0
    z <- p_0_mean
    col <- viridis(20)[1 + round(19*(z - min(z))/diff(range(z)))]
    persp3d(M$x, M$y, z = z, col = col, zlab = "", main = "", xlab = "", ylab = "", cex.main = 4)
    title3d(main = expression(p[0]), xlab = drug_names[1], ylab = drug_names[2], cex = 1.5)    
    
    #Delta_ij
    z <- Delta_mean
    col <- Delta_col_palette(20)[1 + round(19*(z - min(z))/diff(range(z)))]
    persp3d(M$x, M$y, z = z, col = col, zlab = "", main = "", xlab = "", ylab = "", cex.main = 4)
    title3d(main = expression(Delta[ij]), xlab = drug_names[1], ylab = drug_names[2], cex = 1.5)      
    
    # if(save_plot){
    #   rgl.postscript(paste(drug_names_forplot[1], drug_names_forplot[2], "3Dplot.eps", sep = "_"), "eps")
    #   rgl.close()
    # }else{
    readline("Press key for next plot")
    # }
  }
  
  
  if(plot_2D){
    if(save_plot){
      pdf(paste0(path,paste(experiment_ID,drug_names_forplot[1], drug_names_forplot[2], "ResponseContour.pdf", sep = "_")))
    }
    
    
    par(mar = c(6,5,6,5))
    #p_ij
    filled.contour(x = x1,y = x2, z = p_ij_mean, levels = seq(0, 1, by = 0.1),
                   plot.title = title(main = bquote(.(experiment_ID) : hat(p)[ij]), xlab = drug_names[1], ylab = drug_names[2], cex.main = 2.5, cex.lab = 2),
                   plot.axes = {axis(1, round(x1,2),labels=c(0,round(10^x1[-1],2))); axis(2, round(x2,2),labels=c(0,round(10^x2[-1],2))); contour(x = x1,y = x2, z = p_ij_mean, levels = contour_levels, labels = contour_levels, lwd = 2, col = "red", add = add_contour)},
                   color.palette = viridis,
                   key.title = title(main=""),
                   key.axes = axis(4, seq(0, 1, by = 0.1)) )
    if(save_plot){
      dev.off()
    }else{
      readline("Press key for next plot")
    }
    
    if(save_plot){
      pdf(paste0(path,paste(experiment_ID,drug_names_forplot[1], drug_names_forplot[2], "BaselineContour.pdf", sep = "_")))
    }
    
    par(mar = c(6,5,6,5))
    #p_0
    filled.contour(x = x1,y = x2, z = p_0_mean, levels = seq(0, 1, by = 0.1),
                   plot.title = title(main = bquote(.(experiment_ID) : hat(p)[ij]^0), xlab = drug_names[1], ylab = drug_names[2], cex.main = 2.5, cex.lab = 2),
                   plot.axes = {axis(1, round(x1,2),labels=c(0,round(10^x1[-1],2))); axis(2, round(x2,2),labels=c(0,round(10^x2[-1],2)))},
                   color.palette = viridis,
                   key.title = title(main=""),
                   key.axes = axis(4, seq(0, 1, by = 0.1)) )
    if(save_plot){
      dev.off()
    }else{
      readline("Press key for next plot")
    }
    
    if(save_plot){
      pdf(paste0(path,paste(experiment_ID,drug_names_forplot[1], drug_names_forplot[2], "InteractionContour.pdf", sep = "_")))
    }
    
    par(mar = c(6,5,6,5))
    #Delta_ij
    filled.contour(x = x1,y = x2, z = Delta_mean, levels = seq(-1,1,by = 0.1),
                   plot.title = title(main = bquote(.(experiment_ID) : hat(Delta)[ij]), xlab = drug_names[1], ylab = drug_names[2], cex.main = 2.5, cex.lab = 2),
                   plot.axes = {axis(1, round(x1,2),labels=c(0,round(10^x1[-1],2))); axis(2, round(x2,2),labels=c(0,round(10^x2[-1],2))); contour(x = x1,y = x2, z = Delta_mean, levels = 0, labels = 0, lty = 2, lwd = 2, col = "grey", add = TRUE)},
                   color.palette = Delta_col_palette,
                   key.title = title(main=""),
                   key.axes = axis(4, seq(-1,1,by = 0.25)) )
    if(save_plot){
      dev.off()
    }else{
      readline("Press key for next plot")
    }
  }
  
  
  ##############
  ## Posterior distribution of some hyperparameters of interest
  ##############
  

  if(save_plot){
    pdf(paste0(path,paste(experiment_ID,drug_names_forplot[1], drug_names_forplot[2], "S2eps_DSS.pdf", sep = "_")), width = 10, height = 5)
  }
  par(mfrow = c(1,3), mar = c(7.5,5,5,5))
  #s2_eps
  hist(S2_EPS, col = "lightblue", probability = TRUE, breaks = 30, xlab = "", ylab = "", main = bquote("P("~sigma[epsilon]^2~"|y)"), cex.axis = 1.5)
  title(xlab = expression(sigma[epsilon]^2), cex.lab = 1.5)
  #DSS first and second drugs
  hist(DSS_1, col = "lightblue", probability = TRUE, breaks = 30, xlab = "DSS", ylab = "", main = paste("DSS for ", drug_names[1], sep = ""), cex.axis = 1.5)
  hist(DSS_2, col = "lightblue", probability = TRUE, breaks = 30, xlab = "DSS", ylab = "", main = paste("DSS for ", drug_names[2], sep = ""), cex.axis = 1.5)
  mtext(paste(experiment_ID,"-",drug_names_forplot[1], "&", drug_names_forplot[2]),side=1,outer=T,line=-2,cex=1.5)
  if(save_plot){
    dev.off()
  }else{
    readline("Press key for next plot")
  }
  
  if(save_plot){
    pdf(paste0(path,paste(experiment_ID,drug_names_forplot[1], drug_names_forplot[2], "rVUS.pdf", sep = "_")), width = 10, height = 5)
  }
  par(mfrow = c(2,2), mar = c(7.5,5,5,5))
  hist(rVUS_p, col = "lightblue", probability = TRUE, breaks = 30, xlab = "rVUS(1 - p)", ylab = "", main = "Overall efficacy", cex.axis = 1.5)
  hist(rVUS_Delta, col = "lightblue", probability = TRUE, breaks = 30, xlab = bquote("rVUS(|"~Delta~"|)"), ylab = "", main = "Overall interaction", cex.axis = 1.5)
  hist(rVUS_syn, col = "lightblue", probability = TRUE, breaks = 30, xlab = expression("rVUS(" ~ Delta^{phantom()+phantom()} ~ ")"), ylab = "", main = "Synergistic interaction", cex.axis = 1.5)
  hist(rVUS_ant, col = "lightblue", probability = TRUE, breaks = 30, xlab = expression("rVUS(" ~ Delta^{phantom()-phantom()} ~ ")"), ylab = "", main = "Antagonistic interaction", cex.axis = 1.5)
  mtext(paste(experiment_ID,"-",drug_names_forplot[1], "&", drug_names_forplot[2],sep=" "),side=1,outer=T,line=-2,cex=1.5)
  if(save_plot){
    dev.off()
  }else{
    readline("Press key for next plot")
  }

  
}
