//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)


/** Functionality needed to record profiling data.
 *
 * Profiler keeps track of profiling events.
 *
 * Zone is an RAII struct that records precise time at its construction and destruction.
 *
 * Realtime:
 *
 * Recording is very lightweight, without any complicated logic or heap allocations.
 * This allows to use Tharsis-prof as a 'short-term _profiler' that can record profiling
 * data over the duration of a few frames and be detect bottlenecks in real time. Game
 * code can then react, for example by disabling resource intensive nonessential features
 * (e.g. particle systems).
 *
 * Precision:
 *
 * Tharsis.prof measures time in D 'hectonanoseconds', or tenths of a microsecond. This is
 * precise enough to detect irregular overhead during frames but not to profile individual
 * instructions in a linear algebra function. Such use cases are better covered by
 * a Callgrind or a sampling _profiler such as perf or CodeAnalyst. Also note that some
 * platforms may not provide access to high-precision timers and the results may be even
 * less precise. At least Linux, Windows and OSX should be alright, though.
 */
module tharsis.prof.profiler;


import std.algorithm;
import std.datetime;
import std.exception;

import tharsis.prof.event;

// We're measuring in hectonanoseconds.
//
// Second is 10M hnsecs.
// Minute is 600M hnsecs.
// Hour is 36G hnsecs.


// TODO: Time slicing is unrealiable due to multiple events having the same time.
//       ChunkyEventList has the SliceExtents as a hack to avoid this issue, but it's not
//       a general solution. To get precise slices e.g. for Zones, we need to
//       differentiate Events with the same time. On way to do this is to encode an extra
//       number before each event: 0 by default (and ensure it takes 0 bytes in that
//       case), 1 for second event with the same time, 2 for third, etc.
//       We can use variable-length encoding just like when encoding time gaps.
//       TODO IMPROVEMENT: We probably don't even need to store this number in profile
//       data; just let EventRange generate it as a part of the event (eventIndex?)
//       - This should work even with wrapped/filtered/slice EventRanges as there is
//       always a full EventRange below (or for slices that aren't the full EventRange,
//       when we add explicit slicing, keep the index of the first Event in the slice.).
//       We can probably use this to replace SliceExtents (although ChunkyEventRange will
//       need custom code to generate event IDs as it contatenates multiple EventRanges)
//       2014-11-28
// TODO: Use core.time.Duration once its API is @nogc and update the examples to use it.
// TODO: Frame-based analysis. E.g. find the longest frame and create a range over its
//       zones (really just a time slice of a ZoneRange). 2014-08-31
// TODO: Slicing of EventRange, ZoneRange based on a time interval. 2014-08-31
// TODO: Once time slicing works, this example:
//       Get the longest, shortest (in duration) top-level zone, and all zones within it.
// TODO: ZoneTree - with a single parent node for all nodes with no parents.
//       It shouldn't use traditional separately allocated nodes connected by pointers,
//       and should instead use a big array of nodes and possibly auxiliary array/s to
//       translate parent IDs to node indices.
//       What ZoneTree should allow:
//         * Filtering nodes by percentage of parent duration (i.e. ignore anything that's
//           e.g. < 5% of parent)
//         * Tree nodes should have methods to return ForwardRanges of ZoneData,
//           and the nodes themselves should be ForwardRanges of nodes. This would allow
//           using std.algorithm.filter to filter nodes and still have access to their
//           children.
//       2014-08-31
// TODO: (maybe): Compress chunks of profileData by zlib or something similar. E.g.
//       compress every 64kiB. profileData can then be read through a range wrapper
//       that has a fixed-size decompression buffer. Compressed data in profileData would
//       be represented by a 'Compressed' EventID followed by length of compressed data.
// TODO: Compress info strings with a short string compressor like shoco or smaz (both at
//       github) (of course, will need to convert whatever we use to D).

