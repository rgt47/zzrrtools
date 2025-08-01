#!/bin/bash
##############################################################################
# ZZCOLLAB CLI MODULE
##############################################################################
# 
# PURPOSE: Command line interface parsing and validation
#          - Command line argument parsing
#          - Flag variable initialization
#          - User-friendly interface processing
#          - Argument validation
#
# DEPENDENCIES: None (loaded before other modules)
#
# EXPORTS: All CLI variables and functions for use by main script
##############################################################################

#=============================================================================
# CLI ARGUMENT VALIDATION FUNCTIONS
#=============================================================================

# Function: require_arg
# Purpose: Validate that a flag has a required argument
# Arguments: $1 - flag name, $2 - argument value
require_arg() {
    [[ -n "${2:-}" ]] || { echo "❌ Error: $1 requires an argument" >&2; exit 1; }
}

#=============================================================================
# CLI VARIABLE INITIALIZATION
#=============================================================================

# Initialize variables for command line options with same defaults as original
BUILD_DOCKER=true
DOTFILES_DIR=""
DOTFILES_NODOT=false
readonly DEFAULT_BASE_IMAGE="rocker/r-ver"
BASE_IMAGE="$DEFAULT_BASE_IMAGE"

# Multi-architecture support configuration
MULTIARCH_VERSE_IMAGE="${MULTIARCH_VERSE_IMAGE:-rocker/verse}"
FORCE_PLATFORM="${FORCE_PLATFORM:-auto}"
export MULTIARCH_VERSE_IMAGE FORCE_PLATFORM

# New user-friendly interface variables
TEAM_NAME=""
PROJECT_NAME=""
INTERFACE=""
GITHUB_ACCOUNT=""
DOCKERFILE_PATH=""

# Base image selection for team initialization
readonly DEFAULT_INIT_BASE_IMAGE="all"
INIT_BASE_IMAGE="$DEFAULT_INIT_BASE_IMAGE"    # Options: r-ver, rstudio, verse, all

# Initialization mode variables
INIT_MODE=false
USE_DOTFILES=false
PREPARE_DOCKERFILE=false
BUILD_VARIANT_MODE=false
BUILD_VARIANT=""
SKIP_CONFIRMATION=false
CREATE_GITHUB_REPO=false

# Simplified build mode system (replaces complex flag system)
readonly DEFAULT_BUILD_MODE="standard"
BUILD_MODE="$DEFAULT_BUILD_MODE"    # Options: fast, standard, comprehensive
# fast        = minimal Docker + minimal packages (fastest builds)
# standard    = standard Docker + standard packages (balanced)
# comprehensive = extended Docker + full packages (kitchen sink)

# Legacy compatibility flags (deprecated but maintained for backward compatibility)
MINIMAL_PACKAGES=false
EXTRA_PACKAGES=false
MINIMAL_DOCKER=false
EXTRA_DOCKER=false
MINIMAL_PACKAGES_ONLY=false

# Show flags (processed after modules are loaded)
SHOW_HELP=false
SHOW_NEXT_STEPS=false

#=============================================================================
# CLI ARGUMENT PARSING FUNCTION
#=============================================================================

