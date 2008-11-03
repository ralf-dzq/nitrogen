-module (action_validate).
-include ("wf.inc").
-compile(export_all).

render_action(TriggerPath, TargetPath, Record) -> 
	% Initialize a validator for the Target...
	ValidMessage = wf_utils:js_escape(Record#validate.success_text),
	OnlyOnBlur = (Record#validate.on == blur),
	OnlyOnSubmit = (Record#validate.on == submit),	
	InsertAfterNode = case Record#validate.attach_to of
		undefined -> "";
		Node -> wf:f(", insertAfterWhatNode : obj(\"~s\")", [Node])
	end,
	ConstructorJS = wf:f("var v = obj(me).validator = new LiveValidation(obj(me), { validMessage: \"~s\", onlyOnBlur: ~s, onlyOnSubmit: ~s ~s});", [wf_utils:js_escape(ValidMessage), OnlyOnBlur, OnlyOnSubmit, InsertAfterNode]),
	TriggerJS = wf:f("v.trigger = '~s';", [wf:to_ident(TriggerPath)]),
	
	% Render the validation javascript...
	F = fun(X) ->
			Type = element(1, X),
			TypeModule = list_to_atom("validator_" ++ atom_to_list(Type)),
			TypeModule:render_validator(TriggerPath, TargetPath, X)
	end,
	ValidatorsJS = [F(X) || X <- lists:flatten([Record#validate.validators])],

  % Use #script element to create the final javascript to send to the browser...
	action_script:render_action(TriggerPath, TargetPath, #script { script=[ConstructorJS,	TriggerJS, ValidatorsJS] }).
	