// TODO: Allow specifying zone info as a compile-time param:
//       If specified at compile time, instead of ZoneEvent we use a deduplicatedZoneEvent
//       or something with a similar name, which should just store a hash or maybe
//       a 2-byte index to a global immutable array of strings. That array would be
//       built in static this() emitted from all Zone() ctors with a compile-time info
//       string. (Since we know it at compile-time, we can do any deduplication at
//       compile-time or static ctor-time - and the restulting structure can be immutable
//       - usable from multiple threads)
//       To make this work with the profiling data stream, the first time a compile-time
//       string is used in a zone, add an event describing that string. Following events
//       will just contain an index.


/** _Zone of profiled code.
 *
 * Emits a zone start event (recording start time) at construction and a zone end event
 * (recording end time) at destruction.
 *
 * Examples:
 * --------------------
 * // Zones can be nested:
 * while(!done)
 * {
 *     auto frameZone = Zone(profiler, "frame");
 *     {
 *         auto renderingZone = Zone(profiler, "rendering");
 *
 *         // do rendering here
 *     }
 *     {
 *         auto physicsZone = Zone(profiler, "physics");
 *
 *         // do physics here
 *     }
 * }
 * --------------------
 *
 * --------------------
 * // A nested zone must be fully contained in its parent zone, e.g. this won't work:
 * auto zone1 = Zone(profiler, "zone1");
 * while(!done)
 * {
 *     auto zone2 = Zone(profiler, "zone1");
 *     // WRONG: zone1 destroyed manually before zone2
 *     destroy(zone1);
 *
 *     // zone2 implicitly destroyed at the end of scope
 * }
 * --------------------
 */
struct Zone
{
private:
    // Nesting level of this Zone. Top-level zones have nestLevel_ of 1, their children 2, etc.
    uint nestLevel_;

    // Reference to the Profiler so we can emit the zone end event from the dtor.
    Profiler profiler_;

    // Copying a Zone would completely break it.
    @disable this(this);
    @disable bool opAssign(ref Zone);
    @disable this();

public:
    /** Construct a zone to record with specified _profiler.
     *
     * Emits the zone start event.
     *
     * Params:
     *
     * profiler = Profiler to record into. If $(D null), the zone is ignored. This enables
     *            'optional profiling', where instrumenting code (zones) is always present
     *            in the code but only activated when a Profiler exists.
     * info     = Zone information string. Used to recognize zones when parsing and
     *            accumulating profile data. Can be the 'name' of the zone, possibly with
     *            some extra _info (e.g. "frame": entire frame or "batch 5": fifth draw
     *            batch). $(B Must not) be empty or longer than 255 characters and
     *            $(B must not) contain zero ($(D '\0')) characters.
     */
    this(Profiler profiler, string info) @trusted nothrow
    {
        if(profiler !is null)
        {
            nestLevel_ = profiler.zoneStartEvent(info);
        }
        profiler_ = profiler;
    }

    /** A shortcut to call variableEvent() of the zone's profiler, if any.
     *
     * If a null Profiler has been passed to the Zone's constructor, this call is ignored.
     *
     * See_Also: Profiler.variableEvent().
     */
    void variableEvent(string name, V)(const V value) @safe pure nothrow @nogc
    {
        if(profiler_ !is null)
        {
            profiler_.variableEvent!(name, V)(value);
        }
    }

    /** Destructor. Emits the zone end event with the Profiler.
     *
     * Can be called early (using destroy()) to end the zone before end of the scope.
     */
    ~this() @trusted nothrow
    {
        if(profiler_ !is null)
        {
            profiler_.zoneEndEvent(nestLevel_);
        }
        // Ensures that if we call the destructor early, we won't emit the end event twice.
        profiler_ = null;
    }
}
unittest
{
    // Test 'null profiler' (Zone is automatically ignored if a null profiler is passed.)
    foreach(i; 0 .. 10)
    {
        auto frameZone = Zone(null, "frame");
        {
            auto renderingZone = Zone(null, "rendering");
        }
        {
            auto physicsZone = Zone(null, "physics");
        }
    }
}

