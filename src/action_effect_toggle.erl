-module (action_effect_toggle).
-include ("wf.inc").
-compile(export_all).

render_action(_TriggerPath, TargetPath, _Record) -> 
	[wf:me_var(), wf:f("obj('~s').toggle();", [wf:to_ident(TargetPath)])].