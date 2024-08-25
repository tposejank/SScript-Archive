package macro;

import haxe.macro.Context;

class Macro
{
	macro
	public static function initiateMacro() 
	{
		Context.fatalError('SScript is not available, thanks to everyone for their support.', (macro null).pos);
		return macro {}
	}
}