static assert(!allEventIDs.canFind!(e => e > eventIDMask),
              "Too high EventID value; last 3 bits are reserved for byte count");

/* All EventID values must be 5-bit integers, with 0 reserved for 'Checkpoint' EventID
 * which is the only zero byte value that may appear in profiling data (this allows
 * 'going backwards' in profile data).
 *
 * In profile data, an EventID is packed into a byte with a 3-bit 'byteCount' value,
 * which specifies the number of bytes immediately after the EventID/byteCount byte
 * used to encode time elapsed since the last event. Each of these bytes consists of
 * 7 bits of the 'time elapsed' value (first byte - lowest 7 bits, second byte - higher
 * 7 bits, etc. with as many bytes as there are (at most 7)). The highest bit is always
 * set to 1 (to ensure the byte zero).
 */

// Number of bits in event ID bytes storing the event ID itself. Other bytes store 'byteCount'.
package enum eventIDBits = 5;
// Mask of the bits in an event ID byte that store the event ID itself.
package enum eventIDMask = 0b00011111;

// Number of bits in a time byte used to store the actual time value.
package enum timeByteBits = 7;
// Mask of the bits in a time byte used to store the actual time value.
package enum timeByteMask = 0b01111111;
// Mask to set the highest bit of time bytes and other 7-bit encodings to 1.
package enum lastBit = 0b10000000;

// Number of bytes storing absolute time in a checkpoint event (same format as time bytes).
package enum checkpointByteCount = 8;


/** Records profiling events into user-specified buffer.
 *
 * Used together with Zone to record data and with EventRange/ZoneRange/etc. for analysis.
 *
 * Profiler writes profiling data into a byte buffer passed to Profiler constructor by the
 * user. Once there is not enough space to write any more profiling events, the profiler
 * quietly ignores any events (this can be checked by outOfSpace()). Profiler $(B never
 * allocates heap memory) by itself.
 *
 * Recorded data can be accessed at any time through profileData() and analyzed with help
 * of EventRange, ZoneRange and other tharsis.prof utilities. reset() can be used to
 * clear recorded data and start recording from scratch.
 *
 * Note:
 *
 * Profiler is $(B not) designed to be used from multiple threads. If you need to profile
 * multiple threads, create a separate Profiler for each thread and either analyze the
 * results through separate EventRange/ZoneRange instances, or merge them through
 * accumulatedZoneRange.
 *
 * Note:
 *
 * Accessing profile data from an out-of-space profiler or in the middle of a zone will
 * result in an EventRange that's missing some zone end events. Incomplete raw profiling
 * results or EventRanges should never be concatenated. ZoneRange will automatically end
 * the unfinished zones.
 *
 * Memory consumption:
 *
 * Depending on the worload and number of zones, Profiler can eat through assigned memory
 * rather quickly.  With 10000 zones at 120 FPS the overhead is going to be around 14 MiB
 * $(B per second).
 */
final class Profiler
{
    /// Diagnostics used to profile the profiler.
    struct Diagnostics
    {
        size_t zoneStartCount;
        size_t zoneEndCount;
        size_t infoCount;
        size_t frameCount;
        size_t variableCount;
    }

    /// Maximum size of any single event in bytes. Used to quickly check if we're out of space.
    enum maxEventBytes = 512;

private:
    // Buffer we're recording profiling data to. Passed to constructor and never reallocated.
    ubyte[] profileData_;

    // Size recorded data in profileData_.
    //
    // When this reaches profileData_.length, we're out of space (actually, a bit sooner,
    // see outOfSpace()).
    size_t profileDataUsed_;

    // Nesting level of the current zone (used to check that child zones are fully
    // contained by their parents)
    uint zoneNestLevel_;

    // Start time of the last event (as returned by std.datetime.Clock.currStdTime()).
    ulong lastTime_;

    // Time when the Profiler was constructed (as returned by std.datetime.Clock.currStdTime()).
    ulong startTime_;

