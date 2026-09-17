#!/bin/bash

ros2_create_ament_pkg() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a package name."
        echo "Usage: ros2_create_ament_pkg <package_name>"
        return 1
    fi

    local PKG_NAME=$1
    local TARGET_DIR="$(pwd)/$PKG_NAME"

    echo "🚀 Creating ament_cmake ROS 2 + OpenCV package at: $TARGET_DIR"

    mkdir -p "$TARGET_DIR/src"
    mkdir -p "$TARGET_DIR/include/$PKG_NAME"

    # Layout matches:
    # https://ros2-tutorial.readthedocs.io/en/latest/cpp/cpp_library.html
    #   include/<pkg>/<pkg>.hpp          — exported library API
    #   src/<pkg>.cpp                    — library impl
    #   src/<pkg>_node.hpp/.cpp          — local node (not exported)
    #   src/<pkg>_node_main.cpp          — binary entrypoint

    # 1. CMakeLists.txt
    cat << 'EOF' > "$TARGET_DIR/CMakeLists.txt"
cmake_minimum_required(VERSION 3.20)
project({package_name})

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -Wextra -Werror -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(OpenCV REQUIRED)

####################################
# CPP Shared Library Block [BEGIN] #
# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv #
# https://ros2-tutorial.readthedocs.io/en/latest/cpp/cpp_library.html
# Single shared library ${PROJECT_NAME} = everything this package exports.
add_library(${PROJECT_NAME} SHARED
    src/{package_name}.cpp
)

target_include_directories(${PROJECT_NAME}
    PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_features(${PROJECT_NAME} PUBLIC c_std_17 cxx_std_20)

# Non-ROS deps via target_link_libraries; ROS deps via ament_*
target_link_libraries(${PROJECT_NAME}
    ${OpenCV_LIBS}
)

ament_export_targets(export_${PROJECT_NAME} HAS_LIBRARY_TARGET)
ament_export_dependencies(
    rclcpp
    std_msgs
    sensor_msgs
    OpenCV
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
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #
# CPP Shared Library Block [END] #
##################################

############################
# CPP Binary Block [BEGIN] #
# vvvvvvvvvvvvvvvvvvvvvvvv #
# Local node that uses the exported library; not part of the library itself.
set(RCLCPP_LOCAL_BINARY_NAME {package_name}_node)

add_executable(${RCLCPP_LOCAL_BINARY_NAME}
    src/{package_name}_node_main.cpp
    src/{package_name}_node.cpp
)

ament_target_dependencies(${RCLCPP_LOCAL_BINARY_NAME}
    rclcpp
    std_msgs
    sensor_msgs
)

target_link_libraries(${RCLCPP_LOCAL_BINARY_NAME}
    ${PROJECT_NAME}
)

target_include_directories(${RCLCPP_LOCAL_BINARY_NAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_features(${RCLCPP_LOCAL_BINARY_NAME} PUBLIC c_std_17 cxx_std_20)

install(TARGETS ${RCLCPP_LOCAL_BINARY_NAME}
    DESTINATION lib/${PROJECT_NAME}
)

unset(RCLCPP_LOCAL_BINARY_NAME)
# ^^^^^^^^^^^^^^^^^^^^^^ #
# CPP Binary Block [END] #
##########################

ament_package()
EOF

    # 2. package.xml
    cat << EOF > "$TARGET_DIR/package.xml"
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>${PKG_NAME}</name>
  <version>0.0.0</version>
  <description>ament_cmake ROS 2 + OpenCV library package.</description>
  <maintainer email="ubuntu@todo.todo">ubuntu</maintainer>
  <license>MIT</license>

  <buildtool_depend>ament_cmake</buildtool_depend>

  <depend>rclcpp</depend>
  <depend>std_msgs</depend>
  <depend>sensor_msgs</depend>
  <depend>libopencv-dev</depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF

    # 3. Exported library (include/ + src/{pkg}.cpp)
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

    # 4. Local node (src only — not exported)
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

    # 5. Binary entrypoint
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

    # 6. Rename placeholders
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

    echo "✅ Successfully generated ament_cmake package at: $TARGET_DIR"
}

if [ "${BASH_SOURCE}" -ef "$0" ] && [ ! -z "$1" ]; then
    ros2_create_ament_pkg "$1"
fi
