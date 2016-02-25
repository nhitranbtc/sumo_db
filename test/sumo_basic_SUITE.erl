-module(sumo_basic_SUITE).

-export([
         all/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2
        ]).

-export([
         find/1,
         find_all/1,
         find_by/1,
         delete_all/1,
         delete/1,
         check_proper_dates/1
        ]).

-define(EXCLUDED_FUNS,
        [
         module_info,
         all,
         test,
         init_per_suite,
         init_per_testcase,
         end_per_suite,
         find_by_sort,
         find_all_sort
        ]).

-type config() :: [{atom(), term()}].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Common test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec all() -> [atom()].
all() ->
  Exports = ?MODULE:module_info(exports),
  [F || {F, _} <- Exports, not lists:member(F, ?EXCLUDED_FUNS)].

-spec init_per_suite(config()) -> config().
init_per_suite(Config) ->
  sumo_test_utils:start_apps(),
  Config.

init_per_testcase(_, Config) ->
  run_all_stores(fun init_store/1),
  Config.

-spec end_per_suite(config()) -> config().
end_per_suite(Config) ->
  Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Exported Tests Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

find(_Config) ->
  run_all_stores(fun find_module/1).

find_all(_Config) ->
  run_all_stores(fun find_all_module/1).

find_by(_Config) ->
  run_all_stores(fun find_by_module/1).

delete_all(_Config) ->
  run_all_stores(fun delete_all_module/1).

delete(_Config) ->
  run_all_stores(fun delete_module/1).

check_proper_dates(_Config) ->
  run_all_stores(fun check_proper_dates_module/1).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Internal functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

init_store(Module) ->
  sumo:create_schema(Module),
  sumo:delete_all(Module),

  sumo:persist(Module, Module:new(<<"A">>, <<"E">>, 6)),
  sumo:persist(Module, Module:new(<<"B">>, <<"D">>, 3)),
  sumo:persist(Module, Module:new(<<"C">>, <<"C">>, 5)),
  sumo:persist(Module, Module:new(<<"D">>, <<"D">>, 4)),
  sumo:persist(Module, Module:new(<<"E">>, <<"A">>, 2)),
  sumo:persist(Module, Module:new(<<"F">>, <<"E">>, 1)),
  sumo:persist(Module, Module:new(<<"Model T-2000">>, <<"undefined">>, 7)),
  sumo:persist(
    Module,
    Module:new(
     <<"Name">>,
     <<"LastName">>,
     3,
     undefined,
     {2016, 2, 05},
     1.75,
     <<"My description text">>
    )
  ),

  %% Sync Timeout.
  sync_timeout(Module).

find_module(Module) ->
  [First, Second | _] = sumo:find_all(Module),
  First = sumo:find(Module, Module:id(First)),
  Second = sumo:find(Module, Module:id(Second)),
  notfound = sumo:find(Module, 0).

find_all_module(Module) ->
  [_, _, _, _, _, _, _, _] = sumo:find_all(Module).

find_by_module(Module) ->
  Results = sumo:find_by(Module, [{last_name, <<"D">>}]),
  [_, _] = Results,
  SortFun = fun(A, B) -> Module:name(A) < Module:name(B) end,
  [First, Second | _] = lists:sort(SortFun, Results),

  {Today, _} = calendar:universal_time(),

  <<"B">> = Module:name(First),
  <<"D">> = Module:name(Second),
  3 = Module:age(First),
  4 = Module:age(Second),
  <<"D">> = Module:last_name(First),
  undefined = Module:address(First),
  Today = Module:birthdate(First),
  undefined = Module:height(First),
  undefined = Module:description(First),
  {Today, _} = Module:created_at(First),
  % Check that it returns what we have inserted
  [LastPerson | _NothingElse] = sumo:find_by(Module,
                                             [{last_name, <<"LastName">>}]),
  <<"Name">> = Module:name(LastPerson),
  <<"LastName">> = Module:last_name(LastPerson),
  3 = Module:age(LastPerson),
  undefined = Module:address(LastPerson),
  {2016, 2, 05} = Module:birthdate(LastPerson),
  1.75 = Module:height(LastPerson),
  <<"My description text">> = Module:description(LastPerson),
  {Today, _} = Module:created_at(LastPerson),

  %% Check find_by ID
  FirstId = Module:id(First),
  [First1] = sumo:find_by(Module, [{id, FirstId}]),
  [First1] = sumo:find_by(Module, [{last_name, <<"D">>},
                                   {id, FirstId}]),
  [] = sumo:find_by(Module, [{name, <<"NotB">>}, {id, FirstId}]),
  First1 = First,
  %% Check pagination
  Results1 = sumo:find_by(Module, [], 3, 1),
  [_, _, _] = Results1,

  %% This test is #177 github issue related
  [_, _, _, _, _, _, _, _] = sumo:find_by(Module, []),
  Robot = sumo:find_by(Module, [{name, <<"Model T-2000">>}]),
  [_] = Robot.

delete_all_module(Module) ->
  sumo:delete_all(Module),
  [] = sumo:find_all(Module).

delete_module(Module) ->
  %% delete_by
  2 = sumo:delete_by(Module, [{last_name, <<"D">>}]),
  sync_timeout(Module),
  Results = sumo:find_by(Module, [{last_name, <<"D">>}]),

  [] = Results,

  %% delete
  [First | _ ] = All = sumo:find_all(Module),
  Id = Module:id(First),
  sumo:delete(Module, Id),
  NewAll = sumo:find_all(Module),

  [_] = All -- NewAll.

check_proper_dates_module(Module) ->
  [P0] = sumo:find_by(Module, [{name, <<"A">>}]),
  P1 = sumo:find(Module, Module:id(P0)),
  [P2 | _] = sumo:find_all(Module),

  {Date, _} = calendar:universal_time(),

  Date = Module:birthdate(P0),
  {Date, {_, _, _}} = Module:created_at(P0),
  Date = Module:birthdate(P1),
  {Date, {_, _, _}} = Module:created_at(P1),
  Date = Module:birthdate(P2),
  {Date, {_, _, _}} = Module:created_at(P2),

  Person = sumo:persist(Module, Module:new(<<"X">>, <<"Z">>, 6)),
  Date = Module:birthdate(Person).

%%% Helper

-spec run_all_stores(fun()) -> ok.
run_all_stores(Fun) ->
  lists:foreach(Fun, sumo_test_utils:all_people()).

-spec sync_timeout(module()) -> ok.
sync_timeout(Module) ->
  %% Sync Timeout.
  %% 1. Necessary to get elasticsearch in particular to index its stuff.
  %% 2. Necessary to Riak.
  %% Riak clusters will retain deleted objects for some period of time
  %% (3 seconds by default), and the MapReduce framework does not conceal
  %% these from submitted jobs.
  %% @see <a href="http://docs.basho.com/riak/latest/dev/advanced/mapreduce"/>
  case Module of
    sumo_test_people_riak -> timer:sleep(5000);
    _                     -> timer:sleep(1000)
  end.
