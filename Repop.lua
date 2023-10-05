_addon.name = 'Repop'
_addon.version = '2.1.0'
_addon.author = 'PBW'
_addon.commands = {'repop'}

require('chat')
files = require('files')
config = require('config')
require('tables')
require('functions')
require('logger')
require('vectors')
res = require('resources')
local packets = require('packets')
local mime = require("mime")

local storage = T{}
npc_fields_we_care_about = S{'NPC', 'Index', 'Rotation', 'X', 'Y', 'Z', 'Model'}
mob_name_whitelist = S{'Dimensional Portal','Transcendental Radiance','Incantrix','Survival Guide','Home Point #2','Infernal Transposer','???'}

local in_battlefield = false

local player = windower.ffxi.get_player()
local info = windower.ffxi.get_info()

TimestampFormat = '%H:%M:%S'

if info.logged_in then
    zone_id = info.zone
    if zone_id and zone_id > 0 then
        zone_mob_names = T(windower.ffxi.get_mob_list()):filter(set.contains+{mob_name_whitelist})
    end
end

function repop_cmd(...)
    if arg[1]:lower() == 'showstorage' then
		if arg[2] then
			show_storage(arg[2])
		else
			show_storage()
		end
	elseif arg[1]:lower() == 'showmoblist' then
		showmoblist()
	end
end
	
windower.register_event('incoming chunk',function(id,org,mod,inj,blk)
	if in_battlefield then
		return
	end
    if id == 0x00E then
        local packet = packets.parse('incoming',org)
		local mask_position_update = bit.band(packet['Mask'], 1) > 0
		local hidden_model = bit.band(packet['_unknown2'],2) > 0
		local untargetable = bit.band(packet['_unknown2'],0x80000) > 0
		if zone_mob_names and zone_mob_names[packet.Index] and mask_position_update and packet.Model > 0 and not hidden_model and not untargetable then
			windower.send_ipc_message('C':pack(zone_id)..mime.b64(mod))
			update_storage(packet, mod)
		end
	elseif id == 0x00A then --zoned
		zoning = true
	elseif id == 0x065 then
		zoning = os.time() + 10
	end
end)

windower.register_event('zone change', function(new_id, old_id)
	zone_id = new_id
end)

windower.register_event('outgoing chunk',function(id,org,mod,inj,blk)
	if in_battlefield then
		return
	end
	if id == 0x00C then
		zoning = os.time() + 12
		zone_mob_names = T(windower.ffxi.get_mob_list()):filter(set.contains+{mob_name_whitelist})
	elseif id == 0x015 and (not zoning or type(zoning)=='number' and os.time() >= zoning) then
		zoning = false
		local packet = packets.parse('outgoing', mod)
		local my_position = V({packet.X, packet.Y}, 2)
		npc_check_injection(my_position)
	end
end)

function npc_check_injection(positionA)
	
	local zone_data = storage[zone_id]
	if not zone_data then
		return
	end

	for npc in zone_data:it() do
		local positionB = V({npc.fields.X, npc.fields.Y}, 2)
		local distance = (positionA - positionB):length()
		if distance <= 45 then
			local mob = windower.ffxi.get_mob_by_index(npc.fields.Index)
			if mob and mob.id == 0 and mob.index == 0 and mob.is_npc == false and not mob.model then
				windower.add_to_chat(123,'WARNING: Packet injection for NPC %d "%s" to be visible to the client.':format(npc.fields.Index, npc.name))
				local packet_raw_data = mime.unb64(npc.packet)
				windower.packets.inject_incoming(0x00E, packet_raw_data)
			end
		end
	end

end

windower.register_event('ipc message', function(msg, ...) 
    local zone = msg:unpack('C')
    local modified = mime.unb64(msg:sub(2))
    local packet = packets.parse('incoming', modified)
    update_storage(packet, modified, zone)
end)

windower.register_event("gain buff", function(buff_id)
	if buff_id == 254 then
		in_battlefield = true
    end
end)

windower.register_event("lose buff", function(buff_id)
	if buff_id == 254 then
		in_battlefield = false
    end
end)


function update_storage(packet, modified, zone)
    --check for zone data:
	zone = zone or zone_id
    local zone_data = storage[zone]
    if not zone_data then
        storage[zone] = T{} --create area for npcs
        zone_data = storage[zone]
    end
    --find npc in question:
    local npc = zone_data[packet.Index]
    if not npc then
        zone_data[packet.Index] = T{} --create npc area
        npc = zone_data[packet.Index]
    end
    --check if npc data exists:
    if not npc.timestamp then
        --create data:
        update_npc(npc, packet, modified)
    else -- it exists, check if it needs updated instead:
        local not_same = npc_fields_we_care_about:any(function(key)
            return npc[key] ~= packet[key]     
        end)
        if not_same then
            update_npc(npc, packet, modified)
        end
    end
end

function update_npc(npc, packet, modified)
    npc.timestamp = os.time()
    --npc.name = zone_mob_names[packet.Index]
	npc.name = packet.Name
    npc.packet = mime.b64(modified)
    npc.fields = T(packet):key_filter(set.contains+{npc_fields_we_care_about})
end

function show_storage(zone_param)
	if zone_param then
		table.vprint(storage[zone_param])
	else
		table.vprint(storage)
	end
end

function showmoblist()
	zone_mob_names = T(windower.ffxi.get_mob_list()):filter(set.contains+{mob_name_whitelist})
	table.vprint(zone_mob_names)
end

windower.register_event('addon command', repop_cmd)