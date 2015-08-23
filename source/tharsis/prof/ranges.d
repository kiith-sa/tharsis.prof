//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


/** Ranges used to process and analyze profiling results.
 *
 * Code examples can be found below.
 */
module tharsis.prof.ranges;

import std.algorithm;
import std.array;
import std.range;
import std.traits;

import tharsis.prof.event;
import tharsis.prof.profiler;

public import tharsis.prof.accumulatedzonerange;


/// Data about a zone generated by ZoneRange.
struct ZoneData
{
    /// ID of this zone.
    uint id;
    /// ID of the parent zone. 0 if the zone has no parent.
    uint parentID;
    /// Nesting level of the zone. 1 is top-level, 2 children of top-level, etc. 0 is invalid.
    ushort nestLevel = 0;
    /// Start time of the zone since recording started in hectonanoseconds.
    ulong startTime;
    /// Duration of the zone in hectonanoseconds.
    ulong duration;
    /// Zone _info (passed to the Zone constructor); e.g. it's name.
    const(char)[] info;

    /// Get the end time of the zone since recording started in hectonanoseconds.
    ulong endTime() @safe pure nothrow const @nogc { return startTime + duration; }
}


/** Construct a ZoneRange directly from profile data.
 *
 * Params:
 *
 * profileData = Profile data recorded by a Profiler. Note that modifying or concatenating
 *               raw profile data is unsafe unless you know what you're doing.
 *
 * Example:
 * --------------------
 * // Profiler profiler;
 *
 * // Create a ZoneRange from profile data with UFCS syntax.
 * auto zones = profiler.profileData.zoneRange;
 * foreach(zone; zones)
 * {
 *     import std.stdio;
 *     writeln(zone);
 * }
 * --------------------
 */
ZoneRange!EventRange zoneRange(const(ubyte)[] profileData) @safe pure nothrow @nogc
{
    return ZoneRange!EventRange(profileData.eventRange);
}

// Maximum stack depth of the zone stack. 640 nesting levels should be enough for everyone.
package enum maxStackDepth = 640;

// Information about a parent zone in ZoneRange's zone stack.
package struct ZoneInfo
{
    // Zone ID of the zone (to set parentID).
    uint id;
    // Start time of the zone since the recording started.
    ulong startTime;
    // Info string about the zone as passed to the Zone constructor.
    const(char)[] info;
}

/** Creates ZoneData from a parent zone info stack and end time.
 *
 * The ZInfo type must have all ZoneInfo members (e.g. by wrapping ZoneInfo with alias this).
 */
package ZoneData buildZoneData(ZInfo)(const(ZInfo)[] stack, ulong endTime)
    @safe pure nothrow @nogc
{
    const info = stack.back;
    ZoneData result;
    result.id        = info.id;
    result.parentID  = stack.length == 1 ? 0 : stack[$ - 2].id;
    // stack.length, not stack.length - 1. Top-level zones have a stack level of 1.
    result.nestLevel = cast(ushort)stack.length;
    result.startTime = info.startTime;
    result.duration  = endTime - result.startTime;
    result.info      = info.info;
    return result;
}


/** Variable together with its name and time of the variable event.
 *
 * Variable Event itself only stores variable type/value. It is followed by an info event
 * specifying variable name. VariableRange can be used to get NamedVariables from
 * profiling data.
 */
struct NamedVariable
{
    /// Variable name.
    const(char)[] name;
    /// Time when the variable event has occured.
    ulong time;

    /// Variable type and value (members directly accessible with alias this).
    Variable variable;
    alias variable this;
}

/** Construct a VariableRange directly from profile data.
 *
 * Params:
 *
 * profileData = Profile data recorded by a Profiler. Note that modifying or concatenating
 *               raw profile data is unsafe unless you know what you're doing.
 *
 * Example:
 * --------------------
 * // Profiler profiler;
 *
 * // Create a VariableRange from profile data with UFCS syntax.
 * auto variables = profiler.profileData.variableRange;
 * foreach(variable; variables)
 * {
 *     import std.stdio;
 *     writeln(variable);
 * }
 * --------------------
 */
