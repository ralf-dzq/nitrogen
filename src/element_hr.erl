-module (element_hr).
-compile(export_all).
-include ("wf.inc").

render(ControlID, Record) -> 
	wf:f("<hr size=1 id='~s' class='p ~s' style='~s'>", [
		ControlID, 
		Record#hr.class,
		Record#hr.style
	]).