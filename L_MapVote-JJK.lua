--MapVote - Created by Krabs
--Best used with IntermissionLock to prevent voting desynchs, although a desynched voting screen won't actually affect the map that gets chosen in the end, since the server does that.

local score_time = CV_RegisterVar({
	name = "scoretime",
	defaultvalue = tostring(11),
	flags = CV_NETVAR,
	PossibleValue = {MIN = 1, MAX = 100}
})
local vote_time = CV_RegisterVar({
	name = "votetime",
	defaultvalue = tostring(13),
	flags = CV_NETVAR,
	PossibleValue = {MIN = 1, MAX = 100}
})
local weighted_random = CV_RegisterVar({
    name = "weightedrandom",
    defaultvalue = "On",
    flags = CV_NETVAR,
    PossibleValue = CV_OnOff
})

--Constants
local END_TIME = 6
local VSND_SELECT = sfx_s240
local VSND_CONFIRM = sfx_s3k63
local VSND_VOTE_START = sfx_s243
local VSND_CANCEL = sfx_s3k72
local VSND_MISSED_VOTE = sfx_s3k74
local VSND_SPEEDING_OFF = sfx_lvpass
local VSND_BEEP = sfx_s3k89
local IPH_NONE = 0
local IPH_SCORE = 1
local IPH_VOTE = 2
local IPH_END = 3
local IPH_STOP = 4

--Initialize gametype constants
local BattleAdded = false
local GAMETYPE_AMT_VANILLA = 7
local GAMETYPE_AMT_BATTLE = 17

if CBW_Battle
	BattleAdded = true
	local B = CBW_Battle
end
local GT_ARENA = 8
local GT_TEAMARENA = 9
local GT_SURVIVAL = 10
local GT_TEAMSURVIVAL = 11
local GT_CP = 12
local GT_TEAMCP = 13
local GT_DIAMOND = 14
local GT_TEAMDIAMOND = 15
local GT_EGGROBOTAG = 16
local GT_BATTLECTF = 17

--Netvars
rawset(_G, "netvote",{})
netvote.score_timeleft = score_time.value * TICRATE - 1
netvote.vote_timeleft = vote_time.value * TICRATE - 1
netvote.end_timeleft = END_TIME * TICRATE - 1
netvote.enabled_gametypes = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18}
netvote.map_whitelist = {}
netvote.map_blacklist = {}
netvote.maplist = {}
netvote.mapbag = {}
netvote.phase = IPH_NONE
netvote.map_choice = {}
netvote.gt_choice = {}
netvote.vote_tally = {}
netvote.decided_map = 1
netvote.decided_gt = GT_COOP
netvote.charruntime = 0
netvote.runskin = 0

addHook("NetVars", function(n) netvote = n($) end)

--Reset vars on map load
addHook("MapLoad", function()
	hud.enable("intermissiontally")
	netvote.phase = IPH_NONE
	netvote.map_choice = {1,2,3}
	netvote.gt_choice = {0,1,2}
	netvote.vote_tally = {0,0,0}
	netvote.decided_map = 1
	netvote.decided_gt = GT_COOP
	netvote.charruntime = 0
	netvote.runskin = 0
end)

--table_contains_value(t,v)
--Returns true if t contains c
local function table_contains_value(t,v)
	for i = 0, #t
		if v == t[i] return true end
	end
	return false
end

--IntToExtMapNum(n)
--Returns the extended map number as a string
--Returns nil if n is an invalid map number
local function IntToExtMapNum(n)
	if n < 0 or n > 1035
		return nil
	end
	if n < 10
		return "MAP0" + n
	end
	if n < 100
		return "MAP" + n
	end
	local x = n-100
	local p = x/36
	local q = x - (36*p)
	local a = string.char(65 + p)
	local b
	if q < 10
		b = q
	else
		b = string.char(55 + q)
	end
	return "MAP" + a + b
end

--MapIDToName(m)
--Returns the name of a map such as "Greenflower 1" or "Jade Valley"
--Returns MAPXX as a string if the map doesn't have a valid title
local function MapIDToName(m)
	if m == nil
		return "ERROR: nil mapnum"
	end
	local h = mapheaderinfo[m]
	if h and h.lvlttl
		local n = h.lvlttl
		if h.actnum > 0
			n = $ + " " + h.actnum
		end
		return n
	end
	return IntToExtMapNum(m)