VariableRange!EventRange variableRange(const(ubyte)[] profileData) @safe pure nothrow @nogc 
{
    return VariableRange!EventRange(profileData.eventRange);
}

/** Light-weight range that iterates over variables in profile data.
 *
 * Constructed from a ForwardRange of Event (e.g. EventRange or a std.algorithm wrapper
 * around an EventRange). Can also be constructed from raw profile data using
 * variableRange().
 *
 *
 * ForwardRange of NamedVariable ordered by $(I time). Doesn't allocate any heap memory.
 *
 * If profile data is incomplete (e.g. because the Profiler ran out of assigned memory in
 * the middle of profiling), the last recorded variable may be ignored.
 *
 * Ignores any variable events not followed by an info event (this may happen e.g. if a
 * Profiler runs out of memory when recording a variable event).
 */
struct VariableRange(ERange)
{
    static assert(isForwardRange!ERange && is(Unqual!(ElementType!ERange) == Event),
                  "ERange parameter of VariableRange must be a forward range of Event, "
                  " e.g. EventRange");
private:
    // Range to read profiling events from.
    ERange events_;

    // Time of the last encountered variable event. ulong.max means "uninitialized value".
    ulong variableTime_ = ulong.max;
    // Info (name) of the last encontered variable.
    const(char)[] variableInfo_;
    // Value of the last encountered variable.
    Variable variable_;

    static assert(isForwardRange!VariableRange, "VariableRange must be a forward range");
    static assert(is(Unqual!(ElementType!VariableRange) == NamedVariable),
                  "VariableRange must be a range of NamedVariable");

public:
    /** Construct a VariableRange processing events from a range of Events.
     *
     * Params:
     *
     * events = The event range to read from. VariableRange will create a (shallow) copy,
     *          and will not consume this range.
     */
    this(ERange events) @safe pure nothrow @nogc 
    {
        events_ = events.save;
        getToNextVariableEnd();
    }

    /// Get the current variable.
    NamedVariable front() @safe pure nothrow @nogc
    {
        assert(!empty, "Can't get front of an empty range");

        // Handling the case where we've run out of events_, but haven't popped the last
        // variable off the front yet.
        if(events_.empty)
        {
            assert(variableTime_ != ulong.max, "Non-empty VariableRange with empty "
                   "events_ must have non-default variableTime_");
            return NamedVariable(variableInfo_, variableTime_, variable_);
        }

        return NamedVariable(variableInfo_, variableTime_, variable_);
    }

    /// Go to the next variable.
    void popFront() @safe pure nothrow @nogc
    {
        assert(!empty, "Can't pop front of an empty range");
        // Pop the Info event reached by the last getToNextVariableEnd() call.
        assert(events_.front.id == EventID.Info, "Current event is not expected Info");
        events_.popFront();
        getToNextVariableEnd();
    }

    /// Are there no more variables?
    bool empty() @safe pure nothrow @nogc { return events_.empty; }

