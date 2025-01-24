##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2023 BigOmics Analytics SA. All rights reserved.
##



#' @param x
#'
#' @return
#' @export
visplot.PCSF <- function (x, style = 0, edge_width = 5, node_size = 40, node_label_cex = 30, 
    Steiner_node_color = "lightblue", Terminal_node_color = "lightgreen", 
    Terminal_node_legend = "Terminal", Steiner_node_legend = "Steiner",
    layout = "layout_with_fr", physics=TRUE, layoutMatrix = NULL,
    width = 800, height=800, invert.weight=FALSE,
    extra_node_colors = list(), ...) 
{
    subnet = x
    if (missing(subnet)) 
        stop("Need to specify the subnetwork obtained from the PCSF algorithm.")
    if (class(subnet)[1] != "PCSF" || class(subnet)[2] != "igraph") 
        stop("The subnetwork must be a \"PCSF\" object derived from an \"igraph\" class.")
    if (edge_width < 1) 
        stop("The edge_width must be greater than 1.")
    if (node_size < 10) 
        stop("The node_size must be greater than 10.")
    prize = abs(igraph::V(subnet)$prize)
    min1 = 10
    max1 = node_size
    r1 = max1 - min1
    min2 = min(prize)
    max2 = max(prize)
    r2 = max2 - min2
    adjusted_prize = r1 * (prize - min2)/r2 + min1

    weight = igraph::E(subnet)$weight
    if(invert.weight) weight <- 1/(weight+1e-10)
    min1 = 1
    max1 = edge_width
    r1 = max1 - min1
    min2 = min(weight)
    max2 = max(weight)
    r2 = max2 - min2
    adjusted_weight = r1 * (weight - min2)/r2 + min1

    ## prepare nodes/edge dataframes
    nodes = data.frame(1:length(igraph::V(subnet)), igraph::V(subnet)$name)
    names(nodes) = c("id", "name")
    nodes$group = igraph::V(subnet)$type
    nodes$size = adjusted_prize
    nodes$title = nodes$name
    nodes$label = nodes$name
    nodes$label.cex = node_label_cex
    nodes$font.size = node_label_cex
    edges = data.frame(igraph::ends(subnet, es = igraph::E(subnet)), adjusted_weight)
    names(edges) = c("from", "to", "value")
    edges$from = match(edges$from, nodes$name)
    edges$to = match(edges$to, nodes$name)
    
    visNet <- visNetwork::visNetwork(
      nodes, edges, width = width, height = height, ... ) %>%
      visNetwork::visNodes(shadow = list(enabled = TRUE, size = 12)) %>%
      visNetwork::visEdges(scaling = list(min = 6, max = edge_width*6)) ## %>%          
    ##   visNetwork::visGroups(groupname = "Steiner", 
    ##             color = list(background = Steiner_node_color, border = "blue"), 
    ##             shape = "triangle") %>%
    ##   visNetwork::visGroups(groupname = "Terminal", 
    ##             color = list(background = Terminal_node_color, border = "green"), 
    ##             shape = "dot")
    ## leg.groups <- list(
    ##   list(
    ##     label = Terminal_node_legend, 
    ##     shape = "dot", size = 15,
    ##     color = list(background = Terminal_node_color, border = "green"),
    ##     label.cex = 0.8),
    ##   list(label = Steiner_node_legend, 
    ##        shape = "triangle", size = 10,
    ##        color = list(background = Steiner_node_color, 
    ##                     border = "blue"), label.cex = 0.8)
    ## )
    ## if (length(extra_node_colors) > 0) {
    ##   for (i in 1:length(extra_node_colors)) {
    ##     en = names(extra_node_colors)[i]
    ##     visNet <- visNet %>%
    ##       visNetwork::visGroups(
    ##         groupname = en, 
    ##         color = list(background = extra_node_colors[[en]], 
    ##                      border = "grey"), shape = "dot")
    ##     leg.groups[[i + 2]] <- list(label = en, shape = "dot", 
    ##          size = 13, color = list(background = extra_node_colors[[en]], 
    ##                                  border = "grey"), label.cex = 0.8)
    ##   }
    ## }

    if(layout!="hierarchical") {
      visNet <- visNet %>%
        visNetwork::visIgraphLayout(
          layout = layout,
          physics = physics,
          layoutMatrix = layoutMatrix)
    }
    if(layout=="hierarchical") {
      visNet <- visNet %>% visNetwork::visHierarchicalLayout(direction = "UD")
    }
  
    visNet <- visNet %>%
      visNetwork::visPhysics(enabled=physics) %>%
      visNetwork::visOptions(highlightNearest = list(enabled = TRUE)) %>% 
      visNetwork::visLegend(width = 0.05, useGroups = TRUE, position="right")        
    ## visNet <- visNet %>% visLegend(addNodes = leg.groups, width = 0.15, useGroups = FALSE)
    
    visNet
}

#
plot.pcsf <- function(net, fx0=NULL, label.cex=1) {
  ## take largest connected graph
  csize <- clusters(net)$csize
  csize
  net <- igraph::decompose.graph(net)[[which.max(csize)]]  
  
  c1 <- betweenness(net)
  c2 <- closeness(net)
  c3 <- evcent(net)$vector
  tail(sort(c1))
  tail(sort(c2))
  tail(sort(c3))
  
  if(is.null(fx0)) fx0 <- igraph::V(net)$prize
  fx0 <- tanh(1.3*fx0)
  ##vertex.label.cex <- label.cex * (0.2 + 3*abs(fx0)**2)
  vertex.label.cex <- label.cex
  
  vertex.size <- igraph::V(net)$prize**0.66
  # vertex.size <- 1 * (c1 / mean(c1))**0.3
  #vertex.size <- 1 * (c2 / mean(c2))**2
  #vertex.size <- 1.5 * (c3 / mean(c3))**0.15
  #vertex.size <- 2*vertex.label.cex
  
  vertex.color <- "lightblue"  
  cpal <- colorRampPalette(c("blue2","grey90","red3"))(33)
  vertex.color <- cpal[1+16+round(16*fx0)]
  edge.width <- (1 - igraph::E(net)$weight / max(igraph::E(net)$weight))
  
  pos <- igraph::layout_with_graphopt(
    net,
    niter = 5000,
    charge = 0.00001,
    mass = 30,
    spring.length = 1,
    spring.constant = 1
  )
  
  plot(net,
    vertex.size = vertex.size,
    vertex.color = vertex.color,  
    vertex.label.cex =vertex.label.cex,
    vertex.label.dist = 0.16,
    vertex.label.degree = pi/2, 
    vertex.label.family="sans",
    edge.width = 5*edge.width,
    layout=pos )
}

