"use strict";
var isHost = false;
var syncDelay = 1;

function Vote( value )
{
	if (!isHost)
		return;

	if (value == "host")
		GameEvents.SendCustomGameEventToServer( "petri_game_setup_host_shuffle", { } );

	if (value == "random")
	{
		$.GetContextPanel().GetParent().data().SetTimer( 10, "#game_setup_shuffling" );		
		$.GetContextPanel().GetParent().data().UnfreezeVote();
		GameEvents.SendCustomGameEventToServer( "petri_game_setup_random_shuffle", { "CurrentPlayers" : Game.GetAllPlayerIDs().length } );
	}
}

//--------------------------------------------------------------------------------------------------
// Set universal handler
//--------------------------------------------------------------------------------------------------
function SetClickHandler()
{
	var variants = $("#VoteVariants");
	var childCount = variants.GetChildCount();

	for (var i = 0; i < childCount; i++) {
		var child = variants.GetChild(i);
		var isDefault = child.GetAttributeString("default", "false");

		// Click event
		var click = (function( panel ) { 
			return function() {
				$.GetContextPanel().IsVoted = true;
				panel.SetHasClass("selected", true);
				$("#VoteVariants").enabled = false;

				Vote( panel.GetAttributeString("value", "") );
			}
		} (child));

		if (isDefault == "true")
			$.GetContextPanel().VoteDefault = click;

		child.SetPanelEvent("onmouseactivate", click);
	};	
}

function SetVoteTime( time )
{
	$.Schedule( time - syncDelay, function(){
		if (!$.GetContextPanel().IsVoted)
			$.GetContextPanel().VoteDefault();
	});
}

(function ()
{
	$.GetContextPanel().IsVoted = false;
	$.GetContextPanel().data().SetVoteTime = SetVoteTime;

	SetClickHandler();

	var playerInfo = Game.GetLocalPlayerInfo();
	isHost = playerInfo.player_has_host_privileges;
	if (!isHost)
		$.GetContextPanel().visible = false;

	$.GetContextPanel().GetParent().data().FreezeVote();
})();