    // Must be a property, isForwardRange won't work otherwise.
    /// Get a copy of the range in its current state.
    @property VariableRange save() @safe pure nothrow const @nogc { return this; }

private:
    /* Processes events_ until an Info event after a VariableEvent, or the end of events_,
     * is reached.
     *
     * If we already are at such an Info event, stays there.
     *
     * Initializes variable_ with any read variable event, but only exits after reaching
     * an info event; any variable event not followed by an info event will be ignored.
     */
    void getToNextVariableEnd() @safe pure nothrow @nogc
    {
        for(; !events_.empty; events_.popFront())
        {
            const event = events_.front;

            with(EventID) final switch(event.id)
            {
                case Checkpoint, ZoneStart, ZoneEnd: break;
                case Variable:
                    variable_     = event.var;
                    variableTime_ = event.time;
                    variableInfo_ = null;
                    break;
                // If an info event has the same start time as the last variable, it's
                // info about that variable.
                case Info:
                    // The variableInfo_ == null check is necessary because we want
                    // the *first* info event that follows a variable event (there may be
                    // more info events with the same startTime).
                    if(variableInfo_ == null && event.time == variableTime_)
                    {
                        variableInfo_ = event.info;
                        return;
                    }
                    break;
            }
        }
    }
}
///
unittest
{
    // Print names and values of all recorded variables (once for each time they were
    // recorded).

    import tharsis.prof;

    auto storage  = new ubyte[Profiler.maxEventBytes + 2048];
    auto profiler = new Profiler(storage);

    // Simulate 16 'frames'
    foreach(frame; 0 .. 16)
    {
        Zone topLevel = Zone(profiler, "frame");

        topLevel.variableEvent!"frame"(cast(uint)frame);
        topLevel.variableEvent!"frame2"(cast(uint)frame);
        // Simulate frame overhead. Replace this with your frame code.
        {
            import std.random;
            const random = uniform(1.0f, 5.0f);
            import std.stdio;
            writeln(random);
            topLevel.variableEvent!"somethingRandom"(random);
            Zone nested1 = Zone(profiler, "frameStart");
            foreach(i; 0 .. 1000) { continue; }
        }
        {
            Zone nested2 = Zone(profiler, "frameCore");
            foreach(i; 0 .. 10000) { continue; }
        }
    }

    import std.algorithm;

    size_t i = 0;
    ulong lastTime = 0;
    // Write duration of each instance of the "frameCore" zone.
    foreach(var; profiler.profileData.variableRange)
    {
        assert(var.time >= lastTime);
        lastTime = var.time;

        if(i % 3 == 0)      { assert(var.name == "frame"); }
        else if(i % 3 == 1) { assert(var.name == "frame2"); }
        else if(i % 3 == 2) { assert(var.name == "somethingRandom"); }

        import std.stdio;
        writefln("%s: %s == %s", var.time, var.name, var.variable);
        ++i;
    }
}

/** Light-weight range that iterates over zones in profile data.
 *
 * Constructed from a ForwardRange of Event (e.g. EventRange or a std.algorithm wrapper
 * around an EventRange). Can also be constructed from raw profile data using eventRange().
 *
 *
 * ForwardRange of ZoneData ordered by $(I end time).
 * Doesn't allocate any heap memory.
 *
 *
 * If profile data is incomplete (e.g. because the Profiler ran out of assigned memory in
 * the middle of profiling), zones that don't have zone end events will be automatically
 * ended at the time of the last recorded event.
 *
 * Note:
 *
 * ZoneRange only supports zone nesting up to ZoneRange.zoneStack nesting levels
 * (currently this is 640, which should be enough for everyone, may be increased in future).
 */
struct ZoneRange(ERange)
{
    static assert(isForwardRange!ERange && is(Unqual!(ElementType!ERange) == Event),
                  "ERange parameter of ZoneRange must be a forward range of Event, e.g. "
                  "EventRange");

private:
    // Range to read profiling events from.
    ERange events_;

    // Stack of ZoneInfo describing the current zone and all its parents.
    //
    // The current zone can be found at zoneStack_[zoneStackDepth_ - 1], its parent
    // at zoneStack_[zoneStackDepth_ - 2], etc.
    ZoneInfo[maxStackDepth] zoneStack_;

    // Depth of the zone stack at the moment.
    size_t zoneStackDepth_ = 0;

    // ID of the next zone.
    uint nextID_ = 1;

    // startTime of the last processed event.
    ulong lastEventTime_ = 0;

    static assert(isForwardRange!ZoneRange, "ZoneRange must be a forward range");
    static assert(is(Unqual!(ElementType!ZoneRange) == ZoneData),
                  "ZoneRange must be a range of ZoneData");

public:
    /** Construct a ZoneRange processing events from a range of Events (e.g. EventRange).
     *
     * Params:
     *
     * events = The event range to read from. ZoneRange will create a (shallow) copy,
     *          and will not consume this range.
     */
    this(ERange events) @safe pure nothrow @nogc { events_ = events.save; }

