package;

import ex.*;

import haxe.Exception;

import hscriptBase.*;
import hscriptBase.Expr;

import sys.FileSystem;
import sys.io.File;

typedef SScriptCall =
{
	public var ?fileName(default, null):String;
	public var ?className(default, null):String;
	public var succeeded(default, null):Bool;
	public var calledFunction(default, null):String;
	public var returnValue(default, null):Null<Dynamic>;
	public var exceptions(default, null):Array<Exception>;
}

/**
	A simple class for haxe scripts.

	For creating a new script without a file, look at this example.
	```haxe
	var script:String = "package; private final num:Int = 1; function traceNum() { trace(num); }";
	var sscript:SScript = new SScript().doString(script);
	sscript.call('traceNum', []); // 1
	```

	If you want to create a new script with a file, look at this example.
	```haxe
	var script:String = "script.hx";
	var sscript:SScript = new SScript(script);
	sscript.call('traceNum', []);
	```
**/
@:structInit
@:access(hscriptBase.Interp)
@:access(SScriptX)
@:access(ScriptClass)
@:access(AbstractScriptClass)
class SScript
{
	/**
		Use this to access to interpreter's variables!
	**/
	public var variables(get, never):Map<String, Dynamic>;

	/**
		Main interpreter and executer. 

		Do not use `interp.variables.set` to set variables!
		Instead, use `set`.
	**/
	public var interp(default, null):Interp;

	/**
		An unique parser for the script to parse strings.
	**/
	public var parser:Parser;

	/**
		The script to execute. Gets set automatically if you create a `new` SScript.
	**/
	public var script(default, null):String = "";

	/**
		This variable tells if this script is active or not.

		Set this to false if you do not want your script to get executed!
	**/
	public var active:Bool = true;

	/**
		This string tells you the path of your script file as a read-only string.
	**/
	public var scriptFile(default, null):String = "";

	/**
		If true, enables error traces from the functions.
	**/
	public var traces:Bool;

	/**
		Tells if this script is in EX mode, in EX mode you can only use `class`, `import` and `package`.
	**/
	public var exMode(get, never):Bool;

	/**
		Package path of this script. Gets set automatically when you use `package`.
	**/
	public var packagePath(get, null):String = "";

	/**
		A list of classes in the current script.

		Will be null if there are no classes in this script.
	**/
	public var classes(get, never):Map<String, AbstractScriptClass>;

	/**
		The name of the current class in this script.

		When a script created, `currentClass` becomes the first class in that script (if there are any classes in script).
	**/
	public var currentClass(get, set):String;

	/**
		Reference to script class in this script.

		To change, change `currentClass`.
	**/
	public var currentScriptClass(get, never):AbstractScriptClass;

	/**
		Reference to super class of `currentScriptClass`.
	**/
	public var currentSuperClass(get, never):Class<Dynamic>;

	@:noPrivateAccess var parsingExceptions(default, null):Array<Exception> = new Array();
	@:noPrivateAccess var scriptX(default, null):SScriptX;

	/**
		Creates a new haxe script that will be ready to use after executing.

		@param scriptPath The script path or the script itself.
		@param Preset If true, Sscript will set some useful variables to interp. Override `preset` to customize the settings.
		@param startExecute If true, script will execute itself. If false, it will not execute
		and functions in the script file won't be set to interpreter. 
	**/
	public function new(?scriptPath:String = "", ?preset:Bool = true, ?startExecute:Bool = true)
	{
		if (scriptPath != null && scriptPath.length > 0)
		{
			if (FileSystem.exists(scriptPath))
			{
				scriptFile = scriptPath;
				script = File.getContent(scriptPath);
			}
			else
				script = scriptPath;
		}

		interp = new Interp();
		interp.setScr(this);

		parser = new Parser();
		parser.script = this;
		parser.setIntrp(interp);
		interp.setPsr(parser);

		if (preset)
			this.preset();

		if (scriptPath != null && scriptPath.length > 0)
			try
				scriptX = new SScriptX(scriptPath)
			catch (e)
			{
				parsingExceptions.push(new Exception(e.details()));
				scriptX = null;
			}

		if (startExecute && scriptPath != "" && scriptPath != null)
			execute();

		if (scriptX != null)
			scriptX.script = this;
	}