end

--ScanMaps()
--Put all maps into the table
--Seraches through all maps with a level header and adds them to netvote.maplist
local function ScanMaps()
	netvote.maplist = {}
	for m = 1, #mapheaderinfo
		local wl = netvote.map_whitelist
		local bl = netvote.map_blacklist
		local val = false
		if table_contains_value(wl,m)
			--print("Map "..m)
			val = true
		end
		if #wl == 0
			val = true
		end
		if table_contains_value(bl,m)
			val = false
		end
		if mapheaderinfo[m] and val == true
			//print("Found map: " + m + " - " + IntToExtMapNum(m) + " - " + MapIDToName(m))
			table.insert(netvote.maplist, m)
		end
	end
end

--IntToExtMapNum(n)
--Returns the extended map number as a string
--Returns nil if n is an invalid map number
local function IntToExtMapNum(n)
	if n == nil
		return "ERROR: nil mapnum"
	end
	if n < 0 or n > 1035
		return nil
	end
	if n < 10
		return "MAP0" + n
	end
	if n < 100
		return "MAP" + n
	end
	local x = n-100
	local p = x/36
	local q = x - (36*p)
	local a = string.char(65 + p)
	local b
	if q < 10
		b = q
	else
		b = string.char(55 + q)
	end
	return "MAP" + a + b
end

--JJK
--char_to_num(char)
--Converts character to int
local char_to_num = function(char)
    return string.byte(char)-string.byte("A")
end

--JJK
--ExtMapNumToInt(ext)
--Returns the mapnum int
--Returns nil if it's invalid
local function ExtMapNumToInt(ext)
	ext = ext:upper()
	if ext:sub(1, 3) == "MAP"
		ext = ext:sub(4,5)
		--print("removing MAP chars")
	end
	
    local num = tonumber(ext)
    if num != nil then
		--print("simple number")
        return num
    end
	
	if ext:len() != 2
		--print("mapnum too long")
		return nil
	end
	
    local x = ext:sub(1,1)
	if tonumber(x)
		--print("first digit is a number when it shouldn't be")
		return nil
	end
	
	--print("valid ext mapnum")
    local y = ext:sub(2,2)
    local p = char_to_num(x)
    local q = tonumber(y)
    if q == nil then
        q = 10 + char_to_num(y)
    end
    return ((36*p + q) + 100)
end

--IntToGametypeName(g)
--Returns a string name
--Returns " " if the gametype is invalid
local function IntToGametypeName(g)
	local gtnames = {
		[GT_COOP] = "Co-op",
		[GT_COMPETITION] = "Competition",
		[GT_RACE] = "Race",
		[GT_MATCH] = "Match",
		[GT_TEAMMATCH] = "Team Match",
		[GT_TAG] = "Tag",
		[GT_HIDEANDSEEK] = "Hide & Seek",
		[GT_CTF] = "CTF",
		[GT_ARENA] = "Arena",
		[GT_TEAMARENA] = "Team Arena",
		[GT_SURVIVAL] = "Survival",
		[GT_TEAMSURVIVAL] = "Team Survival",
		[GT_CP] = "Control Point",
		[GT_TEAMCP] = "Team Control Point",
		[GT_DIAMOND] = "Diamond in the Rough",
		[GT_TEAMDIAMOND] = "Team Diamond",
		[GT_EGGROBOTAG] = "Egg Robo Tag",
		[GT_BATTLECTF] = "Battle CTF"
	}
	return gtnames[g]
end

COM_AddCommand("gametypelist", function(p, ...)
	local gt = {...}
	if gt == nil or #gt == 0
		print("Please supply a list of gametype numbers, separated by spaces.")
	end
	
	local egt = {}
	
	for i = 1, #gt
		local gametype = tonumber(gt[i])
		if gametype == nil
			print("Invalid gametype. Must be numeric.")
			return
		end
		if IntToGametypeName(gametype) == nil
			print("Invalid gametype: " + gametype)
			return
		end
		table.insert(egt, gametype)
		print("Added gametype: " + IntToGametypeName(gametype))
	end
	
	netvote.enabled_gametypes = egt
end, COM_ADMIN)