    // Diagnostics about the profiler, such as which evenets are the most common.
    Diagnostics diagnostics_;

public:
    /** Construct a Profiler writing profiling data to specified buffer.
     *
     * Profiler doesn't allocate heap memory. It will write profiling data into given
     * buffer until it runs out of space, at which point it will silently stop profiling
     * (this can be detected by outOfSpace() ).
     *
     * Params:
     *
     * profileBuffer = Buffer to write profile data to. Must be at least
     * Profiler.maxEventBytes long.
     */
    this(ubyte[] profileBuffer) @safe nothrow
    {
        assert(profileBuffer.length >= maxEventBytes,
               "Buffer passed to Profiler must be at least Profiler.maxEventBytes long");
        profileData_     = profileBuffer;
        profileDataUsed_ = 0;
        startTime_ = lastTime_ = Clock.currStdTime().assumeWontThrow;
    }

    /** Is the profiler out of space?
     *
     * When the profiler uses up all memory passed to the constructor, it quietly stops
     * profiling. This can be used to determine if that has happened.
     */
    bool outOfSpace() @safe pure nothrow const @nogc
    {
        // maxEventBytes ensures there's enough space for any single event (the longest
        // event, Info, can be at most 258 bytes long.
        return profileDataUsed_ + maxEventBytes >= profileData_.length;
    }

    /** Get diagnostics about the profiler, such as which events are the most common.
     *
     * Useful for profiling the profiler.
     */
    Diagnostics diagnostics() @safe pure nothrow const @nogc
    {
        return diagnostics_;
    }

    /** Emit a checkpoint event.
     *
     * A checkpoint event inserts the absolute time of the last event before the
     * checkpoint. This allows reconstrucing event times from the checkpoint instead of
     * from the start. It also inserts a zero byte into profiling data, which no other
     * event can do. This allows to rewind profiler data without having to go all the way
     * to the start.
     *
     * Note: neither of these options is actually exploited at the moment; but they should
     *       be useful for profiling visualizers and when processing massive profiling
     *       outputs.
     */
    void checkpointEvent() @safe pure nothrow @nogc
    {
        if(outOfSpace) { return; }
        eventWithTime(EventID.Checkpoint, 0);

        auto time = lastTime_ - startTime_;
        // Add 8 time bytes (can represent 128 ** 8 hnsecs)
        foreach(b; 0 .. checkpointByteCount) { time = addTimeByte(time); }
    }

    /** Emit a variable event.
     *
     * Used to keep track of various variables that change over time, e.g. FPS, network
     * traffic, entity count...; Despiker supports viewing the value of a variable once
     * per frame.
     *
     * Params:
     *
     * name  = Variable name (specified at compile-time). The variable event itself does
     *         not contain the name; the name is stored in an info event immediately
     *         after the variable event.
     * V     = Variable type. Only int, uint and float are supported at the moment.
     * value = Value of the variable
     *
     * Example:
     * --------------------
     * // Profiler profiler
     * profiler.variableEvent!"FPS"(4.5f);
     * --------------------
     */
    void variableEvent(string name, V)(const V value) @trusted pure nothrow @nogc
    {
        static assert(name.length <= ubyte.max,
                      "variableEvent name strings must be no longer than 255 bytes");
        if(outOfSpace) { return; }
        ++diagnostics_.variableCount;
        eventWithTime(EventID.Variable, 0);
        enum varType = variableType!V;
        profileData_[profileDataUsed_++] = varType;


        V[1] valueCopy;
        valueCopy[0] = value;
        import std.system;

        import tinyendian;
        // Variable bytes are always in big endian order.
        if(std.system.endian != Endian.bigEndian)
        {
            swapByteOrder(valueCopy[]);
        }

        static assert(V.sizeof == 4,
                      "variableEvent() does not support types with sizeof other than 4 yet");

        const encoded = encode7Bit(cast(ubyte[4])valueCopy, profileData_[profileDataUsed_ .. $]);
        profileDataUsed_ += encoded.length;
        infoEvent(name);
    }