# Function: parse_cli_arguments
# Purpose: Parse all command line arguments and set global variables
# Arguments: All command line arguments passed to script
parse_cli_arguments() {
    # Process all command line arguments (identical to original zzcollab.sh)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-docker|-n)
                BUILD_DOCKER=false
                shift
                ;;
            --dotfiles|-d)
                require_arg "$1" "$2"
                DOTFILES_DIR="$2"
                shift 2
                ;;
            --dotfiles-nodot|-D)
                require_arg "$1" "$2"
                DOTFILES_DIR="$2"
                DOTFILES_NODOT=true
                shift 2
                ;;
            --base-image|-b)
                require_arg "$1" "$2"
                BASE_IMAGE="$2"
                shift 2
                ;;
            --init-base-image|-B)
                require_arg "$1" "$2"
                case "$2" in
                    r-ver|rstudio|verse|all)
                        INIT_BASE_IMAGE="$2"
                        ;;
                    *)
                        echo "❌ Error: Invalid base image '$2'. Valid options: r-ver, rstudio, verse, all" >&2
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --team|-t)
                require_arg "$1" "$2"
                TEAM_NAME="$2"
                shift 2
                ;;
            --project-name|--project|-p)
                require_arg "$1" "$2"
                PROJECT_NAME="$2"
                shift 2
                ;;
            --interface|-I)
                require_arg "$1" "$2"
                INTERFACE="$2"
                shift 2
                ;;
            --init|-i)
                INIT_MODE=true
                shift
                ;;
            --team-name)
                require_arg "$1" "$2"
                TEAM_NAME="$2"
                shift 2
                ;;
            --github-account|-g)
                require_arg "$1" "$2"
                GITHUB_ACCOUNT="$2"
                shift 2
                ;;
            --dockerfile|-f)
                require_arg "$1" "$2"
                DOCKERFILE_PATH="$2"
                shift 2
                ;;
            --prepare-dockerfile|-P)
                PREPARE_DOCKERFILE=true
                shift
                ;;
            --fast|-F)
                BUILD_MODE="fast"
                shift
                ;;
            --standard|-S)
                BUILD_MODE="standard"
                shift
                ;;
            --comprehensive|-C)
                BUILD_MODE="comprehensive"
                shift
                ;;
            --minimal|-m)
                # Legacy compatibility: maps to fast mode
                BUILD_MODE="fast"
                MINIMAL_PACKAGES=true
                shift
                ;;
            --extra-packages|-x)
                # Legacy compatibility: maps to comprehensive mode
                BUILD_MODE="comprehensive"
                EXTRA_PACKAGES=true
                shift
                ;;
            --minimal-docker)
                # Legacy compatibility: set Docker flag and use fast mode
                MINIMAL_DOCKER=true
                BUILD_MODE="fast"
                shift
                ;;
            --extra-docker)
                # Legacy compatibility: set Docker flag and use comprehensive mode
                EXTRA_DOCKER=true
                BUILD_MODE="comprehensive"
                shift
                ;;
            --minimal-packages|-M)
                # Legacy compatibility: set package flag and use fast mode
                MINIMAL_PACKAGES_ONLY=true
                BUILD_MODE="fast"
                shift
                ;;
            --next-steps)
                # Will be processed after modules are loaded
                SHOW_NEXT_STEPS=true
                shift
                ;;
            --build-variant|-V)
                require_arg "$1" "$2"
                case "$2" in
                    r-ver|rstudio|verse)
                        BUILD_VARIANT_MODE=true
                        BUILD_VARIANT="$2"
                        ;;
                    *)
                        echo "❌ Error: Invalid build variant '$2'. Valid options: r-ver, rstudio, verse" >&2
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            --help|-h)
                # Will be processed after modules are loaded
                SHOW_HELP=true
                shift
                ;;
            --yes|-y)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --github)
                CREATE_GITHUB_REPO=true
                shift
                ;;
            *)
                echo "❌ Error: Unknown option '$1'" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

#=============================================================================
# USER-FRIENDLY INTERFACE PROCESSING
#=============================================================================

# Function: process_user_friendly_interface
# Purpose: Convert user-friendly team flags to base image names
process_user_friendly_interface() {
    # Convert user-friendly flags to BASE_IMAGE if provided (only for non-init mode)
    if [[ "$INIT_MODE" != "true" ]]; then
        if [[ -n "$TEAM_NAME" && -n "$PROJECT_NAME" && -n "$INTERFACE" ]]; then
            case "$INTERFACE" in
                shell)
                    BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-shell"
                    ;;
                rstudio)
                    BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-rstudio"
                    ;;
                verse)
                    BASE_IMAGE="${TEAM_NAME}/${PROJECT_NAME}core-verse"
                    ;;
                *)
                    echo "❌ Error: Unknown interface '$INTERFACE'" >&2
                    echo "Valid interfaces: shell, rstudio, verse" >&2
                    exit 1
                    ;;
            esac
            
            # Check if team image exists before proceeding
            check_team_image_availability "$BASE_IMAGE" "$TEAM_NAME" "$PROJECT_NAME" "$INTERFACE"
            echo "ℹ️  Using team image: $BASE_IMAGE"
        elif [[ -n "$TEAM_NAME" || -n "$PROJECT_NAME" || -n "$INTERFACE" ]]; then
            # If some team flags are provided but not all, show error (only for non-init mode)
            echo "❌ Error: When using team interface, all flags are required:" >&2
            echo "  --team TEAM_NAME --project-name PROJECT_NAME --interface INTERFACE" >&2
            echo "  Valid interfaces: shell, rstudio, verse" >&2
            exit 1
        fi
    fi
}