    /// Get the current zone.
    ZoneData front() @safe pure nothrow @nogc
    {
        assert(!empty, "Can't get front of an empty range");

        // Since profiling can stop at any moment due to running out of assigned memory,
        // we need to handle the space where we don't have zone end events for all zones.
        if(events_.empty)
        {
            assert(zoneStackDepth_ > 0, "if events_ are empty, something must be in the stack");
            return buildZoneData(zoneStack_[0 .. zoneStackDepth_], lastEventTime_);
        }

        getToNextZoneEnd();
        // getToNextZoneEnd can only consume all events if we're empty (no more ZoneEnd
        // - if there was a ZoneEnd, getToNextZoneEnd() would stop at the ZoneEnd without
        // making events_ empty.
        // However, the above assert checks that we're not empty, and the above if()
        // handles the case where events_ is empty before getToNextZoneEnd().
        // So, events_ must not be empty here.
        assert(!events_.empty, "ZoneRange empty despite assert at the top of function");
        assert(events_.front.id == EventID.ZoneEnd, "getToNextZoneEnd got to a non-end event");
        return buildZoneData(zoneStack_[0 .. zoneStackDepth_], lastEventTime_);
    }

    /// Go to the next zone.
    void popFront() @safe pure nothrow @nogc
    {
        assert(!empty, "Can't pop front of an empty range");

        // Since profiling can stop at any moment due to running out of assigned memory,
        // we need to handle the case where we don't have zone end events for all zones.
        if(events_.empty)
        {
            assert(zoneStackDepth_ > 0,
                   "non-empty ZoneRange with empty events_ must have non-zero zoneStackDepth_");
        }
        // Pop the ZoneEnd event reached by getToNextZoneEnd() in last range operation.
        else if(events_.front.id == EventID.ZoneEnd)
        {
            events_.popFront();
        }
        --zoneStackDepth_;
    }

    /// Are there no more zones?
    bool empty() @safe pure nothrow @nogc
    {
        // Must call this; otherwise, if there are no zone events in the entire range,
        // this would still return true as long as events_ is empty.
        getToNextZoneEnd();
        return events_.empty && zoneStackDepth_ == 0;
    }

