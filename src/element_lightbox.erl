-module (element_lightbox).
-include ("wf.inc").
-compile(export_all).

render(ControlID, Record) -> 
	Terms = #panel {
		class=lightbox,
		style="position: fixed; top: 0px; left: 0px; bottom: 0px; right: 0px;",
		body=[
			#panel { 			
				class=lightbox_background, 
				style="position: fixed; top: 0px; left: 0px; bottom: 0px; right: 0px; background-color: #000000;", 
				actions=wf:f("obj(me).setOpacity(~f);", [Record#lightbox.opacity])
			},
			#table { 
				style="position: fixed; top: 0px; left: 0px; width: 100%; height: 100%; overflow:auto;", 
				rows=#tablerow {
					cells=#tablecell { align=center, valign=middle, style="vertical-align: middle;", body=Record#lightbox.body } 
				}
			}
		]
	},
	element_panel:render(ControlID, Terms).
