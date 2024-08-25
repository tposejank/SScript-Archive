package macro;

import haxe.macro.Compiler;
import haxe.macro.Context;

class Macro
{
    macro public static function turnOnDisplay()
    {
        trace('SScript is defining the flag \'display\'');
        Compiler.define("display");
        return macro null;
    }

    macro public static function turnDCEOff() 
    {
        var defines = Context.getDefines();
        if (defines.get('dce') != 'no')
        {
            trace('SScript is turning of DCE');
            Compiler.define('dce', 'no');
        }
        return macro null;    
    }
}