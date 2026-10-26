MEDICAL SUPPLY MANAGEMENT SYSTEM 
Makefile
#  Folder layout this file expects:
#
#    Makefile
#    run_tests.sh          <- the shell test script
#    src/      *.c         <- all your C files (main.c, auth.c ...)
#    include/  medsupply.h <- your header file
#    tests/    *.cpp       <- GoogleTest files
#
#  Quick start:   make help



# ---------- 1. TOOLS ----------
# gcc compiles the C code, g++ compiles the C++ test code
CC  = gcc
CXX = g++


# ---------- 2. COMPILER OPTIONS ----------
# -std=c11        : use the C11 version of C
# -Iinclude       : look for header files in the include/ folder
# -Wall -Wextra   : show helpful warnings
CFLAGS = -std=c11 -D_POSIX_C_SOURCE=200809L -Iinclude \
         -Wall -Wextra -Wpedantic -Wshadow -O2

# Same idea for the C++ test files (-g = keep debug info)
CXXFLAGS = -std=c++17 -Iinclude -Itests -Wall -Wextra -O0 -g


# ---------- 3. FILE LISTS ----------
# "wildcard" = automatically find every matching file
SOURCES      = $(wildcard src/*.c)
HEADERS      = $(wildcard include/*.h)
TEST_SOURCES = $(wildcard tests/*.cpp)

# Every C file EXCEPT main.c (tests bring their own main)
LIB_SOURCES  = $(filter-out src/main.c,$(SOURCES))


# ---------- 4. OUTPUT LOCATIONS ----------
# These three change automatically when you run "make coverage"
BUILD_DIR      = build/debug
APP_BINARY     = medsupply
COVERAGE_FLAGS =

# Names of the compiled (.o) files and the test program
LIB_OBJECTS   = $(patsubst src/%.c,$(BUILD_DIR)/%.o,$(LIB_SOURCES))
APP_MAIN_OBJ  = $(BUILD_DIR)/app_main.o
TEST_MAIN_OBJ = $(BUILD_DIR)/test_main.o
TEST_BINARY   = $(BUILD_DIR)/medsupply_tests

# How strict valgrind should be (memory leaks + invalid memory use)
VG_FLAGS = --leak-check=full --show-leak-kinds=all --track-origins=yes \
           --errors-for-leak-kinds=definite,indirect --error-exitcode=1


# "PHONY" = these are commands, not real files
.PHONY: all test shell-test valgrind valgrind-all coverage coverage-html \
        check check-all clean help


# =============================================================
#  BUILD THE PROGRAM          ->   make
# =============================================================
all: $(APP_BINARY)

# Make the build folder if it does not exist yet
$(BUILD_DIR):
	mkdir -p $@

# Compile each src/xxx.c into build/.../xxx.o
$(BUILD_DIR)/%.o: src/%.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(COVERAGE_FLAGS) -O0 -g -c $< -o $@

# main.c is compiled two ways:
#   1) normal             -> used by the real program
$(APP_MAIN_OBJ): src/main.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(COVERAGE_FLAGS) -O0 -g -c $< -o $@

#   2) main() renamed     -> used by tests (GoogleTest has its own main)
$(TEST_MAIN_OBJ): src/main.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(COVERAGE_FLAGS) -O0 -g -Dmain=medsupply_app_main -c $< -o $@

# Join all the .o files into the final program "medsupply"
$(APP_BINARY): $(LIB_OBJECTS) $(APP_MAIN_OBJ)
	$(CC) $(COVERAGE_FLAGS) -o $@ $^


# =============================================================
#  UNIT TESTS (GoogleTest)    ->   make test
# =============================================================
# Build the test program from tests/*.cpp + your C code
$(TEST_BINARY): $(TEST_SOURCES) $(HEADERS) $(LIB_OBJECTS) $(TEST_MAIN_OBJ)
	$(CXX) $(CXXFLAGS) $(COVERAGE_FLAGS) -o $@ \
	$(TEST_SOURCES) $(LIB_OBJECTS) $(TEST_MAIN_OBJ) \
	-lgtest_main -lgtest -pthread

# Run it
test: $(TEST_BINARY)
	./$(TEST_BINARY)


# =============================================================
#  SHELL TESTS (run_tests.sh) ->   make shell-test
# =============================================================
# Runs your script against the program, as if a user typed the input
shell-test: $(APP_BINARY)
	BIN=$(abspath $(APP_BINARY)) bash run_tests.sh


# =============================================================
#  MEMORY CHECK (Valgrind)
# =============================================================
# make valgrind      -> check the unit tests for memory leaks/errors
valgrind: $(TEST_BINARY)
	valgrind $(VG_FLAGS) ./$(TEST_BINARY)

# make valgrind-all  -> check the whole run_tests.sh suite (slower)
valgrind-all: $(APP_BINARY)
	@mkdir -p build
	@printf '#!/bin/sh\nexec valgrind -q --leak-check=full --error-exitcode=99 "%s" "$$@"\n' \
	    "$(abspath $(APP_BINARY))" > build/medsupply_vg
	@chmod +x build/medsupply_vg
	BIN=$(abspath build/medsupply_vg) bash run_tests.sh


# =============================================================
#  CODE COVERAGE (gcov)       ->   make coverage
# =============================================================
# Shows how much of your code the tests actually run.
# Steps: rebuild with coverage on -> run both test types -> show result.
# Lines marked ##### in the .gcov files were NEVER run.
coverage:
	rm -rf build/coverage
	mkdir -p build/coverage/report
	$(MAKE) BUILD_DIR=build/coverage COVERAGE_FLAGS="--coverage" \
	        APP_BINARY=build/coverage/medsupply test shell-test
	gcov -b -c -o build/coverage $(LIB_SOURCES) > build/coverage/report/summary.txt
	@mv -f *.gcov build/coverage/report/ 2>/dev/null || true
	@echo "================ COVERAGE SUMMARY ================"
	@grep -A1 "^File 'src/" build/coverage/report/summary.txt | grep -v '^--'
	@echo "Details: build/coverage/report/*.c.gcov"

# Same thing, but as a web page (needs: sudo apt install gcovr)
coverage-html: coverage
	gcovr -r . --object-directory build/coverage --exclude 'tests/.*' \
	      --html-details -o build/coverage/report/index.html
	@echo "Open build/coverage/report/index.html in your browser"


# =============================================================
#  STATIC ANALYSIS (cppcheck) ->   make check
# =============================================================
# Reads the code (without running it) and looks for bugs
check:
	cppcheck --enable=warning,performance --suppress=missingIncludeSystem \
	         --inconclusive --std=c11 --language=c --platform=unix64 \
	         --library=posix --inline-suppr --error-exitcode=1 \
	         -Iinclude src


# =============================================================
#  EXTRAS
# =============================================================
# Run everything in one go
check-all: all shell-test test valgrind check coverage

# Delete everything that was built
clean:
	rm -f medsupply
	rm -f *.gcov *.gcda *.gcno
	rm -rf build

# Show the list of commands
help:
	@echo "make                build the program (./medsupply)"
	@echo "make shell-test     run run_tests.sh"
	@echo "make test           run GoogleTest unit tests"
	@echo "make valgrind       memory check on unit tests"
	@echo "make valgrind-all   memory check on run_tests.sh"
	@echo "make coverage       how much code the tests cover"
	@echo "make coverage-html  same, as an HTML page"
	@echo "make check          cppcheck static analysis"
	@echo "make check-all      everything above"
	@echo "make clean          delete build output"