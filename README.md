# jsv

**J**SON **S**chema **V**alidator

jsv is an erlang implementation of [JSON Schemas](https://json-schema.org/) that aims to fully support the latest draft (and as many of the previous drafts as possible).

## Usage

Add it to your project using rebar and you are done. There are only 2 functions exported by ``jsv`` ``validate/2`` and ``validate/3``

Using ``jsv:validate/2`` is pretty straightforward:

```erlang
Schema = jiffy:decode(SchemaString, [return_maps]).
Data = jiffy:decode(JSONString, [return_maps]).
IsValid = jsv:validate(Data, Schema). % true | false
```

If your schema references other schemas, call ``jsv:validate/3`` and pass a map of schemas as the third argument. This map key's need to be the URIs of the schemas they point to (as erlang binaries) and match the root ``$id`` element if one is present (jsv will not check if this is the case).

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

It currently passes 5960 of the 6546 tests in the repository (only 81 out of 1007 errors in the 'latest' test SUITE for the 2020 draft). The aim is to reach all 6546, though deprecated functionality might not be handled and might bring the number down.

## Notes

### Default URI

jsv sets a default base URI of ``<<"schema:jsv/root">>`` if no ``$id`` is defined on the root of the schema in accordance with [the RFC](https://json-schema.org/draft/2020-12/json-schema-core.html#rfc.section.9.1.1).

### Limitations

- jsv was designed to work with [jiffy](https://github.com/davisp/jiffy) generated maps and has not been tested with any other json library, [jsx](https://github.com/talentdeficit/jsx) probably also works, but it has not been tested.

- jsv expects the schema to be valid. The behaviour of jsv when faced with an invalid schema is undefined. This is specially true for bad references which can easily match random stuff.

- jsv's methods only return ``true`` or ``false``. There's no way to obtain the specific error or any annotations (nor are there plans to add this). In short, jsv only supports the Flag output format [as defined on the RFC](https://json-schema.org/draft/2020-12/json-schema-core.html#rfc.section.12).

- jsv currently treats dynamic references and dynamic anchors like normal references and anchors.

- ``unevaluatedItems`` and ``unevaluatedProperties`` are currently only partially implemented (they don't interact well with ``anyOf`` and ``allOf``).

- jsv does not yet support ``$vocabulary``

## Contributing

Issues and pull requests are most welcome.

Regarding validation errors, check if there's a failing test covering it. If that's the case, the problem is being looked into, but feel free to open an issue if you feel further information might be of use.

Aditionally, if no test seems to cover the case you have, keep in mind that jsv was tested with the [JSON Schema Test Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite), if you find a schema that should validate but doesn't (or viceversa), please consider contributing a new test for that repository as well.