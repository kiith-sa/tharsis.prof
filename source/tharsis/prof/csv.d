//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


/// CSV serialization.
module tharsis.prof.csv;


import std.algorithm;
import std.exception;
import std.format;
import std.range;
import std.typetuple;

import tharsis.prof.event;
import tharsis.prof.profiler;
import tharsis.prof.ranges;


/** Write Events from a range to CSV.
 *
 * Params:
 *
 * events = An InputRange of Events to write to CSV.
 * output = An OutputRange of characters to write to.
 *          Example output ranges: Appender!string or std.stdio.File.lockingTextWriter.
 *
 * No heap memory will be allocated $(B if) output does not allocate.
 *
 * Throws:
 *
 * Whatever (if anything) output throws on failure to write more data to it.
 */
void writeCSVTo(ERange, ORange)(ERange events, ORange output)
    @trusted
    if(isInputRange!ERange && is(ElementType!ERange == Event) && isCharOutput!ORange)
{
    outer: foreach(event; events) with(event)
    {
        output.formattedWrite("%s,%s,", id, time).assumeWontThrow;

        final switch(id)
        {
            case EventID.Checkpoint, EventID.ZoneStart, EventID.ZoneEnd:
                output.formattedWrite("\"\"\n");
                break;
            case EventID.Info:
                if(!info.empty && !info.canFind!(c => ",\"".canFind(c)).assumeWontThrow)
                {
                    output.formattedWrite("%s\n", info).assumeWontThrow;
                    continue outer;
                }

                // info is at most ubyte.max long, will be quoted and in the worst case
                // will be doubled in size.
                ubyte[ubyte.max * 2 + 2] quotedBuf;
                quotedBuf[0] = '"';
                size_t quotedSize = 1;
                // Only '"' is 'special' here, and it's ASCII so we can use ubyte[]
                foreach(ubyte c; cast(ubyte[])info)
                {
                    quotedBuf[quotedSize++] = c;
                    // quotes must be doubled
                    if(c == '"') { quotedBuf[quotedSize++] = '"'; }
                }
                quotedBuf[quotedSize++] = '"';
                output.formattedWrite("%s\n", cast(char[])quotedBuf[0 .. quotedSize])
                      .assumeWontThrow;
                break;
            case EventID.Variable:
                output.formattedWrite("%s:", var.type);
                final switch(var.type)
                {
                    case VariableType.Int:   output.formattedWrite("%s\n", var.varInt);   break;
                    case VariableType.Uint:  output.formattedWrite("%s\n", var.varUint);  break;
                    case VariableType.Float: output.formattedWrite("%s\n", var.varFloat); break;
                }
                break;
        }
    }
}

/// Get a CSVEventRange parsing character data from input.
auto csvEventRange(Range)(Range input) nothrow
{
    return CSVEventRange!Range(input);
}

/** A range that parses CSV data from a character range (string, file, etc.) and lazily
 * generates Events.
 *
 * front() and popFront() may throw ConvException or CSVException.
 */
struct CSVEventRange(Range)
{
private:
    import std.traits;
    import std.csv;

    // The CSV reader type to use.
    alias CSV = ReturnType!(csvReader!(CSVEvent, Malformed.throwException, Range));

    // The CSV we're reading events from.
    CSV csv_;

    // Representation of an Event in CSV.
    struct CSVEvent
    {
        /// Event.id .
        EventID id;
        /// Event.time .
        ulong time;
        /// The union in Event.
        string typeSpecific;
    }

    // No default constructor (need to read from a char range).
    @disable this();

    // Construct a CSVEventRange parsing from specified character range.
    this(Range input) nothrow
    {
        csv_ = csvReader!CSVEvent(input).assumeWontThrow;
    }

public:
    /** Get the current event.
     *
     * Throws:
     *
     * ConvException on a failure to parse a value stored in the CSV.
     * CSVException on a CSV format error.
     */
    Event front() @trusted pure
    {
        assert(!empty, "Can't get front of an empty range");
        CSVEvent csvEvent = csv_.front();
        auto event = Event(csvEvent.id, csvEvent.time);
        final switch(event.id) with(EventID)
        {
            case Checkpoint, ZoneStart, ZoneEnd: event.info_ = null;
                break;
            case Info:
                event.info_ = csvEvent.typeSpecific;
                break;
            case Variable:
                import std.conv: to;
                auto parts = csvEvent.typeSpecific.splitter(":");
                event.var_.type_ = to!VariableType(parts.front);
                parts.popFront();
                final switch(event.var_.type_) with(VariableType)
                {
                    case Int:   event.var_.int_   = parts.front.to!int;   break;
                    case Uint:  event.var_.uint_  = parts.front.to!uint;  break;
                    case Float: event.var_.float_ = parts.front.to!float; break;
                }
                break;
        }
        return event;
    }

    /** Move to the next event in the range.
     *
     * Throws:
     *
     * CSVException on a CSV format error.
     */
    void popFront() @trusted
    {
        assert(!empty, "Can't pop front of an empty range");
        csv_.popFront();
    }

    /// Is the range empty (no more events)?
    bool empty() @safe pure nothrow @nogc { return csv_.empty; }
}
unittest
{
    import tharsis.prof;

    auto storage  = new ubyte[Profiler.maxEventBytes + 2048];
    auto profiler = new Profiler(storage);

    // Simulate 2 'frames'
    foreach(frame; 0 .. 2)
    {
        Zone topLevel = Zone(profiler, "frame");

        // Simulate frame overhead. Replace this with your frame code.
        {
            Zone nested1 = Zone(profiler, "with,comma");
            foreach(i; 0 .. 1000) { continue; }
        }
        {
            Zone nested2 = Zone(profiler, "with\"quotes\" and\nnewline");
            nested2.variableEvent!"float 3.14"(3.14f);
            nested2.variableEvent!"float 10.1"(10.1f);
            nested2.variableEvent!"int without comma"(314);
            foreach(i; 0 .. 10000) { continue; }
        }
    }

    import std.stdio;
    writeln("Tharsis.prof CSV writing example");
    // Create an EventRange from profile data with UFCS syntax.
    auto events = profiler.profileData.eventRange;

    import std.array;
    auto appender = appender!string();

    events.writeCSVTo(appender);

    writeln(appender.data);

    writeln("Tharsis.prof CSV parsing example");
    import std.csv;
    import std.range;

    // Parse the CSV back into events.
    //
    // Direct file input could work like this (it might be faster to load the entire file
    // to a buffer, though):
    //
    // import std.algorithm
    // foreach(event; csvEventRange(File("values.csv").byLine.joiner))
    foreach(original, parsed; lockstep(events, csvEventRange(appender.data)))
    {
        import std.conv: to;
        assert(original == parsed,
               original.to!string ~ "\n does not match\n" ~ parsed.to!string);
        writeln(parsed);
    }
}

/// Determines if R is an output range of characters (of any character type).
enum bool isCharOutput(R) = isOutputRange!(R, char) ||
                            isOutputRange!(R, wchar) ||
                            isOutputRange!(R, dchar);