#=============================================================================
# TEAM IMAGE AVAILABILITY CHECKING
#=============================================================================

# Function: check_team_image_availability
# Purpose: Verify that required team image exists, provide helpful error if not
# Arguments: $1 = base_image, $2 = team_name, $3 = project_name, $4 = interface
check_team_image_availability() {
    local base_image="$1"
    local team_name="$2"
    local project_name="$3"
    local interface="$4"
    
    # Try to check if image exists on Docker Hub
    if ! docker manifest inspect "$base_image:latest" >/dev/null 2>&1; then
        echo ""
        echo "❌ Error: Team image '$base_image:latest' not found"
        echo ""
        
        # Check what team images are available
        echo "ℹ️  Checking available variants for this project..."
        local available_images=()
        
        # Check common variants
        for variant in shell rstudio verse; do
            local image_name="${team_name}/${project_name}core-${variant}:latest"
            if docker manifest inspect "$image_name" >/dev/null 2>&1; then
                available_images+=("$variant")
            fi
        done
        
        if [[ ${#available_images[@]} -gt 0 ]]; then
            echo "✅ Available variants for this project:"
            for variant in "${available_images[@]}"; do
                echo "    - ${team_name}/${project_name}core-${variant}:latest"
            done
            echo ""
            echo "💡 Solutions:"
            echo "   1. Use available variant:"
            for variant in "${available_images[@]}"; do
                echo "      zzcollab -t $team_name -p $project_name -I $variant -d ~/dotfiles"
            done
            echo "   2. Ask team lead to build $interface variant:"
            echo "      zzcollab -V $(interface_to_variant "$interface")"
            echo "   3. List all available images:"
            echo "      docker images | grep ${team_name}/${project_name}core"
        else
            echo "⚠️  No team images found for $team_name/$project_name"
            echo ""
            echo "💡 Solutions:"
            echo "   1. Check if team lead has run initial setup:"
            echo "      zzcollab -i -t $team_name -p $project_name -B all"
            echo "   2. Verify team and project names are correct"
            echo "   3. Check Docker Hub for available images:"
            echo "      https://hub.docker.com/r/$team_name/$project_name"
        fi
        echo ""
        exit 1
    fi
}

# Function: interface_to_variant
# Purpose: Convert interface name to build variant name
# Arguments: $1 = interface (shell, rstudio, verse)
interface_to_variant() {
    case "$1" in
        shell) echo "r-ver" ;;
        rstudio) echo "rstudio" ;;
        verse) echo "verse" ;;
        *) echo "$1" ;;
    esac
}

#=============================================================================
# CLI VARIABLE EXPORT FUNCTION
#=============================================================================

# Function: export_cli_variables
# Purpose: Export all CLI variables for use by other modules
export_cli_variables() {
    # Core build options
    export BUILD_DOCKER DOTFILES_DIR DOTFILES_NODOT BASE_IMAGE
    
    # Team interface variables
    export TEAM_NAME PROJECT_NAME INTERFACE GITHUB_ACCOUNT DOCKERFILE_PATH
    
    # Mode and behavior flags
    export INIT_MODE USE_DOTFILES PREPARE_DOCKERFILE BUILD_MODE
    
    # GitHub integration flags
    export CREATE_GITHUB_REPO SKIP_CONFIRMATION
    
    # Legacy package configuration flags (deprecated)
    export MINIMAL_PACKAGES EXTRA_PACKAGES
    
    # Legacy Docker and package control flags (deprecated)
    export MINIMAL_DOCKER EXTRA_DOCKER MINIMAL_PACKAGES_ONLY
    
    # Show/display flags
    export SHOW_HELP SHOW_NEXT_STEPS
}

#=============================================================================
# CLI VALIDATION FUNCTIONS
#=============================================================================

