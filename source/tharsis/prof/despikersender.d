//          Copyright Ferdinand Majerech 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

/// Support for <a href="https://github.com/kiith-sa/despiker">Despiker</a>
module tharsis.prof.despikersender;

import std.algorithm;
import std.array;
import std.exception: assumeWontThrow, ErrnoException;
import std.string;

import tharsis.prof.profiler;


/// Exception thrown at DespikerSender errors.
class DespikerSenderException : Exception
{
    this(string msg, string file = __FILE__, int line = __LINE__) @safe pure nothrow
    {
        super(msg, file, line);
    }
}

// TODO: Replace writeln by logger once in Phobos 2014-10-06
/** Sends profiling data recorded by one or more profilers to the Desiker profiler.
 *
 * <a href="https://github.com/kiith-sa/despiker">Despiker</a> is a real-time graphical
 * profiler based on Tharsis.prof. It visualizes zones in frames while the game is running
 * and allows the user to move between frames and automatically find the worst frame. Note
 * that at the moment, Despiker is extremely experimental and unstable.
 *
 * See <a href="http://defenestrate.eu/docs/despiker/index.html">Despiker
 * documentation</a> for more info.
 *
 * Example:
 * --------------------
 * // Profiler profiler - construct it somewhere first
 *
 * auto sender = new DespikerSender([profiler]);
 *
 * for(;;)
 * {
 *     // Despiker will consider code in this zone (named "frame") a part of a single frame.
 *     // Which zone is considered a frame can be changed by setting the 
 *     // sender.frameFilter property.
 *     auto frame = Zone(profiler, "frame");
 *
 *     ... frame code here, with more zones ...
 *
 *     if(... condition to start Despiker ...)
 *     {
 *         // Looks in the current directory, directory with the binary/exe and in PATH
 *         // use sender.startDespiker("path/to/despiker") to specify explicit path
 *         sender.startDespiker();
 *     }
 *
 *     // No zones must be in progress while sender is being updated, so we end the frame
 *     // early by destroying it.
 *     destroy(frame);
 *
 *     // Update the sender, send profiling data to Despiker if it is running
 *     sender.update();
 * }
 * --------------------
 */
class DespikerSender
{
    /// Maximum number of profilers we can send data from.
    enum maxProfilers = 1024;
private:
    /* Profilers we're sending data from.
     *
     * Despiker assumes that each profiler is used to profile a separate thread 
     * (profilers_[0] - thread 0, profilers_[1] - thread 1, etc.).
     */
    Profiler[] profilers_;

    import std.process;
    /* Pipes to send data to the Despiker (when running) along with pid to check its state.
     *
     * Reset by reset().
     */
    ProcessPipes despikerPipes_;

    /* Storage for bytesSentPerProfiler.
     * 
     * Using a fixed-size array for simplest/fastest allocation. 8kiB is acceptable but
     * right at the edge of being acceptable... if we ever increase maxProfilers above
     * 1024, we should use malloc.
     */
    ulong[1024] bytesSentPerProfilerStorage_;
    /* Number of bytes of profiling data sent from each profiler in profilers_.
     *
     * Reset by reset().
     */
    ulong[] bytesSentPerProfiler_;

    // Are we sending data to a running Despiker right now?
    bool sending_ = false;

