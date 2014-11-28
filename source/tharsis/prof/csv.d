//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


/// CSV serialization.
module tharsis.prof.csv;


import tharsis.prof.ranges;

import std.algorithm;
import std.exception;
import std.format;
import std.range;
import std.typetuple;

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
    foreach(event; events) with(event)
    {
        if(!info.empty && !info.canFind!(c => ",\"".canFind(c)).assumeWontThrow)
        {
            output.formattedWrite("%s,%s,%s\n", id, time, info).assumeWontThrow;
            continue;
        }

        // info is at most ubyte.max long, will be quoted and in the worst case will be
        // doubled in size.
        char[ubyte.max * 2 + 2] quotedBuf;
        quotedBuf[0] = '"';
        size_t quotedSize = 1;
        // Only '"' is 'special' here, and it's ASCII so we can use ubyte[]
        foreach(ubyte c; cast(ubyte[])info)
        {
            quotedBuf[quotedSize++] = cast(char)c;
            // quotes must be doubled
            if(c == '"') { quotedBuf[quotedSize++] = '"'; }
        }
        quotedBuf[quotedSize++] = '"';
        output.formattedWrite("%s,%s,%s\n", id, time, quotedBuf[0 .. quotedSize])
              .assumeWontThrow;
    }
}
///
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
            Zone nested2 = Zone(profiler, "with\"quotes\"");
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
    // foreach(event; csvReader!Event(File("values.csv").byLine.joiner))
    foreach(original, parsed; lockstep(events, csvReader!Event(appender.data)))
    {
        assert(original == parsed);
        writeln(parsed);
    }
}

/// Determines if R is an output range of characters (of any character type).
enum bool isCharOutput(R) = isOutputRange!(R, char) ||
                            isOutputRange!(R, wchar) ||
                            isOutputRange!(R, dchar);

