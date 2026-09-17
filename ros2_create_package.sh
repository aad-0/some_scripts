#!/bin/bash

ros2_create_custom_pkg() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a package name."
        echo "Usage: ros2_create_custom_pkg <package_name>"
        return 1
    fi

    local PKG_NAME=$1
    local TARGET_DIR="$(pwd)/$PKG_NAME"

    echo "🚀 Creating fully integrated ROS 2 + OpenCV package at: $TARGET_DIR"

    # Layout (same split as ament script):
    #   include/<pkg>/<pkg>.hpp          — exported library API
    #   src/<pkg>.cpp                    — library impl
    #   src/<pkg>_node.hpp/.cpp          — local node (not exported)
    #   src/<pkg>_node_main.cpp          — binary entrypoint

    mkdir -p "$TARGET_DIR/src"
    mkdir -p "$TARGET_DIR/include/$PKG_NAME"
    mkdir -p "$TARGET_DIR/cmake"

    # 1. CMakeLists.txt
    cat << 'EOF' > "$TARGET_DIR/CMakeLists.txt"
cmake_minimum_required(VERSION 3.20)

set(PROJECT_NAME {package_name})
project(${PROJECT_NAME})

set(${PROJECT_NAME}_MAJOR_VERSION 0)
set(${PROJECT_NAME}_MINOR_VERSION 0)
set(${PROJECT_NAME}_PATCH_VERSION 0)
set(${PROJECT_NAME}_VERSION
  "${${PROJECT_NAME}_MAJOR_VERSION}.${${PROJECT_NAME}_MINOR_VERSION}.${${PROJECT_NAME}_PATCH_VERSION}")

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -Wextra -Werror -Wpedantic)
endif()

find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(OpenCV REQUIRED)

####################################
# CPP Shared Library Block [BEGIN] #
####################################
# Single shared library ${PROJECT_NAME} = everything this package exports.
add_library(${PROJECT_NAME} SHARED
    src/${PROJECT_NAME}.cpp
)