    // Used to determine which zones are frames.
    DespikerFrameFilter frameFilter_;

public:
    // TODO screenshot of a frame in despiker near 'matching their 'frame' zones' text
    // 2014-10-08
    /** Construct a DespikerSender sending data recorded by specified profilers.
     *
     * Despiker will show results from passed profilers side-by-side, matching their
     * 'frame' zones. To get meaningful results, all profilers should start profiling
     * at the same time and have one 'frame' zone for each frame of the profiled 
     * game/program.
     *
     * The main use of multiple profilers is to profile code in multiple threads
     * simultaneously. If you don't need this, pass a single profiler.
     *
     * Params:
     *
     * profilers = Profilers the DespikerSender will send data from. Must not be empty.
     *             Must not have more than 1024 profilers.
     *
     * Note:
     *
     * At the moment, DespikerSender does not support resetting profilers. Neither of the
     * passed profilers may be reset() while the DespikerSender is being used.
     */
    this(Profiler[] profilers) @safe pure nothrow @nogc
    {
        assert(!profilers.empty, "0 profilers passed to DespikerSender constructor");
        assert(profilers.length <= maxProfilers,
               "Despiker supports at most 1024 profilers at once");

        profilers_ = profilers;
        bytesSentPerProfiler_ = bytesSentPerProfilerStorage_[0 .. profilers.length];
        bytesSentPerProfiler_[] = 0;
    }

    /// Is there a Despiker instance (that we are sending to) running at the moment?
    bool sending() @safe pure nothrow const @nogc
    {
        return sending_;
    }

    /** Set the filter to used by Despiker to determine which zones are frames.
     *
     * Affects the following calls to startDespiker(), does not affect the running
     * Despiker instance, if any.
     */
    void frameFilter(DespikerFrameFilter rhs) @safe pure nothrow @nogc
    {
        assert(rhs.info != "NULL",
               "DespikerFrameFilter.info must not be set to string value \"NULL\"");
        frameFilter_ = rhs;
    }

    /** Open a Despiker window and start sending profiling data to it.
     *
     * Can only be called when sending is false (after DespikerSender construction
     * or reset).
     *
     * By default, looks for the Despiker binary in the following order:
     *
     * 0: defaultPath, if specified
     * 1: 'despiker' in current working directory
     * 2: 'despiker' in directory of the running binary
     * 3: 'despiker' in PATH
     *
     * Note: the next update() call will send all profiling data recorded so far to the
     * Despiker.
     *
     * Throws:
     *
     * DespikerSenderException on failure (couldn't find or run Despiker in any of the
     * searched paths, or couldn't run Despiker with path specified by defaultPath).
     */
    void startDespiker(string defaultPath = null) @safe
    {
        assert(!sending_,
               "Can't startDespiker() while we're already sending to a running Despiker");

        string[] errorStrings;

        // Tries to run Despiker at specified path. Adds a string to errorStrings on failure.
        bool runDespiker(string path) @trusted nothrow
        {
            import std.stdio: StdioException;
            try
            {
                import std.conv: to;
                // Pass the frame filter through command-line arguments.
                auto args = [path,
                             "--frameInfo",
                             // "NULL" represents "don't care about frame info"
                             frameFilter_.info is null ? "NULL" : frameFilter_.info,
                             "--frameNestLevel",
                             to!string(frameFilter_.nestLevel)];
                despikerPipes_ = pipeProcess(args, Redirect.stdin);
                sending_ = true;
                return true;
            }
            catch(ProcessException e) { errorStrings ~= e.msg; }
            catch(StdioException e)   { errorStrings ~= e.msg; }
            catch(Exception e)
            {
                assert(false, "Unexpected exception when trying to start Despiker");
            }

            return false;
        }

        // Path specified by the user.
        if(defaultPath !is null && runDespiker(defaultPath))
        {
            return;
        }

        import std.file: thisExePath;
        import std.path: dirName, buildPath;
        // User didn't specify a path, we have to find Despiker ourselves.
        // Try current working directory first, then the directory the game binary is
        // in, then a despiker installation in $PATH
        auto paths = ["./despiker",
                      thisExePath().dirName.buildPath("despiker"),
                      "despiker"];

        foreach(path; paths) if(runDespiker(path))
        {
            return;
        }

        throw new DespikerSenderException
            ("Failed to start Despiker.\n "
             "Tried to look for it in:\n "
             ~ defaultPath is null
               ? "" : "0: path provided by caller: '%s'\n".format(defaultPath) ~
             "1: working directory, 2: directory of the running binary, 3: PATH.\n"
             "Got errors:\n" ~ errorStrings.join("\n"));
    }

