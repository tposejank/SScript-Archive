package;

import haxe.Constraints;
import hscript.*;

import sys.FileSystem;
import sys.io.File;

/**
    A simple class for haxe scripts.
**/
class SScript
{
    /**
        Main interpreter and executer. 

        If you destroy `this` script interp will be null and you won't be able to mess with this ever again.
    **/
    public var interp(default, set):Interp;

    /**
        An unique parser for the script to parse strings.
    **/
    public var parser(default, set):Parser;

    /**
        The script to execute. Gets set automatically if you create a `new` SScript.
        
        Similar to `interp` if you destroy `this` script you won't be able to mess with this ever again.
    **/
    public var script(default, set):String = "";

    /**
        This variable tells if `this` script is active or not.

        Set this to false if you do not want your script to get executed!
    **/
    public var active(default, set):Bool = true;
    
    /**
        This variable tells if `this` script is destroyed or not.

        This variable will ignore all the set attempts by the user once it's set to true.
    **/
    public var destroyed(default, set):Bool;

    /**
        This string tells you the path of your script file as a read-only string.
    **/
    public var scriptFile(default, null):String = "";

    /**
        If true, enables error traces from the functions.
    **/
    public var traces:Bool = true;

    /**
        Creates a new haxe script that will be ready to use after executing.

        @param scriptPath The script path or the script itself.
        @param Preset If true, Sscript will set some useful variables to interp. 
        @param startExecute If true, script will execute itself. If false, it will not execute
        and functions in the script file won't be set to interpreter. 
    **/
    public function new(?scriptPath:String = "", ?preset:Bool = true, ?startExecute:Bool = true)
    {
        if (scriptPath != "")
        {
            if (FileSystem.exists(scriptPath))
                script = File.getContent(scriptPath);
            else
                script = scriptPath;

            scriptFile = scriptPath;
        }

        interp = new Interp();
        parser = new Parser();

        if (preset)
            this.preset();

        if (startExecute && scriptPath != "")
            execute();
    }

    /**
        Executes `this` script once.

        If `this` script does not have any variables set, executing won't do anything.
    **/
    public function execute():Void
    {
        if (interp == null || !active)
            return;

        var expr:Expr = parser.parseString(script, scriptFile);
	    interp.execute(expr);
    }
    
    /**
        Sets a variable to `this` script. 
        
        If `key` already exists it will be replaced.
        
        If you want to set a variable to multiple scripts check the `setOnscripts` function.
        @param key Variable name.
        @param obj The object to set. 
    **/
    public function set(key:String, obj:Dynamic):Void
    {
        if (interp == null || !active)
        {
            if (traces)
            {
                if (interp == null) 
                    trace("This script is destroyed and unusable!");
                else 
                    trace("This script is not active!");
            }

            return;
        }

        interp.variables.set(key, obj);
    }

    /**
        Unsets a variable from `this` script. 
        
        If a variable named `key` doesn't exist, unsetting won't do anything.
        @param key Variable name to unset.
    **/
    public function unset(key:String):Void
    {
        if (interp == null || !active || key == null || !interp.variables.exists(key))
            return;

        interp.variables.remove(key);
    }

    /**
        Gets a variable by name. 
        
        If a variable named as `key` does not exists return is null.
        @param key Variable name.
        @return If `this` script is destroyed or inactive return is null and will trace the error.
        Otherwise, return is the object got by name.
    **/
    public function get(key:String):Dynamic
    {
        if (interp == null || !active)
        {
            if (traces)
            {
                if (interp == null) 
                    trace("This script is destroyed and unusable!");
                else 
                    trace("This script is not active!");
            }

            return null;
        }

        return if (exists(key)) interp.variables.get(key) else null;
    }

    /**
        Calls a function from the script file.

        `ATTENTION:` You MUST execute the script at least once to get the functions to script's interpreter.
        If you do not execute this script and `call` a function, script will ignore your call.
        
        @param func Function name in script file. 
        @param args Arguments for the `func`.
        @return Returns the return value in the function. If the function is `Void` returns nothing.
     **/
    public function call(func:String, args:Array<Dynamic>):Dynamic
    {
        if (func == null)
        {
            if (traces)
                trace('Function name cannot be null for $scriptFile!');
            return null;
        }

        if (args == null)
        {
            if (traces)
                trace('Arguments cannot be null for $scriptFile!');
            return null;
        }

        if (destroyed || interp == null || !interp.variables.exists(func))
        { 
            if (traces)
            {
                if (destroyed) 
                    trace('This script is destroyed.');
                else if (interp == null) 
                    trace('Interpreter is null!');
                else 
                    trace('Function $func does not exist in $scriptFile.'); 
            }

            return null;
        }
   
        var functionField:Function = get(func);
        return Reflect.callMethod(this, functionField, args);
    }

