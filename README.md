# Boehm-Demers-Weiser Garbage Collector

[![Travis-CI build status](https://travis-ci.com/ivmai/bdwgc.svg?branch=master)](https://travis-ci.com/ivmai/bdwgc)
[![AppVeyor CI build status](https://ci.appveyor.com/api/projects/status/github/ivmai/bdwgc?branch=master&svg=true)](https://ci.appveyor.com/project/ivmai/bdwgc)
[![Codecov.io](https://codecov.io/github/ivmai/bdwgc/coverage.svg?branch=master)](https://codecov.io/github/ivmai/bdwgc?branch=master)
[![Coveralls test coverage status](https://coveralls.io/repos/github/ivmai/bdwgc/badge.png?branch=master)](https://coveralls.io/github/ivmai/bdwgc)
[![Coverity Scan build status](https://scan.coverity.com/projects/10813/badge.svg)](https://scan.coverity.com/projects/ivmai-bdwgc)
[![LGTM Code Quality: Cpp](https://img.shields.io/lgtm/grade/cpp/g/ivmai/bdwgc.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/ivmai/bdwgc/context:cpp)
[![LGTM Total Alerts](https://img.shields.io/lgtm/alerts/g/ivmai/bdwgc.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/ivmai/bdwgc/alerts)

[![Hits-of-Code](https://hitsofcode.com/github/ivmai/bdwgc?branch=master)](https://hitsofcode.com/github/ivmai/bdwgc/view)
[![Lines of code](https://img.shields.io/tokei/lines/github/ivmai/bdwgc)](https://shields.io/category/size)
[![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/ivmai/bdwgc)](https://shields.io/category/size)
[![Github All Releases](https://img.shields.io/github/downloads/ivmai/bdwgc/total.svg)](https://shields.io/category/downloads)

This is version 8.1.0 (next release development) of a conservative garbage
collector for C and C++.


## Download

You might find a more recent/stable version on the
[Download](https://github.com/ivmai/bdwgc/wiki/Download) page, or
[BDWGC site](http://www.hboehm.info/gc/).

Also, the latest bug fixes and new features are available in the
[development repository](https://github.com/ivmai/bdwgc).


## Overview

This is intended to be a general purpose, garbage collecting storage
allocator.  The algorithms used are described in:

 * Boehm, H., and M. Weiser, "Garbage Collection in an Uncooperative
   Environment", Software Practice & Experience, September 1988, pp. 807-820.

 * Boehm, H., A. Demers, and S. Shenker, "Mostly Parallel Garbage Collection",
   Proceedings of the ACM SIGPLAN '91 Conference on Programming Language Design
   and Implementation, SIGPLAN Notices 26, 6 (June 1991), pp. 157-164.

 * Boehm, H., "Space Efficient Conservative Garbage Collection", Proceedings
   of the ACM SIGPLAN '91 Conference on Programming Language Design and
   Implementation, SIGPLAN Notices 28, 6 (June 1993), pp. 197-206.

 * Boehm H., "Reducing Garbage Collector Cache Misses", Proceedings of the
   2000 International Symposium on Memory Management.

Possible interactions between the collector and optimizing compilers are
discussed in

 * Boehm, H., and D. Chase, "A Proposal for GC-safe C Compilation",
   The Journal of C Language Translation 4, 2 (December 1992).

and

 * Boehm H., "Simple GC-safe Compilation", Proceedings of the ACM SIGPLAN '96
   Conference on Programming Language Design and Implementation.

Unlike the collector described in the second reference, this collector
operates either with the mutator stopped during the entire collection
(default) or incrementally during allocations.  (The latter is supported
on fewer machines.)  On the most common platforms, it can be built
with or without thread support.  On a few platforms, it can take advantage
of a multiprocessor to speed up garbage collection.

Many of the ideas underlying the collector have previously been explored
by others.  Notably, some of the run-time systems developed at Xerox PARC
in the early 1980s conservatively scanned thread stacks to locate possible
pointers (cf. Paul Rovner, "On Adding Garbage Collection and Runtime Types
to a Strongly-Typed Statically Checked, Concurrent Language" Xerox PARC
CSL 84-7).  Doug McIlroy wrote a simpler fully conservative collector that
was part of version 8 UNIX (tm), but appears to not have received
widespread use.

Rudimentary tools for use of the collector as a
[leak detector](doc/leak.md) are included,
as is a fairly sophisticated string package "cord" that makes use of the
collector.  (See doc/README.cords and H.-J. Boehm, R. Atkinson, and M. Plass,
"Ropes: An Alternative to Strings", Software Practice and Experience 25, 12
(December 1995), pp. 1315-1330.  This is very similar to the "rope" package
in Xerox Cedar, or the "rope" package in the SGI STL or the g++ distribution.)

Further collector documentation can be found in the
[overview](doc/overview.md).


## General Description

This is a garbage collecting storage allocator that is intended to be
used as a plug-in replacement for C's malloc.

Since the collector does not require pointers to be tagged, it does not
attempt to ensure that all inaccessible storage is reclaimed.  However,
in our experience, it is typically more successful at reclaiming unused
memory than most C programs using explicit deallocation.  Unlike manually
introduced leaks, the amount of unreclaimed memory typically stays
bounded.

In the following, an "object" is defined to be a region of memory allocated
by the routines described below.

Any objects not intended to be collected must be pointed to either
from other such accessible objects, or from the registers,
stack, data, or statically allocated bss segments.  Pointers from
the stack or registers may point to anywhere inside an object.
The same is true for heap pointers if the collector is compiled with
`ALL_INTERIOR_POINTERS` defined, or `GC_all_interior_pointers` is otherwise
set, as is now the default.

Compiling without `ALL_INTERIOR_POINTERS` may reduce accidental retention
of garbage objects, by requiring pointers from the heap to the beginning
of an object.  But this no longer appears to be a significant
issue for most programs occupying a small fraction of the possible
address space.

There are a number of routines which modify the pointer recognition
algorithm.  `GC_register_displacement` allows certain interior pointers
to be recognized even if `ALL_INTERIOR_POINTERS` is not defined.
`GC_malloc_ignore_off_page` allows some pointers into the middle of
large objects to be disregarded, greatly reducing the probability of
accidental retention of large objects.  For most purposes it seems
best to compile with `ALL_INTERIOR_POINTERS` and to use
`GC_malloc_ignore_off_page` if you get collector warnings from
allocations of very large objects.  See [here](doc/debugging.md) for details.

_WARNING_: pointers inside memory allocated by the standard `malloc` are not
seen by the garbage collector.  Thus objects pointed to only from such a
region may be prematurely deallocated.  It is thus suggested that the
standard `malloc` be used only for memory regions, such as I/O buffers, that
are guaranteed not to contain pointers to garbage collectible memory.
Pointers in C language automatic, static, or register variables,
are correctly recognized.  (Note that `GC_malloc_uncollectable` has
semantics similar to standard malloc, but allocates objects that are
traced by the collector.)

_WARNING_: the collector does not always know how to find pointers in data
areas that are associated with dynamic libraries.  This is easy to
remedy IF you know how to find those data areas on your operating
system (see `GC_add_roots`).  Code for doing this under SunOS, IRIX
5.X and 6.X, HP/UX, Alpha OSF/1, Linux, and win32 is included and used
by default.  (See doc/README.win32 for Win32 details.)  On other systems
pointers from dynamic library data areas may not be considered by the
collector.  If you're writing a program that depends on the collector
scanning dynamic library data areas, it may be a good idea to include
at least one call to `GC_is_visible` to ensure that those areas are
visible to the collector.

Note that the garbage collector does not need to be informed of shared
read-only data.  However, if the shared library mechanism can introduce
discontiguous data areas that may contain pointers then the collector does
need to be informed.

Signal processing for most signals may be deferred during collection,
and during uninterruptible parts of the allocation process.
Like standard ANSI C mallocs, by default it is unsafe to invoke
malloc (and other GC routines) from a signal handler while another
malloc call may be in progress.

The allocator/collector can also be configured for thread-safe operation.
(Full signal safety can also be achieved, but only at the cost of two system
calls per malloc, which is usually unacceptable.)

_WARNING_: the collector does not guarantee to scan thread-local storage
(e.g. of the kind accessed with `pthread_getspecific`).  The collector
does scan thread stacks, though, so generally the best solution is to
ensure that any pointers stored in thread-local storage are also
stored on the thread's stack for the duration of their lifetime.
(This is arguably a longstanding bug, but it hasn't been fixed yet.)


## Installation and Portability

The collector operates silently in the default configuration.
In the event of problems, this can usually be changed by defining the
`GC_PRINT_STATS` or `GC_PRINT_VERBOSE_STATS` environment variables.  This
will result in a few lines of descriptive output for each collection.
(The given statistics exhibit a few peculiarities.
Things don't appear to add up for a variety of reasons, most notably
fragmentation losses.  These are probably much more significant for the
contrived program "test.c" than for your application.)

On most Unix-like platforms, the collector can be built either using a
GNU autoconf-based build infrastructure (type `./configure; make` in the
simplest case), or with a classic makefile by itself (type
`make -f Makefile.direct`).

Please note that the collector source repository does not contain configure
and similar auto-generated files, thus the full procedure of autoconf-based
build of `master` branch of the collector could look like:

    git clone git://github.com/ivmai/bdwgc.git
    cd bdwgc
    git clone git://github.com/ivmai/libatomic_ops.git
    ./autogen.sh
    ./configure
    make -j
    make check

Cloning of `libatomic_ops` is now optional provided the compiler supports
atomic intrinsics.

Below we focus on the collector build using classic makefile.
For the Makefile.direct-based process, typing `make check` instead of `make`
will automatically build the collector and then run `setjmp_test` and `gctest`.
`Setjmp_test` will give you information about configuring the collector, which is
useful primarily if you have a machine that's not already supported.  Gctest is
a somewhat superficial test of collector functionality.  Failure is indicated
by a core dump or a message to the effect that the collector is broken.  Gctest
takes about a second to two to run on reasonable 2007 vintage desktops.  It may
use up to about 30 MB of memory.  (The multi-threaded version will use more.
64-bit versions may use more.) `make check` will also, as its last step,
attempt to build and test the "cord" string library.)

Makefile.direct will generate a library gc.a which you should link against.
Typing "make cords" will build the cord library (cord.a).

The GNU style build process understands the usual targets.  `make check`
runs a number of tests.  `make install` installs at least libgc, and libcord.
Try `./configure --help` to see the configuration options.  It is currently
not possible to exercise all combinations of build options this way.

All include files that need to be used by clients will be put in the
include subdirectory.  (Normally this is just gc.h.  `make cords` adds
"cord.h" and "ec.h".)

The collector currently is designed to run essentially unmodified on
machines that use a flat 32-bit or 64-bit address space.
That includes the vast majority of Workstations and X86 (X >= 3) PCs.

In a few cases (Amiga, OS/2, Win32, MacOS) a separate makefile
or equivalent is supplied.  Many of these have separate README.system
files.

Dynamic libraries are completely supported only under SunOS/Solaris,
(and even that support is not functional on the last Sun 3 release),
Linux, FreeBSD, NetBSD, IRIX 5&6, HP/UX, Win32 (not Win32S) and OSF/1
on DEC AXP machines plus perhaps a few others listed near the top
of dyn_load.c.  On other machines we recommend that you do one of
the following:

  1. Add dynamic library support (and send us the code).
  2. Use static versions of the libraries.
  3. Arrange for dynamic libraries to use the standard malloc. This is still
  dangerous if the library stores a pointer to a garbage collected object.
  But nearly all standard interfaces prohibit this, because they deal
  correctly with pointers to stack allocated objects.  (`strtok` is an
  exception.  Don't use it.)

In all cases we assume that pointer alignment is consistent with that
enforced by the standard C compilers.  If you use a nonstandard compiler
you may have to adjust the alignment parameters defined in gc_priv.h.
Note that this may also be an issue with packed records/structs, if those
enforce less alignment for pointers.

A port to a machine that is not byte addressed, or does not use 32 bit
or 64 bit addresses will require a major effort.  A port to plain MSDOS
or win16 is hard.

For machines not already mentioned, or for nonstandard compilers,
some porting suggestions are provided [here](doc/porting.md).


## The C Interface to the Allocator

The following routines are intended to be directly called by the user.
Note that usually only `GC_malloc` is necessary.  `GC_clear_roots` and
`GC_add_roots` calls may be required if the collector has to trace
from nonstandard places (e.g. from dynamic library data areas on a
machine on which the collector doesn't already understand them.)  On
some machines, it may be desirable to set `GC_stackbottom` to a good
approximation of the stack base (bottom).

Client code may include "gc.h", which defines all of the following, plus many
others.

  1. `GC_malloc(bytes)` - Allocate an object of a given size.  Unlike malloc,
  the object is cleared before being returned to the user.  `GC_malloc` will
  invoke the garbage collector when it determines this to be appropriate.
  GC_malloc may return 0 if it is unable to acquire sufficient space from the
  operating system.  This is the most probable consequence of running out
  of space.  Other possible consequences are that a function call will fail
  due to lack of stack space, or that the collector will fail in other ways
  because it cannot maintain its internal data structures, or that a crucial
  system process will fail and take down the machine.  Most of these
  possibilities are independent of the malloc implementation.

  2. `GC_malloc_atomic(bytes)` - Allocate an object of a given size that
  is guaranteed not to contain any pointers.  The returned object is not
  guaranteed to be cleared. (Can always be replaced by `GC_malloc`, but
  results in faster collection times.  The collector will probably run faster
  if large character arrays, etc. are allocated with `GC_malloc_atomic` than
  if they are statically allocated.)

  3. `GC_realloc(object, new_bytes)` - Change the size of object to be of
  a given size.  Returns a pointer to the new object, which may, or may not,
  be the same as the pointer to the old object.  The new object is taken to
  be atomic if and only if the old one was.  If the new object is composite
  and larger than the original object then the newly added bytes are cleared.
  This is very likely to allocate a new object.

  4. `GC_free(object)` - Explicitly deallocate an object returned by
  `GC_malloc` or `GC_malloc_atomic`, or friends.  Not necessary, but can be
  used to minimize collections if performance is critical.  Probably
  a performance loss for very small objects (<= 8 bytes).

  5. `GC_expand_hp(bytes)` - Explicitly increase the heap size.  (This is
  normally done automatically if a garbage collection failed to reclaim
  enough memory.  Explicit calls to `GC_expand_hp` may prevent unnecessarily
  frequent collections at program startup.)

  6. `GC_malloc_ignore_off_page(bytes)` - Identical to `GC_malloc`, but the
  client promises to keep a pointer to the somewhere within the first 256
  bytes of the object while it is live.  (This pointer should normally be
  declared volatile to prevent interference from compiler optimizations.)
  This is the recommended way to allocate anything that is likely to be
  larger than 100 KB or so.  (`GC_malloc` may result in a failure to reclaim
  such objects.)

  7. `GC_set_warn_proc(proc)` - Can be used to redirect warnings from the
  collector.  Such warnings should be rare, and should not be ignored during
  code development.

  8. `GC_enable_incremental()` - Enables generational and incremental
  collection.  Useful for large heaps on machines that provide access to page
  dirty information.  Some dirty bit implementations may interfere with
  debugging (by catching address faults) and place restrictions on heap
  arguments to system calls (since write faults inside a system call may not
  be handled well).

  9. `GC_register_finalizer(object, proc, data, 0, 0)` and friends - Allow for
  registration of finalization code.  User supplied finalization code
  (`(*proc)(object, data)`) is invoked after object becomes unreachable.
  For more sophisticated uses, and for finalization ordering issues, see gc.h.

The global variable `GC_free_space_divisor` may be adjusted up from it
default value of 3 to use less space and more collection time, or down for
the opposite effect.  Setting it to 1 will almost disable collections
and cause all allocations to simply grow the heap.

The variable `GC_non_gc_bytes`, which is normally 0, may be changed to reflect
the amount of memory allocated by the above routines that should not be
considered as a candidate for collection.  Careless use may, of course, result
in excessive memory consumption.

Some additional tuning is possible through the parameters defined
near the top of gc_priv.h.

If only `GC_malloc` is intended to be used, it might be appropriate to define:

    #define malloc(n) GC_malloc(n)
    #define calloc(m,n) GC_malloc((m)*(n))

For small pieces of VERY allocation intensive code, gc_inline.h includes
some allocation macros that may be used in place of `GC_malloc` and
friends.

All externally visible names in the garbage collector start with `GC_`.
To avoid name conflicts, client code should avoid this prefix, except when
accessing garbage collector routines.

There are provisions for allocation with explicit type information.
This is rarely necessary.  Details can be found in gc_typed.h.


## The C++ Interface to the Allocator

The Ellis-Hull C++ interface to the collector is included in the collector
distribution.  If you intend to use this, type
`./configure --enable-cplusplus; make` (or `make -f Makefile.direct c++`)
after the initial build of the collector is complete.  See gc_cpp.h for the
definition of the interface.  This interface tries to approximate the
Ellis-Detlefs C++ garbage collection proposal without compiler changes.

Very often it will also be necessary to use gc_allocator.h and the
allocator declared there to construct STL data structures.  Otherwise
subobjects of STL data structures will be allocated using a system
allocator, and objects they refer to may be prematurely collected.


## Use as Leak Detector

The collector may be used to track down leaks in C programs that are
intended to run with malloc/free (e.g. code with extreme real-time or
portability constraints).  To do so define `FIND_LEAK` in Makefile.
This will cause the collector to print a human-readable object description
whenever an inaccessible object is found that has not been explicitly freed.
Such objects will also be automatically reclaimed.

If all objects are allocated with `GC_DEBUG_MALLOC` (see the next section)
then, by default, the human-readable object description will at least contain
the source file and the line number at which the leaked object was allocated.
This may sometimes be sufficient.  (On a few machines, it will also report
a cryptic stack trace.  If this is not symbolic, it can sometimes be called
into a symbolic stack trace by invoking program "foo" with
`tools/callprocs.sh foo`.  It is a short shell script that invokes adb to
expand program counter values to symbolic addresses.  It was largely supplied
by Scott Schwartz.)

Note that the debugging facilities described in the next section can
sometimes be slightly LESS effective in leak finding mode, since in the latter
`GC_debug_free` actually results in reuse of the object.  (Otherwise the
object is simply marked invalid.)  Also, note that most GC tests are not
designed to run meaningfully in `FIND_LEAK` mode.


## Debugging Facilities

The routines `GC_debug_malloc`, `GC_debug_malloc_atomic`, `GC_debug_realloc`,
and `GC_debug_free` provide an alternate interface to the collector, which
provides some help with memory overwrite errors, and the like.
Objects allocated in this way are annotated with additional
information.  Some of this information is checked during garbage
collections, and detected inconsistencies are reported to stderr.

Simple cases of writing past the end of an allocated object should
be caught if the object is explicitly deallocated, or if the
collector is invoked while the object is live.  The first deallocation
of an object will clear the debugging info associated with an
object, so accidentally repeated calls to `GC_debug_free` will report the
deallocation of an object without debugging information.  Out of
memory errors will be reported to stderr, in addition to returning `NULL`.

`GC_debug_malloc` checking during garbage collection is enabled
with the first call to this function.  This will result in some
slowdown during collections.  If frequent heap checks are desired,
this can be achieved by explicitly invoking `GC_gcollect`, e.g. from
the debugger.

`GC_debug_malloc` allocated objects should not be passed to `GC_realloc`
or `GC_free`, and conversely.  It is however acceptable to allocate only
some objects with `GC_debug_malloc`, and to use `GC_malloc` for other objects,
provided the two pools are kept distinct.  In this case, there is a very
low probability that `GC_malloc` allocated objects may be misidentified as
having been overwritten.  This should happen with probability at most
one in 2**32.  This probability is zero if `GC_debug_malloc` is never called.

`GC_debug_malloc`, `GC_debug_malloc_atomic`, and `GC_debug_realloc` take two
additional trailing arguments, a string and an integer.  These are not
interpreted by the allocator.  They are stored in the object (the string is
not copied).  If an error involving the object is detected, they are printed.

The macros `GC_MALLOC`, `GC_MALLOC_ATOMIC`, `GC_REALLOC`, `GC_FREE`,
`GC_REGISTER_FINALIZER` and friends are also provided.  These require the same
arguments as the corresponding (nondebugging) routines.  If gc.h is included
with `GC_DEBUG` defined, they call the debugging versions of these
functions, passing the current file name and line number as the two
extra arguments, where appropriate.  If gc.h is included without `GC_DEBUG`
defined then all these macros will instead be defined to their nondebugging
equivalents.  (`GC_REGISTER_FINALIZER` is necessary, since pointers to
objects with debugging information are really pointers to a displacement
of 16 bytes from the object beginning, and some translation is necessary
when finalization routines are invoked.  For details, about what's stored
in the header, see the definition of the type oh in dbg_mlc.c file.)


## Incremental/Generational Collection

The collector normally interrupts client code for the duration of
a garbage collection mark phase.  This may be unacceptable if interactive
response is needed for programs with large heaps.  The collector
can also run in a "generational" mode, in which it usually attempts to
collect only objects allocated since the last garbage collection.
Furthermore, in this mode, garbage collections run mostly incrementally,
with a small amount of work performed in response to each of a large number of
`GC_malloc` requests.

This mode is enabled by a call to `GC_enable_incremental`.

Incremental and generational collection is effective in reducing
pause times only if the collector has some way to tell which objects
or pages have been recently modified.  The collector uses two sources
of information:

  1. Information provided by the VM system.  This may be provided in one of
  several forms.  Under Solaris 2.X (and potentially under other similar
  systems) information on dirty pages can be read from the /proc file system.
  Under other systems (e.g. SunOS4.X) it is possible to write-protect
  the heap, and catch the resulting faults. On these systems we require that
  system calls writing to the heap (other than read) be handled specially by
  client code. See `os_dep.c` for details.

  2. Information supplied by the programmer.  The object is considered dirty
  after a call to `GC_end_stubborn_change` provided the library has been
  compiled suitably. It is typically not worth using for short-lived objects.
  Note that bugs caused by a missing `GC_end_stubborn_change` or
  `GC_reachable_here` call are likely to be observed very infrequently and
  hard to trace.


## Bugs

Any memory that does not have a recognizable pointer to it will be
reclaimed.  Exclusive-or'ing forward and backward links in a list
doesn't cut it.

Some C optimizers may lose the last undisguised pointer to a memory
object as a consequence of clever optimizations.  This has almost
never been observed in practice.

This is not a real-time collector.  In the standard configuration,
percentage of time required for collection should be constant across
heap sizes.  But collection pauses will increase for larger heaps.
They will decrease with the number of processors if parallel marking
is enabled.

(On 2007 vintage machines, GC times may be on the order of 5 ms
per MB of accessible memory that needs to be scanned and processed.
Your mileage may vary.)  The incremental/generational collection facility
may help in some cases.


## Feedback, Contribution, Questions and Notifications

Please address bug reports and new feature ideas to
[GitHub issues](https://github.com/ivmai/bdwgc/issues).  Before the
submission please check that it has not been done yet by someone else.

If you want to contribute, submit
a [pull request](https://github.com/ivmai/bdwgc/pulls) to GitHub.

If you need help, use
[Stack Overflow](https://stackoverflow.com/questions/tagged/boehm-gc).
Older technical discussions are available in `bdwgc` mailing list archive - it
can be downloaded as a
[compressed file](https://github.com/ivmai/bdwgc/files/1038163/bdwgc-mailing-list-archive-2017_04.tar.gz)
or browsed at [Narkive](http://bdwgc.opendylan.narkive.com).

To get new release announcements, subscribe to
[RSS feed](https://github.com/ivmai/bdwgc/releases.atom).
(To receive the notifications by email, a 3rd-party free service like
[IFTTT RSS Feed](https://ifttt.com/feed) can be setup.)
To be notified on all issues, please
[watch](https://github.com/ivmai/bdwgc/watchers) the project on
GitHub.


## Copyright & Warranty

 * Copyright (c) 1988, 1989 Hans-J. Boehm, Alan J. Demers
 * Copyright (c) 1991-1996 by Xerox Corporation.  All rights reserved.
 * Copyright (c) 1996-1999 by Silicon Graphics.  All rights reserved.
 * Copyright (c) 1999-2011 by Hewlett-Packard Development Company.
 * Copyright (c) 2008-2020 Ivan Maidanski

The files pthread_stop_world.c, pthread_support.c and some others are also

 * Copyright (c) 1998 by Fergus Henderson.  All rights reserved.

The file include/gc.h is also

 * Copyright (c) 2007 Free Software Foundation, Inc

The files Makefile.am and configure.ac are

 * Copyright (c) 2001 by Red Hat Inc. All rights reserved.

The files extra/msvc_dbg.c and include/private/msvc_dbg.h are

 * Copyright (c) 2004-2005 Andrei Polushin

The file tests/initsecondarythread.c is

 * Copyright (c) 2011 Ludovic Courtes

The file tests/disclaim_weakmap_test.c is

 * Copyright (c) 2018 Petter A. Urkedal

Several files supporting GNU-style builds are copyrighted by the Free
Software Foundation, and carry a different license from that given
below.

THIS MATERIAL IS PROVIDED AS IS, WITH ABSOLUTELY NO WARRANTY EXPRESSED
OR IMPLIED.  ANY USE IS AT YOUR OWN RISK.

Permission is hereby granted to use or copy this program
for any purpose,  provided the above notices are retained on all copies.
Permission to modify the code and to distribute modified code is granted,
provided the above notices are retained, and a notice that the code was
modified is included with the above copyright notice.

A few of the files needed to use the GNU-style build procedure come with
slightly different licenses, though they are all similar in spirit.  A few
are GPL'ed, but with an exception that should cover all uses in the
collector. (If you are concerned about such things, I recommend you look
at the notice in config.guess or ltmain.sh.)