COM_AddCommand("mapwhitelist", function(p, ...)
	local wl = {...}
	if wl == nil or #wl == 0
		print("Please supply a list of whitelisted maps, using extended map numbers. Cleared the list.")
		netvote.map_whitelist = {}
	end
	
	local whitelist = {}
	
	for i = 1, #wl
		if wl[i] == nil
			print("nil mapnum.")
			return
		end
		local mapnum = ExtMapNumToInt(wl[i])
		if mapnum == nil
			print("Invalid map: " + wl[i])
			return
		end
		table.insert(whitelist, mapnum)
		print("whitelisted map: " + mapnum)
	end
	
	netvote.map_whitelist = whitelist
end, COM_ADMIN)

COM_AddCommand("mapblacklist", function(p, ...)
	local bl = {...}
	if bl == nil or #bl == 0
		print("Please supply a list of blacklisted maps, using extended map numbers. Cleared the list.")
		netvote.map_blacklist = {}
	end
	
	local blacklist = {}
	
	for i = 1, #bl
		if bl[i] == nil
			print("nil mapnum.")
			return
		end
		local mapnum = ExtMapNumToInt(bl[i])
		if mapnum == nil
			print("Invalid map: " + bl[i])
			return
		end
		table.insert(blacklist, mapnum)
		print("blacklisted map: " + mapnum)
	end
	
	netvote.map_blacklist = blacklist
end, COM_ADMIN)

--MapAvailableGametypes(m)
--Returns a table containing all gametype IDs that the map supports.
local function MapAvailableGametypes(m)
	local h = mapheaderinfo[m]
	if not h
		print("ERROR: map "+ MapIDToName(m) +" has no header.")
		return nil
	end
	
	local gt = {}
	
	if BattleAdded
		local tol_table = {
			[GT_COOP] = TOL_COOP,
			[GT_COMPETITION] = TOL_COMPETITION,
			[GT_RACE] = TOL_RACE,
			[GT_MATCH] = TOL_MATCH,
			[GT_TEAMMATCH] = TOL_MATCH,
			[GT_TAG] = TOL_TAG,
			[GT_HIDEANDSEEK] = TOL_TAG,
			[GT_CTF] = TOL_CTF,
			[GT_ARENA] = TOL_ARENA,
			[GT_TEAMARENA] = TOL_ARENA,
			[GT_SURVIVAL] = TOL_SURVIVAL,
			[GT_TEAMSURVIVAL] = TOL_SURVIVAL,
			[GT_CP] = TOL_MATCH,
			[GT_TEAMCP] = TOL_MATCH,
			[GT_DIAMOND] = TOL_MATCH,
			[GT_TEAMDIAMOND] = TOL_MATCH,
			[GT_EGGROBOTAG] = TOL_TAG,
			[GT_BATTLECTF] = TOL_CTF
		}
		local tol_table2 = {
			[GT_COOP] = TOL_COOP,
			[GT_COMPETITION] = TOL_COMPETITION,
			[GT_RACE] = TOL_RACE,
			[GT_MATCH] = TOL_MATCH,
			[GT_TEAMMATCH] = TOL_MATCH,
			[GT_TAG] = TOL_TAG,
			[GT_HIDEANDSEEK] = TOL_TAG,
			[GT_CTF] = TOL_CTF,
			[GT_ARENA] = TOL_ARENA,
			[GT_TEAMARENA] = TOL_ARENA,
			[GT_SURVIVAL] = TOL_SURVIVAL,
			[GT_TEAMSURVIVAL] = TOL_SURVIVAL,
			[GT_CP] = TOL_CP,
			[GT_TEAMCP] = TOL_CP,
			[GT_DIAMOND] = TOL_DIAMOND,
			[GT_TEAMDIAMOND] = TOL_DIAMOND,
			[GT_EGGROBOTAG] = TOL_EGGROBOTAG,
			[GT_BATTLECTF] = TOL_BATTLECTF
		}
		for i = GT_COOP,GAMETYPE_AMT_BATTLE
			if table_contains_value(netvote.enabled_gametypes,i)
				
				local tol_needed = tol_table[i]
				local tol_needed2 = tol_table2[i]
				if (h.typeoflevel & tol_needed) or (h.typeoflevel & tol_needed2)
					table.insert(gt, i)
				end
			end
		end
	else
		local tol_table = {
			[GT_COOP] = TOL_COOP,
			[GT_COMPETITION] = TOL_COMPETITION,
			[GT_RACE] = TOL_RACE,
			[GT_MATCH] = TOL_MATCH,
			[GT_TEAMMATCH] = TOL_MATCH,
			[GT_TAG] = TOL_TAG,
			[GT_HIDEANDSEEK] = TOL_TAG,
			[GT_CTF] = TOL_CTF
		}

		for i = GT_COOP,GAMETYPE_AMT_VANILLA
			if table_contains_value(netvote.enabled_gametypes,i)
				local tol_needed = tol_table[i]
				if h.typeoflevel & tol_needed
					table.insert(gt, i)
				end
			end
		end
	end
	
	if #gt == 0
		return nil
	end
	
	return gt
