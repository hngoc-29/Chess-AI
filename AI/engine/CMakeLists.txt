cmake_minimum_required(VERSION 3.12 FATAL_ERROR)
project(chess_mcts_engine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(_torch_search_prefixes "")
if(DEFINED CMAKE_PREFIX_PATH AND NOT "${CMAKE_PREFIX_PATH}" STREQUAL "")
    set(_torch_search_prefixes ${CMAKE_PREFIX_PATH})
endif()
list(APPEND _torch_search_prefixes "${CMAKE_CURRENT_SOURCE_DIR}/libtorch")
list(APPEND _torch_search_prefixes "${CMAKE_CURRENT_SOURCE_DIR}/../libtorch")

foreach(_prefix IN LISTS _torch_search_prefixes)
    if(EXISTS "${_prefix}")
        list(APPEND CMAKE_PREFIX_PATH "${_prefix}")
    endif()
endforeach()

find_package(Torch REQUIRED)
find_package(Threads REQUIRED)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${TORCH_CXX_FLAGS}")

add_executable(chess_mcts
    main.cpp
    mcts.cpp
    ChessEnv.cpp
)

add_executable(selfplay
    selfplay.cpp
    mcts.cpp
    ChessEnv.cpp
)

target_link_libraries(chess_mcts PRIVATE "${TORCH_LIBRARIES}" Threads::Threads ${CMAKE_DL_LIBS})
target_link_libraries(selfplay PRIVATE "${TORCH_LIBRARIES}" Threads::Threads ${CMAKE_DL_LIBS})
