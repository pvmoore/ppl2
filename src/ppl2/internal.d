module ppl2.internal;

public:

import core.atomic     : atomicLoad, atomicStore;
import core.memory     : GC;
import core.sync.mutex : Mutex;

import std.stdio     : writefln, writeln;
import std.format    : format;
import std.string    : toLower, indexOf, lastIndexOf;
import std.conv      : to;
import std.typecons  : Tuple, tuple;
import std.array     : Appender, appender, array, join;
import std.range     : takeOne;
import std.json      : JSONValue, toJSON, JSONOptions;
import std.datetime.stopwatch  : StopWatch;

import std.algorithm.iteration : each, map, filter, sum;
import std.algorithm.searching : any, all, count, startsWith;
import std.algorithm.sorting   : sort;

import common : Array, From, Hash, Hasher, Queue, Set, Stack, StringBuffer,
                as, dynamicDispatch, isA, firstNotNull, flushConsole, endsWith,
                removeChars, repeat, visit;

import llvm.all;
import ppl2;

import ppl2.access;
import ppl2.interfaces;
import ppl2.Mangler;
import ppl2.ppl2;
import ppl2.global;
import ppl2.operator;
import ppl2.target;

import ppl2.ast.expression;
import ppl2.ast.expr_address_of;
import ppl2.ast.expr_as;
import ppl2.ast.expr_binary;
import ppl2.ast.expr_call;
import ppl2.ast.expr_closure;
import ppl2.ast.expr_composite;
import ppl2.ast.expr_constructor;
import ppl2.ast.expr_dot;
import ppl2.ast.expr_identifier;
import ppl2.ast.expr_if;
import ppl2.ast.expr_is;
import ppl2.ast.expr_index;
import ppl2.ast.expr_initialiser;
import ppl2.ast.expr_literal_number;
import ppl2.ast.expr_literal_array;
import ppl2.ast.expr_literal_expr_list;
import ppl2.ast.expr_literal_function;
import ppl2.ast.expr_literal_map;
import ppl2.ast.expr_literal_null;
import ppl2.ast.expr_literal_string;
import ppl2.ast.expr_literal_struct;
import ppl2.ast.expr_calloc;
import ppl2.ast.expr_module_alias;
import ppl2.ast.expr_parenthesis;
import ppl2.ast.expr_select;
import ppl2.ast.expr_type;
import ppl2.ast.expr_unary;
import ppl2.ast.statement;
import ppl2.ast.parameters;
import ppl2.ast.stmt_assert;
import ppl2.ast.stmt_break;
import ppl2.ast.stmt_continue;
import ppl2.ast.stmt_function;
import ppl2.ast.stmt_import;
import ppl2.ast.stmt_loop;
import ppl2.ast.stmt_return;
import ppl2.ast.expr_value_of;
import ppl2.ast.stmt_variable;

import ppl2.build.BuildState;

import ppl2.check.check_module;

import ppl2.error.CompilationAborted;
import ppl2.error.CompileError;

import ppl2.gen.gen_binary;
import ppl2.gen.gen_function;
import ppl2.gen.gen_literals;
import ppl2.gen.gen_loop;
import ppl2.gen.gen_if;
import ppl2.gen.gen_module;
import ppl2.gen.gen_select;
import ppl2.gen.gen_struct;
import ppl2.gen.gen_variable;

import ppl2.opt.opt_dead_code;

import ppl2.misc.JsonWriter;
import ppl2.misc.linker;
import ppl2.misc.misc_logging;
import ppl2.misc.node_builder;
import ppl2.misc.optimiser;
import ppl2.misc.util;
import ppl2.misc.writer;

import ppl2.parse.detect_type;
import ppl2.parse.parse_expression;
import ppl2.parse.parse_helper;
import ppl2.parse.parse_module;
import ppl2.parse.parse_named_struct;
import ppl2.parse.parse_statement;
import ppl2.parse.parse_type;
import ppl2.parse.parse_variable;

import ppl2.resolve.after_resolution;
import ppl2.resolve.find_import;
import ppl2.resolve.TypeFinder;
import ppl2.resolve.OverloadCollector;
import ppl2.resolve.resolve_call;
import ppl2.resolve.resolve_identifier;
import ppl2.resolve.resolve_module;

import ppl2.templates.blueprint;
import ppl2.templates.ImplicitTemplates;
import ppl2.templates.ParamTokens;
import ppl2.templates.ParamTypeMatcherRegex;
import ppl2.templates.templates;

import ppl2.type.alias_;
import ppl2.type.type;
import ppl2.type.type_array;
import ppl2.type.type_basic;
import ppl2.type.type_function;
import ppl2.type.type_anon_struct;
import ppl2.type.type_named_struct;
import ppl2.type.type_ptr;

