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

    # Dizin yapısını oluştur
    mkdir -p "$TARGET_DIR/src"
    mkdir -p "$TARGET_DIR/include/$PKG_NAME"
    mkdir -p "$TARGET_DIR/cmake"

    # 1. Sıfırdan dinamik CMakeLists.txt dosyasını KÖK dizine yaz
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

file(GLOB_RECURSE PROJECT_SOURCES
    CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp"
)

# Ana executable dosyasını kütüphane kaynak havuzundan çıkar
list(REMOVE_ITEM PROJECT_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/${PROJECT_NAME}_main.cpp")

# 1. Kütüphane Hedefi (Library Target)
add_library(${PROJECT_NAME}_lib SHARED ${PROJECT_SOURCES})
target_compile_features(${PROJECT_NAME}_lib PUBLIC c_std_17 cxx_std_20)
target_include_directories(${PROJECT_NAME}_lib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(${PROJECT_NAME}_lib PUBLIC
    rclcpp::rclcpp
    std_msgs::std_msgs
    sensor_msgs::sensor_msgs
    ${OpenCV_LIBS}
)

# 2. Çalıştırılabilir Düğüm Hedefi (Executable Target)
add_executable(${PROJECT_NAME}_node src/${PROJECT_NAME}_main.cpp)
target_compile_features(${PROJECT_NAME}_node PUBLIC c_std_17 cxx_std_20)
target_link_libraries(${PROJECT_NAME}_node PRIVATE ${PROJECT_NAME}_lib)

# 3. Yükleme Ayarları (Installation)
install(TARGETS ${PROJECT_NAME}_lib ${PROJECT_NAME}_node
  EXPORT export_${PROJECT_NAME}
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION lib/${PROJECT_NAME}
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include/")
    install(DIRECTORY include/ DESTINATION include)
endif()

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

    # 2. .in Yapılandırma şablonlarını doğrudan 'cmake/' altına yaz
    cat << 'EOF' > "$TARGET_DIR/cmake/{package_name}Config.cmake.in"
@PACKAGE_INIT@
set_and_check(@PROJECT_NAME@_INCLUDE_DIRS "@PACKAGE_CONF_INCLUDE_DIRS@")
include("${CMAKE_CURRENT_LIST_DIR}/export_@PROJECT_NAME@.cmake")
set(@PROJECT_NAME@_LIBRARIES @PROJECT_NAME@_lib)
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

    # 3. Sıfırdan package.xml oluştur
    cat << EOF > "$TARGET_DIR/package.xml"
<?xml version="1.0"?>
<?xml-model href="http://ros.org" schematypens="http://w3.org"?>
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

    # 4. Eksik olan .hpp, .cpp ve _main.cpp dosyalarını sıfırdan oluştur

    # include/{package_name}/{package_name}_node.hpp
    cat << 'EOF' > "$TARGET_DIR/include/$PKG_NAME/{package_name}_node.hpp"
#ifndef {package_name_upper}_NODE_HPP_
#define {package_name_upper}_NODE_HPP_

#include <rclcpp/rclcpp.hpp>
#include <sensor_msgs/msg/image.hpp>
#include <opencv2/opencv.hpp>

class FrameSourceNode : public rclcpp::Node {
public:
    FrameSourceNode();
    virtual ~FrameSourceNode() = default;
private:
    void timer_callback();
    rclcpp::TimerBase::SharedPtr timer_;
};

#endif // {package_name_upper}_NODE_HPP_
EOF

    # src/{package_name}_node.cpp
    cat << 'EOF' > "$TARGET_DIR/src/{package_name}_node.cpp"
#include "{package_name}/{package_name}_node.hpp"

FrameSourceNode::FrameSourceNode() : Node("{package_name}_node") {
    RCLCPP_INFO(this->get_logger(), "FrameSourceNode kütüphanesi başarıyla yüklendi.");
    timer_ = this->create_wall_timer(
        std::chrono::milliseconds(500),
        std::bind(&FrameSourceNode::timer_callback, this)
    );
}

void FrameSourceNode::timer_callback() {
    // Örnek OpenCV Matris operasyonu
    cv::Mat frame = cv::Mat::zeros(480, 640, CV_8UC3);
    // Düğüm içi lojik buraya gelecek
}
EOF

    # src/{package_name}_main.cpp
    cat << 'EOF' > "$TARGET_DIR/src/{package_name}_main.cpp"
#include <rclcpp/rclcpp.hpp>
#include "{package_name}/{package_name}_node.hpp"

int main(int argc, char **argv) {
    rclcpp::init(argc, argv);
    auto node = std::make_shared<FrameSourceNode>();
    rclcpp::spin(node);
    rclcpp::shutdown();
    return 0;
}
EOF

    # 5. Dosya isimlerini ve dosya içlerindeki şablon etiketlerini değiştir
    mv "$TARGET_DIR/cmake/{package_name}Config.cmake.in" "$TARGET_DIR/cmake/${PKG_NAME}Config.cmake.in" 2>/dev/null
    mv "$TARGET_DIR/cmake/{package_name}ConfigVersion.cmake.in" "$TARGET_DIR/cmake/${PKG_NAME}ConfigVersion.cmake.in" 2>/dev/null
    mv "$TARGET_DIR/include/$PKG_NAME/{package_name}_node.hpp" "$TARGET_DIR/include/$PKG_NAME/${PKG_NAME}_node.hpp" 2>/dev/null
    mv "$TARGET_DIR/src/{package_name}_node.cpp" "$TARGET_DIR/src/${PKG_NAME}_node.cpp" 2>/dev/null
    mv "$TARGET_DIR/src/{package_name}_main.cpp" "$TARGET_DIR/src/${PKG_NAME}_main.cpp" 2>/dev/null

    # İçerik kelime güncellemeleri
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

