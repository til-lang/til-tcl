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