    /** Emit a zone start event, when code enters a zone.
     *
     * Params:
     *
     * info = Information about the zone (e.g. its name). Will be added as an info event
     *        following the zone start event. $(B Must not) be empty or longer than 255
     *        characters and $(B must not) contain zero ($(D '\0')) characters.
     *
     * Returns: Nesting level of the newly started zone. Must be passed when corresponding
     *          zoneEndEvent() is called. Used to ensure child events end before their
     *          parent events.
     *
     * Note: zoneStartEvent should only be aleed directly where the Zone struct is not
     *       sufficient (i.e. where a zone cannot be wrapped in a scope).
     */
    uint zoneStartEvent(const string info) @system nothrow
    {
        assert(info.length <= ubyte.max, "Zone info strings can be at most 255 bytes long");
        assert(info.length > 0, "Zone info strings must not be empty");
        assert(!(cast(ubyte[])info).canFind(0), "Zone info strings must not contain '\\0'");

        const time = Clock.currStdTime.assumeWontThrow;

        auto timeLeft = time - lastTime_;
        lastTime_ = time;

        if(outOfSpace) { return ++zoneNestLevel_; }
        ++diagnostics_.zoneStartCount;

        eventWithTime(EventID.ZoneStart, timeLeft);
        if(outOfSpace) { return ++zoneNestLevel_; }
        infoEvent(info);

        return ++zoneNestLevel_;
    }

    /** Emit a zone end event, when code exits a zone.
     *
     * Params:
     *
     * nestLevel = Nesting level of the zone. Used to check that zones are exited in the
     *             correct (hierarchical) order, i.e. a child zone must be ended before
     *             its parent zone.
     *
     * Note: zoneEndEvent should only be called directly where the Zone struct is not
     *       sufficient (i.e. where a zone cannot be wrapped in a scope).
     */
    void zoneEndEvent(const uint nestLevel) @system nothrow
    {
        assert(nestLevel == zoneNestLevel_,
               "Zones must be hierarchical; detected a zone that ends after its parent");
        --zoneNestLevel_;
        const time = Clock.currStdTime.assumeWontThrow;

        const timeLeft = time - lastTime_;
        lastTime_ = time;
        if(outOfSpace) { return; }
        ++diagnostics_.zoneEndCount;

        eventWithTime(EventID.ZoneEnd, timeLeft);
    }


    /** Reset the profiler.
     *
     * Clears all profiled data. Reuses the buffer passed by the constructor to start
     * profiling from scratch.
     *
     * Can only be called outside of any Zone.
     */
    void reset() @safe nothrow
    {
        // Doing the reset inside a zone would result in a zone end without zone start,
        // which we can't handle (at least for now).
        assert(zoneNestLevel_ == 0, "Profiler can only be reset() while not in a Zone");
        profileData_[]   = 0;
        profileDataUsed_ = 0;
        startTime_ = lastTime_ = Clock.currStdTime().assumeWontThrow;
    }

    /** Get the raw data recorded by the profiler.
     *
     * This is a slice to the buffer passed to Profiler's constructor.
     */
    const(ubyte)[] profileData() @safe pure nothrow const @nogc
    {
        return profileData_[0 .. profileDataUsed_];
    }

    /** Get the nest level of the current zone, if any.
     *
     * 0 means the profiler is not in any zone.
     */
    uint zoneNestLevel() @safe pure nothrow const @nogc
    {
        return zoneNestLevel_;
    }

private:
    /* Add one byte of a 'time byte' sequence that encodes a time span.
     *
     * Takes the time we're encoding and returns remainder of that time that is not yet
     * encoded into time btyes (time / 128).
     */
    ulong addTimeByte(ulong time) @safe pure nothrow @nogc
    {
        // The last bit ensures the resulting byte is never 0
        profileData_[profileDataUsed_++] = lastBit | cast(ubyte)(time & timeByteMask);
        return time >> timeByteBits;
    }

