# TRENTO UTILS

## Description

This project is aimed at providing utility functions for Trento support. It includes various tools and scripts that can be used to streamline development processes and enhance productivity.

## Tools

### getcatalog.sh

This script retrieves the catalog from a Trento server installation running in a Kubernetes cluster.
The script expects Trento username to be passed as the only argument (-u) and prompts for the corresponding password: then uses them to authenticate and retrieve the catalog.
The catalog is saved to a file specified by the catalog_file variable.
