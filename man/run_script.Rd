% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{run_script}
\alias{run_script}
\title{Execute analysis script in container}
\usage{
run_script(script_path, container_cmd = "docker-r")
}
\arguments{
\item{script_path}{Path to R script}

\item{container_cmd}{Container command (default: "docker-r")}
}
\value{
Logical indicating success
}
\description{
Execute analysis script in container
}
