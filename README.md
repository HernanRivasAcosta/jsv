# jsv

**J**SON **S**chema **V**alidator

jsv is an erlang implementation of [JSON Schemas](https://json-schema.org/) that aims to fully support every current and previous draft.

## Usage

Add it to your project using rebar and you are done. There are only 2 functions exported by ``jsv`` ``validate/2`` and ``validate/3``

Using ``jsv:validate/2`` is pretty straightforward:

```erlang
Schema = jiffy:decode(SchemaString, [return_maps]).
Data = jiffy:decode(JSONString, [return_maps]).
IsValid = jsv:validate(Data, Schema). % true | false
```

~~If your schema references other schemas, call ``jsv:validate/3`` and pass a map of schemas as the third argument. This map should have keys matching the references in your main schema (the keys should be binaries).~~ Not yet implemented.

## Tests

jsv is tested using the [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite).

To generate the Common Test suites, use the makefile (requires Python >3.9):

```bash
make tests
```

This will generate a suite for each JSON file on the tests directory from JSON-Schema-Test-Suite. With those in place, just call ct normally:

```bash
rebar3 ct
```

It currently passes 5873 of the 6546 tests in the repository (due to the lack of refs, defs and anchors). The aim is to reach 6546.

## Limitations

- jsv was designed to work with [jiffy](https://github.com/davisp/jiffy) generated maps and has not been tested with any other json library, [jsx](https://github.com/talentdeficit/jsx) probably also works, but it might not.

- jsv expects the schema to be valid. The behaviour of jsv when faced with an invalid schema is undefined.

- jsv only returns ``true`` or ``false``, there's no way to obtain the specific error or annotation. In short, jsv only supports the Flag output format [as defined on the spec](https://json-schema.org/draft/2020-12/json-schema-core.html#rfc.section.12).

- Please note that jsv does not currently implement refs, defs or anchors (it's a WIP)

## Contributing

Issues and pull requests are most welcome.

Regarding validation errors, keep in mind that jsv was tested with the [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite), if you find a schema that should validate but doesn't (or viceversa), please consider contributing a new test for that repository as well.