.PHONY: tests

deps/JSON-Schema-Test-Suite:
	mkdir deps
	cd deps && git clone https://github.com/json-schema-org/JSON-Schema-Test-Suite.git

tests: deps/JSON-Schema-Test-Suite
	mkdir -p test
	python3.9 generate_tests.py