    /**
        `WARNING:` This is a dangerous function since it makes `this` script completely unusable.
        
        If you wanna get rid of `this` script COMPLETELY, call this function.
        
        Else if you want to disable `this` script temporarily just set `active` to false!
    **/
    public function destroy():SScript
    {
        if (destroyed)
            return this;

        return SSUtil.destroy(this);
    }

    /**
        Clears all of the keys assigned to `this` script.
    **/
    public function clear():Void
    {
        if (destroyed || interp == null)
            return;

        var importantThings:Array<String> = ['true', 'false', 'null', 'trace'];

        for (i in interp.variables.keys())
            if (!importantThings.contains(i))
                interp.variables.remove(i);
    }

    /**
        Tells if the `key` exists in `this` script's interpreter.
        @param key The string to look for.
        @return Return is true if `key` is found in interpreter.
    **/
    public function exists(key:String):Bool
    {
        if (interp == null)
            return false;

        return interp.variables.exists(key);
    }

    /**
        Tells if any of the keys in `keys` array exist in `interp`.

        If one key or more exist in `interp` returns true.
    @param keys Key array you want to check.
    **/
    public function anyExists(keys:Array<String>):Bool
    {
        if (interp == null || destroyed)
            return false;

        for (key in keys)
            if (exists(key))
                return true;
            
        return false;
    }

    /**
        Tells if all of keys in `keys` array exist in `interp`.

        If one key or more do not exist in `interp`, it immediately breaks itself and returns false.
        @param keys Key array you want to check.
    **/
    public function allExists(keys:Array<String>):Bool
    {
        if (interp == null || destroyed)
            return false;

        for (key in keys)
            if (!exists(key))
                return false;

        return true;
    }

    /**
        Sets some useful variables to interp to make easier using this script.
    **/
    public function preset():Void
    {
        set('Math', Math);
        set('Std', Std);
        set('StringTools', StringTools);
        set('Sys', Sys);
        set('Date', Date);
        set('DateTools', DateTools);
        set('PI', Math.PI);
        set('POSITIVE_INFINITY', 1 / 0);
        set('NEGATIVE_INFINITY', -1 / 0);
        set('NaN', 0 / 0);
        set('File', File);
        set('FileSystem', FileSystem);
    }

    /**
        Returns a clone of this script that needs executing.

        Clone and original are the same scripts but `script == script.clone()` will always return false.
    **/
    public function clone():SScript
    {
        var script:SScript = new SScript(scriptFile, false, false);
        script.interp = interp;
        script.script = this.script;

        return script; 
    }

    /**
        Executes a string once instead of a script file.

        This does not change your `script` and `scriptFile`.
        @param string String you want to execute.
    **/
    public function doString(string:String):Void
    {
        var expr:Expr = parser.parseString(string);
        interp.execute(expr);
    }

    /**
        Sets a variable in multiple scripts.
        @param scriptArray The scripts you want to set the variable to.
        @param key Variable name.
        @param obj The object to set to `key`.
    **/
    public static function setOnscripts(scriptArray:Array<SScript>, key:String, obj:Dynamic):Void
    {
        for (script in scriptArray)
            script.set(key, obj);
    }

    function set_active(active:Bool):Null<Bool>
    {
        return this.active = active;
    }

    function set_destroyed(destroyable:Bool):Null<Bool>
    {
        if (destroyed && !destroyable)
            return true;
        
        active = !destroyed;
        return destroyed = destroyable;
    }

    function set_interp(value:Interp):Interp
    {
        if (interp == null && value != null && destroyed)
            return null;

        return interp = value;
    }

    function set_script(value:String):String
    {
        if (script == "" && value != "" && destroyed)
            return "";

        return script = value;
    }

	function set_parser(value:Parser):Parser 
    {
		if (value != null && Parser == null && destroyed)
            return null;

        return parser = value;
	}
}
