cmake_minimum_required(VERSION 3.18 FATAL_ERROR)
project(chess_selfplay CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Find LibTorch ─────────────────────────────────────────────────────────────
# CMAKE_PREFIX_PATH is set via -DCMAKE_PREFIX_PATH=... by build_engine() in the pipeline.
find_package(Torch REQUIRED)

# ── Download chess.hpp single-header if not already present ──────────────────
set(CHESS_HPP "${CMAKE_CURRENT_SOURCE_DIR}/chess.hpp")
if(NOT EXISTS "${CHESS_HPP}")
    message(STATUS "[chess-library] chess.hpp not found — downloading from GitHub...")
    file(DOWNLOAD
        "https://raw.githubusercontent.com/Disservin/chess-library/master/include/chess.hpp"
        "${CHESS_HPP}"
        SHOW_PROGRESS
        STATUS DOWNLOAD_STATUS
    )
    list(GET DOWNLOAD_STATUS 0 DOWNLOAD_ERROR)
    if(DOWNLOAD_ERROR)
        message(FATAL_ERROR
            "[chess-library] Download failed (status: ${DOWNLOAD_STATUS}). "
            "Please place chess.hpp in AI/engine/ manually and re-run cmake."
        )
    endif()
    message(STATUS "[chess-library] chess.hpp downloaded OK.")
else()
    message(STATUS "[chess-library] chess.hpp found — skipping download.")
endif()

# ── Build structure ───────────────────────────────────────────────────────────
# ChessEnv.cpp is a pure-header-style implementation (has #pragma once) that
# both mcts.cpp and selfplay.cpp textually #include.
#
# mcts.cpp and selfplay.cpp are compiled as SEPARATE translation units so their
# anonymous-namespace symbols (kStateSize, make_action_index, …) don't collide.
# ChessEnv.cpp is compiled into its own OBJECT library so its symbols (ChessEnv
# class, enums, helpers) are defined exactly once and linked into both TUs.
#
# Link order: ChessEnv_obj → mcts_obj → selfplay (entry point)

add_library(ChessEnv_obj OBJECT ChessEnv.cpp)
target_include_directories(ChessEnv_obj PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(ChessEnv_obj PRIVATE _GLIBCXX_USE_CXX11_ABI=1)
target_compile_options(ChessEnv_obj PRIVATE -O2)
# ChessEnv_obj needs torch headers for any torch types that might appear
target_include_directories(ChessEnv_obj PRIVATE ${TORCH_INCLUDE_DIRS})

add_library(mcts_obj OBJECT mcts.cpp)
target_include_directories(mcts_obj PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(mcts_obj PRIVATE _GLIBCXX_USE_CXX11_ABI=1)
target_compile_options(mcts_obj PRIVATE -O2)
target_include_directories(mcts_obj PRIVATE ${TORCH_INCLUDE_DIRS})

add_executable(selfplay selfplay.cpp)
target_include_directories(selfplay PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(selfplay PRIVATE _GLIBCXX_USE_CXX11_ABI=1)
target_compile_options(selfplay PRIVATE -O2)

target_link_libraries(selfplay PRIVATE
    $<TARGET_OBJECTS:ChessEnv_obj>
    $<TARGET_OBJECTS:mcts_obj>
    ${TORCH_LIBRARIES}
)

message(STATUS "[cmake] selfplay target configured.")
message(STATUS "[cmake]   TORCH_LIBRARIES = ${TORCH_LIBRARIES}")
