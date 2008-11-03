-module (action_effect_blinddown).
-include ("wf.inc").
-compile(export_all).

render_action(_TriggerPath, TargetPath, Record) -> 
	Duration = Record#effect_blinddown.duration,
	[
		wf:me_var(), 
		wf:f("new Effect.BlindDown(obj('~s'), { duration: ~f });", [wf:to_ident(TargetPath), Duration])	
	].