    // Must be a property, isForwardRange won't work otherwise.
    /// Get a copy of the range in its current state.
    @property ZoneRange save() @safe pure nothrow const @nogc { return this; }

private:
    /* Processes events_ until a ZoneEnd event or the end of events_ is reached.
     *
     * If we already are at such an ZoneEnd event, stays there.
     *
     * Adds any ZoneStart events to the stack.
     */
    void getToNextZoneEnd() @safe pure nothrow @nogc
    {
        for(; !events_.empty; events_.popFront())
        {
            const event = events_.front;
            lastEventTime_ = event.time;

            with(EventID) final switch(event.id)
            {
                case Checkpoint: break;
                case Variable: break;
                case ZoneStart:
                    assert(zoneStackDepth_ < maxStackDepth,
                           "Zone nesting too deep; zone stack overflow.");
                    zoneStack_[zoneStackDepth_++] = ZoneInfo(nextID_++, lastEventTime_, null);
                    break;
                case ZoneEnd: return;
                // If an info event has the same start time as the current zone, it's info
                // about the current zone.
                case Info:
                    auto curZone = &zoneStack_[zoneStackDepth_ - 1];
                    // The curZone.info == null check is necessary because we want the
                    // *first* info event that follows a zone event (there may be more
                    // info events with the same startTime, e.g. after a variable event
                    // following the zone start event)
                    if(curZone.info == null && event.time == curZone.startTime)
                    {
                        curZone.info = event.info;
                    }
                    break;
            }
        }
    }
}
///
unittest
{
    // Filter zones based on the info string. Useful to determine durations of only
    // certain zones.

    import tharsis.prof;

    auto storage  = new ubyte[Profiler.maxEventBytes + 2048];
    auto profiler = new Profiler(storage);

    // Simulate 16 'frames'
    foreach(frame; 0 .. 16)
    {
        Zone topLevel = Zone(profiler, "frame");

        // Simulate frame overhead. Replace this with your frame code.
        {
            Zone nested1 = Zone(profiler, "frameStart");
            foreach(i; 0 .. 1000) { continue; }
        }
        {
            Zone nested2 = Zone(profiler, "frameCore");
            foreach(i; 0 .. 10000) { continue; }
        }
    }

    import std.algorithm;
    // Write duration of each instance of the "frameCore" zone.
    foreach(zone; profiler.profileData.zoneRange.filter!(z => z.info == "frameCore"))
    {
        import std.stdio;
        writeln(zone.duration);
    }
}
///
unittest
{
    // Sort top-level zones by duration. If there is one top-level zone per frame, this
    // sorts frames by duration: useful to get the worst-case frames.

    // This example also uses C malloc/free and std.typecons.scoped 
    // to show how to do this without using the GC.

    import tharsis.prof;

    const storageLength = Profiler.maxEventBytes + 1024 * 1024 * 2;

    import core.stdc.stdlib;
    // A simple typed-slice malloc wrapper function would avoid the ugly cast/slicing.
    ubyte[] storage  = (cast(ubyte*)malloc(storageLength))[0 .. storageLength];
    scope(exit) { free(storage.ptr); }

    import std.typecons;
    auto profiler = scoped!Profiler(storage);

    // std.typecons.scoped! stores the Profiler on the stack.
    // Simulate 16 'frames'
    foreach(frame; 0 .. 16)
    {
        Zone topLevel = Zone(profiler, "frame");

        // Simulate frame overhead. Replace this with your frame code.
        {
            Zone nested1 = Zone(profiler, "frameStart");
            foreach(i; 0 .. 1000) { continue; }
        }
        {
            Zone nested2 = Zone(profiler, "frameCore");
            foreach(i; 0 .. 10000) { continue; }
        }
    }

    import std.algorithm;
    auto zones = profiler.profileData.zoneRange;

    // nestLevel of 1 is toplevel.
    auto topLevel = zones.filter!(z => z.nestLevel == 1);

    const size_t topLevelLength = zones.walkLength;
    //TODO replace with std.allocator, or better, new containers once added to Phobos
    ZoneData[] topLevelArray = (cast(ZoneData*)malloc(topLevelLength * ZoneData.sizeof))[0 .. topLevelLength];
    scope(exit) { free(topLevelArray.ptr); }

    topLevel.copy(topLevelArray);
    topLevelArray.sort!((a, b) => a.duration > b.duration);
    import std.stdio;
    // Print the 4 longest frames.
    foreach(frame; topLevelArray[0 .. 4])
    {
        writeln(frame);
    }

    auto worst = topLevelArray[0];

    /* Code based on std.container.array.Array: broken due to DMD 2.068 changes.
     * Getting obsolete anyway, as containers are finally being redesigned by Andrei Alexandrescu.
    import std.container;
    // std.container.Array constructor builds an RAII array containing zones from topLevel.
    // We need an array as we need random access to sort the zones (ZoneRange generates
    // ZoneData on-the-fly as it processes profiling data, so it has no random access).
    auto topLevelArray = Array!ZoneData(topLevel);
    topLevelArray[].sort!((a, b) => a.duration > b.duration);

    import std.stdio;
    // Print the 4 longest frames.
    foreach(frame; topLevelArray[0 .. 4])
    {
        writeln(frame);
    }

    auto worst = topLevelArray[0];
    */

    // Print details about all zones in the worst frame.
    writeln("Zones in the worst frame:");
    foreach(zone; zones.filter!(z => z.startTime >= worst.startTime && z.endTime <= worst.endTime))
    {
        writefln("%s: %s hnsecs from %s to %s",
                 zone.info, zone.duration, zone.startTime, zone.endTime);
    }
}


