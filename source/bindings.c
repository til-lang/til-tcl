#include <tcl.h>

#define CAPACITY_STEP_SIZE 8

size_t tcl_interpreters_capacity = 0;
size_t tcl_interpreters_count = 0;
Tcl_Interp** tcl_interpreters;


size_t tclNewInterpreter()
{
    if (tcl_interpreters_capacity == tcl_interpreters_count)
    {
        size_t new_capacity = tcl_interpreters_capacity + CAPACITY_STEP_SIZE;
        size_t size = new_capacity * sizeof(Tcl_Interp*);
        if (tcl_interpreters_count == 0)
        {
            tcl_interpreters = (Tcl_Interp**)Tcl_Alloc(size);
        }
        else
        {
            tcl_interpreters = (Tcl_Interp**)Tcl_Realloc((void*)tcl_interpreters, size);
        }
        tcl_interpreters_capacity = new_capacity;
    }

    tcl_interpreters[tcl_interpreters_count] = Tcl_CreateInterp();
    return tcl_interpreters_count++;
}
void tclDeleteInterpreter(size_t interpreter_index)
{
    Tcl_Interp* interpreter = tcl_interpreters[interpreter_index];
    Tcl_DeleteInterp(interpreter);
}

int tclEval(size_t interpreter_index, char* script)
{
    Tcl_Interp* interpreter = tcl_interpreters[interpreter_index];
    return Tcl_Eval(interpreter, script);
}

const char* tclGetStringResult(size_t interpreter_index)
{
    Tcl_Interp* interpreter = tcl_interpreters[interpreter_index];
    return Tcl_GetStringResult(interpreter);
}

const char* tclGetVar(size_t interpreter_index, const char* name)
{
    Tcl_Interp* interpreter = tcl_interpreters[interpreter_index];
    return Tcl_GetVar(interpreter, name, 0);
}
