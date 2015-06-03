============
Tharsis.prof
============

.. image:: https://travis-ci.org/kiith-sa/tharsis.prof.svg?branch=master
.. image:: https://raw.githubusercontent.com/kiith-sa/tharsis.prof/master/code.dlang.org-shield.png
   :target: http://code.dlang.org


------------
Introduction
------------

Tharsis.prof is an open source `frame-based profiler
<http://defenestrate.eu/2014/09/05/frame_based_game_profiling.html>`_ library for the
D programming language. A frame-based profiler keeps track of overhead separately for
individual frames in a game. This is useful to track down issues with inconsistent
overhead (such as lag that appears only once in a few seconds) that are hard to detect
with conventional profilers.

Tharsis.prof is designed to be easy to use and lightweight. See the example below to get
started.

Note that this is still a **work in progress**. The API is not stable and there might be
compatibility **breaking changes** in future.


---------------
Getting started
---------------

Assuming you use `dub <http://code.dlang.org/about>`_, add this line::

   "tharsis.prof": { "version" : "~>0.5.0" }

to the ``"dependencies"`` in your project's ``dub.json``/``package.json``.


* Recording profiling data:

  .. code-block:: d

     import tharsis.prof;

     // Get 2 MB more than the minimum (maxEventBytes). Could also use malloc() here.
     ubyte[] storage = new ubyte[Profiler.maxEventBytes + 1024 * 1024 * 2];
     // Could use std.typecons.scoped! to avoid GC here.
     auto profiler = new Profiler(storage);

     while(!done)
     {
         auto frameZone = Zone(profiler, "frame");
         {
             auto renderingZone = Zone(profiler, "rendering");

             // do rendering here
         }
         {
             auto physicsZone = Zone(profiler, "physics");

             // do physics here
         }
     }

* Visualizing profiling data in real-time:

  See the `Despiker <https://github.com/kiith-sa/despiker>`_ project
  (`tutorial <http://defenestrate.eu/docs/despiker/tutorials/getting_started.html>`_).


* Processing profiling data in code:

  .. code-block:: d

      // Filter all instances of the "frame" zone
      auto zones = profiler.profileData.zoneRange;
      auto frames = zones.filter!(z => z.info == "frame");

      // Sort the frames by duration from longest to shortest.
      import std.container;
      // Builds an RAII array containing zones from frames. We need an array as we need
      // random access to sort the zones (ZoneRange generates ZoneData on-the-fly as it
      // processes profiling data, so it has no random access).
      auto frameArray = Array!ZoneData(frames);
      frameArray[].sort!((a, b) => a.duration > b.duration);

      import std.stdio;
      // Print the 4 longest frames.
      foreach(frame; frameArray[0 .. 4])
      {
          // In hectonanoseconds (tenths of microsecond)
          writeln(frame.duration);
      }

      // Print details about all zones in the worst frame.
      auto worst = frameArray[0];
      foreach(zone; zones.filter!(z => z.startTime >= worst.startTime && z.endTime <= worst.endTime))
      {
          writefln("%s: %s hnsecs from %s to %s",
                   zone.info, zone.duration, zone.startTime, zone.endTime);
      }


For detailed documentation with more specific code examples, see the `documentation
<http://ddocs.org/tharsis-prof/latest/index.html>`_.


--------
Features
--------

* Easy to use, RAII-style API for recording profiling data.
* Can be used together with `Despiker <https://github.com/kiith-sa/despiker>`_ to visually
  profile a game in real time (`tutorial
  <http://defenestrate.eu/docs/despiker/tutorials/getting_started.html>`_).
* Detailed `API documentation <http://ddocs.org/tharsis-prof/latest/index.html>`_ (on `DDocs.org <http://ddocs.org>`_)
  with code examples.
* Profile data can be analyzed in real time within a game (between frames, or top-level
  zones)
* `Range-based API
  <http://defenestrate.eu/2014/09/05/frame_based_profiling_with_d_ranges.html>`_ for
  analyzing profile data; works with ``std.algorithm`` and other Phobos modules.
* No GC usage and no internal heap allocations (user must provide memory explicitly),
  except for exception handling if sending data to `Despiker
  <https://github.com/kiith-sa/despiker>`_
* Designed to use as little memory as possible in heavy workloads (but it can still use
  quite a lot). *Memory usage in light workloads has been improved*.
* Uses high-precision clocks (hectonanosecond - tenth of microsecond - precision).
* Can be used to record variable values (e.g. FPS) over time.


-------------------
Directory structure
-------------------

===============  =======================================================================
Directory        Contents
===============  =======================================================================
``./``           This README, auxiliary files.
``./doc``        Documentation.
``./source``     Source code.
===============  =======================================================================


-------
License
-------

Tharsis.prof is released under the terms of the
`Boost Software License 1.0 <http://www.boost.org/LICENSE_1_0.txt>`_.
This license allows you to use the source code in your own projects, open source
or proprietary, and to modify it to suit your needs. However, in source
distributions, you have to preserve the license headers in the source code and
the accompanying license file.

Full text of the license can be found in file ``LICENSE_1_0.txt`` and is also
displayed here::

    Boost Software License - Version 1.0 - August 17th, 2003

    Permission is hereby granted, free of charge, to any person or organization
    obtaining a copy of the software and accompanying documentation covered by
    this license (the "Software") to use, reproduce, display, distribute,
    execute, and transmit the Software, and to prepare derivative works of the
    Software, and to permit third-parties to whom the Software is furnished to
    do so, all subject to the following:

    The copyright notices in the Software and this entire statement, including
    the above license grant, this restriction and the following disclaimer,
    must be included in all copies of the Software, in whole or in part, and
    all derivative works of the Software, unless such copies or derivative
    works are solely in the form of machine-executable object code generated by
    a source language processor.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
    SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
    FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.


-------
Credits
-------

Tharsis.prof was created by Ferdinand Majerech aka Kiith-Sa kiithsacmp[AT]gmail.com .

Tharsis.prof was made with Vim and DMD on Linux Mint as a frame profiling library for the
`D programming language <http://www.dlang.org>`_. See more D libraries and projects at
`code.dlang.org <http://code.dlang.org>`_.
