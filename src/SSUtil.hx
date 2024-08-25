package;

import hscript.*;

class SSUtil
{
    public static function destroy(sscript:SScript)
    {
        sscript.destroyed = true;
        sscript.interp = null;
        sscript.parser = null;
        sscript.script = "";
        
        return sscript;
    }

    /**
        Creates a completely empty script.
        
        Created script does not have any variables set and needs executing before using.
    **/
    public static function emptyScript():SScript
    {
        var sscript:SScript = new SScript(false, false);
        sscript.interp = new Interp();
        sscript.parser = new Parser();

        return sscript;
    }
}