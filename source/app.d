import std.string : toStringz;

import til.nodes;


extern (C) size_t tclNewInterpreter();
extern (C) int tclInit(size_t interpreter_index);
extern (C) void tclDeleteInterpreter(size_t interpreter_index);
extern (C) int tclEval(size_t interpreter_index, char* script);
extern (C) char* tclGetVar(size_t interpreter_index, const char* name);
extern (C) char* tclGetStringResult(size_t interpreter_index);


CommandsMap tclCommands;

class TclInterpreter : Item
{
    size_t index;

    this()
    {
        this.commands = tclCommands;
        index = tclNewInterpreter();
    }
    int init()
    {
        return tclInit(index);
    }
    void close()
    {
        tclDeleteInterpreter(index);
    }
    int run(string script)
    {
        return tclEval(index, cast(char*)script.toStringz());
    }
    string getResult()
    {
        return to!string(tclGetStringResult(index));
    }
    string opIndex(string name)
    {
        return to!string(tclGetVar(index, name.toStringz));
    }

    override string toString()
    {
        return "Tcl interpreter " ~ to!string(index);
    }
}


extern (C) CommandsMap getCommands(Escopo escopo)
{
    CommandsMap commands;

    // tcl | as interp
    commands[null] = new Command((string path, Context context)
    {
        debug {stderr.writeln("Creating Tcl interpreter...");}
        return context.push(new TclInterpreter());
    });
    // for autoclose:
    tclCommands["open"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();
        debug {stderr.writeln("tcl.open:", interp);}
        int exitCode = interp.init();
        if (exitCode != 0)
        {
            return context.error(interp.getResult(), exitCode, "tcl");
        }
        return context;
    });
    tclCommands["close"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();
        debug {stderr.writeln("tcl.close:", interp);}
        interp.close();
        return context;
    });

    // run $interp {{ set x 123 }}
    tclCommands["run"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();
        auto script = context.pop!string();
        debug {stderr.writeln("tcl.run:", interp, " : ", script, " (", context.size, ")");}
        auto exitCode = interp.run(script);
        if (exitCode == 1)
        {
            return context.error(interp.getResult(), exitCode, "tcl");
        }
        // TODO: handle 2 (return), 3 (break) and 4 (continue)
        return context.push(interp.getResult());
    });
    tclCommands["extract"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();
        auto name = context.pop!string();
        debug {stderr.writeln("tcl.extract:", interp, " ", name);}
        return context.push(interp[name]);
    });

    return commands;
}
