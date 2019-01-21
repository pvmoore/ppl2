module ide.internal;

public:

import core.thread : Thread;

import std.stdio  : writefln;
import std.format : format;
import std.array  : array, replace, appender;
import std.string : indexOf, lastIndexOf;
import std.datetime.stopwatch : StopWatch;

import std.algorithm.searching : any;
import std.algorithm.iteration : map;

import common : DynamicArray = Array, From, Set, StringBuffer;
import common : as, containsKey, endsWith, flushConsole, repeat, startsWith, toInt;
import dlangui;
import ppl2 = ppl2;

import ide.actions;
import ide.ide;
import ide.IDEConfig;
import ide.project;
import ide.util;

import ide.async_jobs.build;

import ide.editor.IRSyntaxSupport;
import ide.editor.P2SyntaxSupport;

import ide.usecases.BuildCompleted;

import ide.widgets.ASMView;
import ide.widgets.ASTView;
import ide.widgets.ConsoleView;
import ide.widgets.editortab;
import ide.widgets.editorview;
import ide.widgets.infoview;
import ide.widgets.IRView;
import ide.widgets.MyStatusLine;
import ide.widgets.projectview;
import ide.widgets.TokensView;

interface BuildListener {
    void buildSucceeded(ppl2.BuildState state);
    void buildFailed(ppl2.BuildState state);
}