    /** Resets the sender.
     *
     * If Despiker is running, 'forgets' it, stops sending to it without closing it and
     * the next startDespiker() call will launch a new Despiker instance.
     */
    void reset() @trusted nothrow @nogc
    {
        sending_ = false;
        // Not @nogc yet, although ProcessPipes destruction should not use GC. 
        // Probably don't need to explicitly destroy this here anyway.
        // destroy(despikerPipes_).assumeWontThrow;
        bytesSentPerProfiler_[] = 0;
    }

    import std.stdio;
    /** Update the sender.
     *
     * Must not be called if any profilers passed to DespikerSender constructor are in a
     * zone, or are being accessed by other threads (any synchronization must be handled
     * by the caller).
     */
    void update() @trusted nothrow
    {
        assert(!profilers_.canFind!(p => p.zoneNestLevel > 0),
               "Can't update DespikerSender while one or more profilers are in a zone");

        if(!sending_) { return; }
        // Check if Despiker got closed.
        try
        {
            // tryWait may fail. There is no 'nice' way to handle that.
            auto status = tryWait(despikerPipes_.pid);

            if(status.terminated)
            {
                // Non-zero status means Despiker had an error.
                if(status.status != 0)
                {
                    writeln("Despiker exited (crashed?) with non-zero status: ", status.status)
                           .assumeWontThrow;
                }
                reset();
                return;
            }
        }
        catch(ProcessException e)
        {
            writefln("tryWait failed: %s; assuming Despiker dead", e.msg).assumeWontThrow;
            reset();
            return;
        }
        catch(Exception e) { assert(false, "Unexpected exception"); }

        send().assumeWontThrow;
        foreach(profiler; profilers_) { profiler.checkpointEvent(); }
    }

private:
    /** Send profiled data (since the last send()) to Despiker.
     *
     * Despite not being nothrow, should never throw.
     */
    void send() @trusted
    {
        try foreach(uint threadIdx, profiler; profilers_)
        {
            const data = profiler.profileData;
            const newData = data[bytesSentPerProfiler_[threadIdx] .. $];

            import std.array;
            if(newData.empty) { continue; }
            const uint bytes = cast(uint)newData.length;
            // Send a chunk of raw profile data perfixed by a header of two 32-bit uints:
            // thread index and chunks size in bytes.
            uint[2] header;
            header[0] = threadIdx;
            header[1] = bytes;
            despikerPipes_.stdin.rawWrite(header[]);
            despikerPipes_.stdin.rawWrite(newData);
            // Ensure 'somewhat real-time' sending.
            despikerPipes_.stdin.flush();

            assert(bytesSentPerProfiler_[threadIdx] + newData.length == data.length,
                   "Newly sent data doesn't add up to all recorded data");

            bytesSentPerProfiler_[threadIdx] = data.length;
        }
        catch(ErrnoException e) { writeln("Failed to send data to despiker: ", e); }
        catch(Exception e) { writeln("Unhandled exception while sending to despiker: ", e); }
    }
}

/** Used to tell Despiker which zones are 'frames'.
 *
 * Despiker displays one frame at a time, and it lines up frames from multiple profilers
 * enable profiling multiple threads. Properties of this struct determine which zones will
 * be considered frames by Despiker.
 *
 * By default, it is enough to use a zone with info string set to "frame" (and to ensure
 * no other zone uses the same info string).
 */
struct DespikerFrameFilter
{
    /** Info string of a zone must be equal to this for that zone to be considered a frame.
     *
     * If null, zone info does not determine which zones are frames. Must not be set to
     * string value "NULL".
     */
    string info = "frame";

    /** Nest level of a zone must be equal to this for that zone to be considered a frame.
     *
     * If 0, zone nest level does not determine which zones are frames.
     */
    ushort nestLevel = 0;
}

