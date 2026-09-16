#!/bin/bash
set -e

# Check if project name parameter is provided
if [ -z "$1" ]; then
    echo "Error: Project name parameter is required!"
    echo "Usage: $0 <project_name>"
    exit 1
fi

PROJECT_ARG="$1"

# Create standard project directory structure and cmake config directory
mkdir -p src inc app cmake

# ----------------------------------------------------------------------
# 1. GENERIC CMakeLists.txt (Dynamically looks for the parameter-named config)
# ----------------------------------------------------------------------
cat << 'EOF' > CMakeLists.txt
cmake_minimum_required(VERSION 3.16)

# Append custom cmake modules path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# 1. Load Project-Specific Configuration dynamically from cmake directory
# Note: The placeholder below @PROJECT_NAME_PLACEHOLDER@ will be replaced by the script
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/@PROJECT_NAME_PLACEHOLDER@Config.cmake")
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/@PROJECT_NAME_PLACEHOLDER@Config.cmake")
else()
    message(FATAL_ERROR "@PROJECT_NAME_PLACEHOLDER@Config.cmake not found in cmake/ folder!")
endif()

# Validate that essential variables are loaded
if(NOT MY_PROJECT_NAME)
    message(FATAL_ERROR "MY_PROJECT_NAME is not defined in config file!")
endif()

# 2. Project Declaration (Assembling version components dynamically)
project(${MY_PROJECT_NAME}
  VERSION "${MY_PROJECT_VERSION_MAJOR}.${MY_PROJECT_VERSION_MINOR}.${MY_PROJECT_VERSION_PATCH}"
  DESCRIPTION ${MY_PROJECT_DESCRIPTION}
  LANGUAGES ${MY_PROJECT_LANGUAGES}
)

# 3. Global Compiler Settings
if("${MY_PROJECT_LANGUAGES}" STREQUAL "C")
  set(CMAKE_C_STANDARD 99)
  set(CMAKE_C_STANDARD_REQUIRED ON)
  set(CMAKE_C_EXTENSIONS OFF)
else()
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
  set(CMAKE_CXX_EXTENSIONS OFF)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_compile_options(-Wall -Wextra -Wpedantic -Werror)

# Default to Release build type if none is specified
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS Debug Release RelWithDebInfo MinSizeRel)
endif()

# 4. Determine Library Type (Shared / Static)
set(MY_LIB_TYPE STATIC)
if(${MY_PROJECT_NAME}_BUILD_SHARED)
  set(MY_LIB_TYPE SHARED)
endif()

# 5. Automatically Discover Source Files
file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cc"
)

# 6. Target Creation
add_library(${PROJECT_NAME} ${MY_LIB_TYPE} ${PROJECT_SOURCES})
add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

