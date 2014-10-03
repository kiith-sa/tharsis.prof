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

import tharsis.prof.profiler;



/// Profiling event generated by EventRange.
struct Event
{
    /// Event ID or type.
    EventID id;
    /// Start time of the event since recording started in hectonanoseconds.
    ulong startTime;
    /// Information string if id == $(D EventID.Info) .
    const(char)[] info;
}

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


/** Data accumulated from multiple matching zones, generated by $(D
 *  accumulatedZoneRange()).
 *
 * Extends $(D ZoneData) (derived using alias this) with a value returned by the $(D
 * accumulate) function parameter of $(D accumulatedZoneRange()).
 *
 * Durations and start times of accumulated zones are summed into $(D zoneData.duration)
 * and $(D zoneData.startTime). $(D id), $(D parentID) and $(D nestLevel) are updated so
 * the elements of $(D accumulatedZoneRange) can still form trees just like elements of 
 * the $(D ZoneRange) that was accumulated.
 */
struct AccumulatedZoneData(alias accumulate)
{
    /// The 'base' ZoneData; startTime and duration are sums of accumulated ZoneData values.
    ZoneData zoneData;
    alias zoneData this;

    /// The value accumulated by the accumulate function.
    ReturnType!accumulate accumulated;
}


/// Default match function for accumulatedZoneRange(). Compares ZoneData infos for equality.
bool defaultMatch(const(char)[] info1, const(char)[] info2) @safe pure nothrow @nogc
{
    return info1 == info2;
}

/** Returns a range that accumulates (merges) matching zones from one or more zone ranges.
 *
 * On each nesting level from top to bottom, finds zones that are $(B match) based on
 * given match function and merges them into one zone, $(B accumulating) data from merged
 * zone using the accumulate function. Merged zones contain summed durations and start
 * times. The default match function compares info strings of two zones for equality.
 *
 *
 * This is useful for example to get a 'total' of all frames elapsed while the profiler
 * was running. If each frame has one top-level zone and they have matching info strings,
 * the top-level zones will be merged, then all zones within those top-level zones, and so
 * on. The result will be a zone range representing a single tree. The accumulate function
 * could be used, for example, to calculate the maximum duration of matching zones to
 * calculate a 'worst case frame scenario', or to calculate the number of times each zone
 * was entered, or even multiple things at the same time.
 *
 * Params:
 *
 * accumulate = A function alias that takes a pointer to the value accumulated so far, and
 *              the next ZoneData to accumulate. It returns the resulting accumulated
 *              value. The first parameter will be null on the first call.
 *
 *              Must be $(D pure nothrow @nogc).
 *
 * match      = A function alias that takes two const(char) arrays and returns a bool.
 *              If true is returned, two zones with whose info strings were passed to
 *              match() are considered the same zone and will be merged and accumulated.
 *
 *              Must be $(D pure nothrow @nogc).
 *
 *              An example use-case for a custom match() function is to accumulate related
 *              zones that have a slightly different names (e.g. numbered draw batches),
 *              or on the other hand, to prevent merging zones with identical names
 *              (e.g. to see each individual draw as a separate zone).
 *
 * storage    = Array to use for temporary storage during accumulation $(B as well as)
 *              storage in the returned range. Must be long enough to hold zones from all
 *              passed zone ranges, i.e. the sum of their walkLengths. To determine this
 *              length, use $(D import std.range; zoneRange.walkLength;).
 * zones      = One or more zone ranges to accumulate.
 *
 * Returns: A ForwardRange of AccumulatedZoneData. Each element contails ZoneData plus the
 *          return value of the accumulate function.
 *
 * Note: The current implementation is likely to be slow for large inputs. It's probably
 *       too slow for real-time usage except if the inputs are very small.
 *
 * Example of an $(D accumulate) function:
 * --------------------
 * // Increments the accumulated value when called. Useful to determine the
 * // number of times a Zone was entered.
 * size_t accum(size_t* aPtr, ref const ZoneData z) pure nothrow @nogc
 * {
 *     return aPtr is null ? 1 : *aPtr + 1;
 * }
 * --------------------
 */
