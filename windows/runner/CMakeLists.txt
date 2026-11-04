cmake_minimum_required(VERSION 3.15)
project(runner LANGUAGES CXX)

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

add_library(WsaPacManAppTrayHook SHARED "app_tray_hook.cpp")
apply_standard_settings(WsaPacManAppTrayHook)
target_compile_definitions(WsaPacManAppTrayHook PRIVATE "NOMINMAX")
target_link_libraries(WsaPacManAppTrayHook PRIVATE shell32 user32)
install(TARGETS WsaPacManAppTrayHook RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")

apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app shell32 advapi32 user32)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)
