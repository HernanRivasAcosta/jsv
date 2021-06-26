-module(jsv).

% API
-export([validate/2, validate/3]).


%%==============================================================================
%% API
%%==============================================================================
-spec validate(map(), map()) -> boolean().
validate(JSON, Schema) ->
  validate(JSON, Schema, #{}).

-spec validate(map(), map(), map()) -> boolean().
validate(JSON, Schema, Schemas) ->
  do_validate(Schema, JSON, #{root => Schema,
                              defs => #{},
                              remotes => Schemas}).

%%==============================================================================
%% Checks
%%==============================================================================
do_validate(#{<<"$defs">> := NewDefs} = Schema, JSON, State = #{defs := Defs}) ->
  NewState = State#{defs => maps:merge(NewDefs, Defs)},
  do_validate(maps:without([<<"$defs">>], Schema), JSON, NewState);
do_validate(#{<<"type">> := Type} = Schema, JSON, State) ->
  is_of_type(Type, JSON) andalso
  do_validate(maps:without([<<"type">>], Schema), JSON, State);
do_validate(#{<<"pattern">> := Pattern} = Schema, JSON, State) ->
  matches_pattern(Pattern, JSON) andalso
  do_validate(maps:without([<<"pattern">>], Schema), JSON, State);
do_validate(#{<<"propertyNames">> := PropertyNames} = Schema, JSON, State) ->
  property_names_match(PropertyNames, JSON, State) andalso
  do_validate(maps:without([<<"propertyNames">>], Schema), JSON, State);
do_validate(#{<<"properties">> := Properties} = Schema, JSON, State) ->
  NewState = State#{properties => Properties},
  matches_properties(Properties, JSON, State) andalso
  do_validate(maps:without([<<"properties">>], Schema), JSON, NewState);
do_validate(#{<<"patternProperties">> := Properties} = Schema, JSON, State) ->
  NewState = State#{pattern_properties => Properties},
  matches_pattern_properties(Properties, JSON, State) andalso
  do_validate(maps:without([<<"patternProperties">>], Schema), JSON, NewState);
do_validate(#{<<"additionalProperties">> := Properties} = Schema, JSON, State) ->
  validate_additional_properties(Properties, JSON, State) andalso
  do_validate(maps:without([<<"additionalProperties">>], Schema), JSON, State);
do_validate(#{<<"maxProperties">> := MaxProperties} = Schema, JSON, State) ->
  max_properties(MaxProperties, JSON) andalso
  do_validate(maps:without([<<"maxProperties">>], Schema), JSON, State);
do_validate(#{<<"minProperties">> := MinProperties} = Schema, JSON, State) ->
  min_properties(MinProperties, JSON) andalso
  do_validate(maps:without([<<"minProperties">>], Schema), JSON, State);
do_validate(#{<<"maxItems">> := MaxItems} = Schema, JSON, State) ->
  max_items(MaxItems, JSON) andalso
  do_validate(maps:without([<<"maxItems">>], Schema), JSON, State);
do_validate(#{<<"minItems">> := MinItems} = Schema, JSON, State) ->
  min_items(MinItems, JSON) andalso
  do_validate(maps:without([<<"minItems">>], Schema), JSON, State);
do_validate(#{<<"maximum">> := Maximum} = Schema, JSON, State) ->
  is_lower_than(Maximum, JSON, false) andalso
  do_validate(maps:without([<<"maximum">>], Schema), JSON, State);
do_validate(#{<<"minimum">> := Minimum} = Schema, JSON, State) ->
  is_higher_than(Minimum, JSON, false) andalso
  do_validate(maps:without([<<"minimum">>], Schema), JSON, State);
do_validate(#{<<"exclusiveMaximum">> := Maximum} = Schema, JSON, State) ->
  is_lower_than(Maximum, JSON, true) andalso
  do_validate(maps:without([<<"exclusiveMaximum">>], Schema), JSON, State);
do_validate(#{<<"exclusiveMinimum">> := Minimum} = Schema, JSON, State) ->
  is_higher_than(Minimum, JSON, true) andalso
  do_validate(maps:without([<<"exclusiveMinimum">>], Schema), JSON, State);
do_validate(#{<<"maxLength">> := MaxLength} = Schema, JSON, State) ->
  shorter_than(MaxLength, JSON) andalso
  do_validate(maps:without([<<"maxLength">>], Schema), JSON, State);
do_validate(#{<<"minLength">> := MinLength} = Schema, JSON, State) ->
  longer_than(MinLength, JSON) andalso
  do_validate(maps:without([<<"minLength">>], Schema), JSON, State);
do_validate(#{<<"multipleOf">> := MultipleOf} = Schema, JSON, State) ->
  is_multiple_of(MultipleOf, JSON) andalso
  do_validate(maps:without([<<"multipleOf">>], Schema), JSON, State);
do_validate(#{<<"const">> := Const} = Schema, JSON, State) ->
  equals_const(Const, JSON) andalso
  do_validate(maps:without([<<"const">>], Schema), JSON, State);
do_validate(#{<<"enum">> := Enum} = Schema, JSON, State) ->
  matches_enum(Enum, JSON) andalso
  do_validate(maps:without([<<"enum">>], Schema), JSON, State);
do_validate(#{<<"required">> := Required} = Schema, JSON, State) ->
  contains_required_props(Required, JSON) andalso
  do_validate(maps:without([<<"required">>], Schema), JSON, State);
do_validate(#{<<"allOf">> := AllOf} = Schema, JSON, State) ->
  NewMap = lists:foldl(fun(false, _) -> false;
                          (_, false) -> false;
                          (true, _) -> true;
                          (SubSchema, Acc) -> merge_schemas(Acc, SubSchema)
                       end, maps:without([<<"allOf">>], Schema), AllOf),
  do_validate(NewMap, JSON, State);
do_validate(#{<<"prefixItems">> := PrefixItems} = Schema, JSON, State) ->
  NewState = State#{prefix_items => PrefixItems},
  prefix_matches(PrefixItems, JSON, State) andalso
  do_validate(maps:without([<<"prefixItems">>], Schema), JSON, NewState);
do_validate(#{<<"items">> := Items} = Schema, JSON, State) ->
  NewState = State#{items => Items},
  items_match(Items, JSON, State) andalso
  do_validate(maps:without([<<"items">>], Schema), JSON, NewState);
do_validate(#{<<"unevaluatedItems">> := Items} = Schema, JSON, State) ->
  check_unevaluated_items(Items, JSON, State) andalso
  do_validate(maps:without([<<"unevaluatedItems">>], Schema), JSON, State);
do_validate(#{<<"uniqueItems">> := UniqueItems} = Schema, JSON, State) ->
  items_are_unique(UniqueItems, JSON) andalso
  do_validate(maps:without([<<"uniqueItems">>], Schema), JSON, State);
do_validate(#{<<"contains">> := Contains} = Schema, JSON, State) ->
  Schema2 = maps:without([<<"contains">>], Schema),
  {Min, Schema3} = case maps:take(<<"minContains">>, Schema2) of
                     error -> {1, Schema2};
                     R1 -> R1
                   end,
  {Max, Schema4} = case maps:take(<<"maxContains">>, Schema3) of
                     error -> {undefined, Schema3};
                     R2 -> R2
                   end,
  contains(Contains, Min, Max, JSON, State) andalso
  do_validate(Schema4, JSON, State);
do_validate(#{<<"not">> := Items} = Schema, JSON, State) ->
  items_dont_match(Items, JSON, State) andalso
  do_validate(maps:without([<<"not">>], Schema), JSON, State);
do_validate(#{<<"anyOf">> := AnyOf} = Schema, JSON, State) ->
  case contains_any_of(AnyOf, JSON, State) of
    false ->
      false;
    true ->
      do_validate(maps:without([<<"anyOf">>], Schema), JSON, State);
    {true, MatchingSchema} ->
      NewState = case is_map(MatchingSchema) andalso
                      maps:find(<<"prefixItems">>, MatchingSchema) of
                   {ok, PrefixItems} ->
                     State#{prefix_items => PrefixItems};
                   _ ->
                     State
                 end,
      do_validate(maps:without([<<"anyOf">>], Schema), JSON, NewState)
  end;
do_validate(#{<<"oneOf">> := OneOf} = Schema, JSON, State) ->
  contains_one_of(OneOf, JSON, State) andalso
  do_validate(maps:without([<<"oneOf">>], Schema), JSON, State);
do_validate(#{<<"$ref">> := Ref} = Schema, JSON, State) when is_binary(Ref) ->
  handle_ref(Ref, JSON, State) andalso
  do_validate(maps:without([<<"$ref">>], Schema), JSON, State);
do_validate(#{<<"$dynamicRef">> := Ref} = Schema, JSON, State) when is_binary(Ref) ->
  handle_ref(Ref, JSON, State) andalso
  do_validate(maps:without([<<"$dynamicRef">>], Schema), JSON, State);
do_validate(true, _JSON, _State) ->
  true;
do_validate(false, _JSON, _State) ->
  false;
do_validate(#{}, _JSON, _State) ->
  true.

%%==============================================================================
%% Validation functions
%%==============================================================================
is_of_type(<<"integer">>, JSON) ->
  is_whole_number(JSON);
is_of_type(<<"number">>, JSON) ->
  erlang:is_integer(JSON) orelse erlang:is_float(JSON);
is_of_type(<<"string">>, JSON) ->
  erlang:is_binary(JSON);
is_of_type(<<"object">>, JSON) ->
  erlang:is_map(JSON);
is_of_type(<<"array">>, JSON) ->
  erlang:is_list(JSON);
is_of_type(<<"boolean">>, JSON) ->
  JSON =:= true orelse JSON =:= false;
is_of_type(<<"null">>, JSON) ->
  JSON =:= null;
is_of_type(List, JSON) when is_list(List) ->
  lists:any(fun(Type) -> is_of_type(Type, JSON) end, List).

matches_pattern(Pattern, Binary) when is_binary(Binary) ->
  case re:run(Binary, Pattern) of
    {match, _Captured} ->
      true;
    nomatch ->
      false
  end;
matches_pattern(_Pattern, _JSON) ->
  true.

property_names_match(Schema, Object, State) when is_map(Object) ->
  lists:all(fun(K) ->
              validate_nested(Schema, K, State)
            end, maps:keys(Object));
property_names_match(_Schema, _JSON, _State) ->
  true.

matches_properties(Properties, Object, State) when is_map(Object) ->
  maps:fold(fun(_Key, _Schema, false) ->
                 false;
               (<<"$ref">>, Ref, true) when is_binary(Ref) ->
                 handle_ref(Ref, Object, State);
               (<<"$dynamicRef">>, Ref, true) when is_binary(Ref) ->
                 handle_ref(Ref, Object, State);
               (Key, Schema, true) ->
                 case maps:find(Key, Object) of
                   {ok, JSON} ->
                     validate_nested(Schema, JSON, State);
                   error ->
                     true
                 end
            end, true, Properties);
matches_properties(_Properties, _JSON, _State) ->
  true.

matches_pattern_properties(Patterns, Object, State) when is_map(Object) ->
  maps:fold(fun(_Pattern, _Schema, false) ->
                 false;
               (Pattern, Schema, true) ->
                 maps:fold(fun(_Key, _Value, false) ->
                                false;
                              (Key, Value, true) ->
                                case re:run(Key, Pattern) of
                                  {match, _Captured} ->
                                    validate_nested(Schema, Value, State);
                                  nomatch ->
                                    true
                                end
                           end, true, Object)
            end, true, Patterns);
matches_pattern_properties(_PatternProperties, _JSON, _State) ->
  true.

validate_additional_properties(false, Object, State) when is_map(Object) ->
  Properties = maps:keys(maps:get(properties, State, #{})),
  PatternProperties = maps:keys(maps:get(pattern_properties, State, #{})),
  % Check that all keys
  lists:all(fun(Key) ->
              % Are either explicitly mentioned in properties
              lists:member(Key, Properties) orelse
              % Or they match at least one pattern
              lists:any(fun(Pattern) ->
                          case re:run(Key, Pattern) of
                            {match, _Captured} ->
                              true;
                            nomatch ->
                              false
                          end
                        end, PatternProperties)
            end, maps:keys(Object));
validate_additional_properties(Schema, Object, State) when is_map(Object) ->
  Properties = maps:keys(maps:get(properties, State, #{})),
  PatternProperties = maps:keys(maps:get(pattern_properties, State, #{})),
  % Check that all elements
  maps:fold(fun(_Key, _Value, false) ->
                 false;
               (Key, Value, true) ->
                 % If they are not explicitly mentioned in properties
                 lists:member(Key, Properties) orelse
                 % Or they don't match at least one pattern
                 lists:any(fun(Pattern) ->
                             case re:run(Key, Pattern) of
                               {match, _Captured} ->
                                 true;
                               nomatch ->
                                 false
                             end
                           end, PatternProperties) orelse
                 % They need to validate
                 validate_nested(Schema, Value, State)
            end, true, Object);
validate_additional_properties(_Schema, _JSON, _State) ->
  true.

max_properties(MaxProperties, Object) when is_map(Object) ->
  MaxProperties >= maps:size(Object);
max_properties(_MaxProperties, _JSON) ->
  true.

min_properties(MinProperties, Object) when is_map(Object) ->
  MinProperties =< maps:size(Object);
min_properties(_MinProperties, _JSON) ->
  true.

max_items(MaxItems, List) when is_list(List) ->
  MaxItems >= erlang:length(List);
max_items(_MaxItems, _JSON) ->
  true.

min_items(MinItems, List) when is_list(List) ->
  MinItems =< erlang:length(List);
min_items(_MinItems, _JSON) ->
  true.

is_lower_than(Maximum, Number, false) when is_number(Number) ->
  Maximum >= Number;
is_lower_than(Maximum, Number, true) when is_number(Number) ->
  Maximum > Number;
is_lower_than(_Maximum, _JSON, _Exclusive) ->
  true.

is_higher_than(Minimum, Number, false) when is_number(Number) ->
  Minimum =< Number;
is_higher_than(Minimum, Number, true) when is_number(Number) ->
  Minimum < Number;
is_higher_than(_Minimum, _JSON, _Exclusive) ->
  true.

shorter_than(MaxLength, Binary) when is_binary(Binary) ->
  MaxLength >= erlang:length(unicode:characters_to_nfc_list(Binary));
shorter_than(_MaxLength, _JSON) ->
  true.

longer_than(MinLength, Binary) when is_binary(Binary) ->
  MinLength =< erlang:length(unicode:characters_to_nfc_list(Binary));
longer_than(_MinLength, _JSON) ->
  true.

is_multiple_of(MultipleOf, Number) when is_number(Number) ->
  try is_whole_number(Number / MultipleOf)
  catch
    error:badarith ->
      false
  end;
is_multiple_of(_MultipleOf, _JSON) ->
  true.

equals_const(Const, Const) ->
  true;
equals_const(Const, Element) when is_number(Const), is_number(Element) ->
  Const == Element;
equals_const(_Const, _Element) ->
  false.

matches_enum(Enum, Element) ->
  lists:any(fun(E) ->
              equals_const(E, Element)
            end, Enum).

contains_required_props(Required, Object) when is_map(Object),
                                               is_list(Required) ->
  lists:all(fun(Property) ->
              maps:is_key(Property, Object)
            end, Required);
contains_required_props(_Required, _JSON) ->
  true.

items_match(false, List, #{prefix_items := PrefixItems}) when is_list(List) ->
  erlang:length(List) =< erlang:length(PrefixItems);
items_match(true, List, _State) when is_list(List) ->
  true;
items_match(Schema, List, State) when is_list(List) ->
  PrefixItems = maps:get(prefix_items, State, []),
  NonPrefixedList = lists:nthtail(erlang:length(PrefixItems), List),
  case Schema of
    [_ | _] ->
      lists:foldl(fun(_E, Bool) when is_boolean(Bool) ->
                       Bool;
                     (_E, []) ->
                       true;
                     (E, [SubSchema | T]) ->
                       validate_nested(SubSchema, E, State) andalso T
                  end, Schema, NonPrefixedList) =/= false;
    _ ->
      lists:all(fun(Element) ->
                  validate_nested(Schema, Element, State)
                end, NonPrefixedList)
  end;
items_match(_Schema, _JSON, _State) ->
  true.

check_unevaluated_items(_, List, #{items := true}) when is_list(List) ->
  true;
check_unevaluated_items(true, List, _State) when is_list(List) ->
  true;
check_unevaluated_items(Schema, List, State) when is_list(List) ->
  List2 = remove_prefix(maps:get(prefix_items, State, []), List, State),
  ItemsSchema = maps:get(items, State, false),
  List3 = lists:filter(fun(Item) ->
                         not validate_nested(ItemsSchema, Item, State)
                       end, List2),
  lists:all(fun(Item) ->
              validate_nested(Schema, Item, State)
            end, List3);
check_unevaluated_items(_Items, _JSON, _State) ->
  true.

items_are_unique(false, _JSON) ->
  true;
items_are_unique(true, List) when is_list(List) ->
  lists:sort(List) =:= lists:usort(List);
items_are_unique(_Unique, _JSON) ->
  true.

contains(_Schema, _Min, 0, List, _State) when is_list(List) ->
  false;
contains(Schema, Min, Max, List, State) when is_list(List) ->
  FinalCount = lists:foldl(fun(Element, Acc) ->
                             case validate_nested(Schema, Element, State) of
                               true ->
                                 Acc + 1;
                               false ->
                                 Acc
                             end
                           end, 0, List),
  FinalCount >= Min andalso FinalCount =< Max;
contains(_Schema, _Min, _Max, _JSON, _State) ->
  true.

prefix_matches([], List, _State) when is_list(List) ->
  true;
prefix_matches([Schema | T1], [JSON | T2], State) ->
  case validate_nested(Schema, JSON, State) of
    true ->
      prefix_matches(T1, T2, State);
    false ->
      false
  end;
prefix_matches(_Schemas, _JSON, _State) ->
  true.

items_dont_match(Schema, JSON, State) ->
  not validate_nested(Schema, JSON, State).

contains_any_of(AnyOf, JSON, State) when is_list(AnyOf) ->
  case first(fun(Schema) -> validate_nested(Schema, JSON, State) end, AnyOf) of
    {ok, Schema} ->
      {true, Schema};
    nomatch ->
      false
  end;
contains_any_of(_Required, _JSON, _State) ->
  true.

contains_one_of(OneOf, JSON, State) when is_list(OneOf) ->
  lists:foldl(fun(_Schema, false) ->
                   false;
                 (Schema, not_found) ->
                   case validate_nested(Schema, JSON, State) of
                     true -> true;
                     false -> not_found
                   end;
                 (Schema, true) ->
                   not validate_nested(Schema, JSON, State)
              end, not_found, OneOf) =:= true;
contains_one_of(_Required, _JSON, _State) ->
  true.

handle_ref(Ref, JSON, State) ->
  % Don't call validate_nested
  do_validate(get_refd_element(Ref, State), JSON, State).

%%==============================================================================
%% Utils
%%==============================================================================
is_whole_number(Int) when is_integer(Int) ->
  true;
is_whole_number(Float) when is_float(Float) ->
  trunc(Float) == Float;
is_whole_number(_Any) ->
  false.

merge_schemas(B1, B2) when is_boolean(B1), is_boolean(B2) ->
  B1 andalso B2;
merge_schemas(false, _Schema2) ->
  false;
merge_schemas(_Schema1, false) ->
  false;
merge_schemas(true, Schema2) ->
  Schema2;
merge_schemas(Schema1, true) ->
  Schema1;
merge_schemas(Schema1, Schema2) ->
  maps:merge_with(fun(<<"properties">>, V1, V2) ->
                       maps:merge(V1, V2);
                     (<<"required">>, V1, V2) ->
                       V1 ++ V2;
                     (<<"prefixItems">>, V1, V2) ->
                       V1 ++ V2;
                     (<<"unevaluatedItems">>, V1, V2) ->
                       V1 orelse V2;
                     (<<"multipleOf">>, V1, V2) ->
                       lcm(V1, V2);
                     (<<"unevaluatedProperties">>, V1, V2) ->
                       merge_schemas(V1, V2);
                     (<<"contains">>, V1, V2) ->
                       merge_schemas(V1, V2)
                  end, Schema1, Schema2).

remove_prefix([], List, _State) ->
  List;
remove_prefix(_Prefix, [], _State) ->
  [];
remove_prefix([H1 | T1], [H2 | T2] = List, State) ->
  case validate_nested(H1, H2, State) of
    true -> remove_prefix(T1, T2, State);
    false -> List
  end.

first(_F, []) ->
  nomatch;
first(F, [H | T]) ->
  case F(H) of
    true -> {ok, H};
    false -> first(F, T)
  end.

validate_nested(Schema, JSON, State) ->
  % Drop all elements that only apply for the current level
  ElementsToDrop = [properties, pattern_properties, items, prefix_items],
  CleanState = maps:without(ElementsToDrop, State),
  do_validate(Schema, JSON, CleanState).

get_refd_element([], Schema) ->
  Schema;
get_refd_element([H | T], List) when is_list(List) ->
  get_refd_element(T, lists:nth(erlang:binary_to_integer(H) + 1, List));
get_refd_element([H | T], Schema) ->
  get_refd_element(T, maps:get(H, Schema, false));
get_refd_element(Ref, #{root := Root, defs := Defs, remotes := Remotes}) ->
  case maps:find(Ref, Remotes) of
    {ok, Remote} ->
      Remote;
    error ->
      case binary:split(Ref, <<"/">>, [global]) of
        [<<"#">> | T] ->
          get_refd_element(T, Root);
        [Key] ->
          maps:get(unescape_ref(Key), Defs, false);
        _ ->
          % This case happens when the schema has a remote reference that wasn't
          % provided when calling validate/3
          false
      end
  end.

unescape_ref(Bin) ->
  Bin2 = binary:replace(Bin, <<"~1">>, <<"/">>, [global]),
  Bin3 = binary:replace(Bin2, <<"~0">>, <<"~">>, [global]),
  binary:replace(Bin3, <<"%25">>, <<"%">>, [global]).

% From https://rosettacode.org/wiki/Least_common_multiple#Erlang
gcd(A, 0) ->
  A;
gcd(A, B) ->
  gcd(B, A rem B).

lcm(A,B) ->
  abs(A*B div gcd(A,B)).