auto accumulatedZoneRange(alias accumulate, alias match = defaultMatch, ZRange)
                         (AccumulatedZoneData!accumulate[] storage, ZRange[] zones...)
    @trusted pure nothrow @nogc
{
    static assert(isForwardRange!ZRange && is(Unqual!(ElementType!ZRange) == ZoneData),
                  "ZRange parameter of accumulatedZoneRange must be a forward range of "
                  "ZoneData, e.g. ZoneRange");
    debug
    {
        size_t zoneCount;
        foreach(ref zoneRange; zones) { zoneCount += zoneRange.save.walkLength; }

        assert(storage.length >= zoneCount,
               "storage param of accumulatedZoneRange must be long enough to hold zones "
               "from all passed zone ranges");
    }
    alias AccumulatedZone = AccumulatedZoneData!accumulate;

    // Range returned by this function.
    // Just a restricted array at the moment, but we can change it if we need to.
    struct Range
    {
    private:
        // Array storing the accumulated results. Slice of $(D storage) passed to
        // accumulatedZoneRange
        const(AccumulatedZone)[] array;

        static assert(isForwardRange!Range, "accumulated zone range must be a forward range");
        static assert(is(Unqual!(ElementType!Range) == AccumulatedZone),
                      "accumulated zone range must be a range of AccumulatedZoneData");

    public:
        @safe pure nothrow @nogc:
        // ForwardRange primitives.
        AccumulatedZone front() const { return array.front; }
        void popFront()                 { array.popFront;      }
        bool empty()            const { return array.empty;  }
        @property Range save()  const { return Range(array); }
        // Number of zones in the range.
        size_t length()         const { return array.length; }
    }

    // Copy all zones into storage.
    size_t i = 0;
    foreach(ref zoneRange; zones) foreach(zone; zoneRange.save)
    {
        storage[i++] = AccumulatedZone(zone, accumulate(null, zone));
    }
    storage = storage[0 .. i];

    // Complexity of this is O(log(N) * N^2 + 2N^2) == O(log(N) * N^2).
    // TODO: We could probably speed this up significantly by sorting storage by level, or
    //       oven by level first and parent ID second. That would make finding matching
    //       nodes much faster. 2014-08-31

    // Start with merging topmost zones with no parents, then merge their children, etc.
    // All zones in a single level that match are accumulated into one element. parentID
    // of the children of merged zones are updated to point to the resulting zone.
    for(size_t level = 1; ; ++level)
    {
        // We're not done as long as there's at least 1 elem at this nesting level.
        bool notDone = false;
        for(size_t e1Idx; e1Idx < storage.length; ++e1Idx)
        {
            auto e1 = &storage[e1Idx];
            if(e1.nestLevel != level) { continue; }

            notDone = true;

            // Any elems until e1Idx that need to be merged are already merged, so start
            // looking at e2Idx.
            for(size_t e2Idx = e1Idx + 1; e2Idx < storage.length; ++e2Idx)
            {
                auto e2 = &storage[e2Idx];
                if(e1.nestLevel != level) { continue; }

                // Skip if the zones don't match.
                if(e1.parentID != e2.parentID || !match(e1.info, e2.info)) { continue; }

                // This happens at most once per zone (a zone can be removed at most once).

                e1.accumulated  = accumulate(&(e1.accumulated), e2.zoneData);
                e1.duration    += e2.duration;
                e1.startTime   += e2.startTime;

                const idToRemove = e2.id;
                const idToReplaceWith = e1.id;

                // Same as `storage = storage.remove(e2Idx);` but @nogc nothrow.
                foreach(offset, ref moveInto; storage[e2Idx .. $ - 1])
                {
                    moveInto = storage[e2Idx + offset + 1];
                }
                storage.popBack();
                // This removes the element at e2Idx (which is greater than e1Idx), so we
                // must go 1 index back, Elements at after e2Idx may also be removed, but
                // that won't break our loop.
                --e2Idx;
                foreach(ref elem; storage) if(elem.parentID == idToRemove)
                {
                    elem.parentID = idToReplaceWith;
                }
            }
        }

        if(!notDone) { break; }
    }

    // Elements that weren't merged were removed from storage in preceding loops, so
    // storage is likely a lot smaller at this point.
    return Range(storage);
}
///
unittest
{
    // Count the number of times each zone was entered.

    import tharsis.prof;

    auto storage  = new ubyte[Profiler.maxEventBytes + 128];
    auto profiler = new Profiler(storage);

    foreach(i; 0 .. 3)
    {
        import std.datetime;
        auto startTime = Clock.currStdTime();
        profiler.frameEvent();
        // Wait long enough so the time gap is represented by >2 bytes.
        while(Clock.currStdTime() - startTime <= 65536) { continue; }
        auto zone1 = Zone(profiler, "zone1");
        {
            auto zone11 = Zone(profiler, "zone11");
        }
        startTime = Clock.currStdTime();
        // Wait long enough so the time gap is represented by >1 bytes.
        while(Clock.currStdTime() - startTime <= 255) { continue; }
        {
            auto zone12 = Zone(profiler, "zone12");
        }
    }


    // Count the number of instances of each zone.
    size_t accum(size_t* aPtr, ref const ZoneData z) pure nothrow @nogc
    {
        return aPtr is null ? 1 : *aPtr + 1;
    }

    auto zones        = profiler.profileData.zoneRange;
    auto accumStorage = new AccumulatedZoneData!accum[zones.walkLength];
    auto accumulated  = accumulatedZoneRange!accum(accumStorage, zones.save);

    assert(accumulated.walkLength == 3);

    import std.stdio;
    foreach(zone; accumulated)
    {
        writeln(zone);
    }
}
///
unittest
{
    // Accumulate minimum, maximum, average duration and more simultaneously.

    // This example also uses C malloc/free, std.typecons.scoped and std.container.Array
    // to show how to do this without using the GC.

    import tharsis.prof;

    const storageLength = Profiler.maxEventBytes + 2048;

    import core.stdc.stdlib;
    // A simple typed-slice malloc wrapper function would avoid the ugly cast/slicing.
    ubyte[] storage  = (cast(ubyte*)malloc(storageLength))[0 .. storageLength];
    scope(exit) { free(storage.ptr); }

    import std.typecons;
    // std.typecons.scoped! stores the Profiler on the stack.
    auto profiler = scoped!Profiler(storage);

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

    // Accumulate data into this struct.
    struct ZoneStats
    {
        ulong minDuration;
        ulong maxDuration;
        // Needed to calculate average duration.
        size_t instanceCount;

        // We also need the total duration to calculate average, but that is accumulated
        // by default in AccumulatedZoneData.
    }

    // Gets min, max, total duration as well as the number of times the zone was entered.
    ZoneStats accum(ZoneStats* aPtr, ref const ZoneData z) pure nothrow @nogc
    {
        if(aPtr is null) { return ZoneStats(z.duration, z.duration, 1); }

        return ZoneStats(min(aPtr.minDuration, z.duration),
                        max(aPtr.maxDuration, z.duration),
                        aPtr.instanceCount + 1);
    }

    auto zones      = profiler.profileData.zoneRange;
    // Allocate storage to accumulate in with malloc.
    const zoneCount = zones.walkLength;
    alias Data = AccumulatedZoneData!accum;
    auto accumStorage = (cast(Data*)malloc(zoneCount * Data.sizeof))[0 .. zoneCount];
    scope(exit) { free(accumStorage.ptr); }

    auto accumulated = accumulatedZoneRange!accum(accumStorage, zones.save);

    // Write out the results.
    foreach(zone; accumulated) with(zone.accumulated)
    {
        import std.stdio;
        writefln("id: %s, min: %s, max: %s, avg: %s, total: %s, count: %s",
                 zone.id, minDuration, maxDuration,
                 zone.duration / cast(double)instanceCount, zone.duration, instanceCount);
    }
}
///
unittest
{
    // Get the average duration of a top-level zone. This is a good way to determine
    // average frame duration as the top-level zone often encapsulates a frame.

    // This example also uses C malloc/free, std.typecons.scoped and std.container.Array
    // to show how to do this without using the GC.

    import tharsis.prof;

    const storageLength = Profiler.maxEventBytes + 2048;

    import core.stdc.stdlib;
    // A simple typed-slice malloc wrapper function would avoid the ugly cast/slicing.
    ubyte[] storage  = (cast(ubyte*)malloc(storageLength))[0 .. storageLength];
    scope(exit) { free(storage.ptr); }

    import std.typecons;
    // std.typecons.scoped! stores the Profiler on the stack.
    auto profiler = scoped!Profiler(storage);

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

    // Count the number of instances of each zone.
    size_t accum(size_t* aPtr, ref const ZoneData z) pure nothrow @nogc
    {
        return aPtr is null ? 1 : *aPtr + 1;
    }

    import std.algorithm;
    // Top-level zones are level 1.
    //
    // Filtering zones before accumulating allows us to decrease memory space needed for
    // accumulation, as well as speed up the accumulation, which is relatively expensive.
    auto zones = profiler.profileData.zoneRange.filter!(z => z.nestLevel == 1);
    // Allocate storage to accumulate in with malloc.
    const zoneCount = zones.walkLength;
    alias Data = AccumulatedZoneData!accum;
    auto accumStorage = (cast(Data*)malloc(zoneCount * Data.sizeof))[0 .. zoneCount];
    scope(exit) { free(accumStorage.ptr); }

    auto accumulated = accumulatedZoneRange!accum(accumStorage, zones.save);

    // If there is just one top-level zone, and it always has the same info ("frame" in
    // this case), accumulatedZoneRange with the default match function will have exactly
    // 1 element; with the accumulated result for all instances of the zone. Also here,
    // we use $(D duration), which is accumulated by default.
    import std.stdio;
    writeln(accumulated.front.duration / cast(real)accumulated.front.accumulated);
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
 *     writeln(event);
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


/** Light-weight range that iterates over zones in profile data.
 *
 * Constructed from a ForwardRange of Event (e.g. EventRange or a std.algorithm/std.range
 * wrapper around an EventRange). Can also be constructed from raw profile data using
 * eventRange().
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
                  "ERange parameter of ZoneRange must be a forward range of Event, "
                  "e.g. EventRange");

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
        // If getToNextZoneEnd consumed all events, we're empty (since no more ZoneEnd).
        assert(!events_.empty, "ZoneRange empty despite assertion at the top of function");
        assert(events_.front.id == EventID.ZoneEnd, "getToNextZoneEnd got to a non-end event");
        return buildZoneData(zoneStack_[0 .. zoneStackDepth_], lastEventTime_);
    }

    /// Go to the next zone.
    void popFront() @safe pure nothrow @nogc
    {
        assert(!empty, "Can't pop front of an empty range");

        // Since profiling can stop at any moment due to running out of assigned memory,
        // we need to handle the space where we don't have zone end events for all zones.
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
     * Adds any ZoneStart events to the stack.
     */
    void getToNextZoneEnd() @safe pure nothrow @nogc
    {
        for(; !events_.empty; events_.popFront())
        {
            const event = events_.front;
            lastEventTime_ = event.startTime;

            with(EventID) final switch(event.id)
            {
                case Frame, Checkpoint: break;
                case ZoneStart:
                    assert(zoneStackDepth_ < maxStackDepth,
                           "Zone nesting too deep; zone stack overflow.");
                    zoneStack_[zoneStackDepth_++] = ZoneInfo(nextID_++, lastEventTime_);
                    break;
                case ZoneEnd: return;
                // If an info event has the same start time as the current zone, it's info
                // about the current zone.
                case Info:
                    auto curZone = &zoneStack_[zoneStackDepth_ - 1];
                    if(event.startTime == curZone.startTime) { curZone.info = event.info; }
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

    // This example also uses C malloc/free, std.typecons.scoped and std.container.Array
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
    // front_.startTime is incrementally increased with each readEvent() call instead of
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
        empty_ = profileData_.empty;
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
        assert(!profileData_.empty, "Trying to read an event from empty profile data");

        front_.id = cast(EventID)(profileData_.front & eventIDMask);
        // Assert validity of the profile data.
        debug
        {
            bool found = allEventIDs.canFind(front_.id);
            assert(found, "Invalid profiling data; expected event ID but got something else");
        }

        const timeBytes = profileData_.front >> eventIDBits;
        profileData_.popFront();

        assert(profileData_.length >= timeBytes, 
               "Invalid profiling data; not long enough to store expected time gap bytes");

        // Parses 'time bytes' each encoding 7 bits of a time span value
        void parseTimeBytes(uint count) nothrow @nogc
        {
            foreach(b; 0 .. count)
            {
                assert(profileData_.front != 0, "Time bytes must not be 0");
                front_.startTime += cast(ulong)(profileData_.front() & timeByteMask) 
                                    << (b * timeByteBits);
                profileData_.popFront();
            }
        }

        parseTimeBytes(timeBytes);
        front_.info = null;

        with(EventID) switch(front_.id)
        {
            case Frame, ZoneStart, ZoneEnd: return;
            case Checkpoint:
                // A checkpoint contains absolute start time. 
                // This is not really necessary ATM, (relative time would get us the same
                // result as this code), but allow 'disjoint' checkpoints that change the
                // 'current time' in future.
                front_.startTime = 0;
                parseTimeBytes(checkpointByteCount);
                break;
            // Info is followed by an info string.
            case Info:
                assert(!profileData_.empty,
                       "Invalid profiling data: info event not followed by string length");
                const infoBytes = profileData_.front;
                profileData_.popFront;
                front_.info = cast(const(char)[])profileData_[0 .. infoBytes];
                assert(profileData_.length >= infoBytes,
                       "Invalid profiling data: info event not followed by info string");
                profileData_ = profileData_[infoBytes .. $];
                return;
            default: assert(false, "Unknown event ID");
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
    auto filtered = events.filter!(e => e.startTime > 1500 && e.startTime < 2000);
    // Here, we print the IDs of events between 10000 and 50000 hectonanoseconds
    foreach(id; filtered.map!(e => e.id))
    {
        writeln(id);
    }

    // And here we count the number of events between 1000 and 5000
    writeln(filtered.count);
}