/** Construct an EventRange directly from profile data.
 *
 * ForwardRange of Event.
 *
 * Params:
 *
 * profileData = Profile data recorded by a Profiler. Note that modifying or concatenating
 *               profile data is unsafe unless you know what you're doing.
 * Example:
 * --------------------
 * // Profiler profiler;
 *
 * // Create an EventRange from profile data with UFCS syntax.
 * auto events = profiler.profileData.eventRange;
 * foreach(event; events)
 * {
 *     import std.stdio;
 *     writeln(event);
 * }
 * --------------------
 */
EventRange eventRange(const(ubyte)[] profileData) @safe pure nothrow @nogc
{
    return EventRange(profileData);
}

/** Light-weight type-safe range that iterates over events in profile data.
 *
 * EventRange is a 'low-level' range to base other ranges or structures (such as
 * ZoneRange) on top of.
 *
 * Doesn't allocate any heap memory.
 */
struct EventRange
{
private:
    /// Raw profile data recorded by a Profiler.
    const(ubyte)[] profileData_;

    static assert(isForwardRange!EventRange, "EventRange must be a forward range");
    static assert(is(Unqual!(ElementType!EventRange) == Event),
                    "EventRange must be a range of Event");

    // If empty_ is false, this is the event at the front of the range.
    //
    // front_.time is incrementally increased with each readEvent() call instead of
    // clearing front_ completely.
    Event front_;

    // Is the range empty (last event has been popped)?
    bool empty_;

public:
@safe pure nothrow @nogc:
    /** Construct an EventRange.
     *
     * Params:
     *
     * profileData = Profile data recorded by a Profiler. Note that modifying or
     *               concatenating raw profile data is unsafe unless you know what you're
     *               doing.
     */
    this(const(ubyte)[] profileData)
    {
        profileData_ = profileData;
        empty_ = profileData_.empty;
        if(!empty_) { readEvent(); }
    }

    /// Get the current event.
    Event front() const
    {
        assert(!empty, "Can't get front of an empty range");
        return front_;
    }

    /// Move to the next event.
    void popFront()
    {
        assert(!empty, "Can't pop front of an empty range");
        // unoptimized // empty_ = profileData_.empty;
        empty_ = profileData_.length == 0;
        if(!empty_) { readEvent(); }
    }

    /// Are there no more events?
    bool empty() const { return empty_; }