target_compile_features(${PROJECT_NAME} PUBLIC c_std_17 cxx_std_20)
target_include_directories(${PROJECT_NAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(${PROJECT_NAME} PUBLIC
    ${OpenCV_LIBS}
)

install(
    DIRECTORY include/
    DESTINATION include
)

install(
    TARGETS ${PROJECT_NAME}
    EXPORT export_${PROJECT_NAME}
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include
)
##################################
# CPP Shared Library Block [END] #
##################################

############################
# CPP Binary Block [BEGIN] #
############################
# Local node that uses the exported library; not part of the library itself.
set(RCLCPP_LOCAL_BINARY_NAME ${PROJECT_NAME}_node)

add_executable(${RCLCPP_LOCAL_BINARY_NAME}
    src/${PROJECT_NAME}_node_main.cpp
    src/${PROJECT_NAME}_node.cpp
)

target_compile_features(${RCLCPP_LOCAL_BINARY_NAME} PUBLIC c_std_17 cxx_std_20)
target_include_directories(${RCLCPP_LOCAL_BINARY_NAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(${RCLCPP_LOCAL_BINARY_NAME} PRIVATE
    ${PROJECT_NAME}
    rclcpp::rclcpp
    std_msgs::std_msgs
    sensor_msgs::sensor_msgs
)

install(TARGETS ${RCLCPP_LOCAL_BINARY_NAME}
    DESTINATION lib/${PROJECT_NAME}
)

unset(RCLCPP_LOCAL_BINARY_NAME)
##########################
# CPP Binary Block [END] #
##########################

install(FILES package.xml DESTINATION share/${PROJECT_NAME})

install(CODE "
  file(WRITE \"\${CMAKE_INSTALL_PREFIX}/share/ament_index/resource_index/packages/${PROJECT_NAME}\" \"\")
")

export(EXPORT export_${PROJECT_NAME}
  FILE "${PROJECT_BINARY_DIR}/export_${PROJECT_NAME}.cmake")

configure_file(cmake/${PROJECT_NAME}Config.cmake.in
  "${PROJECT_BINARY_DIR}/${CMAKE_FILES_DIRECTORY}/${PROJECT_NAME}Config.cmake" @ONLY)

configure_file(cmake/${PROJECT_NAME}ConfigVersion.cmake.in
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake" @ONLY)

install(FILES
  "${PROJECT_BINARY_DIR}/${CMAKE_FILES_DIRECTORY}/${PROJECT_NAME}Config.cmake"
  "${PROJECT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
  DESTINATION "share/${PROJECT_NAME}/cmake" COMPONENT dev)

install(EXPORT export_${PROJECT_NAME}
  DESTINATION "share/${PROJECT_NAME}/cmake"
  FILE export_${PROJECT_NAME}.cmake
  COMPONENT dev)
EOF

    # 2. cmake Config templates
    cat << 'EOF' > "$TARGET_DIR/cmake/{package_name}Config.cmake.in"
@PACKAGE_INIT@
set_and_check(@PROJECT_NAME@_INCLUDE_DIRS "@PACKAGE_CONF_INCLUDE_DIRS@")
include("${CMAKE_CURRENT_LIST_DIR}/export_@PROJECT_NAME@.cmake")
set(@PROJECT_NAME@_LIBRARIES @PROJECT_NAME@)
check_required_components("@PROJECT_NAME@")
EOF

    cat << 'EOF' > "$TARGET_DIR/cmake/{package_name}ConfigVersion.cmake.in"
set(PACKAGE_VERSION "@PROJECT_VERSION@")
if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if(PACKAGE_VERSION VERSION_EQUAL PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF

    # 3. package.xml
    cat << EOF > "$TARGET_DIR/package.xml"
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>${PKG_NAME}</name>
  <version>0.0.0</version>
  <description>Custom OpenCV and ROS 2 enabled CMake library package.</description>
  <maintainer email="ubuntu@todo.todo">ubuntu</maintainer>
  <license>MIT</license>

  <!--<buildtool_depend>cmake</buildtool_depend> -->

  <depend>rclcpp</depend>
  <depend>std_msgs</depend>
  <depend>sensor_msgs</depend>

  <export>
    <build_type>cmake</build_type>
  </export>
</package>
EOF

    # 4. Exported library
    cat << 'EOF' > "$TARGET_DIR/include/$PKG_NAME/{package_name}.hpp"
#ifndef {package_name_upper}_HPP_
#define {package_name_upper}_HPP_

#include <opencv2/opencv.hpp>

class FrameSource {
public:
    FrameSource() = default;
    cv::Mat create_frame(int rows = 480, int cols = 640) const;
};

#endif // {package_name_upper}_HPP_
EOF

    cat << 'EOF' > "$TARGET_DIR/src/{package_name}.cpp"
#include "{package_name}/{package_name}.hpp"

cv::Mat FrameSource::create_frame(int rows, int cols) const {
    return cv::Mat::zeros(rows, cols, CV_8UC3);
}
EOF

    # 5. Local node (src only — not exported)
    cat << 'EOF' > "$TARGET_DIR/src/{package_name}_node.hpp"
#pragma once

#include <rclcpp/rclcpp.hpp>
#include <{package_name}/{package_name}.hpp>

class FrameSourceNode : public rclcpp::Node {
public:
    FrameSourceNode();

private:
    void timer_callback();

    FrameSource frame_source_;
    rclcpp::TimerBase::SharedPtr timer_;
};
EOF

    cat << 'EOF' > "$TARGET_DIR/src/{package_name}_node.cpp"
#include "{package_name}_node.hpp"

FrameSourceNode::FrameSourceNode() : Node("{package_name}_node") {
    RCLCPP_INFO(this->get_logger(), "FrameSourceNode started.");
    timer_ = this->create_wall_timer(
        std::chrono::milliseconds(500),
        std::bind(&FrameSourceNode::timer_callback, this)
    );
}

void FrameSourceNode::timer_callback() {
    cv::Mat frame = frame_source_.create_frame();
    RCLCPP_DEBUG(this->get_logger(), "frame %dx%d", frame.cols, frame.rows);
}
EOF

    # 6. Binary entrypoint
    cat << 'EOF' > "$TARGET_DIR/src/{package_name}_node_main.cpp"
#include <rclcpp/rclcpp.hpp>
#include "{package_name}_node.hpp"

int main(int argc, char **argv) {
    rclcpp::init(argc, argv);
    auto node = std::make_shared<FrameSourceNode>();
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}
EOF

    # 7. Rename placeholders
    mv "$TARGET_DIR/cmake/{package_name}Config.cmake.in" "$TARGET_DIR/cmake/${PKG_NAME}Config.cmake.in" 2>/dev/null
    mv "$TARGET_DIR/cmake/{package_name}ConfigVersion.cmake.in" "$TARGET_DIR/cmake/${PKG_NAME}ConfigVersion.cmake.in" 2>/dev/null
    mv "$TARGET_DIR/include/$PKG_NAME/{package_name}.hpp" "$TARGET_DIR/include/$PKG_NAME/${PKG_NAME}.hpp" 2>/dev/null
    mv "$TARGET_DIR/src/{package_name}.cpp" "$TARGET_DIR/src/${PKG_NAME}.cpp" 2>/dev/null
    mv "$TARGET_DIR/src/{package_name}_node.hpp" "$TARGET_DIR/src/${PKG_NAME}_node.hpp" 2>/dev/null
    mv "$TARGET_DIR/src/{package_name}_node.cpp" "$TARGET_DIR/src/${PKG_NAME}_node.cpp" 2>/dev/null
    mv "$TARGET_DIR/src/{package_name}_node_main.cpp" "$TARGET_DIR/src/${PKG_NAME}_node_main.cpp" 2>/dev/null

    local UPPER_PKG_NAME=$(echo "$PKG_NAME" | tr '[:lower:]' '[:upper:]')

    if [[ "$OSTYPE" == "darwin"* ]]; then
        find "$TARGET_DIR" -type f -exec sed -i '' "s/{package_name}/$PKG_NAME/g" {} +
        find "$TARGET_DIR" -type f -exec sed -i '' "s/{package_name_upper}/$UPPER_PKG_NAME/g" {} +
    else
        find "$TARGET_DIR" -type f -exec sed -i "s/{package_name}/$PKG_NAME/g" {} +
        find "$TARGET_DIR" -type f -exec sed -i "s/{package_name_upper}/$UPPER_PKG_NAME/g" {} +
    fi

    echo "✅ Successfully generated customized ROS 2 package at: $TARGET_DIR"
}

if [ "${BASH_SOURCE}" -ef "$0" ] && [ ! -z "$1" ]; then
    ros2_create_custom_pkg "$1"
fi