    /* Write an event ID and bytes specifying the time left (gap) since the last event.
     *
     * Event ID is packed *time gap byte count* into a byte (low 5 bits for event ID, high
     * 3 bits for byte count). This byte is followed by time gap bytes, each of which
     * stores 7 time gap bits (topmost bit is always 1 to ensure the bytes are never 0, to
     * avoid confusion with checkpoint bytes, which are 0). The first byte stores the
     * lowest 7 bits of the time gap, second stores the next 7 bits, etc.
     */
    void eventWithTime(EventID id, ulong timeLeft) @trusted pure nothrow @nogc
    {
        const idIndex = profileDataUsed_++;
        size_t byteCount = 0;

        // Add as many time bytes as needed (1 byte can represent 128 hnsecs, 2 bytes can
        // represent 128 ** 2, etc.)
        while(timeLeft > 0)
        {
            timeLeft = addTimeByte(timeLeft);
            ++byteCount;
            if(byteCount >= 8)
            {
                assert(false, "Tharsis.prof does not support time gaps over 228 years");
            }
        }
        const ubyte idByte = cast(ubyte)(id | (byteCount << eventIDBits));
        profileData_[idIndex] = idByte;
        assert((idByte & eventIDMask) == id,  "EventID saved incorrectly");
        assert((idByte >> eventIDBits) == byteCount, "byte count saved incorrectly");
    }
    unittest
    {
        import std.array;
        import std.stdio;

        writeln("time gap recording unittest");

        ubyte[4096] storage;
        auto profiler = new Profiler(storage[]);
        const ulong time = 33457812484;
        profiler.eventWithTime(EventID.ZoneStart, time);

        auto data = profiler.profileData;
        ulong recordedTime = 0;
        const timeBytes = data.front >> eventIDBits;

        data.popFront();
        foreach(b; 0 .. timeBytes)
        {
            recordedTime += cast(ulong)(data.front() & timeByteMask) << (b * timeByteBits);
            data.popFront();
        }

        assert(recordedTime == time);
    }