	/**
		Executes this script once.

		If this script does not have any variables set, executing won't do anything.

		Executing scripts with classes will not do anything.
	**/
	public function execute():Void
	{
		if (scriptX != null)
			return;

		if (interp == null || !active)
			return;

		if (scriptX == null)
		{
			var expr:Expr = parser.parseString(script, if (scriptFile != null && scriptFile.length > 0) scriptFile else "SScript");
			interp.execute(expr);
		}
	}

	/**
		Sets a variable to this script. 

		If `key` already exists it will be replaced.
		@param key Variable name.
		@param obj The object to set. If the object is a macro class, function will be aborted.
		@return Returns this instance for chaining.
	**/
	public function set(key:String, obj:Dynamic):SScript
	{
		if (Tools.keys.contains(key))
			throw '$key is a keyword, set something else';
		else if (macro.Macro.macroClasses.contains(obj))
			throw '$key cannot be a Macro class (tried to set ${Type.getClassName(obj)})';

		SScriptX.variables[key] = obj;
		if (scriptX != null)
		{
			var value:Dynamic = obj;
			scriptX.set(key, value);
		}
		else
		{
			if (interp == null || !active)
			{
				if (traces)
				{
					if (interp == null)
						trace("This script is unusable!");
					else
						trace("This script is not active!");
				}

				return null;
			}

			interp.variables[key] = obj;
		}

		return this;
	}

	/**
		This is a helper function to set classes easily.
		For example, if `cl` is `sys.io.File` it will be set as `File`.
		@param cl The class to set. It cannot be macro classes.
		@return this instance for chaining.
	**/
	public function setClass(cl:Class<Dynamic>):SScript
	{
		if (cl == null)
		{
			if (traces)
			{
				trace('Class cannot be null');
			}

			return null;
		}

		var clName:String = Type.getClassName(cl);
		if (clName != null)
		{
			if (clName.split('.').length > 1)
			{
				clName = clName.split('.')[clName.split('.').length - 1];
			}

			set(clName, cl);
		}
		return this;
	}

	/**
		Sets a class to this script from a string.
		`cl` will be formatted, for example: `sys.io.File` -> `File`.
		@param cl The class to set. It cannot be macro classes.
		@return this instance for chaining.
	**/
	public function setClassString(cl:String):SScript
	{
		if (cl == null || cl.length < 1)
		{
			if (traces)
				trace('Class cannot be null');

			return null;
		}

		var cls:Class<Dynamic> = Type.resolveClass(cl);
		if (cls != null)
		{
			if (cl.split('.').length > 1)
			{
				cl = cl.split('.')[cl.split('.').length - 1];
			}

			set(cl, cls);
		}
		return this;
	}

	/**
		Returns the local variables in this script as a fresh map.

		Changing any value in returned map will not change the script's variables.
	**/
	public function locals():Map<String, Dynamic>
	{
		if (scriptX != null)
		{
			var newMap:Map<String, Dynamic> = new Map();
			if (scriptX.interpEX.locals != null)
				for (i in scriptX.interpEX.locals.keys())
				{
					var v = scriptX.interpEX.locals[i];
					if (v != null)
						newMap[i] = v.r;
				}
			return newMap;
		}

		var newMap:Map<String, Dynamic> = new Map();
		for (i in interp.locals.keys())
		{
			var v = interp.locals[i];
			if (v != null)
				newMap[i] = v.r;
		}
		return newMap;
	}

	/**
		Unsets a variable from this script. 

		If a variable named `key` doesn't exist, unsetting won't do anything.
		@param key Variable name to unset.
		@return Returns this instance for chaining.
	**/
	public function unset(key:String):SScript
	{
		if (interp == null || !active || key == null || !interp.variables.exists(key))
			return null;

		if (scriptX != null)
		{
			scriptX.interpEX.variables.remove(key);
			SScriptX.variables.remove(key);
		}

		interp.variables.remove(key);
		return this;
	}

