Makefile
# ============================================================================
#  Medical Supply Management System
#  Build + GoogleTest + shell tests + Valgrind + gcov coverage + cppcheck
#
#  Layout:  src/*.c   include/medsupply.h   tests/*.cpp   run_tests.sh
#  Run `make help` for the list of targets.
# ============================================================================
 
CC  = gcc
CXX = g++
 
CFLAGS = -std=c11 \
         -D_POSIX_C_SOURCE=200809L \
         -Iinclude \
         -Wall -Wextra -Wpedantic \
         -Wshadow \
         -O2
 
CXXFLAGS = -std=c++17 \
           -Iinclude \
           -Itests \
           -Wall -Wextra \
           -O0 -g
 
SOURCES      = $(wildcard src/*.c)
HEADERS      = $(wildcard include/*.h)
LIB_SOURCES  = $(filter-out src/main.c,$(SOURCES))
TEST_SOURCES = $(wildcard tests/*.cpp)
 
# These are overridden by `make coverage`
BUILD_DIR      = build/debug
APP_BINARY     = medsupply
COVERAGE_FLAGS =
 
LIB_OBJECTS   = $(patsubst src/%.c,$(BUILD_DIR)/%.o,$(LIB_SOURCES))
APP_MAIN_OBJ  = $(BUILD_DIR)/app_main.o
TEST_MAIN_OBJ = $(BUILD_DIR)/test_main.o
TEST_BINARY   = $(BUILD_DIR)/medsupply_tests
 
VG_FLAGS = --leak-check=full --show-leak-kinds=all --track-origins=yes \
           --errors-for-leak-kinds=definite,indirect --error-exitcode=1
 
.PHONY: all test shell-test valgrind valgrind-all coverage coverage-html \
        check check-all clean help
 
all: $(APP_BINARY)
 
# ------------------------------------------------------------------ objects
$(BUILD_DIR):
	mkdir -p $@
 
$(BUILD_DIR)/%.o: src/%.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(COVERAGE_FLAGS) -O0 -g -c $< -o $@
 
# main.c twice: normal main() for the app, renamed main() for the test binary
# (GoogleTest supplies its own main)
$(APP_MAIN_OBJ): src/main.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(COVERAGE_FLAGS) -O0 -g -c $< -o $@
 
$(TEST_MAIN_OBJ): src/main.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(COVERAGE_FLAGS) -O0 -g -Dmain=medsupply_app_main -c $< -o $@
 
# ------------------------------------------------------------------ program
$(APP_BINARY): $(LIB_OBJECTS) $(APP_MAIN_OBJ)
	$(CC) $(COVERAGE_FLAGS) -o $@ $^
 
# --------------------------------------------------------- GoogleTest (C++)
$(TEST_BINARY): $(TEST_SOURCES) $(HEADERS) $(LIB_OBJECTS) $(TEST_MAIN_OBJ)
	$(CXX) $(CXXFLAGS) $(COVERAGE_FLAGS) -o $@ \
	$(TEST_SOURCES) $(LIB_OBJECTS) $(TEST_MAIN_OBJ) \
	-lgtest_main -lgtest -pthread
 
test: $(TEST_BINARY)
	./$(TEST_BINARY)
 
# ------------------------------------------- shell tests (run_tests.sh)
shell-test: $(APP_BINARY)
	BIN=$(abspath $(APP_BINARY)) bash run_tests.sh
 
# ----------------------------------------------------------------- Valgrind
# GoogleTest suite under valgrind
valgrind: $(TEST_BINARY)
	valgrind $(VG_FLAGS) ./$(TEST_BINARY)
 
# whole run_tests.sh suite, every program run wrapped in valgrind
valgrind-all: $(APP_BINARY)
	@mkdir -p build
	@printf '#!/bin/sh\nexec valgrind -q --leak-check=full --error-exitcode=99 "%s" "$$@"\n' \
	    "$(abspath $(APP_BINARY))" > build/medsupply_vg
	@chmod +x build/medsupply_vg
	BIN=$(abspath build/medsupply_vg) bash run_tests.sh
 
# ----------------------------------------------------------------- Coverage
# Builds everything with --coverage, runs GoogleTest AND run_tests.sh,
# then prints a gcov summary. Annotated files: build/coverage/report/*.gcov
coverage:
	rm -rf build/coverage
	mkdir -p build/coverage/report
	$(MAKE) BUILD_DIR=build/coverage COVERAGE_FLAGS="--coverage" \
	        APP_BINARY=build/coverage/medsupply test shell-test
	gcov -b -c -o build/coverage $(LIB_SOURCES) > build/coverage/report/summary.txt
	@mv -f *.gcov build/coverage/report/ 2>/dev/null || true
	@echo "================ COVERAGE SUMMARY ================"
	@grep -A1 "^File 'src/" build/coverage/report/summary.txt | grep -v '^--'
	@echo "Annotated sources: build/coverage/report/*.c.gcov  (##### = never executed)"
 
# HTML report (needs gcovr:  sudo apt install gcovr)
coverage-html: coverage
	gcovr -r . --object-directory build/coverage --exclude 'tests/.*' \
	      --html-details -o build/coverage/report/index.html
	@echo "Open build/coverage/report/index.html in a browser"
 
# ----------------------------------------------------------- Static analysis
check:
	cppcheck \
	--enable=warning,performance \
	--suppress=missingIncludeSystem \
	--inconclusive \
	--std=c11 \
	--language=c \
	--platform=unix64 \
	--library=posix \
	--inline-suppr \
	--error-exitcode=1 \
	-Iinclude \
	src
 
# --------------------------------------------------------------- Everything
check-all: all shell-test test valgrind check coverage
 
clean:
	rm -f medsupply
	rm -f *.gcov *.gcda *.gcno
	rm -rf build
 
help:
	@echo "make                build ./medsupply"
	@echo "make shell-test     run run_tests.sh against the binary"
	@echo "make test           build + run GoogleTest unit tests"
	@echo "make valgrind       GoogleTest suite under valgrind"
	@echo "make valgrind-all   whole run_tests.sh suite under valgrind"
	@echo "make coverage       gcov coverage (GoogleTest + run_tests.sh)"
	@echo "make coverage-html  HTML coverage report (needs gcovr)"
	@echo "make check          cppcheck static analysis"
	@echo "make check-all      everything above"
	@echo "make clean          remove build output"
 
