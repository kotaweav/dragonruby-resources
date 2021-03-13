project(cpp_drgtk_integration)
cmake_minimum_required(VERSION 3.1)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CXX_STANDARD 17)

set(DRGTK_HEADERS include/myext.h)

add_library(myext
  src/myext.cpp)
include_directories(include)

set_target_properties(myext PROPERTIES PUBLIC_HEADER "${DRGTK_HEADERS}")

install(TARGETS myext
  LIBRARY DESTINATION lib
  PUBLIC_HEADER DESTINATION include)
