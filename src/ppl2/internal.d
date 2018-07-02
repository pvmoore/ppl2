module ppl2.internal;

public:

import std.stdio     : writefln;
import std.format    : format;
import std.string    : toLower, indexOf, lastIndexOf;
import std.conv      : to;
import std.typecons  : Tuple, tuple;
import std.array     : appender, array, join;
import std.range     : takeOne;
import std.datetime.stopwatch  : StopWatch;
import std.algorithm.iteration : each, map, filter, sum;
import std.algorithm.searching : any, all, count;
import std.algorithm.sorting   : sort;

import common : Array, Set, Queue, Stack, StringBuffer,
                as, isA, firstNotNull, flushConsole, endsWith,
                removeChars, repeat, visit;

import llvm.all;

import ppl2.access;
import ppl2.config;
import ppl2.error;
import ppl2.ppl2;
import ppl2.global;
import ppl2.operator;
import ppl2.scope_;
import ppl2.target;
import ppl2.tokens;

import ppl2.ast.ast_node;
import ppl2.ast.expression;
import ppl2.ast.expr_address_of;
import ppl2.ast.expr_as;
import ppl2.ast.expr_binary;
import ppl2.ast.expr_call;
import ppl2.ast.expr_composite;
import ppl2.ast.expr_dot;
import ppl2.ast.expr_identifier;
import ppl2.ast.expr_if;
import ppl2.ast.expr_index;
import ppl2.ast.expr_initialiser;
import ppl2.ast.expr_literal_number;
import ppl2.ast.expr_literal_array;
import ppl2.ast.expr_literal_function;
import ppl2.ast.expr_literal_map;
import ppl2.ast.expr_literal_null;
import ppl2.ast.expr_literal_string;
import ppl2.ast.expr_literal_struct;
import ppl2.ast.expr_meta_function;
import ppl2.ast.expr_parenthesis;
import ppl2.ast.expr_type;
import ppl2.ast.expr_unary;
import ppl2.ast.statement;
import ppl2.ast.module_;
import ppl2.ast.stmt_assert;
import ppl2.ast.stmt_function;
import ppl2.ast.stmt_return;
import ppl2.ast.expr_value_of;
import ppl2.ast.stmt_variable;

import ppl2.check.check_module;

import ppl2.gen.gen_binary;
import ppl2.gen.gen_function;
import ppl2.gen.gen_module;
import ppl2.gen.gen_struct;
import ppl2.gen.gen_variable;

import ppl2.opt.opt_dce;
import ppl2.opt.opt_const_fold;

import ppl2.interfaces.callable;
import ppl2.interfaces.container;

import ppl2.misc.arguments;
import ppl2.misc.lexer;
import ppl2.misc.misc_logging;
import ppl2.misc.mangle;
import ppl2.misc.node_builder;
import ppl2.misc.tasks;
import ppl2.misc.util;
import ppl2.misc.writer;

import ppl2.parse.parse_expression;
import ppl2.parse.parse_module;
import ppl2.parse.parse_named_struct;
import ppl2.parse.parse_statement;
import ppl2.parse.parse_type;
import ppl2.parse.parse_variable;

import ppl2.resolve.find_type;
import ppl2.resolve.resolve_call;
import ppl2.resolve.resolve_identifier;
import ppl2.resolve.resolve_module;

import ppl2.type.define;
import ppl2.type.type;
import ppl2.type.type_array;
import ppl2.type.type_basic;
import ppl2.type.type_function;
import ppl2.type.type_anon_struct;
import ppl2.type.type_named_struct;
import ppl2.type.type_ptr;

// Debug logging
void dd(A...)(A args) {
    import std.stdio : writef;
    foreach(a; args) {
        writef("%s ", a);
    }
    writefln("");
    flushConsole();
}