end

--GetRandomMaps()
--Returns a table with three random maps, and removes those maps from netvote.mapbag
local function GetRandomMaps()
	ScanMaps()
	netvote.mapbag = {}
	for i = 1, #netvote.maplist
		if MapAvailableGametypes(netvote.maplist[i])
			table.insert(netvote.mapbag, netvote.maplist[i])
		end
	end
	
	if #netvote.mapbag < 3
		print("Error - not enough maps")
		return {1,1,1}
	end
	
	local m = {}
	local index
	for i = 1,3
		index = P_RandomRange(1,#netvote.mapbag)
		m[i] = netvote.mapbag[index]
		table.remove(netvote.mapbag, index)
	end
	return m
end

--GetARandomGametype(m)
--Returns a random gametype ID that is compatible with map m
local function GetARandomGametype(m)
	local gtypes = MapAvailableGametypes(m)
	return gtypes[P_RandomRange(1,#gtypes)]
end

--GetRandomGametypes(m)
--m must be a table with three map IDs in it.
--Returns a table containing 3 random gametypes that correspond with the three maps in table m
local function GetRandomGametypes(m)
	local g = {}
	for i = 1,3
		g[i] = GetARandomGametype(m[i])
	end
	return g
end

--Intermission countdown and voting
addHook("IntermissionThinker", function()
	--Disable vanilla intermission timer text
	if hud.enabled("intermissionmessages")
		hud.disable("intermissionmessages")
	end
	
	--Switch to the score phase
	if netvote.phase == IPH_NONE
		netvote.map_choice = GetRandomMaps()
		netvote.gt_choice = GetRandomGametypes(netvote.map_choice)
		netvote.phase = IPH_SCORE
		netvote.score_timeleft = score_time.value * TICRATE - 1
		netvote.vote_timeleft = vote_time.value * TICRATE - 1
		netvote.end_timeleft = END_TIME * TICRATE - 1
		for player in players.iterate
			player.vote_slot = nil
			player.voted = false
		end
	
	--Score
	elseif netvote.phase == IPH_SCORE
		--Enable the score
		if not hud.enabled("intermissiontally")
			hud.enable("intermissiontally")
		end
		--Timer
		if netvote.score_timeleft > 0
			netvote.score_timeleft = $ - 1
		--Switch to the voting phase
		else
			netvote.phase = IPH_VOTE
			S_StartSound(nil, VSND_VOTE_START, nil)
			S_SetMusicPosition(35000)
		end
	
	--Voting
	elseif netvote.phase == IPH_VOTE
		--Disable the score
		if hud.enabled("intermissiontally")
			hud.disable("intermissiontally")
		end
		--Time to vote
		if netvote.vote_timeleft > 0
			netvote.vote_timeleft = $ - 1
			
			--Reset vote counter each frame
			netvote.vote_tally = {0,0,0}
			
			--Voting controls
			for player in players.iterate
				if player.vote_slot == nil
					player.vote_slot = 1
					player.voted = false
				else
					--Input checking
					local btn = player.cmd.buttons
					local pbtn = player.prevbuttons
					if pbtn == nil
						pbtn = btn
					end
					
					local up = (player.cmd.forwardmove >= 40)
					local down = (player.cmd.forwardmove <= -40)
					local pup = player.prevup
					local pdown = player.prevdown
					
					local confirm =	((btn & BT_JUMP) and not (pbtn & BT_JUMP)) or ((btn & BT_ATTACK) and not (pbtn & BT_ATTACK))
					local cancel = (btn & BT_USE) and not (pbtn & BT_USE)
					local scrollup = up and not pup
					local scrolldown = down and not pdown
					
					if not player.voted
						--Select a map with up and down
						if (scrollup or scrolldown)
							S_StartSound(nil, VSND_SELECT, player)
							if scrollup
								player.vote_slot = $ - 1
							elseif scrolldown
								player.vote_slot = $ + 1
							end
							player.vote_slot = max(1,min($,3))
						end
						
						--Confirm the selection with jump or attack button
						if confirm
							S_StartSound(nil, VSND_CONFIRM, player)
							player.voted = true
						end
					end
					if cancel
						S_StartSound(nil, VSND_CANCEL, player)
						player.voted = false
					end
					
					--Previous frame inputs
					player.prevbuttons = btn
					player.prevup = up
					player.prevdown = down
					
					if netvote.vote_timeleft == 0 and not player.voted
						S_StartSound(nil, VSND_MISSED_VOTE, player)
					end
				end
				
				--Increase the vote tally if it's been selected or if time ran out
				if player.voted
					netvote.vote_tally[player.vote_slot] = $ + 1
				end
			end
			--Countdown beeps for the last few seconds of voting
			if netvote.vote_timeleft == 1 * TICRATE or netvote.vote_timeleft == 2 * TICRATE or netvote.vote_timeleft == 3 * TICRATE
				S_StartSound(nil, VSND_BEEP)
			end
		else
			netvote.phase = IPH_END
			S_StartSound(nil, VSND_SPEEDING_OFF, nil)
			netvote.charruntime = 0
			local skinlist = {"sonic", "tails", "knuckles", "amy", "fang", "metalsonic"}
			netvote.runskin = skinlist[P_RandomRange(1, #skinlist)]
			local winnertext = "\130The winner is: "
			
			local votedslot = 1
            if weighted_random.value
                local num_votes = 3 --Every map gets 1 vote initially
                for i = 1,3
                    num_votes = num_votes + netvote.vote_tally[i]
                end
                local weight_select = P_RandomKey(num_votes)
                local vote_count = 0
                for i = 1,3
                    local current_tally = netvote.vote_tally[i] + 1
                    if weight_select < vote_count + current_tally
                        votedslot = i
                        break
                    else
                        vote_count = vote_count + current_tally
                    end
                end
				winnertext = "\x87(weighted random) The winner is: "
            else
                --Choose the most popular map or roll an RNG tiebreaker. This is probably a dumb way to do this but shut up
				if netvote.vote_tally[1] == netvote.vote_tally[2] and netvote.vote_tally[1] == netvote.vote_tally[3] --three way tiebreaker
					votedslot = P_RandomRange(1,3)
					print("\130There's a three-way tie! Picking randomly...")
				elseif netvote.vote_tally[1] == netvote.vote_tally[2] and netvote.vote_tally[3] < netvote.vote_tally[1] --two way tiebreaker, slot 1 or 2
					votedslot = P_RandomRange(1,2)
					print("\130There's a two-way tie! Picking randomly...")
				elseif netvote.vote_tally[2] == netvote.vote_tally[3] and netvote.vote_tally[1] < netvote.vote_tally[2] --two way tiebreaker, slot 2 or 3
					votedslot = P_RandomRange(2,3)
					print("\130There's a two-way tie! Picking randomly...")
				elseif netvote.vote_tally[1] == netvote.vote_tally[3] and netvote.vote_tally[2] < netvote.vote_tally[1] --two way tiebreaker, slot 1 or 3
					if P_RandomRange(1,2) == 1
						votedslot = 1
					else
						votedslot = 3
					end
					print("\130There's a two-way tie! Picking randomly...")
				else
					local best = 0
					for i = 1, 3
						if netvote.vote_tally[i] > best
							best = netvote.vote_tally[i]
							votedslot = i
						end
					end
				end
            end
			netvote.decided_map = netvote.map_choice[votedslot]
			netvote.decided_gt = netvote.gt_choice[votedslot]
			print(winnertext + MapIDToName(netvote.decided_map) + " (" + IntToGametypeName(netvote.decided_gt) + ")")
		end
	
	--End
	elseif netvote.phase == IPH_END
		--Disable the score
		if hud.enabled("intermissiontally")
			hud.disable("intermissiontally")
		end
		--Timer
		netvote.charruntime = $ + 1
		if netvote.end_timeleft > 0
			netvote.end_timeleft = $ - 1
		--Change the map
		else
			local gotomap = IntToExtMapNum(netvote.decided_map)
			netvote.phase = IPH_STOP
			COM_BufInsertText(server, "map " + gotomap + " -gt " + netvote.decided_gt)
		end
	end
end)

addHook("PlayerThink", function(player)
	--Keep track of the skin each player was last using before intermission
	if player.realmo
		player.lastknownskin = player.realmo.skin
	end
end)

--Intermission voting HUD display
local function hud_voting(v, player)
	local player = consoleplayer
	if netvote.phase == IPH_NONE return end
	
	--Thumbnail pictures of the 3 choices
	local vote_pic = {}
	for i = 1, 3
		local pname = IntToExtMapNum(netvote.map_choice[i]) + "P"
		if v.patchExists(pname)
			vote_pic[i] = v.cachePatch(pname)
		else
			vote_pic[i] = v.cachePatch("BLANKLVL")
		end
	end
	
	--Display stuff based on the current intermission phase
	if netvote.phase == IPH_SCORE
		local score_secondsleft = netvote.score_timeleft / TICRATE
		v.drawString(160, 170, "Vote begins in " + score_secondsleft + " seconds", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_YELLOWMAP, "center")
	
	elseif netvote.phase == IPH_VOTE
		local vote_secondsleft = netvote.vote_timeleft / TICRATE
		v.drawString(160, 16, "*VOTING*", V_SNAPTOTOP, "center")
		v.drawString(160, 170, "Vote ends in " + vote_secondsleft + " seconds", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_YELLOWMAP, "center")
		v.drawString(160, 180, "Select: JUMP     Cancel: SPIN", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM, "small-center")
		
		--Draw the map choices and vote amounts
		local picscale = FRACUNIT / 2
		local xoff = 404
		local yoff = 38
		local borderxoff = -1
		local borderyoff = -1
		local textxoff = 3
		local textyoff = 4
		local gtyoff = 16
		local ybetween = 103
		local mapn = MapIDToName(netvote.map_choice[1])
		local pic = vote_pic[1]
		local cmap1 = v.getColormap(TC_RAINBOW, SKINCOLOR_JET)
		local cmap2 = v.getColormap(TC_DEFAULT)
		local cmap
		local tflags1 = V_ALLOWLOWERCASE | V_SNAPTOLEFT
		local tflags2 = V_ALLOWLOWERCASE | V_SNAPTOLEFT | V_YELLOWMAP
		local tflags
		
		for i = 1, 3
			mapn = MapIDToName(netvote.map_choice[i])
			pic = vote_pic[i]
			
			if player.vote_slot == i
				cmap = cmap2
				tflags = tflags2
			else
				cmap = cmap1
				tflags = tflags1
			end
			
			v.drawScaled(picscale*xoff, picscale*yoff, picscale, pic, V_SNAPTOLEFT, cmap)
			
			if player.vote_slot == i
				local borderpatch = v.cachePatch("SLCT1LVL")
				v.drawScaled(picscale*(xoff + borderxoff), picscale*(yoff + borderyoff), picscale, borderpatch, V_SNAPTOLEFT)
			end
			
			v.drawString((xoff + textxoff)/2, (yoff + textyoff)/2, mapn, tflags, "thin")
			v.drawString((xoff + textxoff)/2, (gtyoff + yoff + textyoff)/2, IntToGametypeName(netvote.gt_choice[i]), tflags, "small")
			
			local headxoff0 = -32
			local headxoff = -32
			local headxstack = -24
			local headyoff = 34
			local headystack = 32
			local amountheads = 0
			for player in players.iterate
				if player.voted and player.vote_slot == i
					local head = v.getSprite2Patch(player.lastknownskin, SPR2_LIFE)
					local cmap = v.getColormap(nil, player.skincolor)
					amountheads = $ + 1
					v.draw((xoff + headxoff)/2, (yoff + headyoff)/2, head, V_SNAPTOLEFT, cmap)
					headxoff = $ + headxstack
					if amountheads == 11 or amountheads == 22
						headyoff = $ + headystack
						headxoff = headxoff0
					end
				end
			end
			
			yoff = $ + ybetween
		end
		
	elseif netvote.phase == IPH_END
		--Thumbnail picture of the winner
		local winner_pic = 0
		local pname = IntToExtMapNum(netvote.decided_map) + "P"
		if v.patchExists(pname)
			winner_pic = v.cachePatch(pname)
		else
			winner_pic = v.cachePatch("BLANKLVL")
		end
		
		local runpos = 500 - 10 * (netvote.charruntime)
		local runframeamt = 4
		local tailframeamt = 4
		local tailframe = 0
		local tailsprite = nil
		local tailoffsetx = 10
		local tailoffsety = 0
		
		if netvote.runskin == "tails"
			runframeamt = 2
			tailframe = (netvote.charruntime / 2) % tailframeamt
			tailsprite = v.getSprite2Patch("tails", SPR2_TAL6, false, tailframe, 3)
		elseif netvote.runskin == "amy"
			runframeamt = 8
		elseif netvote.runskin == "fang"
			runframeamt = 6
		elseif netvote.runskin == "metalsonic"
			runframeamt = 1
			tailframeamt = 3
			tailframe = (netvote.charruntime / 2) % tailframeamt
			tailsprite = v.getSpritePatch("JETF", tailframe)
			tailoffsetx = 18
			tailoffsety = -11
		end
		local runframe = (netvote.charruntime / 2) % runframeamt
		local charcmap = v.getColormap(TC_ALLWHITE, SKINCOLOR_WHITE)
		local charsprite = v.getSprite2Patch(netvote.runskin, SPR2_RUN, false, runframe, 3)
		
		if tailsprite
			v.draw(runpos + 64 + tailoffsetx, 48 + tailoffsety, tailsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_80TRANS, charcmap)
		end
		v.draw(runpos + 64, 48, charsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_80TRANS, charcmap)
		
		if tailsprite
			v.draw(runpos + 32 + tailoffsetx, 48 + tailoffsety, tailsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_60TRANS, charcmap)
		end
		v.draw(runpos + 32, 48, charsprite, V_SNAPTORIGHT | V_SNAPTOTOP | V_60TRANS, charcmap)
		
		if tailsprite
			v.draw(runpos + tailoffsetx, 48 + tailoffsety, tailsprite, V_SNAPTORIGHT | V_SNAPTOTOP, charcmap)
		end
		v.draw(runpos, 48, charsprite, V_SNAPTORIGHT | V_SNAPTOTOP, charcmap)
		
		local end_secondsleft = netvote.end_timeleft / TICRATE
		v.drawString(160, 20, "*DECISION*", V_SNAPTOBOTTOM, "center")
		v.draw(80, 32, winner_pic, V_SNAPTOBOTTOM)
		v.drawString(160, 144, "Speeding off to", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_GREENMAP, "center")
		v.drawString(160, 157, MapIDToName(netvote.decided_map) + " (" + IntToGametypeName(netvote.decided_gt) + ")", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_YELLOWMAP, "center")
		v.drawString(160, 170, "In " + end_secondsleft + " seconds", V_ALLOWLOWERCASE | V_SNAPTOBOTTOM | V_GREENMAP, "center")
	end
end
hud.add(hud_voting, "intermission")