    /* Emit an info event.
     *
     * This event stores character data (at most 255 bytes). Currently info events are
     * only used to 'describe' immediately previous zone start events.
     */
    void infoEvent(const string info) @trusted pure nothrow @nogc
    {
        assert(info.length <= ubyte.max, "Zone info strings can be at most 255 bytes long");
        if(outOfSpace) { return; }
        ++diagnostics_.infoCount;
        eventWithTime(EventID.Info, 0);
        profileData_[profileDataUsed_++] = cast(ubyte)(info.length);
        profileData_[profileDataUsed_ .. profileDataUsed_ + info.length] = cast(ubyte[])info[];
        profileDataUsed_ += info.length;
    }
}
///
unittest
{
    ubyte[] storage = new ubyte[Profiler.maxEventBytes + 2048];
    auto profiler = new Profiler(storage);

    // Simulate 16 'frames'
    foreach(frame; 0 .. 16)
    {
        Zone topLevel = Zone(profiler, "frame");
        // Record a variable event (useful for tracking FPS, entity count, network
        // traffic, etc.). Only uint, int and float supported at the moment.
        profiler.variableEvent!"frame" = cast(uint)frame;

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

    // see tharsis.profiler.ranges for how to process recorded data
}
///
unittest
{
    // This example uses C malloc/free and std.typecons.scoped to show how to use Profiler
    // without GC allocations.

    const storageLength = Profiler.maxEventBytes + 2048;

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

    // see tharsis.profiler.ranges for how to process recorded data
}
unittest
{
    import std.range;

    import tharsis.prof.ranges;

    Profiler profiler;

    void addZones()
    {
        foreach(i; 0 .. 3)
        {
            auto startTime = Clock.currStdTime().assumeWontThrow;
            // Wait long enough to store the time gap in >2 bytes.
            while(Clock.currStdTime().assumeWontThrow - startTime <= 65536)
            {
                continue;
            }
            auto zone1 = Zone(profiler, "zone1");
            {
                auto zone11 = Zone(profiler, "zone11");
            }
            startTime = Clock.currStdTime().assumeWontThrow;
            // Wait long enough to store the time gap in >1 bytes.
            while(Clock.currStdTime().assumeWontThrow - startTime <= 256)
            {
                continue;
            }
            {
                auto zone12 = Zone(profiler, "zone12");
            }
            profiler.variableEvent!"var_i" = cast(float)i;
            profiler.checkpointEvent();
        }
    }

    {
        auto storage = new ubyte[Profiler.maxEventBytes + 256];
        profiler = new Profiler(storage);
        addZones();

        // Check if the events generated are what we expect.
        auto evts = profiler.profileData.eventRange;
        foreach(i; 0 .. 3) with(EventID)
        {
            assert(evts.front.id == ZoneStart);                           evts.popFront();
            assert(evts.front.id == Info && evts.front.info == "zone1");  evts.popFront();

            assert(evts.front.id == ZoneStart);                           evts.popFront();
            assert(evts.front.id == Info && evts.front.info == "zone11"); evts.popFront();
            assert(evts.front.id == ZoneEnd);                             evts.popFront();

            assert(evts.front.id == ZoneStart);                           evts.popFront();
            assert(evts.front.id == Info && evts.front.info == "zone12"); evts.popFront();
            assert(evts.front.id == ZoneEnd);                             evts.popFront();

            const time = evts.front.time;
            assert(evts.front.id == Variable &&
                   evts.front.var.type == VariableType.Float &&
                   evts.front.var.varFloat == cast(float)i);              evts.popFront();
            assert(evts.front.id == Info && evts.front.info == "var_i");  evts.popFront();

            // Checkpoint start time must match the previous event.
            assert(evts.front.time == time);
            assert(evts.front.id == Checkpoint);                          evts.popFront();
            assert(evts.front.id == ZoneEnd);                             evts.popFront();
        }

        auto zones = profiler.profileData.zoneRange;
        assert(zones.walkLength == 9, "Unexpected number of zones");

        // Check that zones have expected nesting, infos and time ordering.
        foreach(i; 0 .. 3)
        {
            const z11 = zones.front; zones.popFront();
            const z12 = zones.front; zones.popFront();
            const z1  = zones.front; zones.popFront();
            assert(z11.parentID == z1.id && z12.parentID == z1.id);
            assert(z11.nestLevel == 2 && z12.nestLevel == 2 && z1.nestLevel == 1);
            assert(z11.info == "zone11" && z12.info == "zone12" && z1.info == "zone1");

            assert(z11.startTime >= z1.startTime &&
                   z12.startTime >= z11.startTime + z11.duration &&
                   z1.startTime + z1.duration >= z12.startTime + z12.duration);
        }
    }

    // Test what happens when Profiler runs out of space.
    {
        auto storage  = new ubyte[Profiler.maxEventBytes + 50];
        profiler = new Profiler(storage);
        addZones();

        ulong lastTime = 0;
        foreach(zone; profiler.profileData.zoneRange)
        {
            assert(zone.endTime >= lastTime,
                   "Incomplete profile data resulted in wrong order of zone end times");
            lastTime = zone.endTime;
        }
    }

    {
        auto storage  = new ubyte[Profiler.maxEventBytes + 128];
        profiler = new Profiler(storage);
        addZones();

        auto zones = profiler.profileData.zoneRange;


        // Just count the number of instances of each zone.
        size_t accum(size_t* aPtr, ref const ZoneData z) pure nothrow @nogc
        {
            return aPtr is null ? 1 : *aPtr + 1;
        }
        auto accumStorage = new AccumulatedZoneData!accum[zones.walkLength];
        auto accumulated = accumulatedZoneRange!accum(accumStorage, zones.save);
    }
}


package:

/* Encode 4 bytes of data into 5 7-bit encoded bytes in target.
 *
 * The last bit of each byte in the 7-bit encoding is set to 1. This is used to avoid
 * zero bytes in e.g. variable events (zero bytes can *only* be used by the
 * CheckpointEvent, to allow searching for it backwards).
 *
 * Params:
 *
 * data   = Data to encode.
 * target = First 5 bytes of target will store the encoded data. Must be at least 5 bytes.
 *
 * Returns: A 5-byte slice of target with the encoded data.
 */
static ubyte[] encode7Bit(ubyte[4] data, ubyte[] target)
    @safe pure nothrow @nogc
{
    assert(target.length >= 5,
            "Not enough space to encode a 4 bytes chunk into 7-bit encoding");

    // first 7 bits from first byte
    ubyte b = lastBit | (data[0] & (0xFF >> 1));
    target[0] = b;
    // last bit from first byte (moved 7 to right),
    // first 6 bits from second byte (moved by 1 to left)
    b = lastBit | ((data[0] & (0xFF << 7)) >> 7) | ((data[1] & (0xFF >> 2)) << 1);
    target[1] = b;
    // last 2 bits from second byte (moved 6 to right),
    // first 5 bits from third byte (moved 2 to left)
    b = lastBit | ((data[1] & (0xFF << 6)) >> 6) | ((data[2] & (0xFF >> 3)) << 2);
    target[2] = b;
    // last 3 bits from third byte (moved 5 to right),
    // first 4 bits from fourth byte (moved 3 to left)
    b = lastBit | ((data[2] & (0xFF << 5)) >> 5) | ((data[3] & (0xFF >> 4)) << 3);
    target[3] = b;
    // last 4 bits from fourth byte (moved 4 to right)
    b = lastBit | ((data[3] & (0xFF << 4)) >> 4);
    target[4] = b;

    return target[0 .. 5];
}

/* Decoded 4 bytes of data stored in 5 bytes of 7-bit encoded data.
 *
 * Params:
 *
 * data   = Data to decode.
 * target = First 4 bytes of target will store the decoded data. Must be at least 4 bytes.
 *
 * Returns: A 4-byte slice of target with the encoded data.
 *
 * See_Also: encode7Bit
 */
static ubyte[] decode7Bit(ubyte[5] encoded, ubyte[] target)
    @safe pure nothrow @nogc
{
    assert(target.length >= 4,
            "Not enough space to decode a 5-byte chunk encoded in 7-bit encoding");

    target[0] = (encoded[0] & 0b01111111)        | ((encoded[1] & 0b00000001) << 7);
    target[1] = ((encoded[1] & 0b01111110) >> 1) | ((encoded[2] & 0b00000011) << 6);
    target[2] = ((encoded[2] & 0b01111100) >> 2) | ((encoded[3] & 0b00000111) << 5);
    target[3] = ((encoded[3] & 0b01111000) >> 3) | ((encoded[4] & 0b00001111) << 4);

    return target[0 .. 4];
}

unittest
{
    import std.random;
    foreach(attempt; 0 .. 1024)
    {
        uint[1] u;
        float[1] f;
        u[0] = uniform(uint.min, uint.max);
        f[0] = uniform(-100000.0f, 100000.0f) + uniform(-1.0f, 1.0f);

        ubyte[5] encodeBuf;
        ubyte[4] decodeBuf;
        encode7Bit(cast(ubyte[4])u, encodeBuf[]);
        decode7Bit(encodeBuf, decodeBuf[]);

        assert(*(cast(uint*)decodeBuf.ptr) == u[0],
                "encoded/decoded uint data does not match original");

        encode7Bit(cast(ubyte[4])f, encodeBuf[]);
        decode7Bit(encodeBuf, decodeBuf[]);

        assert(*(cast(float*)decodeBuf.ptr) == f[0],
                "encoded/decoded float data does not match original");
    }
}