# Function: validate_cli_arguments
# Purpose: Validate CLI argument combinations and required values
validate_cli_arguments() {
    # Validate BUILD_MODE is valid
    if [[ "$BUILD_MODE" != "fast" && "$BUILD_MODE" != "standard" && "$BUILD_MODE" != "comprehensive" ]]; then
        echo "❌ Error: Invalid build mode '$BUILD_MODE'" >&2
        echo "   Valid modes: fast, standard, comprehensive" >&2
        exit 1
    fi
    
    # Warn about deprecated flag usage (informational only)
    if [[ "$MINIMAL_PACKAGES" == "true" || "$EXTRA_PACKAGES" == "true" || "$MINIMAL_DOCKER" == "true" || "$EXTRA_DOCKER" == "true" || "$MINIMAL_PACKAGES_ONLY" == "true" ]]; then
        echo "ℹ️  Note: Legacy flags detected. Consider using simplified build modes:" >&2
        echo "   --fast (minimal), --standard (balanced), --comprehensive (kitchen sink)" >&2
    fi
}

#=============================================================================
# MAIN CLI PROCESSING FUNCTION
#=============================================================================

# Function: process_cli
# Purpose: Main function to process all CLI arguments and setup
# Arguments: All command line arguments
process_cli() {
    # Parse command line arguments
    parse_cli_arguments "$@"
    
    # Process user-friendly interface options
    process_user_friendly_interface
    
    # Validate argument combinations
    validate_cli_arguments
    
    # Export variables for other modules
    export_cli_variables
}

#=============================================================================
# CLI DEBUGGING FUNCTIONS
#=============================================================================

# Function: show_cli_debug
# Purpose: Display current CLI variable values for debugging
show_cli_debug() {
    echo "🔧 CLI Debug Information:"
    echo "  BUILD_DOCKER: $BUILD_DOCKER"
    echo "  BUILD_MODE: $BUILD_MODE"
    echo "  DOTFILES_DIR: $DOTFILES_DIR"
    echo "  DOTFILES_NODOT: $DOTFILES_NODOT" 
    echo "  BASE_IMAGE: $BASE_IMAGE"
    echo "  TEAM_NAME: $TEAM_NAME"
    echo "  PROJECT_NAME: $PROJECT_NAME"
    echo "  INTERFACE: $INTERFACE"
    echo "  GITHUB_ACCOUNT: $GITHUB_ACCOUNT"
    echo "  INIT_MODE: $INIT_MODE"
    echo "  SHOW_HELP: $SHOW_HELP"
    echo "  SHOW_NEXT_STEPS: $SHOW_NEXT_STEPS"
    echo "  --- Legacy flags (deprecated) ---"
    echo "  MINIMAL_PACKAGES: $MINIMAL_PACKAGES"
    echo "  EXTRA_PACKAGES: $EXTRA_PACKAGES"
    echo "  MINIMAL_DOCKER: $MINIMAL_DOCKER"
    echo "  EXTRA_DOCKER: $EXTRA_DOCKER"
    echo "  MINIMAL_PACKAGES_ONLY: $MINIMAL_PACKAGES_ONLY"
}

# Helper functions for modules to use simplified build modes
is_fast_mode() { [[ "$BUILD_MODE" == "fast" ]]; }
is_standard_mode() { [[ "$BUILD_MODE" == "standard" ]]; }
is_comprehensive_mode() { [[ "$BUILD_MODE" == "comprehensive" ]]; }

# Helper functions for template selection
get_template() {
    local template_type="$1"
    case "$template_type" in
        Dockerfile)
            # Use personal Dockerfile when building from team base images
            if [[ "$BASE_IMAGE" == *"core-"* ]]; then
                echo "Dockerfile.personal"
            else
                # Use unified Dockerfile for standard rocker base images
                echo "Dockerfile.unified"
            fi
            ;;
        *)
            # For other templates, use original logic
            case "$BUILD_MODE" in
                fast) echo "${template_type}.minimal" ;;
                comprehensive) echo "${template_type}.pluspackages" ;;
                *) echo "$template_type" ;;
            esac
            ;;
    esac
}

# Legacy wrapper functions for backward compatibility
get_dockerfile_template() { get_template "Dockerfile"; }
get_description_template() { get_template "DESCRIPTION"; }
get_workflow_template() { 
    case "$BUILD_MODE" in
        fast) echo "workflows/r-package-minimal.yml" ;;
        comprehensive) echo "workflows/r-package-full.yml" ;;
        *) echo "workflows/r-package.yml" ;;
    esac
}

#=============================================================================
# MODULE VALIDATION AND LOADING
#=============================================================================

# Set cli module loaded flag
readonly ZZCOLLAB_CLI_LOADED=true

# Note: No logging here since core.sh may not be loaded yet