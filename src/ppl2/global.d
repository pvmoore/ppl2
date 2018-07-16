module ppl2.global;
/**
 *  Handle all global shared initialisation and storage.
 */
import ppl2.internal;
import std.stdio : File;

public:

const string VERSION = "2.0.0";

__gshared Config g_config;

__gshared int g_nodeid = 1;
__gshared int g_callableID = 1;

__gshared string g_mainModuleCanonicalName;
__gshared int g_mainModuleNID;

__gshared FileLogger g_logger;

__gshared Queue!Task g_taskQueue;
__gshared Set!string g_definesRequested;      /// key = moduleName|defineName
__gshared Set!string g_functionsRequested;  /// key = moduleName|funcName

__gshared Set!string g_uniqueFunctionNames;
__gshared Set!string g_uniqueStructNames;

__gshared int[string] g_builtinTypes;
__gshared string[int] g_typeToString;

__gshared Operator[TT] g_ttToOperator;

__gshared Token NO_TOKEN = Token(TT.NONE, null, -1, -1, -1);

__gshared Type TYPE_UNKNOWN = new BasicType(Type.UNKNOWN);
__gshared Type TYPE_BOOL    = new BasicType(Type.BOOL);
__gshared Type TYPE_BYTE    = new BasicType(Type.BYTE);
__gshared Type TYPE_INT     = new BasicType(Type.INT);
__gshared Type TYPE_LONG    = new BasicType(Type.LONG);
__gshared Type TYPE_VOID    = new BasicType(Type.VOID);

__gshared Callable CALLABLE_NOT_READY;

__gshared const TRUE  = -1;
__gshared const FALSE = 0;

shared static this() {
    g_logger = new FileLogger(".logs/log.log");
    g_taskQueue = new Queue!Task(1024);
    g_definesRequested = new Set!string;
    g_functionsRequested = new Set!string;
    g_uniqueFunctionNames = new Set!string;
    g_uniqueStructNames = new Set!string;

    g_builtinTypes["var"]    = Type.UNKNOWN;
    g_builtinTypes["bool"]   = Type.BOOL;
    g_builtinTypes["byte"]   = Type.BYTE;
    g_builtinTypes["short"]  = Type.SHORT;
    g_builtinTypes["int"]    = Type.INT;
    g_builtinTypes["long"]   = Type.LONG;
    g_builtinTypes["half"]   = Type.HALF;
    g_builtinTypes["float"]  = Type.FLOAT;
    g_builtinTypes["double"] = Type.DOUBLE;
    g_builtinTypes["void"]   = Type.VOID;

    g_typeToString[Type.UNKNOWN]      = "?type";
    g_typeToString[Type.BOOL]         = "bool";
    g_typeToString[Type.BYTE]         = "byte";
    g_typeToString[Type.SHORT]        = "short";
    g_typeToString[Type.INT]          = "int";
    g_typeToString[Type.LONG]         = "long";
    g_typeToString[Type.HALF]         = "half";
    g_typeToString[Type.FLOAT]        = "float";
    g_typeToString[Type.DOUBLE]       = "double";
    g_typeToString[Type.VOID]         = "void";
    g_typeToString[Type.ANON_STRUCT]  = "anon_struct";
    g_typeToString[Type.NAMED_STRUCT] = "named_struct";
    g_typeToString[Type.ARRAY]        = "array";
    g_typeToString[Type.FUNCTION]     = "function";

    // unary
    //ttOperator[NEG] =
    //g_ttToOperator[TT.BIT_NOT] = Operator.BIT_NOT;
    //g_ttToOperator[TT.BOOL_NOT] = Operator.BOOL_NOT;

    g_ttToOperator[TT.DIV] = Operator.DIV;
    g_ttToOperator[TT.ASTERISK] = Operator.MUL;
    g_ttToOperator[TT.PERCENT] = Operator.MOD;

    g_ttToOperator[TT.PLUS] = Operator.ADD;
    g_ttToOperator[TT.MINUS] = Operator.SUB;

    g_ttToOperator[TT.SHL] = Operator.SHL;
    g_ttToOperator[TT.SHR] = Operator.SHR;
    g_ttToOperator[TT.USHR] = Operator.USHR;

    g_ttToOperator[TT.LANGLE] = Operator.LT;
    g_ttToOperator[TT.RANGLE] = Operator.GT;
    g_ttToOperator[TT.LTE] = Operator.LTE;
    g_ttToOperator[TT.GTE] = Operator.GTE;

    g_ttToOperator[TT.BOOL_EQ] = Operator.BOOL_EQ;
    g_ttToOperator[TT.BOOL_NE] = Operator.BOOL_NE;

    g_ttToOperator[TT.AMPERSAND] = Operator.BIT_AND;
    g_ttToOperator[TT.HAT] = Operator.BIT_XOR;
    g_ttToOperator[TT.PIPE] = Operator.BIT_OR;

    //g_ttToOperator[TT.BOOL_AND] = Operator.BOOL_AND;
    //g_ttToOperator[TT.BOOL_OR] = Operator.BOOL_OR;

    g_ttToOperator[TT.ADD_ASSIGN] = Operator.ADD_ASSIGN;
    g_ttToOperator[TT.SUB_ASSIGN] = Operator.SUB_ASSIGN;
    g_ttToOperator[TT.MUL_ASSIGN] = Operator.MUL_ASSIGN;
    g_ttToOperator[TT.DIV_ASSIGN] = Operator.DIV_ASSIGN;
    g_ttToOperator[TT.MOD_ASSIGN] = Operator.MOD_ASSIGN;
    g_ttToOperator[TT.BIT_AND_ASSIGN] = Operator.BIT_AND_ASSIGN;
    g_ttToOperator[TT.BIT_XOR_ASSIGN] = Operator.BIT_XOR_ASSIGN;
    g_ttToOperator[TT.BIT_OR_ASSIGN] = Operator.BIT_OR_ASSIGN;
    g_ttToOperator[TT.SHL_ASSIGN] = Operator.SHL_ASSIGN;
    g_ttToOperator[TT.SHR_ASSIGN] = Operator.SHR_ASSIGN;
    g_ttToOperator[TT.USHR_ASSIGN] = Operator.USHR_ASSIGN;
    g_ttToOperator[TT.EQUALS] = Operator.ASSIGN;
}