    // Must be a property, isForwardRange won't work otherwise.
    /// Get a copy of the range in its current state.
    @property EventRange save() const { return this; }

package:
    /** Get the number of remaining bytes in the underlying profile data.
     *
     * Used by code in tharsis.prof package to determine end position of an event in
     * profile data without increasing memory overhead of EventRange.
     */
    size_t bytesLeft() @safe pure nothrow const @nogc
    {
        return profileData_.length;
    }

private:
    /* Read the next event from profile data.
     *
     * Called from constructor and popFront() to update front_.
     */
    void readEvent()
    {
        // Store on the stack for fast access.
        const(ubyte)[] profileData = profileData_;
        scope(exit) { profileData_ = profileData; }
        assert(!profileData.empty, "Trying to read an event from empty profile data");

        front_.id = cast(EventID)(profileData[0] & eventIDMask);
        // Assert validity of the profile data.
        debug
        {
            bool found = allEventIDs.canFind(front_.id);
            assert(found, "Invalid profiling data; expected event ID but got something else");
        }

        const timeBytes = profileData[0] >> eventIDBits;
        profileData = profileData[1 .. $];

        assert(profileData.length >= timeBytes,
               "Invalid profiling data; not long enough to store expected time gap bytes");

        // Parses 'time bytes' each encoding 7 bits of a time span value
        void parseTimeBytes(uint count) nothrow @nogc
        {
            assert(count <= 8, "Time byte count can't be more than 8 bytes");

            import std.typetuple;
            // This unrolls the loop at compile-time (for performance).
            foreach(b; TypeTuple!(0, 1, 2, 3, 4, 5, 6, 7, 8, 9))
            {
                // 7 is the maximum for time gap, but 8 is used for checkpoints
                static if(b == 9)
                {
                    assert(false, "Time durations over 128 * 228 years not supported");
                }
                else
                {
                    if(count--)
                    {
                        enum bitOffset = b * timeByteBits;
                        assert(profileData[0] != 0, "Time bytes must not be 0");
                        front_.time += cast(ulong)(profileData[0] & timeByteMask) << bitOffset;
                        profileData = profileData[1 .. $];
                    }
                    else
                    {
                        return;
                    }
                }
            }
        }

        parseTimeBytes(timeBytes);
        front_.info_ = null;

        with(EventID) switch(front_.id)
        {
            case ZoneStart, ZoneEnd: return;
            case Checkpoint:
                // A checkpoint contains absolute start time.
                // This is not really necessary ATM, (relative time would get us the same
                // result as this code), but allow 'disjoint' checkpoints that change the
                // 'current time' in future.
                front_.time = 0;
                parseTimeBytes(checkpointByteCount);
                break;
            // Info is followed by an info string.
            case Info:
                assert(profileData.length != 0,
                       "Invalid profiling data: info event not followed by string length");
                const infoBytes = profileData[0];
                profileData = profileData[1 .. $];
                front_.info_ = cast(const(char)[])profileData[0 .. infoBytes];

                assert(profileData.length >= infoBytes,
                       "Invalid profiling data: info event not followed by info string");
                profileData = profileData[infoBytes .. $];
                return;
            // Variable is followed by variable type and 7-bit encoded value.
            case Variable:
                const ubyte type = profileData[0];
                profileData = profileData[1 .. $];
                bool knownType = allVariableTypes.canFind(type);
                assert(knownType, "Variable event has unknown type");
                front_.var_.type_ = cast(VariableType)type;

                // Decode a 7-bit variable value at the front of profileData.
                V decode(V)() @trusted nothrow @nogc
                {
                    enum VType = variableType!V;
                    enum encBytes = variable7BitLengths[VType];
                    ubyte[encBytes] encoded = profileData[0 .. encBytes];
                    V[1] decoded;
                    decode7Bit(encoded, cast(ubyte[])(decoded[]));
                    profileData = profileData[encBytes .. $];

                    import std.system;
                    if(std.system.endian != Endian.bigEndian)
                    {
                        import tinyendian;
                        swapByteOrder(decoded[]);
                    }
                    return decoded[0];
                }

                final switch(front_.var_.type_)
                {
                    case VariableType.Int:   front_.var_.int_   = decode!int;   break;
                    case VariableType.Uint:  front_.var_.uint_  = decode!uint;  break;
                    case VariableType.Float: front_.var_.float_ = decode!float; break;
                }
                return;
            default: assert(false, "Unknown event ID");
        }


        // // Unoptimized version:
        //
        // assert(!profileData_.empty, "Trying to read an event from empty profile data");
        //
        // // un-optimized // front_.id = cast(EventID)(profileData_.front & eventIDMask);
        // front_.id = cast(EventID)(profileData_[0] & eventIDMask);
        // // Assert validity of the profile data.
        // debug
        // {
        //     bool found = allEventIDs.canFind(front_.id);
        //     assert(found, "Invalid profiling data; expected event ID but got something else");
        // }
        //
        // // un-optimized // const timeBytes = profileData_.front >> eventIDBits;
        // const timeBytes = profileData_.front >> eventIDBits;
        // // un-optimized // profileData_.popFront();
        // profileData_ = profileData[1 .. $];
        //
        // assert(profileData_.length >= timeBytes,
        //        "Invalid profiling data; not long enough to store expected time gap bytes");
        //
        // // Parses 'time bytes' each encoding 7 bits of a time span value
        // void parseTimeBytes(uint count) nothrow @nogc
        // {
        //     assert(count <= 8, "Time byte count can't be more than 8 bytes");
        //     foreach(b; 0 .. count)
        //     {
        //         assert(profileData_.front != 0, "Time bytes must not be 0");
        //         front_.time += cast(ulong)(profileData_.front() & timeByteMask)
        //                        << (b * timeByteBits);
        //         profileData_.popFront();
        //     }
        // }
        //
        // parseTimeBytes(timeBytes);
        // front_.info_ = null;
        //
        // with(EventID) switch(front_.id)
        // {
        //     case ZoneStart, ZoneEnd: return;
        //     case Checkpoint:
        //         // A checkpoint contains absolute start time.
        //         // This is not really necessary ATM, (relative time would get us the same
        //         // result as this code), but allow 'disjoint' checkpoints that change the
        //         // 'current time' in future.
        //         front_.time = 0;
        //         parseTimeBytes(checkpointByteCount);
        //         break;
        //     // Info is followed by an info string.
        //     case Info:
        //         assert(!profileData_.empty,
        //                "Invalid profiling data: info event not followed by string length");
        //         const infoBytes = profileData_.front;
        //         profileData_.popFront;
        //         front_.info_ = cast(const(char)[])profileData_[0 .. infoBytes];
        //
        //         assert(profileData_.length >= infoBytes,
        //                "Invalid profiling data: info event not followed by info string");
        //         profileData_ = profileData_[infoBytes .. $];
        //         return;
        //     // Variable is followed by variable type and 7-bit encoded value.
        //     case Variable:
        //         const ubyte type = profileData_.front;
        //         profileData_.popFront();
        //         bool knownType = allVariableTypes.canFind(type);
        //         assert(knownType, "Variable event has unknown type");
        //         front_.var_.type_ = cast(VariableType)type;
        //
        //         // Decode a 7-bit variable value at the front of profileData_.
        //         V decode(V)() @trusted pure nothrow @nogc
        //         {
        //             enum VType = variableType!V;
        //             enum encBytes = variable7BitLengths[VType];
        //             ubyte[encBytes] encoded = profileData_[0 .. encBytes];
        //             V[1] decoded;
        //             decode7Bit(encoded, cast(ubyte[])(decoded[]));
        //             profileData_ = profileData_[encBytes .. $];
        //
        //             import std.system;
        //             if(std.system.endian != Endian.bigEndian)
        //             {
        //                 import tinyendian;
        //                 swapByteOrder(decoded[]);
        //             }
        //             return decoded[0];
        //         }
        //
        //         final switch(front_.var_.type_)
        //         {
        //             case VariableType.Int:   front_.var_.int_   = decode!int;   break;
        //             case VariableType.Uint:  front_.var_.uint_  = decode!uint;  break;
        //             case VariableType.Float: front_.var_.float_ = decode!float; break;
        //         }
        //         return;
        //     default: assert(false, "Unknown event ID");
        // }
    }
}
///
unittest
{
    // Filter zones based on the info string. Useful to determine durations of only
    // certain zones.

    import tharsis.prof;

    auto storage  = new ubyte[Profiler.maxEventBytes + 2048];
    auto profiler = new Profiler(storage);

    // Simulate 8 'frames'
    foreach(frame; 0 .. 8)
    {
        Zone topLevel = Zone(profiler, "frame");

        // Simulate frame overhead. Replace this with your frame code.
        {
            Zone nested1 = Zone(profiler, "frameStart");
            foreach(i; 0 .. 1000) { continue; }
        }
        {
            Zone nested2 = Zone(profiler, "frameCore");
            foreach(i; 0 .. 10000) { continue; }
        }
    }

    import std.stdio;
    // Create an EventRange from profile data with UFCS syntax.
    auto events = profiler.profileData.eventRange;
    // Foreach over range calls popFront()/front()/empty() internally
    foreach(event; events)
    {
        writeln(event);
    }

    // Get a range of only the events with start time between 1000 and 5000 (hectonanoseconds)
    //
    // This doesn't filter anything or allocate; filtering only happens once the
    // range is iterated over (but if we did want to do the filtering right now, e.g. to
    // get an array of filtered results, we'd suffix this with ".array")
    auto filtered = events.filter!(e => e.time > 1500 && e.time < 2000);
    // Here, we print the IDs of events between 10000 and 50000 hectonanoseconds
    foreach(id; filtered.map!(e => e.id))
    {
        writeln(id);
    }

    // And here we count the number of events between 1000 and 5000
    writeln(filtered.count);
}
