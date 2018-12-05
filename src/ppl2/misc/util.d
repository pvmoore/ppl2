module ppl2.misc.util;

import ppl2.internal;
import std.conv : to;

/// filter!(..).frontOrNull!Thing()
T frontOrNull(T,Range)(Range r) {
    return cast(T)(r.empty ? null : r.front);
}
string toString(string[] array) {
    auto buf = appender!string;
    foreach(i, a; array) {
        if(i>0) buf ~= ",";
        buf ~= a;
    }
    return buf.data;
}
string escapeRegex(string s) {
    auto buf = appender!string;
    foreach(c; s) {
        switch(c) {
            case '[': case ']': case '{': case '}': case '<': case '>': case '*': case '-':
                buf ~= "\\";
                buf ~= c;
                break;
            default:
                buf ~= c;
                break;
        }
    }
    return buf.data;
}

bool isDigit(char c) {
    return c>='0' && c<='9';
}
bool isDigits(string s) {
    foreach(c; s) if(!isDigit(c)) return false;
    return true;
}
bool isHexDigits(string s) {
    foreach(c; s.toLower) {
        if(!isDigit(c) && c!='_' && (c<'a' || c>'f')) return false;
    }
    return true;
}
bool isBinaryDigits(string s) {
    foreach(c; s) if(c!='0' && c!='1' && c!='_') return false;
    return true;
}
long binaryToLong(string binary) {
    long total;
    foreach(c; binary) {
        if(c=='_') continue;
        int n = c-'0';
        total <<= 1;
        total |= n;
    }
    return total;
}
long hexToLong(string hex) {
    long total;
    foreach(c; hex.toLower) {
        if(c=='_') continue;
        int n;
        if(c>='0' && c<='9') n = c-'0';
        else n = (c-'a')+10;
        total <<= 4;
        total |= n;
    }
    return total;
}
/// f  \n  \x12 \u1234 \U12345678
int parseCharLiteral(string s) {
    if(s[0]=='\\') {
        switch(s[1]) {
            case '0' : return 0;
            case 'b' : return 8;
            case 't' : return 9;
            case 'n' : return 10;
            case 'f' : return 12;
            case 'r' : return 13;
            case '\"': return 34;
            case '\'': return 39;
            case '\\': return 92;
            case 'x' : return cast(uint)hexToLong(s[2..4]);
            case 'u' : return cast(uint)hexToLong(s[2..6]);
            //case 'U' : return cast(ulong)hexToLong(s[2..10]);
            default: return -1;
        }
    }
    return s[0];
}
From!"std.typecons".Tuple!(Type,string) parseNumberLiteral(string v) {
    import std.typecons : tuple;
    auto t = tuple(TYPE_UNKNOWN, v);
    assert(v.length>0);

    bool neg = (v[0]=='-');
    if(neg) v = v[1..$];

    if(v.length==1) {
        if(v[0].isDigit) t[0] = new BasicType(Type.INT);
    } else if(v=="true") {
        t[0] = TYPE_BOOL;
        t[1] = TRUE.to!string;
    } else if(v=="false") {
        t[0] = TYPE_BOOL;
        t[1] = FALSE.to!string;
    } else if(v[0]=='\'') {
        long l = parseCharLiteral(v[1..$-1]);
        t[0] = TYPE_INT;
        t[1] = l.to!string;
    } else if(v.endsWith("L")) {
        t[0] = new BasicType(Type.LONG);
        t[1] = v[0..$-1];
    } else if(v[0..2]=="0x") {
        v = v[2..$];
        if(v.length>0 && isHexDigits(v)) {
            long l = hexToLong(v);
            t[0] = new BasicType(getTypeOfLong(l));
            t[1] = l.to!string;
        }
    } else if(v[0..2]=="0b") {
        v = v[2..$];
        if (v.length>0 && isBinaryDigits(v)) {
            long l = binaryToLong(v);
            t[0] = new BasicType(getTypeOfLong(l));
            t[1] = l.to!string;
        }
    } else if(v.endsWith("h")) {
        string s = v[0..$-1];
        if (s.count('.')<2 &&
        s.removeChars('.').isDigits)
        {
            t[0] = new BasicType(Type.HALF);
            t[1] = s;
        }
    } else if(v.endsWith("d")) {
        string s = v[0..$-1];
        if(s.count('.')<2 &&
        s.removeChars('.').isDigits)
        {
            t[0] = new BasicType(Type.DOUBLE);
            t[1] = s;
        }
    } else if(v.endsWith("f")) {
        string s = v[0..$-1];
        if(s.count('.')<2 &&
           s.removeChars('.').isDigits)
        {
            t[0] = new BasicType(Type.FLOAT);
            t[1] = s;
        }
    } else if(v.count('.')==1) {        /// assume float if no type specified
        if(v.removeChars('.').isDigits) {
            t[0] = new BasicType(Type.FLOAT);
        }
    } else if(isDigits(v)) {
        long l = to!long(t[1]);
        t[0] = new BasicType(getTypeOfLong(l));
    } else {
        // not a number literal
    }
    return t;
}
int getTypeOfLong(long l) {
    //if(isByte(l)) return Type.BYTE;
    //if(isShort(l)) return Type.SHORT;
    if(isInt(l)) return Type.INT;
    return Type.LONG;
}
//bool isByte(long l) {
//    return l >= byte.min && l <= byte.max;
//}
//bool isShort(long l) {
//    return l >= short.min && l <= short.max;
//}
bool isInt(long l) {
    return l >= int.min && l <= int.max;
}

int calculateAggregateSize(Type[] types) {
    int offset  = 0;
    int largest = 1;

    foreach(t; types) {
        int align_    = t.alignment();
        int and       = (align_-1);
        int newOffset = (offset + and) & ~and;

        offset = newOffset + t.size;

        if(align_ > largest) largest = align_;
    }

    /// The final size must be a multiple of the largest alignment
    offset = (offset + (largest-1)) & ~(largest-1);

    return offset;
}