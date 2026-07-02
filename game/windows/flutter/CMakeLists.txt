cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")

set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll" PARENT_SCOPE)

set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)

set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)

set(AOT_LIBRARY "${PROJECT_DIR}/build/windows/app.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
)
list(TRANSFORM FLUTTER_LIBRARY_HEADERS PREPEND "${EPHEMERAL_DIR}/")

add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY}.lib")
add_dependencies(flutter flutter_assemble)

list(APPEND FLUTTER_WRAPPER_APP_SOURCES
  "flutter_window.cc"
  "flutter_event_channel.cc"
  "flutter_method_channel.cc"
  "flutter_basic_message_channel.cc"
  "standard_codec.cc"
)
list(TRANSFORM FLUTTER_WRAPPER_APP_SOURCES PREPEND "${WRAPPER_ROOT}/")

add_library(flutter_wrapper_app STATIC ${FLUTTER_WRAPPER_APP_SOURCES})
target_include_directories(flutter_wrapper_app PUBLIC "${WRAPPER_ROOT}")
target_link_libraries(flutter_wrapper_app PUBLIC flutter)

add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_LIBRARY_HEADERS}
  ${FLUTTER_ICU_DATA_FILE}
  ${AOT_LIBRARY}
)
