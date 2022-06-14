import std.stdio;
import std.string : join, toStringz;

import til.grammar;
import til.nodes;


extern (C) size_t tclNewInterpreter();
extern (C) int tclInit(size_t interpreter_index);
extern (C) void tclDeleteInterpreter(size_t interpreter_index);
extern (C) int tclCreateCommand(size_t interpreter_index, char* name, void* f);
extern (C) int tclEval(size_t interpreter_index, char* script);
extern (C) char* tclGetVar(size_t interpreter_index, const char* name);
extern (C) char* tclSetVar(size_t interpreter_index, const char* name, const char* value);
extern (C) char* tclGetStringResult(size_t interpreter_index);
extern (C) int tclSetResult(size_t interpreter_index, char* result);


CommandsMap tclCommands;

class TclInterpreter : Item
{
    size_t index;
    Context context;

    this(Context context)
    {
        this.commands = tclCommands;
        this.context = context;
        index = tclNewInterpreter();
        interpreters ~= this;
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
    void opIndexAssign(string value, string name)
    {
        auto result = tclSetVar(index, name.toStringz, value.toStringz);
        if (result is null)
        {
            auto msg = to!string(tclGetStringResult(index));
            throw new Exception(msg);
        }
        else
        {
            debug {stderr.writeln("tclSetVar.result:", to!string(result));}
        }
    }
    void exportCommand(Context context, string procName)
    {
        auto exitCode = tclCreateCommand(index, cast(char*)procName.toStringz, &runProc);
        assert (exitCode == 0);
    }
    void exportFastCommand(Context context, string procName)
    {
        auto exitCode = tclCreateCommand(index, cast(char*)procName.toStringz, &runFastProc);
        assert (exitCode == 0);
    }

    override string toString()
    {
        return "Tcl interpreter " ~ to!string(index);
    }
}


TclInterpreter[] interpreters;


extern (C) int runProc(void* clientData, void* interp, int argc, const char** argv)
{
    auto interpreter_index = cast(size_t)clientData;
    stderr.writeln("interpreter_index:", interpreter_index);
    auto tclInterpreter = interpreters[interpreter_index];
    stderr.writeln("interpreter:", tclInterpreter);

    auto context = tclInterpreter.context;
    stderr.writeln("context:", context);
    string[] parts;
    for (size_t i = 0; i < argc; i++)
    {
        auto s = to!string(argv[i]);
        stderr.writeln("arg ", i, ":", s);
        parts ~= s;
    }
    string code = parts.join(" ");
    stderr.writeln("evaluating: ", code);

    auto parser = new Parser(code);
    SubProgram subprogram = parser.run();
    context = context.process.run(subprogram, context);
    stderr.writeln(" DONE! ", context.exitCode, " / ", context.size);

    if (context.size)
    {
        string s = context.pop!string();
        stderr.writeln(" Result: ", s);
        char* result = cast(char*)(s.toStringz);
        tclSetResult(interpreter_index, result);
    }

    // XXX: what about this `context`? Will something
    // from here reflect on Til's side?
    tclInterpreter.context = context;

    return 0;
}
extern (C) int runFastProc(void* clientData, void* interp, int argc, const char** argv)
{
    auto interpreter_index = cast(size_t)clientData;
    stderr.writeln("interpreter_index:", interpreter_index);
    auto tclInterpreter = interpreters[interpreter_index];
    stderr.writeln("interpreter:", tclInterpreter);

    auto context = tclInterpreter.context;
    stderr.writeln("context:", context);

    string cmdName = to!string(argv[0]);
    auto command = context.escopo.getCommand(cmdName);

    for (size_t i = 1; i < argc; i++)
    {
        auto s = to!string(argv[i]);
        stderr.writeln("arg ", i, ":", s);
        context.push(s);
    }

    context = command.run(cmdName, context);
    stderr.writeln(" DONE! ", context.exitCode, " / ", context.size);

    if (context.size)
    {
        string s = context.pop!string();
        stderr.writeln(" Result: ", s);
        char* result = cast(char*)(s.toStringz);
        tclSetResult(interpreter_index, result);
    }

    // XXX: what about this `context`? Will something
    // from here reflect on Til's side?
    tclInterpreter.context = context;

    return 0;
}


extern (C) CommandsMap getCommands(Escopo escopo)
{
    CommandsMap commands;

    // tcl | as interp
    commands[null] = new Command((string path, Context context)
    {
        debug {stderr.writeln("Creating Tcl interpreter...");}
        return context.push(new TclInterpreter(context));
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
        return context;
    });
    tclCommands["result"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();
        return context.push(interp.getResult());
    });
    tclCommands["export"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();

        while (context.size)
        {
            auto procName = context.pop!string();
            stderr.writeln("exporting ", procName, " from ", context.escopo);
            interp.exportCommand(context, procName);
        }
        return context;
    });
    tclCommands["export.fast"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();

        while (context.size)
        {
            auto procName = context.pop!string();
            stderr.writeln("exporting (fast) ", procName, " from ", context.escopo);
            interp.exportFastCommand(context, procName);
        }
        return context;
    });
    tclCommands["set"] = new Command((string path, Context context)
    {
        auto interp = context.pop!TclInterpreter();
        auto name = context.pop!string();
        auto value = context.pop!string();
        debug {stderr.writeln("tcl.set:", interp, " ", name, " = ", value);}
        interp[name] = value;
        return context;
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