	/**
		Gets a variable by name. 

		If a variable named as `key` does not exists return is null.
		@param key Variable name.
		@return The object got by name.
	**/
	public function get(key:String):Dynamic
	{
		if (scriptX != null)
		{
			return
			{
				var l = locals();
				if (l.exists(key))
					l[key];
				else if (scriptX.interpEX.variables.exists(key))
					scriptX.interpEX.variables[key];
				else if (classes != null) // script with classes will return hscriptBase.Expr if a function is searched
				{
					for (k => i in classes)
					{
						if (i != null && i.listFunctions().exists(key) && i.listFunctions()[key] != null)
							return '#fun';
					}
					null;
				}
				else if (SScriptX.variables.exists(key))
					SScriptX.variables[key];
				else
					null;
			}
		}

		if (interp == null || !active)
		{
			if (traces)
			{
				if (interp == null)
					trace("This script is unusable!");
				else
					trace("This script is not active!");
			}

			return null;
		}

		var l = locals();
		if (l.exists(key))
			return l[key];

		return if (exists(key)) interp.variables[key] else null;
	}

	/**
		Calls a function from the script file.

		`WARNING:` You MUST execute the script at least once to get the functions to script's interpreter.
		If you do not execute this script and `call` a function, script will ignore your call.

		@param func Function name in script file. 
		@param args Arguments for the `func`. If the function does not require arguments, leave it null.
		@param className If provided, searches the specific class. If the function is not found, other classes will be searched.
		@return Returns an unique structure that contains called function, returned value etc. Returned value is at `returnValue`.
	**/
	public function call(func:String, ?args:Array<Dynamic>, ?className:String):SScriptCall
	{
		var scriptFile:String = if (scriptFile != null && scriptFile.length > 0) scriptFile else "";
		var caller:SScriptCall = {
			exceptions: [],
			calledFunction: func,
			succeeded: false,
			returnValue: null
		};
		if (scriptFile != null && scriptFile.length > 0)
			caller = {
				fileName: scriptFile,
				exceptions: [],
				calledFunction: func,
				succeeded: false,
				returnValue: null
			};
		if (args == null)
			args = new Array();

		var pushedExceptions:Array<String> = new Array();
		function pushException(e:String)
		{
			if (!pushedExceptions.contains(e))
				caller.exceptions.push(new Exception(e));
			
			pushedExceptions.push(e);
		}
		if (func == null)
		{
			if (traces)
				trace('Function name cannot be null for $scriptFile!');

			pushException('Function name cannot be null for $scriptFile!');
			return caller;
		}
		var callX:SScriptCall = null;
		if (scriptX != null)
		{
			callX = scriptX.callFunction(func);
		}
		else
		{
			if (exists(func) && Type.typeof(get(func)) != TFunction)
			{
				if (traces)
					trace('$func is not a function');

				pushException('$func is not a function');
			}

			else if (interp == null || !exists(func))
			{
				if (interp == null)
				{
					if (traces)
						trace('Interpreter is null!');

					pushException('Interpreter is null!');
				}
				else
				{
					if (traces)
						trace('Function $func does not exist in $scriptFile.');

					if (scriptFile != null && scriptFile.length > 1)
						pushException('Function $func does not exist in $scriptFile.');
					else 
						pushException('Function $func does not exist in SScript instance.');
				}
			}
			else 
			{
				var oldCaller = caller;
				try
				{
					var functionField:Dynamic = Reflect.callMethod(this, get(func), args);
					caller = {
						exceptions: caller.exceptions,
						calledFunction: func,
						succeeded: true,
						returnValue: functionField
					};
					if (scriptFile != null && scriptFile.length > 0)
						caller = {
							fileName: scriptFile,
							exceptions: caller.exceptions,
							calledFunction: func,
							succeeded: true,
							returnValue: functionField
						};
				}
				catch (e)
				{
					caller = oldCaller;
					pushException(e.details());
				}
			}
		}
		if (!caller.succeeded && (callX == null || !callX.succeeded))
		{
			for (i in parsingExceptions)
			{
				pushException(i.details());
				
				if (callX != null)
					callX.exceptions.push(new Exception(i.details()));
			}
		}

		return if (scriptX != null) callX else caller;
	}

