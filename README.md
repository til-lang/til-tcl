# til-tcl

Run Tcl scripts from Til.

## Build

1. `make`

## Usage

```tcl
scope "setting and retrieving values on Tcl" {
    tcl | autoclose | as interp
    run $interp {{
        set a 1
        set b 2
        set x [expr {$a + $b}]
    }}
    assert $(<$interp x> == "3")
}
```

This package **does not** evaluate the returned values: anything coming
from Tcl is a Til `string`. It's up to the developer to use `eval` or not
on returned values.

### Tcl_Init

`Tcl_Init` function is called as part of `open $interp`. This method is
called automatically by Til's `autoclose`. If you prefer to **not**
initialize the Tcl interpreter, avoid `autoclose`, so that `open` method
don't get called.

### Interacting with Til's code

```tcl
scope "call a Til's proc and make use of the return" {
    tcl | autoclose | as t
    set result 0
    proc add2 (x y) {
        return $($x + $y)
    }
    proc set_result (x) {
        print "set_result $x"
        uplevel set result $x
        print " done"
        print " result is $result"
    }
    # Export these 2 procs from this scope into $t Tcl interpreter:
    export $t add2 set_result
    run $t {{
        # Calls Til's procedures:
        set x [add2 11 22]
        set_result $x
    }}
    print "result is $result"
    assert $($result == 33)
}
```

### export and export.fast

Let's take the following excerpt of code as an example:

```tcl
run $interpreter {{
    til_proc 1 2.3
}}
```

If `til_proc` was exported into `$interpreter` using `export`, that means
that it is going to receive *the integer 1* and *the floating-point 2.3*
as arguments.

But if `til_proc` was exported into `$interpreter` using `export.fast`, it
is going to receive *the string "1"* and *the string "2.3"* as arguments.

That's because commands going through `export` have their correspondent
calls **evaluated** as Til grammar, while those going through
`export.fast` are simply called with all arguments as strings. The later
tends to be much faster than the former and is recommended when you don't
really need to parse *every* argument.
