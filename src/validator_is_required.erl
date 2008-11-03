-module (validator_is_required).
-include ("wf.inc").
-compile(export_all).

render_validator(TriggerPath, TargetPath, Record) -> 
	Text = wf_utils:js_escape(Record#is_required.text),
	validator_custom:render_validator(TriggerPath, TargetPath, #custom { function=fun validate/2, text = Text, record=Record }),
	wf:f("v.add(Validate.Presence, { failureMessage: \"~s\" });", [Text]).

validate(Value, _) -> 
	Value /= [].