	/**
		Clears all of the keys assigned to this script.

		@return Returns this instance for chaining.
	**/
	public function clear():SScript
	{
		if (scriptX != null)
		{
			scriptX.interpEX.variables = new Map();
			return this;
		}

		if (interp == null)
			return this;

		var importantThings:Array<String> = ['true', 'false', 'null', 'trace'];

		for (i in interp.variables.keys())
			if (!importantThings.contains(i))
				interp.variables.remove(i);

		return this;
	}

	/**
		Tells if the `key` exists in this script's interpreter.
		@param key The string to look for.
		@return Returns true if `key` is found in interpreter.
	**/
	public function exists(key:String):Bool
	{
		if (scriptX != null)
		{
			if (scriptX.currentScriptClass != null
				&& scriptX.currentScriptClass.listFunctions() != null
				&& scriptX.currentScriptClass.listFunctions().exists(key))
				return true;

			var l = scriptX.interpEX.locals;
			var v = scriptX.interpEX.variables;
			return if (l != null && l.exists(key)) true else if (v != null && v.exists(key)) true else false;
		}

		if (interp == null)
			return false;
		if (locals().exists(key))
			return locals().exists(key);

		return interp.variables.exists(key);
	}

	/**
		Sets some useful variables to interp to make easier using this script.
		Override this function to set your custom sets aswell.
	**/
	public function preset():Void
	{
		set('Math', Math);
		set('Std', Std);
		set('StringTools', StringTools);
		set('Sys', Sys);
		set('Date', Date);
		set('DateTools', DateTools);
		set('File', File);
		set('FileSystem', FileSystem);
	}

	/**
		Executes a string once instead of a script file.

		This does not change your `scriptFile` but it changes `script`.

		This function should be avoided whenever possible, when you do a string a lot variables remain unchanged.
		Always try to use a script file.
		@param string String you want to execute.
		@return Returns this instance for chaining.
	**/
	public function doString(string:String):SScript
	{
		var og:String = "SScript";
		if (string == null || string.length < 0)
			return this;
        else if (FileSystem.exists(string))
		{
			og = "" + string;
            string = File.getContent(string);
		}
		if (scriptX != null)
		{
			scriptX.doString(string, og);
			return this;
		}
		if (!active || interp == null)
			return this;

		if (scriptX == null)
		{
			try
			{
				var expr:Expr = parser.parseString(string, og);
				interp.execute(expr);
			}
			catch (e)
				try
				{
					scriptX = new SScriptX(string);
				}
				catch (e)
				{
					parsingExceptions.push(new Exception(e.details()));
					scriptX = null;
				}
		}

		script = string;
		return this;
	}

	inline function toString():String
	{
		if (scriptFile != null && scriptFile.length > 0)
			return scriptFile;

		return Std.string(this);
	}

	function get_variables():Map<String, Dynamic>
	{
		return if (scriptX != null) scriptX.interpEX.variables else interp.variables;
	}

	function setPackagePath(p):String
	{
		return packagePath = p;
	}

	function get_packagePath():String
	{
		return if (scriptX != null) scriptX.interpEX.pkg else packagePath;
	}

	function get_classes():Map<String, AbstractScriptClass>
	{
		return if (scriptX != null)
		{
			var newMap:Map<String, AbstractScriptClass> = new Map();
			for (i => k in scriptX.classes)
				newMap[i] = k;
			newMap;
		}
		else null;
	}

	function get_currentScriptClass():AbstractScriptClass
	{
		return if (scriptX != null) scriptX.currentScriptClass else null;
	}

	function get_currentSuperClass():Class<Dynamic>
	{
		return if (scriptX != null) scriptX.currentSuperClass else null;
	}

	function set_currentClass(value:String):String
	{
		return if (scriptX != null) scriptX.currentClass = value else null;
	}

	function get_currentClass():String
	{
		return if (scriptX != null) scriptX.currentClass else null;
	}

	function get_exMode():Bool 
	{
		return scriptX != null;
	}
}