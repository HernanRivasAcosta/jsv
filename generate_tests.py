#!/usr/bin/env python3

import sys
import os
import os.path
import json
import re

##
## Utils
##
def removeRedundantUnderscores(string):
  newString = string.replace('__', '_')
  if (newString == string):
    return newString
  else:
    return removeRedundantUnderscores(newString)

def reservedWords():
  # A list of erlang restricted atom names
  # https://erlang.org/doc/reference_manual/introduction.html#reserved-words
  return ['after', 'and', 'andalso', 'band', 'begin', 'bnot', 'bor', 'bsl',
          'bsr', 'bxor', 'case', 'catch', 'cond', 'div', 'end', 'fun', 'if',
          'let', 'not', 'of', 'or', 'orelse', 'receive', 'rem', 'try', 'when',
          'xor']

def toValidAtom(string):
  # First we replace some symbols with words to make it prettier
  fancyString = string.replace('=', '_equals_')
  fancyString = fancyString.replace('<', '_less_than_')
  fancyString = fancyString.replace('>', '_more_than_')
  # Now, we replace spaces, dashes and some words
  nonSpacedString = fancyString.replace('-', '_').replace(' ', '_')
  # Then we remove all invalid characters
  validString = re.sub('[^A-Za-z0-9_]', '', nonSpacedString)
  # Make sure it's camel cased (or the next regex will add an underscore)
  camelCased = re.sub('^[A-Z]+', lambda x: x.group(0).lower(), validString)
  # Then we take care of the uppercase values in subsequent matches
  snakeCased = re.sub('[A-Z]+', lambda x: '_' + x.group(0).lower(), camelCased)
  # Remove redundant underscores
  finalAtom = removeRedundantUnderscores(snakeCased)
  # Lastly, we make sure we didn't land in a reserved word
  if (finalAtom in reservedWords()):
    return f'{finalAtom}_atom'
  else:
    return finalAtom

def uniqueAtomName(name, names, counter = 0):
  atomName = toValidAtom(f'test_{name}')
  if (counter > 0):
    atomName += '_%d' % counter
  if (atomName in names):
    return uniqueAtomName(name, names, counter + 1)
  else:
    return atomName

def printableJSON(JSON):
  # Double dumping escapes all quotation marks
  return json.dumps(json.dumps(JSON, ensure_ascii=False), ensure_ascii=False)

# Same as printableJSON, but generates the binary representation of the string
def printableBinaryJSON(JSON):
  string = json.dumps(JSON, ensure_ascii=False)
  encodedString = string.encode('utf8')
  integerList = ', '.join(map(str, list(encodedString)))
  return integerList

def groupDeclaration(group):
  (name, properties) = group
  casesString = ',\n     '.join(properties['caseNames'])
  return f'{{{name},\n    [parallel],\n    [{casesString}]}}'

##
## Main
##
# Get all tests:
testsPath = 'deps/JSON-Schema-Test-Suite/tests'
generatedTestsPath = 'test/generated'
if not os.path.exists(generatedTestsPath):
  os.makedirs(generatedTestsPath)

if (len(sys.argv) > 1 and sys.argv[1] != 'all'):
  suites = [sys.argv[1]]
else:
  suites = os.listdir(testsPath)

for suite in suites:
  suitePath = os.path.join(testsPath, suite)
  if (os.path.isdir(suitePath) and not os.path.islink(suitePath)):
    for test in os.listdir(suitePath):
      if (test.endswith('.json')):
        testPath = os.path.join(suitePath, test)
        groupNames = []
        caseNames = []
        i = 0
        with open(testPath, 'r') as f:
          testJSON = json.load(f)
          groups = {}
          for group in testJSON:
            groupName = uniqueAtomName(group['description'], groupNames)
            groupNames.append(groupName)
            groups[groupName] = {'schema': printableJSON(group['schema']),
                                 'caseNames': [],
                                 'cases': []}
            for case in group['tests']:
              description = case['description']
              name = uniqueAtomName(description, caseNames)
              caseNames.append(name)
              groups[groupName]['caseNames'].append(name)
              testCase = {'name': name,
                          'data': printableJSON(case['data']),
                          'valid': case['valid']}
              groups[groupName]['cases'].append(testCase)

        suiteName = toValidAtom(f'{suite} {test[:-5]}') + '_SUITE'
        # Module name
        content = f'-module({suiteName}).\n\n'
        # Mandatory exports
        content += '-export([all/0,\n'\
                   '         groups/0,\n'\
                   '         init_per_group/2,\n'\
                   '         end_per_group/2'
        # Export all test cases
        for caseName in caseNames:
          content += f',\n         {caseName}/1'
        # Close the export declaration
        content += ']).\n\n-type config() :: [{atom(), term()}].\n\n'
        # Add all the groups
        content += '-spec all() -> [{group, atom()}].\nall() ->\n  ['
        groupsStrings = list(map(lambda g: f'{{group, {g}}}', groups.keys()))
        content += ',\n   '.join(groupsStrings)
        # Close the tests list
        content += '].\n\n'
        # Define the groups
        content += '-spec groups() -> [{atom(), [any()], [atom()]}].\n'
        content += 'groups() ->\n  ['
        groupsStrings = list(map(groupDeclaration, groups.items()))
        content += ',\n   '.join(groupsStrings)
        # Close the group list
        content += '].\n\n'
        # Add the init functions
        content += '-spec init_per_group(atom(), config()) -> config().\n'
        for groupName, groupData in groups.items():
          content += f'init_per_group({groupName}, _Config) ->\n'
          content += f'  Schema = jiffy:decode(<<{groupData["schema"]}>>, [return_maps]),\n'
          content +=  '  [{schema, Schema}];\n'
        content = content[:-2] + '.\n\n'
        # Add the end per group function
        content += '-spec end_per_group(atom(), config()) -> config().\n'
        content += 'end_per_group(_, Config) ->\n'
        content += '  Config.\n'
        # Add all the tests
        for groupName, groupData in groups.items():
          for testCase in groupData['cases']:
            name = testCase['name']
            content += f'\n-spec {name}(config()) -> ok.\n'
            content += f'{name}(Config) ->\n'
            content +=  '  Schema = proplists:get_value(schema, Config),\n'
            content += f'  Data = jiffy:decode(<<{testCase["data"]}>>, [return_maps]),\n'
            if (testCase['valid']):
              content += '  ct:pal("data: ~p, schema: ~p, expected: ~p", [Data, Schema, true]),\n'
              content += '  true = '
            else:
              content += '  ct:pal("data: ~p, schema: ~p, expected: ~p", [Data, Schema, false]),\n'
              content += '  false = '
            content += 'jsv:validate(Data, Schema),\n'
            content += '  ok.\n'
        # Write the file
        with open(os.path.join(generatedTestsPath, suiteName + '.erl'), 'w') as f:
          f.write(content)