# 7. Include Directories
target_include_directories(${PROJECT_NAME}
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/inc>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# 8. Trigger Project-Specific Custom Behaviors
if(COMMAND target_custom_behavior)
    target_custom_behavior(${PROJECT_NAME})
endif()

target_compile_options(${PROJECT_NAME} PRIVATE
  $<$<CONFIG:Release>:-O3>
  $<$<CONFIG:RelWithDebInfo>:-O2>
)

# 9. Subdirectories (e.g., Examples or Apps)
if(${MY_PROJECT_NAME}_BUILD_EXAMPLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/app/CMakeLists.txt")
  add_subdirectory(app)
endif()

# 10. Installation Rules
include(GNUInstallDirs)

install(TARGETS ${PROJECT_NAME}
  EXPORT ${PROJECT_NAME}Targets
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/inc/")
  install(DIRECTORY inc/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp")
elseif(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/")
  install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp")
endif()

install(EXPORT ${PROJECT_NAME}Targets
  FILE ${PROJECT_NAME}Targets.cmake
  NAMESPACE ${PROJECT_NAME}::
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}
)

# 11. Status Summary
message(STATUS "--------------------------------------------")
message(STATUS "Project: ${PROJECT_NAME} v${PROJECT_VERSION}")
message(STATUS "  Build type           : ${CMAKE_BUILD_TYPE}")
message(STATUS "  Library Type         : ${MY_LIB_TYPE}")
message(STATUS "  Build Example        : ${${MY_PROJECT_NAME}_BUILD_EXAMPLE}")
if(COMMAND print_custom_status)
    print_custom_status()
endif()
message(STATUS "--------------------------------------------")
EOF

# Inject the project name into CMakeLists.txt placeholder
sed -i "s/@PROJECT_NAME_PLACEHOLDER@/${PROJECT_ARG}/g" CMakeLists.txt

# ----------------------------------------------------------------------
# 2. EDITABLE {project_name}Config.cmake TEMPLATE
# ----------------------------------------------------------------------
cat << EOF > "cmake/${PROJECT_ARG}Config.cmake"
# =====================================================================
# PROJECT CORE CONFIGURATION (Modify this file for your specific project)
# =====================================================================
set(MY_PROJECT_NAME "${PROJECT_ARG}")
set(MY_PROJECT_DESCRIPTION "Template project description")
set(MY_PROJECT_LANGUAGES C) # Options: C or CXX (C++)

# --- Versioning ---
set(MY_PROJECT_VERSION_MAJOR 0)
set(MY_PROJECT_VERSION_MINOR 1)
set(MY_PROJECT_VERSION_PATCH 0)

# --- Standard Compilation Toggles ---
option(\${MY_PROJECT_NAME}_BUILD_SHARED "Build as a shared library" OFF)
option(\${MY_PROJECT_NAME}_BUILD_EXAMPLE "Build the app/ example" ON)

# =====================================================================
# GENERIC EXAMPLE: Custom Variables & Cache Options
# =====================================================================
# set(MY_CUSTOM_VAR 100 CACHE STRING "An example custom configuration option")

# --- Validation Rules ---
# if(NOT MY_CUSTOM_VAR MATCHES "^[0-9]+\$" OR MY_CUSTOM_VAR EQUAL 0)
#   message(FATAL_ERROR "MY_CUSTOM_VAR must be a positive integer!")
# endif()

# =====================================================================
# TARGET CUSTOMIZATION & EXTERNAL LINKING
# =====================================================================
function(target_custom_behavior TARGET_NAME)
    # 1. Inject custom preprocessor definitions (Macros):
    # target_compile_definitions(\${TARGET_NAME} PUBLIC MY_CUSTOM_VAR=\${MY_CUSTOM_VAR})

    # 2. Link third-party or dependency libraries here:
    # target_link_libraries(\${TARGET_NAME} PRIVATE pthread)
endfunction()

# --- Custom Fields to Append to the Status Summary ---
function(print_custom_status)
    # message(STATUS "  MY_CUSTOM_VAR        : \${MY_CUSTOM_VAR}")
endfunction()
EOF

# ----------------------------------------------------------------------
# 3. GENERATE .clangd CONFIGURATION
# ----------------------------------------------------------------------
cat << 'EOF' > .clangd
CompileFlags:
  CompilationDatabase: build
  Add:
    - "-std=c99"
  QueryDriver: /usr/bin/c++,/usr/bin/cpp,/usr/bin/gcc,/usr/bin/g++,/usr/bin/clang,/usr/bin/clang++

Diagnostics:
  UnusedIncludes: None
  Suppress:
    - "pp_including_file_in_preamble"
EOF

# ----------------------------------------------------------------------
# 4. GENERATE .clang-format CONFIGURATION
# ----------------------------------------------------------------------
cat << 'EOF' > .clang-format
BasedOnStyle: LLVM
IndentWidth: 4
Language: Cpp
AccessModifierOffset: -4
DerivePointerAlignment: false
PointerAlignment: Left
SortIncludes: false
ColumnLimit: 120
AlignConsecutiveDeclarations: true
AlignConsecutiveAssignments: true
BreakBeforeBraces: Custom
BraceWrapping:
  AfterClass: false
  AfterFunction: false
  AfterControlStatement: false
  BeforeElse: true
  AfterEnum: false
  AfterStruct: false
  AfterNamespace: false
EOF

echo "✓ Template files, folder structure, and toolconfigs generated successfully!"
echo "✓ Configurations created: .clangd, .clang-format, and cmake/${PROJECT_ARG}Config.cmake"
