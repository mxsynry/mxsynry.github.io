--[[
LUCKY BLESSING / RAYFIELD v0.4.1

Classic Rayfield/ArrayField interface by Arrays and Rafa, originally Sirius,
is bundled below with nil-safe section parenting, scoped helper functions,
tracked service connections and repaired visibility controls. If the classic
UI model cannot load, current official Rayfield is used with the same six tabs.

OPEN / HIDE: Insert or ]. The top-right LB button always reopens the interface.
START: select a Modified Perks preset, choose its matching base perk in the
normal game's loadout menu, then spawn. Selections do not require a character.
UNDO: Restore original perk definitions, Pause, or Destroy UI / unload.
PROFILE: explicit Save / Load; no old duplicate Flags or automatic remote calls.

Repaired paths: current ReplicatedStorage.data.content.perks -> stats/ui/actives;
compatible Workspace.ServerStuff.Statistics.CLASS_STATISTICS -> basestats.
Sovereign root-table mistakes and stray explosive_resist globals are normalized.
The original mainHUD/upvalue-index stamina scan and global getgc cooldown sweep
are not used. Legacy startup whitelist kicks and optional helper auto-loads are
removed. No embedded webhook or automatic Discord RPC is retained.

IMPLEMENTATION AND VERIFICATION:
* Preset edits affect real client definitions. Server-authorized health, damage,
  cooldowns, inventory and auxiliary uses are not established by a client dump.
* CORRECTION to the prior builds: Workspace.ServerStuff.dealDamage and
  ReplicatedStorage.Interactables.interaction DO exist in the supplied dump.
  Existence is not proof that their old requests pass current server validation.
* Original spawn buttons send the original finite blueprint/workbench sequence.
  Craft / find uses owned resources. Neither action is silently substituted.
* Original resource buttons check for dropAmmo at runtime. It is not present
  in the supplied dump. Amount sliders never issue requests by themselves.
* RIS Medic preserves healthmod=999999. Custom Lazarus controls expose actual
  healthmod, min_heal and lazarus_max_heal definition fields. Observed HP is
  read from the character, never faked through a UI-only health setter.
* Built-in regeneration uses the public legacy Regeneration method. It is not
  recovered Snowy code: the original Semi URL returned HTTP 404 when researched.
  It cannot protect against a lethal hit and has not been verified on a server.
* The stamina runtime refill only writes an existing numeric controller state;
  when it is not exposed, the result panel reports definition-capacity-only.
* NPC positioning is local and can be corrected by server replication.
* Death/spawn actions require their actual original endpoints. Dupe Loot sends
  one deliberate death request, with no claim that a duplication happened.
  The server-crasher flood remains disabled.
* Optional archived external scripts run only when clicked. Some old URLs are
  dead. The repair cannot undo independently loaded external scripts.

Runtime dependencies: classic UI model rbxassetid://13067385695, or official
https://sirius.menu/rayfield if that model is unavailable. No hosted core-script
file is required. The original helper links remain in the Other Scripts tab.

Bundled FALLBACK only: 16 traits, 20 normal perks + one debug entry, 10 auxiliaries,
198 items/weapons, 145 NPC definitions and 102 interactions from your .rbxl dump.
Verification: official Luau compilation and isolated mock-client scenarios.
No live Roblox session was available; this is not a claim of live-game success.

RESEARCH SOURCES (read as text, never auto-executed):
https://rblx-decaying-winter.fandom.com/wiki/Lazarus
https://rblx-decaying-winter.fandom.com/wiki/Survivalist_Perk_Guide
https://rblx-decaying-winter.fandom.com/wiki/Effects
https://github.com/Havenviex/decaying_winter/blob/main/GOODWILL_COMMAND_SCRIPT
https://scriptblox.com/script/Decaying-Winter-script-not-finished-24262
https://github.com/IrishBaker/scripts/tree/main/decaying%20winter
https://scriptblox.com/script/Decaying-Winter-SkidWare-or-Keyless-228345
]]

local Services = {
    Players = game:GetService("Players"),
    Run = game:GetService("RunService"),
    Input = game:GetService("UserInputService"),
    World = game:GetService("Workspace"),
    Lighting = game:GetService("Lighting"),
    Replicated = game:GetService("ReplicatedStorage"),
    Http = game:GetService("HttpService"),
    Starter = game:GetService("StarterGui"),
    Teleport = game:GetService("TeleportService"),
}
local LP = Services.Players.LocalPlayer
assert(LP, "DW Field Kit must run on the client.")
local Environment = (type(getgenv) == "function" and getgenv()) or _G
if type(Environment.DW_RayfieldFieldKit) == "table" and type(Environment.DW_RayfieldFieldKit.Unload) == "function" then
    pcall(Environment.DW_RayfieldFieldKit.Unload)
end

-- Embedded snapshot from the uploaded place. Replaced by the build step.
local Catalog = Services.Http:JSONDecode([==[{"traits":{"boned":{"name":"Tormented","description":"Max Health increased by 20.","stats":{"1":20}},"boxer":{"name":"Aggressive Behaviour","description":"Gain 25% more melee damage while using Fists and perform shoves 30% faster.","stats":{"1":25,"2":30}},"hip":{"name":"Lone Wolf","description":"Hip fire ranged weapons 65% more accurately.\nShoot lever-action rifles and revolvers faster.","stats":{"1":65}},"honor":{"name":"Honorable","description":"Double damage while using fists.","stats":{"1":100}},"leg":{"name":"Impatient","description":"Gain 15% more movement speed.","stats":{"1":15}},"lungs":{"name":"Calm","description":"Max Stamina increased by 75.","stats":{"1":75}},"manic":{"name":"Manic","description":"Perform Heavy Swings with melee weapons 45% faster.","stats":{"1":45}},"paranoia":{"name":"Paranoid","description":"Shoot semi-automatic firearms 50% faster.\n150% increased ADS speed.","stats":{"1":150,"2":50}},"recoil":{"name":"Professional","description":"Reduce felt recoil from all firearms by 65%.\nRemove weapon sway while moving.","stats":{"1":65}},"regen":{"name":"Survivor","description":"Restore 1 health every 10 seconds.","stats":{"1":10}},"reliab":{"name":"Reliable","description":"Perform reloads with firearms 65% faster.\nNo additional time delay when reloading from empty","stats":{"1":65}},"rustic":{"name":"Methodical","description":"Deal 15% more melee damage.","stats":{"1":15}},"second":{"name":"Relentless","description":"Faster stamina regeneration","stats":{"1":30,"2":10,"3":15}},"thick":{"name":"Fearless","description":"Receive 25% less damage from firearms and explosives.","stats":{"1":25}},"tough":{"name":"Dependable","description":"Receive 15% less damage.","stats":{"1":15}},"violence":{"name":"Violent Tendencies","description":"Perform Light Swings with melee weapons 45% faster.","stats":{"1":45}}},"perks":{"berz":{"name":"Berserker","description":"Carving a path through relentless battles, you believe that survival is to overcome anything alone, no matter the odds.","class":"frontliner","pros":{"1":"+25% Melee Damage","2":"+15% Damage Resistance","3":"Unable to be Grappled.","4":"Immune to Fracture."},"cons":{"1":"-100% Recoil Control","2":"-65% Reload Speed"},"stats":{"atkmod":25.0,"defmod":15.0,"frac_immune":true,"grap":true,"recoilmod":-100.0,"reloadmod":-65.0},"actives":{"main":{"name":"Calamity Serum","description":"Upon injection, gain increased attack damage, speed and bloodlust. Duration increased on kills and parries. Fatigue on end.","stats":{"activeend":1.0,"atkboost":60.0,"cooldown":45.0,"duration":12.0,"healthonaction":2.0,"regenonkill":2.0,"regenonparry":6.0,"speedboost":25.0}}}},"dagger":{"name":"Sovereign","description":"You believe in the truth of higher power that will guide you to not only survival - but also true enlightenment.","class":"support","pros":{"1":"Cursed Dagger","2":"+50 Stamina"},"cons":{"1":"-15% Melee Damage","2":"-10% Walkspeed"},"stats":{"atkmod":-15.0,"mvtmod":-10.0,"stammod":50.0},"actives":{"main":{"name":"'Cytherean' Ritual Dagger","description":"Throw an Accursed Dagger that hexes nearby enemies. Can be used out of cooldown by performing Bloodletting.","stats":{"activeend":1.3,"blood_damage":14.0,"cooldown":50.0,"dagger_damage":10.0,"spectral_amount":3.0,"spectral_decay":8.0,"spectral_range":35.0,"useanyduration":true}}}},"damn":{"name":"Damned","description":"Condemned and cursed, you've lost everything. The only way forward is to survive when all is lost.","class":"unique","pros":{"1":"Morale does not affect you","2":"You are fearless"},"cons":{"1":"Starving","2":"Reduced combat and movement capability","3":"Unable to use your equipment"},"stats":{"accmod":-55.0,"atkmod":-40.0,"defmod":-40.0,"fearless":true,"heavyatkspeed":-40.0,"lightatkspeed":-40.0,"mvtmod":-40.0,"no_ability":true,"no_aim_mod":true,"no_aux":true,"no_morale":true,"recoilmod":-55.0,"reloadmod":-55.0,"shovemod":-40.0},"actives":{"main":{"name":"None","description":"Condemned and cursed. For those seeking a challenge.","stats":{}}}},"debug":{"name":"Taro's Hivemind","description":"Lore accurate hivemind","class":"backliner","pros":{"1":""},"cons":{},"stats":{"atkmod":1000.0,"bleed_immune":true,"cripple_immune":true,"defmod":1000.0,"exhaust_immune":true,"fearless":true,"frac_immune":true,"grap":true,"healthmod":900.0,"mvtmod":400.0,"no_morale":true,"recoilmod":1000.0,"reloadmod":1000.0,"shovemod":1000.0,"stammod":900.0},"actives":{"main":{"name":"Dev's blessings","description":"","stats":{"activeend":2.0,"cooldown":2.0}}}},"drift":{"name":"Drifter","description":"Drifting amongst the shadow, one to one with the great smoke, you believe in the truth, and that one day, it will be known.","class":"frontliner","pros":{"1":"+30% Melee Damage","2":"Immune to Cripple","3":"Immune to Exhaustion"},"cons":{"1":"-50% Recoil Control","2":"-10 Max Health","3":"-40% Reload Speed"},"stats":{"atkmod":30.0,"cripple_immune":true,"exhaust_immune":true,"healthmod":-10.0,"recoilmod":-50.0,"reloadmod":-40.0},"actives":{"main":{"name":"Anchor RSB / M.B Type 'Dread'","description":"Deploy a smoke bomb that Cloaks you and Teammates then equip Dread. Hold to project yourself at a distance, leaving an Anchor.","stats":{"activeend":1.2,"alt_swing_charge":2.0,"alt_swing_damage":150.0,"alt_swing_lifesteal":15.0,"cooldown":40.0,"drift_cloak_aoe":15.0,"drift_duration":21.0,"drift_project_range":60.0,"perk_gain":0.05,"perk_gain_heavy":0.2,"speed_boost":45.0,"swing_damage":100.0,"swing_duration_take":5.0,"swing_lunge":1.0,"swing_range":6.0}}}},"fire":{"name":"Immolator","description":"Cursing all as unclean, you firmly stand that the only way to survive is to light a torch to all that is unwelcome.","class":"support","pros":{"1":"Immune to Burning","2":"+25% Melee Damage"},"cons":{"1":"-15% Reload Speed"},"stats":{"atkmod":25.0,"burnimmune":true,"reloadmod":-15.0},"actives":{"main":{"name":"Flamer Unit 'CHAOS'","description":"Immolate everything around you. Hold to prime OV-FT, igniting enemies. More Overheat increases melee damage. Do not fully Overheat.","stats":{"activeend":0.9,"cooldown":90.0,"flamer_burn_damage":5.0,"flamer_burn_tick":0.75,"flamer_overheat":2.0,"flamer_range":10.0,"flamer_slowdown":3.0,"immolate_damage":40.0,"immolate_overheat":45.0,"immolate_range":15.0,"inverse_cd":true,"overheat_cooldown_multiplier":0.5,"overheat_damage_buff":90.0,"overheat_graceperiod":0.1,"overheat_gun_multiplier":1.0,"useanyduration":true}}}},"goggles":{"name":"Executioner","description":"You believe you have a job to do and surviving only comes second to accomplishing what is due.","class":"frontliner","pros":{"1":"+20% Damage Resistance","2":"+50 Stamina","3":"+30% Attack Speed","4":"+25% Shove Speed"},"cons":{"1":"-100% Hipfire Accuracy","2":"-30% Recoil Control","3":"Cannot use Scrappers"},"stats":{"accmod":-100.0,"defmod":20.0,"heavyatkspeed":30.0,"lightatkspeed":30.0,"no_scrapper":true,"norecycle":true,"recoilmod":-30.0,"shovemod":25.0,"stammod":50.0},"actives":{"main":{"name":"Kill-Warrant GPNVG-M42","description":"Lower goggles to view information on Enemies. Claim and redeem bounties for melee damage and scrap. Receiving attacks will damage goggles.","stats":{"activeend":0.7,"boostonkill":10.0,"cooldown":190.0,"damage_taken_multi":1.75,"scrap_per_bounty":7.0,"useanyduration":true}}}},"gunner":{"name":"Riskrunner","description":"You believe that overwhelming firepower is the only way to survive, to be able to blaze through all odds.","class":"backliner","pros":{"1":"+80% Hipfire Accuracy","2":"+80% Recoil Control","3":"Unable to be Grappled"},"cons":{"1":"Inability to aim ranged weapons","2":"-10% Walkspeed","3":"Scavenge much less ammo"},"stats":{"accmod":80.0,"grap":true,"mvtmod":-10.0,"no_aim_mod":true,"recoilmod":80.0,"scavmod":0.25},"actives":{"main":{"name":"TYPE-19 VULKA-MG","description":"Arm and wield the high power VULKA Machine Gun. Ammo Pickups will refill VULKA faster. Can only be armed at 50% or more. Designed for sustained fire only.","stats":{"activeend":1.0,"ammo_cd_pickup":50.0,"cooldown":360.0,"perk_mincd":180.0,"start_empty":true,"vulka_accuracy":3.5,"vulka_accuracy_timer":2.5,"vulka_ammo_usage":4.0,"vulka_damage":18.0,"vulka_overheat_duration":3.0,"vulka_range":200.0,"vulka_rpm":900.0,"vulka_slowdown":7.0}}}},"hive":{"name":"Hivemind","description":"We believe in the safety of us, in safety of numbers, survival is only second nature to being collective as one.","class":"backliner","pros":{"1":"Immune to Bleed","2":"HIVE Aura"},"cons":{"1":"-15 Max Health","2":"-20% Recoil Control","3":"-20 Stamina"},"stats":{"bleed_immune":true,"healthmod":-15.0,"recoilmod":-20.0,"stammod":-20.0},"actives":{"main":{"name":"HIVE Actuator","description":"Release a swarm of programmed toxic insects. Swap between DISPERSE, DIVIDE and DIRECT. Swarms will debilitate enemies.","stats":{"activeend":0.7,"attack_tick":0.75,"aura_sickness":1.5,"aura_slow":1.5,"aura_tick":0.5,"cooldown":40.0,"hive_bleed_wound":1.0,"hive_disperse_studs":20.0,"hive_divide_studs":50.0,"hive_duration":40.0,"hunt_charge_duration":1.0,"hunt_chargespeed":0.1,"hunt_damage":5.0,"hunt_lerpspeed":0.03,"normal_damage":5.0,"sickness_wait":2.0,"slow_duration":2.0,"useanyduration":true}}}},"lazarus":{"name":"Lazarus","description":"Through the art of experience, you believe that self perseverance is the strongest motivator to survival.","class":"support","pros":{"1":"+20 Max Health","2":"Immune to bleeds"},"cons":{"1":"Drop ranged weapons on damage","2":"-25% Reload Speed","3":"-20% Melee Damage"},"stats":{"atkmod":-20.0,"bleed_immune":true,"drop_ranged":true,"healthmod":20.0,"reloadmod":-25.0},"actives":{"main":{"name":"ARTIK-NCU Device","description":"Press to fire a bolt that numbs pain and saves lives. Hold to fire a bolt that can heal teammates. Enemies hit by bolts will be shocked. Two charges.","stats":{"activeend":0.8,"bolt_radius":15.0,"cooldown":70.0,"enemy_slow_duration":8.0,"lazarus_max_heal":8.0,"lazarus_shoot_range":70.0,"min_heal":20.0,"multicooldown":35.0}}}},"mind":{"name":"Mindflayer","description":"You believe intellect and wits are the only way to truly survive - without planning ahead, others are lost","class":"support","pros":{"1":"+20% Walkspeed","2":"+25% Shove Speed"},"cons":{"1":"-15% Recoil Control","2":"-20% Damage Resistance"},"stats":{"defmod":-20.0,"mvtmod":20.0,"recoilmod":-15.0,"shovemod":25.0},"actives":{"main":{"name":"MD.K1LR-6B Prototype","description":"Release a Mindkiller spider in front of you. Hold to Throw. Will latch onto and convert injured Enemies. Three Charges.","stats":{"activeend":1.2,"cooldown":90.0,"hang_time":30.0,"latch_held_throw":50.0,"latch_min_active":0.5,"latch_range":8.0,"latch_throw":15.0,"low_count":79.0,"multicooldown":30.0,"reducecooldown":30.0,"throw_hang_time":5.0,"throw_min_active":0.0,"time_until_det":30.0}}}},"ranger":{"name":"Blitzer","description":"You believe in the brave and the risk takers who have survived from their commitment - you intend to be a part of that list.","class":"backliner","pros":{"1":"+30% Damage with Explosives","2":"+65% Aiming Speed","3":"Immune to Explosives effects"},"cons":{"1":"-15% Melee Damage","2":"-50% Trap Deployment Speed"},"stats":{"aimmod":65.0,"atkmod":-15.0,"explosive_resist":true,"explosivemod":30.0,"trapmod":-50.0},"actives":{"main":{"name":"'Izbucni' Gift","description":"Arm an explosive air-burst payload that causes disorientation and sticks to anything. Hold to detonate. Six Charges.","stats":{"activeend":0.5,"cluserfuse":0.65,"clusters":6.0,"cooldown":90.0,"explosiondamage":10.0,"explosionradius":10.0,"max_bombs":32.0,"multicooldown":15.0,"throwvelocity":50.0,"useanyduration":true}}}},"revolver":{"name":"Artillerist","description":"One shot one kill - an art form you believe in, with every shot capable of opening new opportunities.","class":"backliner","pros":{"1":"+50% Reload Speed","2":"+40% Hipfire Accuracy","3":"Scavenge more ammo."},"cons":{"1":"-25% Shove Speed","2":"-15% Damage Resistance"},"stats":{"accmod":40.0,"defmod":-15.0,"reloadmod":50.0,"scavmod":1.3,"shovemod":-25.0},"actives":{"main":{"name":"M.A.G.N.U.M 'Impusca Vana'","description":"Ready a high calibre revolver before firing. Gain a buff and reduce cooldown on Headshot kill. Pierces Resistances.","stats":{"activeend":1.8,"cooldown":20.0,"revolver_cooldown_reduce_on_kill":10.0,"revolver_damage":75.0,"revolver_headshot_multi":2.0,"revolver_pierce":2.0,"revolver_range":400.0}}}},"scan":{"name":"Prophet","description":"A keen eye for supplies and tactical planning is the only way for survival, you intend to capitalise on that.","class":"support","pros":{"1":"+20% Walkspeed","2":"Faster Harvesting","3":"Faster Crude Crafting","4":"No fall damage."},"cons":{"1":"-15% Melee Damage"},"stats":{"atkmod":-15.0,"falldamagemod":true,"harvestmod":6.0,"mvtmod":20.0},"actives":{"main":{"name":"Savant's Scanner","description":"Hold to scan and analyse the surrounding, marking supplies for yourself. Press to scan in front of you, marking Enemies for Teammates. Marked Enemies are more susceptible.","stats":{"activeend":1.0,"cooldown":30.0,"front":60.0,"healthreduction":25.0,"scan_around":60.0,"scan_around_timer":2.0,"scanlast":20.0,"studsscan":80.0,"useanyduration":true}}}},"shadow":{"name":"Apostle","description":"Drawn to the occult, absorbed by the shadow and chose rejection, yet still alive to tell the tale. You believe in your end drawing near.","class":"frontliner","pros":{"1":"Start with Theourgia's Hand","2":"Shadow's body","3":"+10% Damage Resistance","4":"+25 Max Health","5":"You are fearless"},"cons":{"1":"Cannot drop Theourgia's Hand","2":"Inability to aim ranged weapons","3":"-10% Walkspeed"},"stats":{"can_command":true,"cripple_immune":true,"defmod":10.0,"fearless":true,"frac_immune":true,"healthmod":25.0,"mvtmod":-10.0,"no_aim_mod":true},"actives":{"main":{"name":"Seal of Reikala","description":"Press and Hold to summon a Shadow Hunter that will target nearby enemies. Press to shoot a stake and Condemn enemies. Shadow Hunters will focus Condemneds. Condemned kills reduce cooldown. Press B to command Shadow Hunters, hold to cancel.","stats":{"activeend":1.4,"cast_damage":20.0,"cd_add_on_kill":15.0,"cooldown":240.0,"hand_summon":0.0,"maxshadows":2.0,"stakehealamount":20.0,"tag_cast_damage":5.0,"tag_last":25.0,"useanyduration":true}}}},"shield":{"name":"Zealot","description":"You believe that a strong bond is the true path to survival, Will and Dedication would only get you so far alone.","class":"support","pros":{"1":"+35 Max Health","2":"+35% Damage Resistance"},"cons":{"1":"-15% Walkspeed","2":"-25% Attack Speed"},"stats":{"defmod":35.0,"healthmod":35.0,"heavyatkspeed":-25.0,"lightatkspeed":-25.0,"mvtmod":-15.0},"actives":{"main":{"name":"Aegis VOID-DS","description":"Deploy the Aegis barrier and automated turret in Guard mode. Hold to guard with the Aegis shield in Protect mode.","stats":{"activeend":0.7,"aegisdamagetakenmelee":1.0,"aegisdefenseboost":4.0,"aegisduration":50.0,"aegisrangeddamagemultiplier":0.5,"cooldown":40.0,"targetfront":18.0,"turretRPM":300.0,"turretdamage":8.0,"turretduration":30.0,"turrethealth":150.0}}}},"shotgun":{"name":"Arbiter","description":"You believe that taking initiative and setting things straight first is the only way for survival to succeed.","class":"frontliner","pros":{"1":"+30% Melee Damage","2":"+30 Max Health","3":"Immune to Cripple"},"cons":{"1":"-65% Reload Speed","2":"-100% Hipfire Accuracy"},"stats":{"accmod":-100.0,"atkmod":30.0,"cripple_immune":true,"healthmod":30.0,"reloadmod":-65.0},"actives":{"main":{"name":"Augmentation 'Knuckleboom'","description":"Fire a shotshell blast from your wrist. Disorientates and damages Enemies - causes user knockback. Punching your bullet at the half-second mark grants more range.","stats":{"activeend":1.0,"blast_damage":45.0,"blast_forward":5.0,"blast_knockback":60.0,"blast_punch_multiplier":2.0,"blast_punch_range":50.0,"blast_punch_window":0.1,"blast_range":8.0,"cooldown":10.0}}}},"survival":{"name":"Survivalist","description":"You've learned that the only way to survive alone is to be prepared for everything.","class":"unique","pros":{"1":"Start with Backpack equipped","2":"Extra home supplies. (50 scrap)","3":"More resilient to hunger and thirst.","4":"Spawn with rations."},"cons":{},"stats":{"backpack":true,"no_ability":true,"no_morale_impact":true},"actives":{"main":{"name":"None","description":"Jack of most trades, master of none. Perfect beginner Perk.","stats":{}}}},"sword":{"name":"Vagabond","description":"There is only one constant to surviving alone - taking matters into your own hands, no matter the costs.","class":"frontliner","pros":{"1":"+30% Attack Speed","2":"+15% Walkspeed","3":"+15% Melee Damage"},"cons":{"1":"-15 Max Health","2":"-10% Damage Resistance"},"stats":{"atkmod":15.0,"defmod":-10.0,"healthmod":-15.0,"heavyatkspeed":30.0,"lightatkspeed":30.0,"mvtmod":15.0},"actives":{"main":{"name":"Nomad Blade 'Kira'","description":"Swing 'Kira' in a slash in-front of you. Executing Enemies with 'Kira' grants 1 Dogtag. Hold to redeem Dogtags for health.","stats":{"activeend":1.4,"cooldown":36.0,"dogtagmaxmovement":10.0,"dogtagmovementbuff":10.0,"dogtagreduction":4.0,"dogtagsdamagetimer":1.5,"dogtagsheavydamage":20.0,"dogtagslostondamage":50.0,"frontradius":6.0,"healthperdogtag":5.0,"kiramaxdamage":75.0,"kiramindamage":15.0,"mincooldown":1.5,"useanyduration":true}}}},"trapper":{"name":"Tickspider","description":"Trickery and cunningness is what lets you survive on your own terms without relying on others.","class":"backliner","pros":{"1":"+30% Damage with Explosives","2":"+50% Trap Deployment Speed","3":"+40% Recoil Control"},"cons":{"1":"-10% Walkspeed","2":"-15% Melee Damage"},"stats":{"atkmod":-15.0,"explosivemod":30.0,"mvtmod":-10.0,"recoilmod":40.0,"trapmod":50.0},"actives":{"main":{"name":"PARAGON Ticks","description":"Throw an explosive Tick in front of you. Ticks will detonate in the presence of nearby Enemies. Hold to enable Seeking. Three Charges.","stats":{"activeend":1.5,"cooldown":103.0,"maxticks":99.0,"multicooldown":30.0,"tickarmtime":3.0,"tickarmtime_mover":1.0,"tickdetectionradius":6.5,"tickdetectionradius_mover":6.5,"tickexplosiondamage":60.0,"tickexplosiondamage_mover":40.0,"tickexplosionradius":15.0,"tickexplosionradius_mover":15.0,"tickseekrange":25.0,"tickslowduration":8.0,"tickthrow":15.0,"ticktimetodet":0.5,"tickwoundintensity":4.0}}}},"wire":{"name":"Crosslink","description":"An elegant dancer, from one wire to another on a razor thin thread - you believe true finesse can carry you to the end.","class":"backliner","pros":{"1":"+20% Walkspeed","2":"Does not set off traps","3":"+30% Hipfire Accuracy","4":"+50% Trap Deployment Speed"},"cons":{"1":"-10% Melee Damage","2":"-20% Damage Resistance"},"stats":{"accmod":30.0,"atkmod":-10.0,"defmod":-20.0,"mvtmod":20.0,"trapmod":50.0},"actives":{"main":{"name":"Cross-Wire Spool C3-7","description":"Throw Cross-Wire linking daggers that interrupt enemies. Returning Daggers damages enemies in the path and restore charges. Five Charges.","stats":{"activeend":1.0,"cooldown":150.0,"max_dagger_return_range":45.0,"max_link_range":40.0,"min_link_range":4.0,"multicooldown":30.0,"returncooldowns":"not used, check shared/perk for the handling for now","useanyduration":true,"wire_bleed_intensity":1.0,"wire_caught_damage":10.0,"wire_dagger_last":80.0,"wire_dagger_stack_damage":20.0,"wire_return_bleed":2.0,"wire_return_damage":20.0}}}}},"equipment":{"ballistic_dagger":{"name":"Ballistic Dagger","description":"Spring loaded knife that ejects the blade with a toxic payload. Can be swung in a pinch.","uses":1.0,"stats":{"impact_damage":12.0}},"concertina_bomb":{"name":"Concertina Bomb","description":"Razor wire bundle that can block an area with sharp Concertina. Will cause Bleeding.","uses":1.0,"stats":{"bleed_intensity":4.0,"damage":5.0,"held":true,"num_wires":13.0,"slow_time":5.0,"throw_velocity":30.0,"trigger_timer":2.5}},"holo_emitter":{"name":"Hologram Emitter","description":"Emission device that creates a convincing Hologram to seek out and divert attention.","uses":2.0,"stats":{}},"koldera":{"name":"Koldera PRT-STRS","description":"The latest prototype developed in Koldera's labs, injects stress relief chemicals directly into the bloodstream via stimulant.","uses":1.0,"stats":{}},"ladder":{"name":"Collapsible Ladder","description":"Steel framed ladder that allow access to vertical travel or escape. Fickle.","uses":1.0,"stats":{}},"matchsticks":{"name":"SANC Matchsticks","description":"Mass manufactured matchsticks. Used to cauterise and fully heal light wounds.","uses":1.0,"stats":{"burn_heal":5.0,"lower_max_heal":15.0}},"respirator":{"name":"Emergency Respirator","description":"Quick-Attach Respirator allowing you to temporarily breathe in storm, increases visibility in the storm and prevents exhaust.","uses":1.0,"stats":{}},"shrapnel_device":{"name":"Shrapnel Device","description":"Shrapnel cartridges loaded on a fuse triggered device. Fans out Fracturing shrapnel on a cycle.","uses":2.0,"stats":{"cycles":3.0,"frac_intensity":4.0,"held":true,"shrap_damage":8.0,"shrap_range":25.0,"throw_velocity":25.0,"time_between_cycle":1.5,"trigger_range":200.0,"trigger_timer":1.0}},"tear_gas":{"name":"Tear Gas","description":"Riot Control grenade that detonates on impact. Disorientates enemies, causing them to lose focus.","uses":2.0,"stats":{"damage":10.0,"held":true}},"throwing_knives":{"name":"Throwing Knives","description":"Set of knives that allow for silent takedowns. Highly effective on unaware enemies.","uses":3.0,"stats":{"held":true}}},"items":{"SHammer":{"scrap_value":{"min":17.0,"max":17.0},"weapontype":"Bludgeon","animset":"2H","name":"Sledgehammer","damagerating":{"1":18,"2":71},"rarity":4,"speedrating":1,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":2,"ability":"Heavy, slow, hard hitting."},"Hyperlame":{"scrap_value":{"min":17.0,"max":17.0},"weapontype":"Blade","animset":"1HS","name":"Lameo-Blade","damagerating":{"1":20,"2":50},"rarity":4,"speedrating":4,"woundrating":3,"chargerating":4,"throwrating":1,"sizerating":3,"ability":"Hyper lame."},"Fist":{"scrap_value":null,"weapontype":"Fists","animset":"Fists","name":"Fists","damagerating":{"1":6,"2":20},"speedrating":2,"woundrating":null,"chargerating":2,"throwrating":null,"sizerating":1,"ability":"Better than nothing.","blacklisted":true},"CKnife":{"weapontype":"Blade","scrap_value":{"min":11.0,"max":11.0},"animset":"1HBL","name":"Combat Knife","damagerating":{"1":13,"2":30},"rarity":2,"speedrating":4,"woundrating":2,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"Outdated but still reliable."},"RPier":{"weapontype":"Blade","scrap_value":{"min":14.0,"max":14.0},"animset":"1HBL","name":"Rapier","damagerating":{"1":17,"2":50},"rarity":3,"speedrating":1,"woundrating":3,"chargerating":4,"throwrating":1,"sizerating":3,"ability":"Old earth weaponry, good for thrusts."},"KaramB":{"weapontype":"Blade","scrap_value":{"min":14.0,"max":14.0},"animset":"1HBL","name":"Specialist Knife","damagerating":{"1":17,"2":55},"rarity":3,"speedrating":4,"woundrating":4,"chargerating":2,"throwrating":1,"sizerating":2,"ability":"Stylish knife, cuts deep."},"IPick":{"weapontype":"Axe","scrap_value":{"min":11.0,"max":11.0},"animset":"1HAXE","name":"Ice Axe","damagerating":{"1":13,"2":43},"rarity":2,"speedrating":3,"woundrating":3,"chargerating":3,"throwrating":1,"sizerating":2,"ability":"Traditional, well balanced."},"MilAxe":{"weapontype":"Axe","scrap_value":{"min":14.0,"max":14.0},"animset":"1HAXE","name":"Military Axe","damagerating":{"1":16,"2":54},"rarity":3,"speedrating":1,"woundrating":3,"chargerating":2,"throwrating":2,"sizerating":2,"ability":"Military issued. Chops well."},"TSpear":{"weapontype":"Spear","scrap_value":{"min":14.0,"max":14.0},"animset":"2HSPR","name":"Tactical Spear","damagerating":{"1":16,"2":51},"rarity":3,"speedrating":3,"woundrating":3,"chargerating":2,"throwrating":2,"sizerating":4,"ability":"Long reach, stabs deep."},"SCKnife":{"weapontype":"Blade","scrap_value":{"min":8.0,"max":8.0},"animset":"1HBL","name":"Scissors","damagerating":{"1":8,"2":34},"rarity":1,"speedrating":4,"woundrating":4,"chargerating":1,"throwrating":3,"sizerating":2,"ability":"Cuts well enough."},"BKnuckles":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"Fists","name":"Brass Knuckles","damagerating":{"1":9,"2":32},"rarity":1,"speedrating":3,"woundrating":3,"chargerating":3,"throwrating":1,"sizerating":2,"ability":"Fit for a brute."},"THand":{"weapontype":"Axe","scrap_value":null,"animset":"1TH","name":"Theourgia's Hand","damagerating":{"1":15,"2":50},"speedrating":3,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":2,"ability":"Bleed through the pain, once accursed.","blacklisted":true},"HKnife":{"weapontype":"Blade","scrap_value":{"min":14.0,"max":14.0},"animset":"Fists","name":"Hidden Knife","damagerating":{"1":15,"2":56},"rarity":3,"speedrating":1,"woundrating":4,"chargerating":4,"throwrating":1,"sizerating":2,"ability":"Good for poking from behind."},"NSword":{"weapontype":"Blade","scrap_value":{"min":11.0,"max":11.0},"animset":"1HS","name":"Wakizashi","damagerating":{"1":15,"2":40},"rarity":2,"speedrating":3,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Old earth blade."},"CBar":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"1HB","name":"Crowbar","damagerating":{"1":9,"2":37},"rarity":1,"speedrating":2,"woundrating":3,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"Good against headcrabs."},"PBaton":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"1HB","name":"Police Baton","damagerating":{"1":9,"2":38},"rarity":1,"speedrating":4,"woundrating":4,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"Police brutality."},"LPipe":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"1HB","name":"Lead Pipe","damagerating":{"1":10,"2":33},"rarity":1,"speedrating":4,"woundrating":1,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"Full of lead."},"FPan":{"weapontype":"Bludgeon","scrap_value":{"min":11.0,"max":11.0},"animset":"1HB","name":"Frying Pan","damagerating":{"1":10,"2":40},"rarity":2,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":2,"ability":"Heavy bottom hits hard."},"CHammer":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"1HB","name":"Construction Hammer","damagerating":{"1":9,"2":36},"rarity":1,"speedrating":3,"woundrating":1,"chargerating":2,"throwrating":1,"sizerating":2,"ability":"Good for hammering nails in."},"FAxe":{"weapontype":"Axe","scrap_value":{"min":17.0,"max":17.0},"animset":"2H","name":"Fire Axe","damagerating":{"1":20,"2":65},"rarity":4,"speedrating":2,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Can chop fires."},"SAxe":{"weapontype":"Axe","scrap_value":{"min":14.0,"max":14.0},"animset":"2H","name":"Splitting Axe","damagerating":{"1":15,"2":63},"rarity":3,"speedrating":3,"woundrating":2,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Splits torsos as well as wood."},"BSpear":{"weapontype":"Spear","scrap_value":{"min":11.0,"max":11.0},"animset":"2HSPR","name":"Boar Spear","damagerating":{"1":14,"2":46},"rarity":2,"speedrating":1,"woundrating":1,"chargerating":4,"throwrating":3,"sizerating":4,"ability":"Boars are extinct."},"HBerd":{"weapontype":"Axe","scrap_value":{"min":17.0,"max":17.0},"animset":"2HSPR","name":"Halberd","damagerating":{"1":18,"2":60},"rarity":4,"speedrating":3,"woundrating":3,"chargerating":3,"throwrating":2,"sizerating":4,"ability":"Good for thrusting and slashing."},"Rake":{"weapontype":"Axe","scrap_value":{"min":8.0,"max":8.0},"animset":"2H","name":"Rake","damagerating":{"1":8,"2":34},"rarity":1,"speedrating":4,"woundrating":1,"chargerating":4,"throwrating":1,"sizerating":3,"ability":"Light but weak."},"DMusket":{"weapontype":"Spear","scrap_value":{"min":14.0,"max":14.0},"animset":"2HSPR","name":"Decommissioned Musket","damagerating":{"1":17,"2":53},"rarity":3,"speedrating":1,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":4,"ability":"Not loaded anymore."},"PSpear":{"weapontype":"Spear","scrap_value":{"min":11.0,"max":11.0},"animset":"2HSPR","name":"Pike","damagerating":{"1":12,"2":41},"rarity":2,"speedrating":4,"woundrating":2,"chargerating":1,"throwrating":3,"sizerating":4,"ability":"Old earth weaponry. Still sharp."},"PFork":{"weapontype":"Spear","scrap_value":{"min":8.0,"max":8.0},"animset":"2HSPR","name":"Pitchfork","damagerating":{"1":8,"2":33},"rarity":1,"speedrating":1,"woundrating":4,"chargerating":2,"throwrating":2,"sizerating":4,"ability":"Good for farming."},"MFork":{"weapontype":"Spear","scrap_value":{"min":11.0,"max":11.0},"animset":"2HSPR","name":"Military Fork","damagerating":{"1":13,"2":42},"rarity":2,"speedrating":2,"woundrating":1,"chargerating":2,"throwrating":2,"sizerating":4,"ability":"Well balanced for thrusting."},"TJavelin":{"weapontype":"Spear","scrap_value":{"min":11.0,"max":11.0},"animset":"2HSPR","name":"Throwing Javelin","damagerating":{"1":15,"2":45},"rarity":2,"speedrating":2,"woundrating":4,"chargerating":1,"throwrating":4,"sizerating":4,"ability":"Too heavy to throw."},"CCleaver":{"weapontype":"Axe","scrap_value":{"min":8.0,"max":8.0},"animset":"1HAXE","name":"Cleaver","damagerating":{"1":9,"2":35},"rarity":1,"speedrating":1,"woundrating":4,"chargerating":3,"throwrating":2,"sizerating":2,"ability":"Good for slicing meat."},"MMachete":{"weapontype":"Blade","scrap_value":{"min":11.0,"max":11.0},"animset":"1HS","name":"Military Machete","damagerating":{"1":14,"2":45},"rarity":2,"speedrating":2,"woundrating":3,"chargerating":2,"throwrating":1,"sizerating":2,"ability":"Cuts meat like butter."},"BadBat":{"weapontype":"Bludgeon","scrap_value":{"min":11.0,"max":11.0},"animset":"1HS","name":"The Bad Business","damagerating":{"1":15,"2":42},"rarity":2,"speedrating":2,"woundrating":2,"chargerating":2,"throwrating":2,"sizerating":2,"ability":"Extremely stiff."},"BBat":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"2HB","name":"Baseball Bat","damagerating":{"1":9,"2":34},"rarity":1,"speedrating":3,"woundrating":1,"chargerating":3,"throwrating":1,"sizerating":2,"ability":"Purification in progress."},"GSword":{"weapontype":"Blade","scrap_value":{"min":17.0,"max":17.0},"animset":"2HB","name":"Great Sword","damagerating":{"1":17,"2":63},"rarity":4,"speedrating":1,"woundrating":4,"chargerating":4,"throwrating":1,"sizerating":3,"ability":"Has really good drags."},"PCutter":{"weapontype":"Blade","scrap_value":{"min":8.0,"max":8.0},"animset":"2HB","name":"Pizza Cutter","damagerating":{"1":9,"2":33},"rarity":1,"speedrating":3,"woundrating":3,"chargerating":3,"throwrating":1,"sizerating":3,"ability":"Crude but sharp enough."},"ESword":{"weapontype":"Spear","scrap_value":{"min":14.0,"max":14.0},"animset":"2HSPR","name":"Estoc","damagerating":{"1":16,"2":52},"rarity":3,"speedrating":2,"woundrating":1,"chargerating":3,"throwrating":1,"sizerating":4,"ability":"Historical heirloom. Thrusts well."},"Yari":{"weapontype":"Spear","scrap_value":{"min":14.0,"max":14.0},"animset":"2HSPR","name":"Yari","damagerating":{"1":15,"2":50},"rarity":3,"speedrating":3,"woundrating":3,"chargerating":3,"throwrating":4,"sizerating":4,"ability":"Swift and agile like a dragon."},"CFlag":{"weapontype":"Spear","scrap_value":{"min":11.0,"max":11.0},"animset":"2HSPR","name":"Company Flagpole","damagerating":{"1":12,"2":42},"rarity":2,"speedrating":1,"woundrating":1,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"For the company."},"EFlag":{"weapontype":"Spear","scrap_value":{"min":11.0,"max":11.0},"animset":"2HSPR","name":"Opposers Flagpole","damagerating":{"1":12,"2":42},"rarity":2,"speedrating":1,"woundrating":1,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"For the opposers."},"PAxe":{"weapontype":"Axe","scrap_value":{"min":11.0,"max":11.0},"animset":"2H","name":"Pickaxe","damagerating":{"1":14,"2":41},"rarity":2,"speedrating":2,"woundrating":2,"chargerating":4,"throwrating":1,"sizerating":2,"ability":"Can't mine diamonds."},"THawk":{"weapontype":"Axe","scrap_value":{"min":8.0,"max":8.0},"animset":"1HAXE","name":"Tomahawk","damagerating":{"1":9,"2":33},"rarity":1,"speedrating":2,"woundrating":2,"chargerating":1,"throwrating":4,"sizerating":2,"ability":"Old earth axe. Dulled a lot."},"Shovel":{"weapontype":"Bludgeon","scrap_value":{"min":8.0,"max":8.0},"animset":"2H","name":"Shovel","damagerating":{"1":8,"2":37},"rarity":1,"speedrating":2,"woundrating":2,"chargerating":1,"throwrating":1,"sizerating":2,"ability":"Blunt side towards enemy."},"SClaw":{"weapontype":"Blade","scrap_value":null,"animset":"2SC","name":"Shadow Claws","damagerating":{"1":1,"2":5},"rarity":4,"speedrating":1,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Claw gang!","blacklisted":true},"KitKnife":{"weapontype":"Blade","scrap_value":null,"animset":"1KK","name":"Kitchen Knife","damagerating":{"1":1,"2":5},"rarity":4,"speedrating":1,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Knife gang!","blacklisted":true},"RBHammer":{"weapontype":"Bludgeon","scrap_value":{"min":17.0,"max":17.0},"animset":"2H","name":"'The Decimator'","damagerating":{"1":14,"2":60},"speedrating":2,"woundrating":4,"chargerating":2,"throwrating":1,"sizerating":2,"ability":"Shotgun plus Hammer equals...","blacklisted":true},"DFAxe":{"weapontype":"Axe","scrap_value":{"min":17.0,"max":17.0},"animset":"2H","name":"Firerier Axe","damagerating":{"1":24,"2":45},"speedrating":4,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Double the axe, double the pain.","blacklisted":true},"NailedB":{"weapontype":"Bludgeon","scrap_value":{"min":17.0,"max":17.0},"animset":"2HB","name":"'Maria'","damagerating":{"1":16,"2":85},"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":1,"sizerating":3,"ability":"Mercy is not an option.","blacklisted":true},"ExecSword":{"weapontype":"Blade","scrap_value":{"min":17.0,"max":17.0},"animset":"2HB","name":"Executioner Sword","damagerating":{"1":14,"2":125},"speedrating":1,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":3,"ability":"Slow but devastating. Used to cleave Heretics.","blacklisted":true},"RedCodeSword":{"weapontype":"Blade","scrap_value":null,"animset":"2HB","name":"'The Redslayer'","damagerating":{"1":100,"2":10000},"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"Taro's demise","blacklisted":true,"developer_only":true},"BHook":{"weapontype":"Spear","scrap_value":{"min":17.0,"max":17.0},"animset":"2HSPR","name":"Artisan's Hook","damagerating":{"1":14,"2":65},"speedrating":2,"woundrating":4,"chargerating":2,"throwrating":1,"sizerating":4,"ability":"A relic of a past preserved by The Artisans.","blacklisted":true},"SSword":{"weapontype":"Blade","scrap_value":{"min":11.0,"max":11.0},"animset":"1HS","name":"Short Sword","damagerating":{"1":13,"2":41},"speedrating":2,"woundrating":3,"rarity":2,"chargerating":2,"throwrating":1,"sizerating":2,"ability":"Clean and simple blade."},"AgentCA":{"weapontype":"Item","scrap_value":null,"stack_size":1,"animset":"AGENTC","name":"Agent Container 'Alpha'","damagerating":{"1":5,"2":10},"speedrating":1.5,"woundrating":4,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Retrieve lost supplies.","blacklisted":true},"AgentCB":{"weapontype":"Item","scrap_value":null,"stack_size":1,"animset":"AGENTC","name":"Agent Container 'Epsilon'","damagerating":{"1":5,"2":10},"speedrating":1.5,"woundrating":4,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Retrieve lost supplies.","blacklisted":true},"AgentCC":{"weapontype":"Item","scrap_value":null,"stack_size":1,"animset":"AGENTC","name":"Agent Container 'Omicron'","damagerating":{"1":5,"2":10},"speedrating":1.5,"woundrating":4,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Retrieve lost supplies.","blacklisted":true},"AgentCD":{"weapontype":"Item","scrap_value":{"min":400.0,"max":777.0},"stack_size":1,"animset":"AGENTC","name":"Agent Container 'Zero'","damagerating":{"1":5,"2":10},"speedrating":1.5,"woundrating":4,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Retrieve reclaimed supplies.","blacklisted":true},"CRSpear":{"weapontype":"Spear","scrap_value":{"min":5.0,"max":5.0},"animset":"2HSPR","name":"Crafted Spear","damagerating":{"1":9,"2":30},"speedrating":2,"woundrating":1,"chargerating":1,"throwrating":1,"sizerating":4,"ability":"Pointy rock on a stick! How much better can you get than that? You cant!","blacklisted":true},"CRKnife":{"weapontype":"Blade","scrap_value":{"min":5.0,"max":5.0},"animset":"1HBL","name":"Crafted Knife","damagerating":{"1":9,"2":30},"speedrating":3,"rarity":0,"woundrating":2,"chargerating":1,"throwrating":1,"sizerating":2,"ability":"Crude but better than nothing.","blacklisted":true},"CRCudgel":{"weapontype":"Bludgeon","scrap_value":{"min":5.0,"max":5.0},"animset":"1HB","name":"Crafted Cudgel","damagerating":{"1":9,"2":30},"speedrating":2,"woundrating":1,"chargerating":1,"throwrating":1,"sizerating":2,"ability":"A blunt rock on a stick! For people who want to unleash a bit more of their inner cavemen, whatever those are.","blacklisted":true},"CRHatchet":{"weapontype":"Axe","scrap_value":{"min":5.0,"max":5.0},"animset":"1HAXE","name":"Crafted Hatchet","damagerating":{"1":9,"2":30},"speedrating":2,"woundrating":1,"chargerating":1,"throwrating":1,"sizerating":2,"ability":"A sharp but slightly angled rock on a stick! Can be used to chop wood or limbs!","blacklisted":true},"CRBranch":{"weapontype":"Item","scrap_value":{"min":1.0,"max":1.0},"stack_size":1,"animset":"global","name":"Wood Branch","damagerating":{"1":5,"2":10},"speedrating":3.5,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Piece of wood.","blacklisted":true},"CRWoodS":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":1,"animset":"global","name":"Wood Scrap","damagerating":{"1":5,"2":10},"speedrating":3.5,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Sturdy. Used for crafting.","blacklisted":true},"CRStoneS":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":1,"animset":"global","name":"Stone Scrap","damagerating":{"1":5,"2":10},"speedrating":3.5,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Tough. Used for crafting.","blacklisted":true},"CRStone":{"weapontype":"Item","scrap_value":{"min":1.0,"max":1.0},"stack_size":1,"animset":"global","name":"Stone Rock","damagerating":{"1":5,"2":10},"speedrating":3.5,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Piece of stone.","blacklisted":true},"CRQuiver":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":16,"animset":"THRW","name":"Crafted Quiver","damagerating":{"1":5,"2":10},"speedrating":3.5,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"A quiver of arrows.","blacklisted":true},"CRNade":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":1,"animset":"THRW","name":"Crafted Explosive","damagerating":{"1":0,"2":0,"3":30},"speedrating":null,"woundrating":0,"chargerating":null,"throwrating":5,"sizerating":4,"ability":"Detonates with a five seconds fuse and deals 30 damage","blacklisted":true},"CRSplint":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":4,"animset":"STM","name":"Crude Splint","damagerating":{"1":5,"2":10},"speedrating":3,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Repairs Fracture and Cripple."},"CRBandage":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":4,"animset":"STM","name":"Crude Bandage","damagerating":{"1":5,"2":10,"3":35},"speedrating":3,"woundrating":1,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Stops bleeding."},"CRCaltrop":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":4,"animset":"global","name":"Crafted Caltrops","damagerating":{"1":5,"2":5},"speedrating":null,"woundrating":0,"chargerating":null,"throwrating":4,"sizerating":3,"ability":"Crude, causes Bleeding.","blacklisted":true},"CRBow":{"weapontype":"Bow","scrap_value":{"min":5.0,"max":5.0},"animset":"2HBOW","name":"Crafted Bow","damagerating":{"1":5,"2":10,"3":35,"4":70},"speedrating":0.85,"woundrating":0,"chargerating":0,"throwrating":1,"sizerating":0,"ability":"Crude. Works well enough.","blacklisted":true},"CRPTrap":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":4,"animset":"global","name":"Crafted Punjis","damagerating":{"1":5,"2":10,"3":15},"speedrating":null,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":20,"ability":"Brittle. Causes Sickness.","blacklisted":true},"CRPavise":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":10,"animset":"global","name":"Crafted Pavise","damagerating":{"1":5,"2":10},"speedrating":null,"woundrating":0,"chargerating":null,"throwrating":1,"sizerating":20,"ability":"Makeshift barrier that blocks damage.","blacklisted":true},"RVolver":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"RV","name":"Peacemaker","damagerating":{"1":5,"2":10,"3":35,"4":75},"speedrating":0.333,"woundrating":10,"chargerating":2,"throwrating":1,"sizerating":3,"auto":false,"ammoused":"Short","ability":"Uses Short Ammo"},"CRVolver":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RV","name":"Peacemaker Chain","damagerating":{"1":5,"2":10,"3":50,"4":60},"speedrating":0.45,"woundrating":8,"chargerating":3,"throwrating":1.3,"sizerating":3,"auto":false,"ammoused":"Small","ability":"Uses Small Ammo"},"URVolver":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"RV","name":"Peacemaker Uppercut","damagerating":{"1":5,"2":10,"3":40,"4":85},"speedrating":0.6,"woundrating":16,"chargerating":3,"throwrating":1.5,"sizerating":6,"auto":false,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"MRVolver":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"MRV","name":"'The Redeemer'","damagerating":{"1":5,"2":10,"3":110,"4":270},"speedrating":0.63,"woundrating":30,"chargerating":5,"throwrating":3,"sizerating":6,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"Mateba":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RV","name":"Model 6 Unica","damagerating":{"1":5,"2":10,"3":44,"4":85},"speedrating":0.66,"woundrating":16,"chargerating":3,"throwrating":1.3,"sizerating":4,"auto":false,"ammoused":"Short","ability":"Uses Short Ammo"},"SubMG":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"SMG","name":"CBJ-MS PDW","damagerating":{"1":5,"2":10,"3":40,"4":50},"speedrating":0.0857,"woundrating":7,"chargerating":3,"throwrating":1.2,"sizerating":6.5,"auto":true,"ammoused":"Small","ability":"Uses Small Ammo"},"UMP":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"SMG","name":"H&K UMP45","damagerating":{"1":5,"2":10,"3":50,"4":60},"speedrating":0.1,"woundrating":5,"chargerating":4,"throwrating":1.2,"sizerating":5,"auto":true,"ammoused":"Small","ability":"Uses Small Ammo"},"SubPS":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"SMG","name":"FN P90 TR","damagerating":{"1":5,"2":10,"3":38,"4":48},"speedrating":0.0666,"woundrating":5,"chargerating":4,"throwrating":1.5,"sizerating":5,"auto":true,"ammoused":"Small","ability":"Uses Small Ammo"},"SubPP":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"SMG","name":"PPSh-41","damagerating":{"1":5,"2":10,"3":17,"4":30},"speedrating":0.048,"woundrating":5,"chargerating":4,"throwrating":2,"sizerating":9,"auto":true,"ammoused":"Light","ability":"Uses Light Ammo"},"SubMPX":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"SMG","name":"SIG MPX","damagerating":{"1":5,"2":10,"3":15,"4":40},"speedrating":0.0705,"woundrating":3,"chargerating":4,"throwrating":1.2,"sizerating":5,"auto":true,"ammoused":"Light","ability":"Uses Light Ammo"},"Scorp":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"SMG","name":"Skorpion vz. 61","damagerating":{"1":5,"2":10,"3":12,"4":30},"speedrating":0.0705,"woundrating":2,"chargerating":2,"throwrating":1.2,"sizerating":5,"auto":true,"ammoused":"Light","ability":"Uses Light Ammo"},"SubAK":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"ASMG","name":"AK-74","damagerating":{"1":5,"2":10,"3":21,"4":53},"speedrating":0.092,"woundrating":5,"chargerating":3,"throwrating":1.5,"sizerating":3.5,"auto":true,"ammoused":"Medium","ability":"Uses Medium Ammo"},"FNLMG":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"FN M249","damagerating":{"1":5,"2":10,"3":26,"4":56},"speedrating":0.0857,"woundrating":10,"chargerating":5,"throwrating":2.2,"sizerating":8,"auto":true,"ammoused":"Medium","ability":"Uses Medium Ammo"},"AshR":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"SMG","name":"ASh-12","damagerating":{"1":5,"2":10,"3":45,"4":85},"speedrating":0.092,"woundrating":10,"chargerating":3,"throwrating":1.75,"sizerating":9,"auto":true,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"SKS":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"ASMG","name":"Simonov SKS","damagerating":{"1":5,"2":10,"3":25,"4":60},"speedrating":0.3,"woundrating":8,"chargerating":2,"throwrating":1,"sizerating":6,"auto":false,"ammoused":"Medium","ability":"Uses Medium Ammo"},"SubScar":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"ASMG","name":"FN SCAR-H","damagerating":{"1":5,"2":10,"3":34,"4":83},"speedrating":0.109,"woundrating":10,"chargerating":4,"throwrating":3,"sizerating":6,"auto":true,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"SubMP":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"SMG","name":"H&K MP5A3","damagerating":{"1":5,"2":10,"3":15,"4":35},"speedrating":0.075,"woundrating":3,"chargerating":3,"throwrating":1.5,"sizerating":4,"auto":true,"ammoused":"Light","ability":"Uses Light Ammo"},"MPTen":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"SMG","name":"H&K MP5/10","damagerating":{"1":5,"2":10,"3":23,"4":58},"speedrating":0.075,"woundrating":3,"chargerating":4,"throwrating":1.4,"sizerating":6,"auto":true,"ammoused":"Short","ability":"Uses Short Ammo"},"FAMAS":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"SMG","name":"FAMAS F1","damagerating":{"1":5,"2":10,"3":18,"4":50},"speedrating":0.06,"woundrating":2,"chargerating":4,"throwrating":1.5,"sizerating":3.2,"auto":false,"ammoused":"Medium","ability":"Uses Medium Ammo"},"SUPAK":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"Modded AKM","damagerating":{"1":5,"2":10,"3":22,"4":59},"speedrating":0.1,"woundrating":6,"chargerating":5,"throwrating":1.4,"sizerating":5,"auto":true,"ammoused":"Medium","ability":"Uses Medium Ammo"},"ScarL":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"ASMG","name":"FN SCAR-L","damagerating":{"1":5,"2":10,"3":20,"4":54},"speedrating":0.12,"woundrating":4,"chargerating":4,"throwrating":1.6,"sizerating":6,"auto":true,"ammoused":"Medium","ability":"Uses Medium Ammo"},"KSG":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"RFL","name":"Kel-Tec KSG","damagerating":{"1":5,"2":10,"3":11,"4":19},"speedrating":0.9,"woundrating":10,"chargerating":5,"throwrating":1.4,"sizerating":2,"auto":false,"ammoused":"Shells","ability":"Uses Shell Ammo"},"SubMCX":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"SMG","name":"MCX VIRTUS","damagerating":{"1":5,"2":10,"3":19,"4":50},"speedrating":0.075,"woundrating":3,"chargerating":4,"throwrating":1.3,"sizerating":6,"auto":true,"ammoused":"Medium","ability":"Uses Medium Ammo"},"MShotgun":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"RFL","name":"Model 870","damagerating":{"1":5,"2":10,"3":10,"4":12},"speedrating":0.85,"woundrating":15,"chargerating":2,"throwrating":1.1,"sizerating":2.5,"auto":false,"ammoused":"Shells","ability":"Uses Shell Ammo"},"AAShotgun":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"Atchisson AA-12","damagerating":{"1":5,"2":10,"3":13,"4":13},"speedrating":0.2,"woundrating":10,"chargerating":5,"throwrating":2,"sizerating":3,"auto":true,"ammoused":"Shells","ability":"Uses Shell Ammo"},"LeverShotgun":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"Winchester 1901","damagerating":{"1":5,"2":10,"3":10,"4":17},"speedrating":0.85,"woundrating":18,"chargerating":3,"throwrating":1.1,"sizerating":2.5,"auto":false,"ammoused":"Shells","ability":"Uses Shell Ammo"},"KShotgun":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"MVD KS-23","damagerating":{"1":5,"2":10,"3":75,"4":100},"speedrating":1.4,"woundrating":23,"chargerating":3,"throwrating":2,"sizerating":3,"auto":false,"ammoused":"Shells","ability":"Uses Shell Ammo"},"Mac":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"PST","name":"Ingram MAC-10","damagerating":{"1":5,"2":10,"3":17,"4":34},"speedrating":0.05,"woundrating":5,"chargerating":3,"throwrating":1.2,"sizerating":8,"auto":true,"ammoused":"Light","ability":"Uses Light Ammo"},"PLMG":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"EXPR-19 \"PWR-WSHR\"","damagerating":{"1":5,"2":10,"3":33,"4":66},"speedrating":0.08,"woundrating":8,"chargerating":5,"throwrating":99999.0,"sizerating":4,"auto":true,"ammoused":"Heavy","ability":"Experimental Energy LMG. Cannot be reloaded / unloaded","blacklisted":true},"SubLMG":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"M60-E6","damagerating":{"1":5,"2":10,"3":22,"4":68},"speedrating":0.11,"woundrating":4,"chargerating":5,"throwrating":2.5,"sizerating":12,"auto":true,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"Pistol":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"PST","name":".22 Broomhandle","damagerating":{"1":5,"2":10,"3":16,"4":29},"speedrating":0.2,"woundrating":4,"chargerating":2,"throwrating":1,"sizerating":2,"auto":false,"ammoused":"Light","ability":"Uses Light Ammo"},"Mauser":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"PST","name":"Dolch 96","damagerating":{"1":5,"2":10,"3":35,"4":65},"speedrating":0.3,"woundrating":14,"chargerating":3,"throwrating":2,"sizerating":5,"auto":false,"ammoused":"Short","ability":"Uses Short Ammo"},"Ruger":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"PST","name":"Ruger LCP","damagerating":{"1":5,"2":10,"3":17,"4":40},"speedrating":0.2,"woundrating":5,"chargerating":2,"throwrating":1,"sizerating":5,"auto":false,"ammoused":"Light","ability":"Uses Light Ammo"},"Glock":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"PST","name":"Glock 17","damagerating":{"1":5,"2":10,"3":40,"4":45},"speedrating":0.2,"woundrating":4,"chargerating":3,"throwrating":1,"sizerating":3,"ability":"Uses Small Ammo","auto":false,"ammoused":"Small"},"Deagle":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"2HPST","name":"Mark VII","damagerating":{"1":5,"2":10,"3":50,"4":100},"speedrating":0.5,"woundrating":23,"chargerating":4,"throwrating":1.3,"sizerating":8,"ability":"Uses Short Ammo","auto":false,"ammoused":"Short"},"AJM":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"2HPST","name":"A.J.M. 9","damagerating":{"1":5,"2":10,"3":20,"4":65},"speedrating":0.063,"woundrating":3,"chargerating":5,"throwrating":1.2,"sizerating":2,"ability":"Uses Short Ammo","auto":false,"ammoused":"Short"},"AJMOC":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"2HPST","name":"A.J.M. EXPR-14 Overcharged","damagerating":{"1":5,"2":10,"3":12,"4":17},"speedrating":0.125,"woundrating":3,"chargerating":2,"throwrating":1.5,"sizerating":3,"ability":"Experimental Energy Pistol. Uses Long Ammo","auto":true,"ammoused":"Long","blacklisted":true},"MPistol":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"PST","name":"M1911A1","damagerating":{"1":5,"2":10,"3":43,"4":58},"speedrating":0.2,"woundrating":9,"chargerating":2,"throwrating":1.1,"sizerating":3,"ability":"Uses Small Ammo","auto":false,"ammoused":"Small"},"SUPMPistol":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"PST","name":"Modded Pistol","damagerating":{"1":5,"2":10,"3":40,"4":54},"speedrating":0.2,"woundrating":6,"chargerating":3,"throwrating":1.1,"sizerating":2.7,"ability":"Uses Small Ammo","auto":false,"ammoused":"Small"},"STIPistol":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"PST","name":"STI DVC Limited Custom","damagerating":{"1":5,"2":10,"3":15,"4":42},"speedrating":0.1,"woundrating":4,"chargerating":3,"throwrating":1.1,"sizerating":2,"ability":"Uses Light Ammo","auto":false,"ammoused":"Light"},"DBarrel":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"DBB","name":"Caldwell Handcannon","damagerating":{"1":5,"2":10,"3":9,"4":12},"speedrating":0.3,"woundrating":8,"chargerating":2,"throwrating":1.3,"sizerating":6.5,"ability":"Uses Shell Ammo","auto":false,"ammoused":"Shells"},"DoubleShotgun":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"Caldwell 940","damagerating":{"1":5,"2":10,"3":14,"4":25},"speedrating":0.3,"woundrating":12,"chargerating":4,"throwrating":1.5,"sizerating":2.5,"ability":"Uses Shell Ammo","auto":false,"ammoused":"Shells"},"SPShotgun":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"SPAS-12","damagerating":{"1":5,"2":12,"3":12,"4":18},"speedrating":0.3,"woundrating":10,"chargerating":3,"throwrating":1.3,"sizerating":4,"ability":"Uses Shell Ammo","auto":false,"ammoused":"Shells"},"Benelli":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"RFL","name":"Benelli M4","damagerating":{"1":5,"2":10,"3":10,"4":16},"speedrating":0.4,"woundrating":8,"chargerating":4,"throwrating":1.2,"sizerating":2,"ability":"Uses Shell Ammo","auto":false,"ammoused":"Shells"},"SubVector":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"SMG","name":"KRISS Vector","damagerating":{"1":5,"2":10,"3":39,"4":45},"speedrating":0.05,"woundrating":2,"chargerating":4,"throwrating":1.3,"sizerating":6,"auto":true,"ammoused":"Small","ability":"Uses Small Ammo"},"ASVal":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"AS Val","damagerating":{"1":5,"2":10,"3":20,"4":55},"speedrating":0.06,"woundrating":2,"chargerating":5,"throwrating":1.3,"sizerating":6,"auto":true,"ammoused":"Short","ability":"Uses Short Ammo"},"TSMG":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"ASMG","name":"1927A1 Deluxe","damagerating":{"1":5,"2":10,"3":25,"4":50},"speedrating":0.0857,"woundrating":5,"chargerating":4,"throwrating":2,"sizerating":3,"auto":true,"ammoused":"Short","ability":"Uses Short Ammo"},"Rifle":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"RFL","name":"Modded Rifle","damagerating":{"1":5,"2":10,"3":50,"4":140},"speedrating":1.035,"woundrating":18,"chargerating":5,"throwrating":1.7,"sizerating":0.5,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"SVD":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"RFL","name":"Dragunov SVD-63","damagerating":{"1":5,"2":10,"3":45,"4":140},"speedrating":0.3,"woundrating":30,"chargerating":4,"throwrating":2,"sizerating":2,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"AWMSniper":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"AI-AWSM","damagerating":{"1":5,"2":10,"3":75,"4":175},"speedrating":1.75,"woundrating":35,"chargerating":3,"throwrating":2,"sizerating":6,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"IntSniper":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"RFL","name":"CheyTac M200","damagerating":{"1":5,"2":10,"3":80,"4":175},"speedrating":1.85,"woundrating":35,"chargerating":4,"throwrating":2,"sizerating":3,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"RSASS":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"ASMG","name":"R11 RSASS","damagerating":{"1":5,"2":10,"3":30,"4":75},"speedrating":0.3,"woundrating":3,"chargerating":4,"throwrating":1.3,"sizerating":2,"auto":false,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"HKMR":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"ASMG","name":"H&K MR308 A3","damagerating":{"1":5,"2":10,"3":28,"4":72},"speedrating":0.25,"woundrating":4,"chargerating":4,"throwrating":1.4,"sizerating":3,"auto":false,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"HuntingR":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"Remington 700","damagerating":{"1":5,"2":10,"3":40,"4":150},"speedrating":1.25,"woundrating":30,"chargerating":3,"throwrating":1.3,"sizerating":2.5,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"SUPSniper":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"RFL","name":"IZhMASh SV-98M","damagerating":{"1":5,"2":10,"3":45,"4":145},"speedrating":1.5,"woundrating":24,"chargerating":4,"throwrating":1.4,"sizerating":1.5,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"MusketR":{"weapontype":"Gun","scrap_value":{"min":35.0,"max":35.0},"animset":"RFL","name":"Commissioned Musket","damagerating":{"1":5,"2":10,"3":40,"4":115},"speedrating":2,"woundrating":28,"chargerating":4,"throwrating":2,"sizerating":8,"auto":false,"ammoused":"Heavy","ability":"Uses Heavy Ammo","blacklisted":true},"KarSniper":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"Karabiner 98k","damagerating":{"1":5,"2":10,"3":45,"4":140},"speedrating":1.3,"woundrating":15,"chargerating":3,"throwrating":1.7,"sizerating":2.75,"auto":false,"ammoused":"Long","ability":"Uses Long Ammo"},"Avto":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"RFL","name":"M1891 Avtomat","damagerating":{"1":5,"2":10,"3":90,"4":140},"speedrating":0.12,"woundrating":15,"chargerating":5,"throwrating":4.1,"sizerating":6,"auto":true,"ammoused":"Long","ability":"Uses Long Ammo"},"AMR":{"weapontype":"Gun","scrap_value":{"min":40.0,"max":40.0},"animset":"RFL","name":"PGM FR-12.7","damagerating":{"1":5,"2":10,"3":200,"4":360},"speedrating":2.4,"woundrating":50,"chargerating":5,"throwrating":2.2,"sizerating":5,"ability":"Uses Long Ammo","auto":false,"ammoused":"Long"},"EBR":{"weapontype":"Gun","scrap_value":{"min":25.0,"max":25.0},"animset":"ASMG","name":"M14 EBR","damagerating":{"1":5,"2":10,"3":35,"4":78},"speedrating":0.3,"woundrating":3,"chargerating":2,"throwrating":2,"sizerating":2,"auto":false,"ammoused":"Heavy","ability":"Uses Heavy Ammo"},"HRifle":{"weapontype":"Gun","scrap_value":{"min":30.0,"max":30.0},"animset":"RFL","name":"Winchester 940-1","damagerating":{"1":5,"2":10,"3":29,"4":71},"speedrating":0.71,"woundrating":18,"chargerating":3,"throwrating":1.1,"sizerating":3,"ability":"Uses Short Ammo","auto":false,"ammoused":"Short"},"RBow":{"weapontype":"Bow","scrap_value":{"min":25.0,"max":25.0},"animset":"2HBOW","name":"Recurve Bow","damagerating":{"1":15,"2":10,"3":40,"4":80},"speedrating":0.65,"woundrating":0,"chargerating":2,"throwrating":1,"sizerating":0,"ability":"String powered. Decent."},"CPBow":{"weapontype":"Bow","scrap_value":{"min":35.0,"max":35.0},"animset":"2HBOW","name":"Compound MilBow","damagerating":{"1":25,"2":10,"3":65,"4":95},"speedrating":0.45,"woundrating":0,"chargerating":4,"throwrating":1,"sizerating":0,"ability":"High velocity. Lethal."},"HStim":{"weapontype":"Item","scrap_value":{"min":25.0,"max":30.0},"stack_size":1,"animset":"STM","name":"Cocktail \"Perithesene\"","damagerating":{"1":5,"2":10},"speedrating":3.5,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Full Heal"},"DStim":{"weapontype":"Item","scrap_value":{"min":25.0,"max":30.0},"stack_size":1,"animset":"STM","name":"3-(cbSTM)","damagerating":{"1":5,"2":10},"speedrating":1,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Increased Melee Damage and Shove Speed, cures Fracture"},"DEFStim":{"weapontype":"Item","scrap_value":{"min":40.0,"max":40.0},"stack_size":1,"animset":"STM","name":"I4S-DS","damagerating":{"1":5,"2":10},"speedrating":1,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Grants Regeneration and Death Prevention"},"SStim":{"weapontype":"Item","scrap_value":{"min":25.0,"max":30.0},"stack_size":1,"animset":"STM","name":"BL1 (Neloprephine)","damagerating":{"1":5,"2":10},"speedrating":1,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Removes Morale. Instant Stamina Regeneration"},"SPDStim":{"weapontype":"Item","scrap_value":{"min":25.0,"max":30.0},"stack_size":1,"animset":"STM","name":"S44-UL1","damagerating":{"1":5,"2":10},"speedrating":1,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Move, reload and melee faster"},"ImpN":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":2,"animset":"THRW","name":"Impact Grenade","damagerating":{"1":0,"2":0,"3":80},"speedrating":null,"woundrating":2,"chargerating":null,"throwrating":4,"sizerating":4,"ability":"Impact triggered explosive."},"Molo":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"THRW","name":"Fire Bomb","damagerating":{"1":0,"2":0,"3":10},"speedrating":null,"woundrating":2,"chargerating":null,"throwrating":3,"sizerating":4,"ability":"Ignites an area in flames."},"Dynamite":{"weapontype":"Item","scrap_value":{"min":16.0,"max":16.0},"stack_size":1,"animset":"THRW","name":"Dynamite","damagerating":{"1":0,"2":0,"3":150},"speedrating":null,"woundrating":3,"chargerating":null,"throwrating":5,"sizerating":4,"ability":"Bundle of dangerous explosive."},"MGrenade":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":3,"animset":"THRW","name":"M67 Grenade","damagerating":{"1":0,"2":0,"3":130},"speedrating":null,"woundrating":2,"chargerating":null,"throwrating":4,"sizerating":4,"ability":"Lightweight explosive."},"TAxe":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":6,"animset":"1HAXE","name":"Hunting Axe","damagerating":{"1":10,"2":35},"speedrating":null,"woundrating":1,"chargerating":null,"throwrating":3,"sizerating":3,"ability":"Heavy for throwing."},"TCaltrop":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":6,"animset":"global","name":"Steel Caltrops","damagerating":{"1":5,"2":5},"speedrating":null,"woundrating":1,"chargerating":null,"throwrating":4,"sizerating":3,"ability":"Slows and causes Bleeding."},"AdrStim":{"weapontype":"Item","scrap_value":{"min":25.0,"max":30.0},"stack_size":1,"animset":"STM","name":"Hemostatic Zanustin","damagerating":{"1":5,"2":10},"speedrating":1,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Numbs Pain and Major Injuries"},"BPMPistol":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":1,"animset":"global","name":"Pistol Blueprint","damagerating":{"1":5,"2":15,"3":"SUPMPistol"},"speedrating":null,"woundrating":1,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for a Suppressed M1911A1."},"BPSTI":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":1,"animset":"global","name":"Hi-Capa Blueprint","damagerating":{"1":5,"2":15,"3":"STIPistol"},"speedrating":null,"woundrating":1,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for a Custom Hi-Capa."},"BPRSASS":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"RSASS Blueprint","damagerating":{"1":5,"2":15,"3":"RSASS"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for an accurate DMR."},"BPAJM":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"A.J.M. 9 Blueprint","damagerating":{"1":5,"2":15,"3":"AJM"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for an A.J.M. 9."},"BPCPBow":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"Milbow Blueprint","damagerating":{"1":5,"2":15,"3":"CPBow"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for a Military Bow."},"BPHammer":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"'The Decimator' Blueprint","damagerating":{"1":5,"2":15,"3":"RBHammer"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for 'The Decimator'"},"BPScythe":{"weapontype":"Item","scrap_value":{"min":16.0,"max":16.0},"stack_size":1,"animset":"global","name":"Reaper's Scythe Blueprint","damagerating":{"1":5,"2":15,"3":"RScythe"},"speedrating":null,"woundrating":3,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for the Reaper's Scythe"},"BPExec":{"weapontype":"Item","scrap_value":{"min":16.0,"max":16.0},"stack_size":1,"animset":"global","name":"Executioner Blueprint","damagerating":{"1":5,"2":15,"3":"ExecSword"},"speedrating":null,"woundrating":3,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for an Executioner Sword"},"BPHook":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"Billhook Blueprint","damagerating":{"1":5,"2":15,"3":"BHook"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for a Billhook"},"BPNailed":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"'Maria' Blueprint","damagerating":{"1":5,"2":15,"3":"NailedB"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for 'Maria'"},"BPAKM":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"AKM Blueprint","damagerating":{"1":5,"2":15,"3":"SUPAK"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for an Ergonomic AKM"},"BPFAXE":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"Firerier Axe Blueprint","damagerating":{"1":5,"2":15,"3":"DFAxe"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for a Firerier Axe"},"BPKSG":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"KSG Blueprint","damagerating":{"1":5,"2":15,"3":"KSG"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for an Kel-Tec KSG"},"BPRifle":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"global","name":"Rifle Blueprint","damagerating":{"1":5,"2":15,"3":"Rifle"},"speedrating":null,"woundrating":2,"chargerating":"blueprint","throwrating":1,"sizerating":4,"ability":"Blueprint for a Scoped Rifle."},"BPack":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":1,"animset":"STM","name":"Backpack","damagerating":{"1":5,"2":20},"speedrating":0.7,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Grants all inventory slots."},"APack":{"weapontype":"Item","scrap_value":{"min":80.0,"max":80.0},"stack_size":1,"animset":"STM","name":"Tactical Armour","damagerating":{"1":5,"2":10},"speedrating":0.7,"woundrating":4,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Grants the Armoured buff."},"FAid":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":3,"animset":"STM","name":"Advanced IFAK","damagerating":{"1":5,"2":10,"3":40},"speedrating":2.55,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Medical kit with superior healing."},"Tourni":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":2,"animset":"STM","name":"Esmarch Tourniquet","damagerating":{"1":5,"2":10},"speedrating":2.2,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Stops Arterial Bleeding."},"Splint":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":3,"animset":"STM","name":"Immobilising Splint","damagerating":{"1":5,"2":10},"speedrating":1.9,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Fixes and prevents fractures & cripple."},"PKillers":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":8,"animset":"STM","name":"Amoxicillin Tablets","damagerating":{"1":5,"2":10},"speedrating":1.4,"woundrating":1,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Regresses infection progress"},"IbuP":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":100,"animset":"STM","name":"Augmentin Antibiotics","damagerating":{"1":5,"2":10},"speedrating":2.1,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Regresses and pauses infection progress."},"ADBandage":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":3,"animset":"STM","name":"Aseptic Bandage","damagerating":{"1":5,"2":10,"3":50},"speedrating":3,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Stops and prevents bleeding."},"MAid":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":8,"animset":"STM","name":"First Aid Kit","damagerating":{"1":5,"2":10},"speedrating":4,"woundrating":1,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"Provides basic healing."},"PMine":{"weapontype":"Item","scrap_value":{"min":16.0,"max":16.0},"stack_size":4,"animset":"global","name":"Proximity Mine","damagerating":{"1":5,"2":10,"3":85},"speedrating":null,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":15,"ability":"Motion activated."},"ScanMine":{"weapontype":"Item","scrap_value":{"min":16.0,"max":16.0},"stack_size":4,"animset":"global","name":"EX-362 'Vulnerability' Mine","damagerating":{"1":5,"2":10},"speedrating":null,"woundrating":3,"chargerating":null,"throwrating":1,"sizerating":15,"ability":"Reveals nearby enemies, scanned enemies take more damage","blacklisted":true},"PTrap":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":8,"animset":"global","name":"Steel Punjis","damagerating":{"1":5,"2":10,"3":15},"speedrating":null,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":20,"ability":"Causes sickness. Spikey."},"SSnare":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":65535.0,"animset":"global","name":"Steel Snares","damagerating":{"1":5,"2":10},"speedrating":null,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":20,"ability":"Capable of Ensnaring. Durable wire."},"RExplosive":{"weapontype":"Item","scrap_value":{"min":10.0,"max":10.0},"stack_size":4,"animset":"global","name":"Remote Explosive","damagerating":{"1":5,"2":10,"3":120},"speedrating":null,"woundrating":2,"chargerating":null,"throwrating":1,"sizerating":20,"ability":"Remote detonated."},"RScythe":{"weapontype":"Scythe","scrap_value":{"min":17.0,"max":17.0},"animset":"RSCYTH","name":"Reaper's Scythe","damagerating":{"1":30,"2":90,"3":10},"rarity":4,"speedrating":3,"woundrating":2,"chargerating":2,"throwrating":1,"sizerating":3,"ability":"Red like roses, deadly like RSASS.","blacklisted":true,"heavy_stamina_cost":25,"dashstun":true},"Snowball":{"weapontype":"Item","scrap_value":{"min":5.0,"max":5.0},"stack_size":65535.0,"animset":"1HAXE","name":"Snowball","damagerating":{"1":25,"2":50},"speedrating":null,"woundrating":1,"chargerating":null,"throwrating":3,"sizerating":3,"ability":"It's really heavy..."},"GPCutter":{"weapontype":"Blade","scrap_value":{"min":17.0,"max":17.0},"animset":"2HB","name":"Golden Pizzacutter","damagerating":{"1":25,"2":55},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"'shiny'","blacklisted":true},"TKnife":{"weapontype":"Item","animset":"1HBL","name":"Throwing Knife","desc":"__legacy__internal__used_for_equipment","icon":"__legacy__internal__used_for_equipment","damagerating":{"1":50,"2":50},"speedrating":null,"woundrating":1,"chargerating":null,"throwrating":3,"sizerating":4,"ability":"__legacy__internal__used_for_equipment","blacklisted":true},"TGas":{"weapontype":"Item","animset":"1HBL","name":"Throwing Knife","desc":"__legacy__internal__used_for_equipment","icon":"__legacy__internal__used_for_equipment","damagerating":{"1":0,"2":0},"speedrating":0,"woundrating":0,"chargerating":0,"throwrating":0,"sizerating":0,"ability":"__legacy__internal__used_for_equipment","blacklisted":true},"Adminweapon":{"weapontype":"Blade","scrap_value":{"min":0.0,"max":0.0},"animset":"2HB","name":"Admin's Pizzacutter","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"'there are no admin items'","blacklisted":true},"BHammer":{"weapontype":"Bludgeon","scrap_value":{"min":0.0,"max":0.0},"animset":"KRELLIS","name":"Krellis","damagerating":{"1":1,"2":1},"rarity":5,"speedrating":2,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":4,"ability":"GRAAAAHHHHHHHHH!!!","blacklisted":true},"BInjector":{"weapontype":"Item","scrap_value":{"min":0.0,"max":0.0},"animset":"STM","name":"Berserk Injector","damagerating":{"1":1,"2":1},"rarity":1,"speedrating":0.4,"woundrating":3,"chargerating":1,"throwrating":1,"sizerating":4,"ability":"Improves Fists lethality, grants Bloodthirst and Regeneration","blacklisted":true},"CMMaul":{"weapontype":"Bludgeon","scrap_value":{"min":0.0,"max":0.0},"animset":"2H","name":"Commander's Maul","damagerating":{"1":1,"2":1},"rarity":1,"speedrating":2,"woundrating":4,"chargerating":2,"throwrating":1,"sizerating":2,"ability":"","blacklisted":true},"EMSword":{"weapontype":"Blade","scrap_value":{"min":0.0,"max":0.0},"animset":"2HB","name":"Zealot's Blade","damagerating":{"1":1,"2":1},"rarity":1,"speedrating":2,"woundrating":4,"chargerating":4,"throwrating":1,"sizerating":2,"ability":"Faithful, loyal, forgotten.","blacklisted":true},"GPan":{"weapontype":"Bludgeon","scrap_value":{"min":1.0,"max":111.0},"animset":"1HB","name":"Golden Frying Pan","damagerating":{"1":21,"2":67},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":3,"ability":"machine versus man"},"GasWrench":{"weapontype":"Bludgeon","scrap_value":{"min":0.0,"max":0.0},"animset":"wrench","name":"Wrench","damagerating":{"1":1,"2":1},"rarity":2,"speedrating":2,"woundrating":2,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"feint feint feint","blacklisted":true},"HScythe":{"weapontype":"Scythe","scrap_value":{"min":17.0,"max":17.0},"animset":"RSCYTH","name":"Hallow's Scythe","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":3,"woundrating":2,"chargerating":2,"throwrating":1,"sizerating":3,"ability":"You can hear it calling for you.","blacklisted":true},"IceSword":{"weapontype":"Blade","scrap_value":{"min":0.0,"max":0.0},"animset":"1HS","name":"Lumi's Blade","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"[REDACTED]","blacklisted":true},"Kukri":{"weapontype":"Blade","scrap_value":{"min":0.0,"max":0.0},"animset":"kukri","name":"Kukri","damagerating":{"1":1,"2":1},"rarity":2,"speedrating":3,"woundrating":2,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"feint feint feint","blacklisted":true},"PipeWrench":{"weapontype":"Bludgeon","scrap_value":{"min":0.0,"max":0.0},"animset":"bigwrench","name":"PipeWrench","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":1,"woundrating":4,"chargerating":1,"throwrating":1,"sizerating":4,"ability":"feint feint feint","blacklisted":true},"SPCStim":{"weapontype":"Item","scrap_value":{"min":0.0,"max":0.0},"animset":"STM","name":"Compound Z","damagerating":{"1":1,"2":1},"rarity":5,"speedrating":1,"woundrating":3,"chargerating":5,"throwrating":1,"sizerating":4,"ability":"Grants all Stim eff","blacklisted":true},"Sabre":{"weapontype":"Blade","scrap_value":{"min":0.0,"max":0.0},"animset":"sbre","name":"Saber","damagerating":{"1":1,"2":1},"rarity":2,"speedrating":4,"woundrating":2,"chargerating":1,"throwrating":2,"sizerating":2,"ability":"feint feint feint","blacklisted":true},"MRSASS":{"weapontype":"Gun","scrap_value":{"min":0.0,"max":0.0},"animset":"ASMG","name":"Modded RSASS","damagerating":{"1":5,"2":10,"3":1,"4":1},"speedrating":9999,"woundrating":9999,"chargerating":5,"throwrating":99999.0,"sizerating":99999.0,"auto":false,"ammoused":"Heavy","ability":"Useless in your hands...","blacklisted":true},"Radio":{"weapontype":"Item","scrap_value":null,"stack_size":1,"animset":"AGENTC","name":"Radio","damagerating":{"1":5,"2":10},"speedrating":0.5,"woundrating":4,"chargerating":null,"throwrating":1,"sizerating":4,"ability":"...","blacklisted":true},"lumi_sword_base":{"weapontype":"Blade","scrap_value":null,"animset":"1HBL","name":"lumi_sword_base","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"lumi_sword_base.ability","blacklisted":true},"lumi_sword_ice":{"weapontype":"Blade","scrap_value":null,"animset":"1HBL","name":"lumi_sword_ice","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"lumi_sword_ice.ability","blacklisted":true},"lumi_sword_fire":{"weapontype":"Blade","scrap_value":null,"animset":"1HBL","name":"lumi_sword_fire","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"lumi_sword_fire.ability","blacklisted":true},"thorum_chainsaw_fire":{"weapontype":"Blade","scrap_value":null,"animset":"1HBL","name":"thorum_chainsaw_fire","damagerating":{"1":1,"2":1},"rarity":4,"speedrating":4,"woundrating":4,"chargerating":4,"throwrating":4,"sizerating":4,"ability":"thorum_chainsaw_fire.ability","blacklisted":true}},"enemies":{"ARENA_CLOSER":{"name":"ARENA_CLOSER","stats":{"basemovement":30.0,"cangrapple":false,"chargemultiplier":1.0,"damage":4294967295.0,"firerate":0.01,"getupanim":true,"health":4294967295.0,"mag":4294967295.0,"no_rogue":true,"preferranged":1.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.2,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":1.0,"staggermultiplier":1.0,"visionrange":70.0,"wep":"FNLMG"}},"AilaGuard":{"name":"AilaGuard","stats":{"alt_anim":"RRIOT","basemovement":16.0,"cangrapple":false,"canrest":"sq_guard","chargemultiplier":1.0,"damage":30.0,"firerate":0.7,"friendly":true,"health":300.0,"mag":30.0,"no_roaming":true,"preferranged":3.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"riotshield":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.5,"visionrange":70.0,"wep":"FAxe"}},"AllyDefect":{"name":"AllyDefect","stats":{"alt_anim":"DEF","basemovement":18,"brace_aim":true,"can_dodge":true,"cangrapple":false,"canrest":true,"chargemultiplier":1,"closebydialogue":"defect","combat_rest_anims":"defect","damage":8,"defect":true,"firerate":0.092,"friendly":true,"grenade_launcher":true,"health":300,"healthbartop":"Defector 'Daemon'","holdout_defend_point":70,"mag":30,"no_roaming":true,"notagging":true,"preferranged":25,"range":6,"ranged":true,"rangedbulletsfired":1,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1,"spread":6,"staggermultiplier":0.8,"summon_allies":true,"tac_reload":true,"visionrange":150,"weaponskin":"ScarLSkin","wep":"ScarL"}},"AllyDefectSummonA":{"name":"AllyDefectSummonA","stats":{"alt_anim":"RTAC","basemovement":14.0,"brace_aim":true,"cangrapple":false,"chargemultiplier":1.0,"damage":4.0,"defect_follower":true,"firerate":0.0705,"friendly":true,"health":100.0,"mag":30.0,"no_roaming":true,"preferranged":5.0,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.0,"tac_reload":true,"visionrange":65.0,"wep":"SubMPX"}},"AllyDefect_evac":{"name":"AllyDefect_evac","stats":{"alt_anim":"DEF","basemovement":18.0,"brace_aim":true,"can_dodge":true,"cangrapple":false,"canrest":"damien","chargemultiplier":1.0,"damage":8.0,"defect":true,"firerate":0.092,"friendly":true,"grenade_launcher":true,"health":300.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":25.0,"range":6.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":6.0,"staggermultiplier":0.8,"visionrange":150.0,"weaponskin":"ScarLSkin","wep":"ScarL"}},"AllyGuard":{"name":"AllyGuard","stats":{"alt_anim":"DEF","basemovement":14.0,"brace_aim":true,"cangrapple":true,"chargemultiplier":1.0,"damage":20.0,"dying_rage":true,"firerate":0.2,"friendly":true,"grenade_launcher":true,"health":450.0,"healthbartop":"idk what to name this guy","mag":25.0,"preferranged":10.0,"range":6.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.8,"shoveblocksmultiplier":0.35,"spread":1.0,"staggermultiplier":0.35,"visionrange":75.0,"wep":"MRSASS"}},"AllyIlija":{"name":"AllyIlija","stats":{"basemovement":0.0,"cangrapple":false,"chargemultiplier":1.0,"closebydialogue":"ilija","damage":500.0,"firerate":1.75,"friendly":true,"health":250.0,"ilija":true,"mag":19.0,"no_jumping":true,"no_roaming":true,"notarget":true,"preferranged":25.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":12.0,"shoveblocksmultiplier":1.0,"sniper_laser":true,"spread":0.1,"staggermultiplier":1.0,"visionrange":150.0,"wep":"SUPSniper"}},"AllyMalice":{"name":"AllyMalice","stats":{"alt_anim":"2JR","arbiter_launch":true,"arbiter_shot":true,"basemovement":25,"boss":true,"can_dodge":true,"cangrapple":false,"canrest":true,"chargemultiplier":1.1,"closebydialogue":"malice","combat_rest_anims":"malice","damage":35,"firerate":0.5,"flame_upswing":true,"friendly":true,"health":850,"healthbartop":"Agent 'Jericho'","holdout_defend_point":90,"mag":19,"malice":true,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"preferranged":25,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":15,"resistrange":true,"shoveblocksmultiplier":1,"spin_charge":true,"spread":0.1,"staggermultiplier":0.3,"use_stims":true,"visionrange":150,"weaponskin":"MaliceSkin","wep":"FAxe"}},"AllyServo":{"name":"AllyServo","stats":{"alt_anim":"SRV","aoe_healer":true,"aoe_shocker":true,"basemovement":8,"cangrapple":false,"canrest":true,"chargemultiplier":1,"closebydialogue":"servo","combat_rest_anims":"servo","damage":5,"firerate":0.25,"friendly":true,"health":450,"healthbartop":"'Archangel' DELTA","holdout_defend_point":50,"mag":50,"max_shoot":30,"no_roaming":true,"notagging":true,"player_healer":true,"preferranged":15,"range":6,"ranged":true,"rangedbulletsfired":4,"reloadmultiplier":4,"resistrange":true,"servo":true,"shoveblocksmultiplier":1,"spread":10,"staggermultiplier":0.8,"visionrange":150,"weaponskin":"ServoGun","wep":"AJM"}},"BadBoss":{"name":"BadBoss","stats":{"basemovement":17.0,"boss":true,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.2,"damage":8.0,"dualies":true,"firerate":0.055,"health":750.0,"mag":200.0,"preferranged":1.0,"range":6.5,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":20.0,"staggermultiplier":0.8,"visionrange":100.0,"weaponskin":"BadGun","wep":"SubLMG"}},"BadEnemy":{"name":"BadEnemy","stats":{"basemovement":20.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.2,"damage":10.0,"firerate":0.75,"health":200.0,"mag":25.0,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.8,"visionrange":60.0,"wep":"BadBat"}},"BadGunner":{"name":"BadGunner","stats":{"basemovement":17.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.2,"damage":8.0,"firerate":0.11,"health":150.0,"mag":200.0,"preferranged":1.0,"range":6.5,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":20.0,"staggermultiplier":0.8,"visionrange":60.0,"weaponskin":"BadGun","wep":"SubLMG"}},"BossCommander":{"name":"BossCommander","stats":{"basemovement":8.0,"boss":true,"cangrapple":false,"chargemultiplier":4.0,"damage":80.0,"firerate":1.0,"health":4000.0,"ignoreblocks":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":12.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":0.5,"unshovable":true,"visionrange":120.0,"weaponskin":"CMMaul","wep":"SHammer"}},"BossFunRuiner":{"name":"BossFunRuiner","stats":{"alt_anim":"2QU","arbiter_jump":true,"arbiter_launch":true,"arbiter_shot":true,"basemovement":22,"boss":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1,"custom_exec":"queen_exec","damage":15,"extra_parry_window":0.4,"female":true,"firerate":0.7,"health":1200,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"noturretarget":true,"preferranged":1,"queen":true,"raidboss_unit":true,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":6,"resistrange":true,"shoveblocksmultiplier":1,"spin_charge":true,"spread":10,"staggermultiplier":0.35,"suppress":false,"visionrange":120,"weaponskin":"AilaHammer","wep":"SHammer"}},"BossFunRuiner_legacy":{"name":"BossFunRuiner_legacy","stats":{"alt_anim":"2QU","arbiter_jump":true,"arbiter_launch":true,"arbiter_shot":true,"basemovement":25,"boss":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1,"custom_exec":"queen_exec","damage":15,"extra_parry_window":0.4,"firerate":0.7,"health":1200,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"noturretarget":true,"preferranged":1,"queen":true,"raidboss_unit":true,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":6,"resistrange":true,"shoveblocksmultiplier":1,"spin_charge":true,"spread":10,"staggermultiplier":0.35,"suppress":false,"visionrange":120,"weaponskin":"QHammer","wep":"SHammer"}},"BossRedeemers":{"name":"BossRedeemers","stats":{"basemovement":16.0,"boss":true,"cangrapple":false,"chargemultiplier":1.5,"damage":20.0,"dualies":true,"firerate":0.5,"health":800.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":12.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":0.5,"visionrange":120.0,"wep":"MRVolver"}},"BossScav":{"name":"BossScav","stats":{"basemovement":10.0,"boss":true,"cangrapple":false,"cansprint":true,"chargemultiplier":1.0,"damage":7.0,"firerate":0.11,"health":1200.0,"healthbartop":"Yosef","immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100.0,"morale_health_bar":true,"no_roaming":true,"notagging":true,"preferranged":2.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":4.0,"resistrange":true,"scavboss":true,"shoveblocksmultiplier":1.0,"spread":9.0,"staggermultiplier":0.5,"suppress":false,"visionrange":80.0,"wep":"SubLMG"}},"BossScavGuard":{"name":"BossScavGuard","stats":{"basemovement":10.0,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":0.1,"health":225.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":30.0,"notagging":true,"preferranged":2.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"resistrange":true,"scavguard":true,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":0.7,"suppress":false,"visionrange":60.0,"wep":"SUPAK"}},"BossZealot":{"name":"BossZealot","stats":{"basemovement":14.0,"boss":true,"cangrapple":false,"cansprint":true,"chargemultiplier":1.5,"damage":4.0,"firerate":1.0,"health":1200.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":9.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":true,"rangedbulletsfired":12.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"visionrange":120.0,"wep":"SPShotgun","zealotshield":true}},"BossZealotFodderA":{"name":"BossZealotFodderA","stats":{"basemovement":18.0,"cangrapple":false,"chargemultiplier":1.5,"damage":10.0,"firerate":1.0,"health":300.0,"immune_poison":true,"immune_snares":true,"mag":9.0,"notagging":true,"preferranged":3.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"visionrange":120.0,"wep":"MMachete"}},"BossZealotFodderB":{"name":"BossZealotFodderB","stats":{"basemovement":15.0,"cangrapple":false,"chargemultiplier":1.5,"damage":4.0,"firerate":0.05,"health":250.0,"immune_poison":true,"immune_snares":true,"mag":25.0,"notagging":true,"preferranged":3.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"visionrange":70.0,"wep":"SubVector"}},"BossZealotFodderC":{"name":"BossZealotFodderC","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":1.5,"damage":8.0,"firerate":2.0,"health":250.0,"immune_poison":true,"immune_snares":true,"mag":10.0,"notagging":true,"preferranged":3.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.5,"visionrange":80.0,"wep":"EBR"}},"BossZealotMinionA":{"name":"BossZealotMinionA","stats":{"basemovement":17.0,"cangrapple":false,"chargemultiplier":1.5,"damage":10.0,"firerate":1.0,"health":350.0,"immune_poison":true,"immune_snares":true,"mag":9.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"visionrange":120.0,"wep":"MMachete"}},"BossZealotMinionB":{"name":"BossZealotMinionB","stats":{"basemovement":15.0,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":0.11,"health":350.0,"immune_poison":true,"immune_snares":true,"mag":100.0,"notagging":true,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"unshovable":true,"visionrange":80.0,"wep":"SubLMG"}},"BucketDude":{"name":"BucketDude","stats":{"basemovement":22.0,"boss":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1.0,"damage":15.0,"firerate":0.6,"health":1500.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"immuneheadshot":true,"mag":25.0,"melee_block_bullets":true,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.3,"visionrange":70.0,"wep":"FPan"}},"CHEVENT_EvacAlly":{"name":"CHEVENT_EvacAlly","stats":{"alt_anim":"RTAC","basemovement":14.0,"brace_aim":true,"cangrapple":false,"chargemultiplier":1.0,"damage":4.0,"defect_follower":true,"firerate":0.1,"friendly":true,"health":150.0,"mag":25.0,"no_roaming":true,"preferranged":15.0,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":7.0,"staggermultiplier":1.0,"tac_reload":true,"visionrange":65.0,"wep":"UMP"}},"CultAdvanced":{"name":"CultAdvanced","stats":{"alt_anim":"CULA","basemovement":18.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"cultknife":true,"damage":5.0,"firerate":0.1,"health":250.0,"mag":25.0,"no_roaming":true,"notagging":true,"preferranged":2.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":0.6,"suppress":false,"visionrange":60.0,"weaponskin":"CultG","wep":"SubMG"}},"CultBoss":{"name":"CultBoss","stats":{"alt_anim":"CULB","basemovement":20.0,"boss":true,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"cultscythe":true,"damage":5.0,"firerate":0.1,"health":600.0,"immune_mindkill":true,"mag":25.0,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"preferranged":2.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shadow":true,"shadowfading":true,"shoveblocksmultiplier":1.0,"spread":3.0,"staggermultiplier":0.4,"suppress":false,"visionrange":70.0,"weaponskin":"CultG","wep":"SubMG"}},"CultGun":{"name":"CultGun","stats":{"basemovement":17.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"damage":5.0,"firerate":0.1,"health":150.0,"mag":25.0,"no_roaming":true,"notagging":true,"preferranged":5.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.0,"suppress":false,"visionrange":50.0,"weaponskin":"CultG","wep":"SubMG"}},"CultGun_CHEVENT":{"name":"CultGun_CHEVENT","stats":{"basemovement":17.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"damage":2.0,"firerate":0.1,"health":120.0,"mag":25.0,"no_roaming":true,"notagging":true,"preferranged":5.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.0,"visionrange":50.0,"weaponskin":"CultG","wep":"SubMG"}},"CultMelee":{"name":"CultMelee","stats":{"basemovement":20.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"damage":10.0,"firerate":0.7,"health":200.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.8,"suppress":false,"visionrange":50.0,"weaponskin":"CultK","wep":"CKnife"}},"CultMelee_CHEVENT":{"name":"CultMelee_CHEVENT","stats":{"basemovement":20.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":3.0,"cult":true,"damage":5.0,"firerate":0.7,"health":175.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.8,"suppress":false,"visionrange":50.0,"weaponskin":"CultK","wep":"CKnife"}},"DRP_FINAL_BOSS":{"name":"DRP_FINAL_BOSS","stats":{"basemovement":23,"boss":true,"can_combo":false,"can_dodge":true,"cangrapple":false,"chargemultiplier":1,"damage":2,"fireboss_lumi":true,"firerate":0.01,"health":9000,"healthbartop":"","hemorrhage":true,"immune_fracture":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"invisbody":true,"lumi":true,"mag":100,"no_charge_attacks":true,"notagging":true,"preferranged":1,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":6,"resistrange":true,"shoveblocksmultiplier":1,"snowenemy":true,"spread":10,"staggermultiplier":0.35,"visionrange":1200,"wep":"thorum_chainsaw_fire"}},"DRP_lumi":{"name":"DRP_lumi","stats":{"alt_anim":"Lumi","basemovement":23.0,"boss":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1.0,"damage":15.0,"female":true,"fireboss_lumi":true,"firerate":0.8,"health":9000.0,"healthbartop":"Lumi","hemorrhage":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"lumi":true,"mag":100.0,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.35,"visionrange":1200.0,"wep":"lumi_sword_fire"}},"ERUScoutA":{"name":"ERUScoutA","stats":{"alternate_stagger_anim":true,"basemovement":20.0,"can_block":true,"can_combo":true,"can_dodge":true,"can_feint":true,"cangrapple":true,"chargemultiplier":1.0,"damage":11.0,"firerate":0.7,"health":175.0,"mag":25.0,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.7,"use_stims":true,"visionrange":55.0,"wep":"MMachete"}},"EVIL_JollyCQC":{"name":"EVIL_JollyCQC","stats":{"alt_anim":"CULA","basemovement":16.0,"can_dodge":true,"cangrapple":true,"chargemultiplier":1.0,"close_range_shank":true,"damage":5.0,"elite_getupanim":true,"firerate":0.6,"health":200.0,"hemorrhage":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"invis_limbs":true,"mag":17.0,"preferranged":3.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.6,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":7.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"Glock"}},"EVIL_JollyManiac":{"name":"EVIL_JollyManiac","stats":{"alt_anim":"J_Maniac","basemovement":20.0,"can_combo":true,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"elite_getupanim":true,"extra_parry_window":0.15,"firerate":0.55,"health":175.0,"hemorrhage":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"invis_limbs":true,"mag":30.0,"melee_dualies":true,"no_charge_attacks":true,"no_roaming":true,"preferranged":1.0,"range":6.0,"rangedbulletsfired":1.0,"reloadmultiplier":2.8,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":30.0,"staggermultiplier":0.35,"visionrange":50.0,"wep":"MilAxe"}},"EVIL_JollySMGShield":{"name":"EVIL_JollySMGShield","stats":{"alt_anim":"RCAR","assault_shield":true,"basemovement":13.0,"cangrapple":true,"chargemultiplier":1.0,"damage":2.0,"elite_getupanim":true,"firerate":0.1,"health":225.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"invis_limbs":true,"mag":40.0,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.6,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"MPTen"}},"EVIL_JollySWAT":{"name":"EVIL_JollySWAT","stats":{"alt_anim":"RTAC","basemovement":14.0,"brace_aim":true,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.0,"damage":1.5,"elite_getupanim":true,"firerate":0.08,"health":175.0,"hemorrhage":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"invis_limbs":true,"mag":40.0,"preferranged":25.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":15.0,"staggermultiplier":1.0,"tac_reload":true,"visionrange":75.0,"wep":"SubMCX"}},"EvacAllyA":{"name":"EvacAllyA","stats":{"alt_anim":"RTAC","basemovement":14.0,"brace_aim":true,"cangrapple":false,"chargemultiplier":1.0,"damage":4.0,"defect_follower":true,"firerate":0.0705,"friendly":true,"health":120.0,"mag":30.0,"no_roaming":true,"preferranged":15.0,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"return_position":true,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.0,"suppress":false,"tac_reload":true,"visionrange":65.0,"wep":"SubMPX"}},"EvacAllyB":{"name":"EvacAllyB","stats":{"alt_anim":"RTAC","basemovement":14.0,"brace_aim":true,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"defect_follower":true,"firerate":0.1,"friendly":true,"health":120.0,"mag":25.0,"no_roaming":true,"preferranged":15.0,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"return_position":true,"shoveblocksmultiplier":1.0,"spread":7.0,"staggermultiplier":1.0,"suppress":false,"tac_reload":true,"visionrange":65.0,"wep":"UMP"}},"HoldoutAgent":{"name":"HoldoutAgent","stats":{"basemovement":0.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.5,"friendly":true,"health":600.0,"holdout_target":true,"mag":8.0,"no_roaming":true,"preferranged":25.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"Ruger"}},"HoldoutBoss":{"name":"HoldoutBoss","stats":{"basemovement":10.0,"boss":true,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":0.1,"health":250.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"scavguard":true,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":0.7,"visionrange":60.0,"wep":"SUPAK"}},"HoldoutDMR":{"name":"HoldoutDMR","stats":{"basemovement":0.0,"cangrapple":false,"chargemultiplier":1.0,"damage":15.0,"firerate":0.5,"health":175.0,"immune_poison":true,"immune_snares":true,"mag":10.0,"no_jumping":true,"no_roaming":true,"notagging":true,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.5,"scavguard":true,"shoveblocksmultiplier":1.0,"spread":1.0,"staggermultiplier":1.0,"visionrange":90.0,"wep":"RSASS"}},"HoldoutGuard":{"name":"HoldoutGuard","stats":{"basemovement":10.0,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":0.1,"health":175.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":2.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"scavguard":true,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":0.7,"visionrange":60.0,"wep":"SUPAK"}},"HoldoutSniper":{"name":"HoldoutSniper","stats":{"basemovement":0.0,"cangrapple":false,"chargemultiplier":1.0,"damage":20.0,"firerate":3.0,"health":150.0,"immune_poison":true,"immune_snares":true,"mag":10.0,"no_jumping":true,"no_roaming":true,"notagging":true,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.5,"scavguard":true,"shoveblocksmultiplier":1.0,"sniper_laser":true,"spread":1.0,"staggermultiplier":1.0,"visionrange":90.0,"wep":"Rifle"}},"HyperUnitA":{"name":"HyperUnitA","stats":{"basemovement":20.0,"can_block":true,"cangrapple":true,"chargemultiplier":1.0,"damage":8.0,"firerate":0.5,"health":175.0,"mag":25.0,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.7,"use_stims":true,"visionrange":55.0,"wep":"MilAxe"}},"HyperUnitB":{"name":"HyperUnitB","stats":{"basemovement":20.0,"cangrapple":true,"chargemultiplier":1.0,"damage":6.0,"dualies":true,"firerate":0.2,"health":150.0,"mag":34.0,"preferranged":5.0,"range":6.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":15.0,"staggermultiplier":1.0,"use_stims":true,"visionrange":55.0,"wep":"Glock"}},"HyperlyMoment":{"name":"HyperlyMoment","stats":{"basemovement":20.0,"boss":true,"can_dodge":true,"cangrapple":false,"cansprint":true,"chargemultiplier":1.2,"damage":10.0,"firerate":0.35,"health":900.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":4.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.3,"unshovable":true,"visionrange":60.0,"wep":"Hyperlame"}},"JollyCultAdvanced":{"name":"JollyCultAdvanced","stats":{"alt_anim":"CULA","basemovement":17.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.5,"damage":3.5,"firerate":0.13,"getupanim":true,"health":150.0,"mag":25.0,"no_roaming":true,"notagging":true,"preferranged":2.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.6,"visionrange":60.0,"weaponskin":"CultG","wep":"SubMG"}},"JollyCultGun":{"name":"JollyCultGun","stats":{"basemovement":16.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.5,"damage":2.5,"firerate":0.13,"getupanim":true,"health":120.0,"mag":25.0,"no_roaming":true,"notagging":true,"preferranged":5.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":8.0,"staggermultiplier":1.0,"visionrange":50.0,"weaponskin":"CultG","wep":"SubMG"}},"JollyCultMelee":{"name":"JollyCultMelee","stats":{"basemovement":20.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":3.0,"damage":8.0,"firerate":0.7,"getupanim":true,"health":150.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":5.0,"staggermultiplier":0.8,"visionrange":50.0,"weaponskin":"CultK","wep":"CKnife"}},"Jolly_AR":{"name":"Jolly_AR","stats":{"basemovement":13.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.093,"getupanim":true,"health":115.0,"mag":30.0,"preferranged":20.0,"random_weapon":{"1":"SubAK","2":"SUPAK","3":"SubMCX","4":"SubScar","5":"FAMAS"},"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.8,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":30.0,"staggermultiplier":1.0,"visionrange":30.0,"wep":"Snowball"}},"Jolly_BOSS_LMG":{"name":"Jolly_BOSS_LMG","stats":{"alt_anim":"RJUG","basemovement":8.0,"boss":true,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.1,"getupanim":true,"health":1000.0,"healthbartop":"Snow Tank","immune_mindkill":true,"immune_poison":true,"immune_snares":true,"immuneheadshot":true,"mag":2000.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":6.5,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":0.1,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"special_mark":true,"specialmark":true,"spread":16.0,"staggermultiplier":0.8,"visionrange":70.0,"wep":"FNLMG"}},"Jolly_Big_Blade":{"name":"Jolly_Big_Blade","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":3.0,"damage":7.0,"firerate":1.0,"getupanim":true,"health":120.0,"mag":25.0,"preferranged":1.0,"random_weapon":{"1":"NSword","2":"GSword","3":"PCutter","4":"MMachete","5":"ExecSword"},"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":45.0,"wep":"Snowball"}},"Jolly_Big_Bludgeon":{"name":"Jolly_Big_Bludgeon","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":4.0,"damage":6.0,"firerate":1.0,"getupanim":true,"health":140.0,"mag":25.0,"preferranged":1.0,"random_weapon":{"1":"SHammer","2":"DFAxe","3":"RBHammer"},"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":45.0,"wep":"Snowball"}},"Jolly_Pistol":{"name":"Jolly_Pistol","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":1.0,"damage":4.0,"firerate":1.0,"getupanim":true,"health":100.0,"mag":15.0,"preferranged":10.0,"random_weapon":{"1":"Pistol","2":"MPistol","3":"SUPMPistol","4":"STIPistol","5":"Glock"},"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.0,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":5.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"Snowball"}},"Jolly_Rifle":{"name":"Jolly_Rifle","stats":{"basemovement":9.0,"cangrapple":false,"chargemultiplier":1.0,"damage":12.0,"firerate":1.2,"getupanim":true,"health":90.0,"mag":10.0,"preferranged":5.0,"random_weapon":{"1":"HKMR","2":"RSASS","3":"HRifle","4":"EBR"},"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.2,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":5.0,"staggermultiplier":1.0,"visionrange":60.0,"wep":"Snowball"}},"Jolly_SMG":{"name":"Jolly_SMG","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":1.0,"damage":3.0,"firerate":0.0857,"getupanim":true,"health":95.0,"mag":25.0,"preferranged":5.0,"random_weapon":{"1":"UMP","2":"Mac","3":"ASVal","4":"SubMPX","5":"SubMG"},"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":8.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"Snowball"}},"Jolly_Shotgun":{"name":"Jolly_Shotgun","stats":{"basemovement":12.0,"cangrapple":false,"chargemultiplier":1.0,"damage":3.5,"firerate":1.0,"getupanim":true,"health":110.0,"mag":9.0,"preferranged":1.0,"random_weapon":{"1":"LeverShotgun","2":"MShotgun","3":"KSG","4":"SPShotgun"},"range":4.0,"ranged":true,"rangedbulletsfired":10.0,"reloadmultiplier":3.5,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":14.0,"staggermultiplier":1.0,"visionrange":40.0}},"Jolly_Small_Blade":{"name":"Jolly_Small_Blade","stats":{"basemovement":20.0,"cangrapple":false,"chargemultiplier":0.0,"damage":3.0,"firerate":0.3,"getupanim":true,"health":110.0,"mag":25.0,"preferranged":1.0,"random_weapon":{"1":"CKnife","2":"KaramB","3":"SCKnife","4":"HKnife"},"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":40.0,"wep":"Snowball"}},"Jolly_Small_Bludgeon":{"name":"Jolly_Small_Bludgeon","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":1.0,"getupanim":true,"health":120.0,"mag":25.0,"preferranged":1.0,"random_weapon":{"1":"PBaton","2":"BKnuckles","3":"CBar","4":"LPipe"},"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":40.0,"wep":"Snowball"}},"NZ":{"name":"NZ","stats":{"alt_anim":"NZ","basemovement":1.0,"boss":true,"cangrapple":false,"chargemultiplier":1.0,"custom_exec":"nightmare_zealot_exec","damage":1.0,"dualies":true,"firerate":0.5,"health":1.0,"immune_fracture":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":25.0,"nightmarezealot":true,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":7.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.8,"unshovable":true,"visionrange":9999.0,"weaponskin":"BrokenZealotBlade","wep":"ExecSword"}},"PlayerHolo":{"name":"PlayerHolo","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":0.0,"damage":1.0,"firerate":1.0,"friendly":true,"health":5.0,"holo":true,"hologram":true,"mag":25.0,"no_roaming":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"Fist"}},"PlayerHunter":{"name":"PlayerHunter","stats":{"alt_anim":"2SCY","basemovement":19.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.1,"damage":15.0,"firerate":0.5,"friendly":true,"health":125.0,"immune_mindkill":true,"mag":100.0,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"resistrange":true,"shadow":true,"shadowfading":true,"shadowhunter":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"suppress":false,"unshovable":true,"visionrange":40.0,"weaponskin":"SScythe","wep":"FAxe"}},"PlayerThrall":{"name":"PlayerThrall","stats":{"basemovement":16.0,"cangrapple":true,"chargemultiplier":1.0,"damage":8.0,"firerate":0.8,"friendly":true,"health":40.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"thrall":true,"visionrange":40.0,"wep":"SClaw"}},"RaiderAR":{"name":"RaiderAR","stats":{"alt_anim":"RTAC","basemovement":12.0,"brace_aim":true,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.075,"health":150.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":30.0,"no_roaming":true,"preferranged":5.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.0,"suppress":false,"tac_reload":true,"visionrange":70.0,"wep":"SubMCX"}},"RaiderLMG":{"name":"RaiderLMG","stats":{"alt_anim":"RJUG","basemovement":6.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.0857,"health":300.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"immuneheadshot":true,"mag":200.0,"max_shoot":40.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":70.0,"wep":"FNLMG"}},"RaiderMeleeA":{"name":"RaiderMeleeA","stats":{"basemovement":20.0,"can_block":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1.0,"damage":12.0,"firerate":0.8,"health":175.0,"mag":30.0,"no_roaming":true,"preferranged":1.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.75,"suppress":false,"visionrange":70.0,"wep":"MilAxe"}},"RaiderMeleeB":{"name":"RaiderMeleeB","stats":{"basemovement":20.0,"can_block":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1.0,"damage":12.0,"firerate":0.8,"health":175.0,"mag":30.0,"no_roaming":true,"preferranged":1.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.75,"suppress":false,"visionrange":70.0,"wep":"MilAxe"}},"RaiderShieldMelee":{"name":"RaiderShieldMelee","stats":{"alt_anim":"RRIOT","basemovement":18.0,"cangrapple":false,"chargemultiplier":1.0,"damage":8.0,"firerate":0.7,"health":150.0,"mag":30.0,"no_roaming":true,"preferranged":1.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"riotshield":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.5,"suppress":false,"visionrange":70.0,"wep":"FAxe"}},"RaiderShieldPistol":{"name":"RaiderShieldPistol","stats":{"alt_anim":"RCAR","basemovement":14.0,"cangrapple":false,"carshield":true,"chargemultiplier":1.0,"damage":4.0,"firerate":0.5,"health":140.0,"mag":20.0,"max_shoot":40.0,"no_roaming":true,"preferranged":5.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.5,"suppress":false,"visionrange":60.0,"wep":"STIPistol"}},"RaiderSniper":{"name":"RaiderSniper","stats":{"alt_anim":"RSNI","basemovement":10.0,"brace_aim":true,"cangrapple":false,"chargemultiplier":1.0,"damage":30.0,"firerate":3.8,"health":120.0,"mag":7.0,"no_jumping":true,"no_roaming":true,"preferranged":15.0,"raidboss_unit":true,"raider":true,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":7.0,"shoveblocksmultiplier":1.0,"sniper_laser":true,"spread":0.0,"staggermultiplier":1.0,"suppress":false,"tac_reload":true,"visionrange":80.0,"wep":"IntSniper"}},"ScavAKA":{"name":"ScavAKA","stats":{"basemovement":11.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.092,"health":90.0,"mag":30.0,"preferranged":20.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.2,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"SubAK"}},"ScavAKB":{"name":"ScavAKB","stats":{"basemovement":11.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":0.092,"health":90.0,"mag":30.0,"preferranged":20.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.2,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"SubAK"}},"ScavDoubleBarrel":{"name":"ScavDoubleBarrel","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":1.0,"damage":4.0,"firerate":0.8,"health":85.0,"mag":2.0,"preferranged":1.0,"range":4.0,"ranged":true,"rangedbulletsfired":10.0,"reloadmultiplier":2.8,"shoveblocksmultiplier":1.0,"spread":14.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"DoubleShotgun"}},"ScavDualies":{"name":"ScavDualies","stats":{"basemovement":20.0,"cangrapple":false,"chargemultiplier":1.0,"damage":3.0,"dualies":true,"firerate":0.15,"health":85.0,"mag":16.0,"preferranged":3.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.6,"shoveblocksmultiplier":1.0,"spread":7.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"Ruger"}},"ScavHenry":{"name":"ScavHenry","stats":{"basemovement":9.0,"cangrapple":false,"chargemultiplier":1.0,"damage":8.0,"firerate":1.0,"health":90.0,"mag":14.0,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.2,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.0,"suppress":false,"visionrange":50.0,"wep":"HRifle"}},"ScavMeleeA":{"name":"ScavMeleeA","stats":{"basemovement":17.0,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":1.1,"health":80.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"IPick"}},"ScavMeleeB":{"name":"ScavMeleeB","stats":{"basemovement":17.0,"cangrapple":false,"chargemultiplier":1.0,"damage":5.0,"firerate":1.4,"health":80.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"CKnife"}},"ScavMeleeC":{"name":"ScavMeleeC","stats":{"basemovement":17.0,"cangrapple":false,"chargemultiplier":1.0,"damage":6.0,"firerate":1.2,"health":80.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"LPipe"}},"ScavMeleeD":{"name":"ScavMeleeD","stats":{"basemovement":17.0,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":1.25,"health":100.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"CBar"}},"ScavMeleeE":{"name":"ScavMeleeE","stats":{"basemovement":28.0,"cangrapple":false,"chargemultiplier":0.3,"damage":3.0,"firerate":0.35,"health":75.0,"mag":25.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"KaramB"}},"ScavMeleeF":{"name":"ScavMeleeF","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":3.0,"damage":3.0,"firerate":1.0,"health":80.0,"mag":25.0,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.8,"suppress":false,"visionrange":40.0,"wep":"BSpear"}},"ScavMeleeG":{"name":"ScavMeleeG","stats":{"basemovement":20.0,"cangrapple":true,"chargemultiplier":1.2,"damage":15.0,"firerate":1.0,"health":150.0,"mag":25.0,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.8,"suppress":false,"visionrange":60.0,"wep":"SHammer"}},"ScavNewAWM":{"name":"ScavNewAWM","stats":{"basemovement":4.0,"cangrapple":false,"chargemultiplier":1.0,"damage":30.0,"firerate":5.0,"health":80.0,"mag":5.0,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"sniper_laser":true,"spread":0.0,"staggermultiplier":1.0,"suppress":false,"visionrange":80.0,"wep":"AWMSniper"}},"ScavNewComboA":{"name":"ScavNewComboA","stats":{"basemovement":16.0,"can_combo":true,"cangrapple":false,"chargemultiplier":0.8,"damage":8.0,"firerate":0.8,"health":85.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"NSword"}},"ScavNewComboB":{"name":"ScavNewComboB","stats":{"basemovement":16.0,"can_combo":true,"cangrapple":false,"chargemultiplier":0.8,"damage":7.0,"firerate":0.7,"health":85.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"Shovel"}},"ScavNewHenry":{"name":"ScavNewHenry","stats":{"basemovement":18.0,"cangrapple":false,"chargemultiplier":1.0,"damage":8.0,"fanning":true,"firerate":0.2,"health":95.0,"mag":14.0,"max_shoot":30.0,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.6,"shoveblocksmultiplier":1.0,"spread":15.0,"staggermultiplier":1.0,"suppress":false,"visionrange":50.0,"wep":"HRifle"}},"ScavNewMeleeA":{"name":"ScavNewMeleeA","stats":{"basemovement":16.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.0,"damage":9.0,"firerate":0.9,"health":100.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.9,"suppress":false,"visionrange":40.0,"wep":"BKnuckles"}},"ScavNewMeleeB":{"name":"ScavNewMeleeB","stats":{"basemovement":17.0,"cangrapple":true,"chargemultiplier":1.0,"damage":9.0,"firerate":1.2,"health":85.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"THawk"}},"ScavNewMeleeC":{"name":"ScavNewMeleeC","stats":{"basemovement":28.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":0.3,"damage":6.0,"firerate":0.3,"health":80.0,"mag":25.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"SCKnife"}},"ScavNewMeleeD":{"name":"ScavNewMeleeD","stats":{"basemovement":16.0,"can_block":true,"cangrapple":false,"chargemultiplier":1.0,"damage":9.0,"firerate":1.1,"health":85.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"CCleaver"}},"ScavNewMeleeE":{"name":"ScavNewMeleeE","stats":{"basemovement":16.0,"can_block":true,"cangrapple":false,"chargemultiplier":1.0,"damage":9.0,"firerate":1.1,"health":85.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"BBat"}},"ScavNewMeleeF":{"name":"ScavNewMeleeF","stats":{"basemovement":17.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.0,"damage":11.0,"firerate":0.9,"health":90.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"PBaton"}},"ScavNewMeleeG":{"name":"ScavNewMeleeG","stats":{"basemovement":16.0,"cangrapple":true,"chargemultiplier":1.0,"damage":9.0,"firerate":1.0,"health":90.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"CHammer"}},"ScavNewMeleeH":{"name":"ScavNewMeleeH","stats":{"basemovement":16.0,"cangrapple":true,"chargemultiplier":1.0,"damage":9.0,"firerate":1.0,"health":90.0,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"Rake"}},"ScavNewPistolA":{"name":"ScavNewPistolA","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":1.0,"damage":9.0,"firerate":1.0,"health":85.0,"mag":17.0,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"Glock"}},"ScavNewRevolver":{"name":"ScavNewRevolver","stats":{"basemovement":18.0,"cangrapple":false,"chargemultiplier":1.0,"damage":9.0,"fanning":true,"firerate":0.15,"health":75.0,"mag":6.0,"max_shoot":10.0,"preferranged":3.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":4.0,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"RVolver"}},"ScavNewSKS":{"name":"ScavNewSKS","stats":{"basemovement":10.0,"cangrapple":false,"chargemultiplier":1.0,"damage":10.0,"firerate":0.8,"health":90.0,"mag":10.0,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.4,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.0,"suppress":false,"visionrange":50.0,"wep":"SKS"}},"ScavNewSVD":{"name":"ScavNewSVD","stats":{"basemovement":8.0,"cangrapple":false,"chargemultiplier":1.0,"damage":16.0,"firerate":1.5,"health":90.0,"mag":10.0,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":7.0,"staggermultiplier":1.0,"suppress":false,"visionrange":50.0,"wep":"SVD"}},"ScavNewSpas":{"name":"ScavNewSpas","stats":{"basemovement":11.0,"cangrapple":false,"chargemultiplier":1.0,"damage":3.0,"firerate":1.0,"health":85.0,"mag":9.0,"preferranged":1.0,"range":4.0,"ranged":true,"rangedbulletsfired":10.0,"reloadmultiplier":3.5,"shoveblocksmultiplier":1.0,"spread":14.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"SPShotgun"}},"ScavNewSpear":{"name":"ScavNewSpear","stats":{"basemovement":10.0,"cangrapple":false,"chargemultiplier":0.1,"damage":7.0,"firerate":0.3,"health":140.0,"mag":25.0,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.75,"suppress":false,"visionrange":40.0,"wep":"PFork"}},"ScavPistolA":{"name":"ScavPistolA","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":1.0,"damage":6.0,"firerate":1.5,"health":80.0,"mag":12.0,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.0,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"Pistol"}},"ScavPistolB":{"name":"ScavPistolB","stats":{"basemovement":14.0,"cangrapple":false,"chargemultiplier":1.0,"damage":9.0,"firerate":2.3,"health":80.0,"mag":7.0,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"MPistol"}},"ScavPistolC":{"name":"ScavPistolC","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":1.0,"damage":3.0,"firerate":0.35,"health":75.0,"mag":8.0,"preferranged":3.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.6,"shoveblocksmultiplier":1.0,"spread":7.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"Ruger"}},"ScavSMGA":{"name":"ScavSMGA","stats":{"basemovement":16.0,"cangrapple":false,"chargemultiplier":1.0,"damage":3.0,"firerate":0.0857,"health":75.0,"mag":20.0,"preferranged":5.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"SubMG"}},"ScavShotgun":{"name":"ScavShotgun","stats":{"basemovement":7.0,"cangrapple":false,"chargemultiplier":1.0,"damage":7.0,"firerate":1.75,"health":90.0,"mag":6.0,"preferranged":1.0,"range":4.0,"ranged":true,"rangedbulletsfired":10.0,"reloadmultiplier":2.5,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"suppress":false,"visionrange":40.0,"wep":"MShotgun"}},"ScavSniper":{"name":"ScavSniper","stats":{"basemovement":5.0,"cangrapple":false,"chargemultiplier":1.0,"damage":15.0,"firerate":2.0,"health":80.0,"mag":10.0,"preferranged":10.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.5,"shoveblocksmultiplier":1.0,"spread":1.0,"staggermultiplier":1.0,"suppress":false,"visionrange":70.0,"wep":"HuntingR"}},"ShadowHanger":{"name":"ShadowHanger","stats":{"basemovement":2.0,"cangrapple":false,"chargemultiplier":0.0,"damage":10.0,"fearless_blockable":false,"fearless_shovable":true,"firerate":0.8,"hanger":true,"health":150.0,"ignoreblocks":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100.0,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"shadow":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.15,"suppress":false,"unshovable":true,"unstunnable":true,"visionrange":50.0,"wep":"KitKnife"}},"ShadowHidden":{"name":"ShadowHidden","stats":{"basemovement":7.0,"cangrapple":false,"cansprint":true,"chargemultiplier":3.0,"cloaker":true,"damage":30.0,"fearless_blockable":false,"fearless_shovable":false,"firerate":2.0,"health":120.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"shadow":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.5,"suppress":false,"unshovable":true,"visionrange":120.0,"weaponskin":"GhostKnife","wep":"CKnife"}},"ShadowSickler":{"name":"ShadowSickler","stats":{"basemovement":2.0,"boss":true,"cangrapple":false,"chargemultiplier":0.0,"damage":15.0,"fearless_blockable":true,"fearless_shovable":true,"firerate":0.4,"health":700.0,"ignoreblocks":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100.0,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"resistrange":true,"shadow":true,"shoveblocksmultiplier":1.0,"sickler":true,"spread":10.0,"staggermultiplier":0.15,"suppress":false,"unshovable":true,"unstunnable":true,"visionrange":15.0,"wep":"SClaw"}},"ShiroseGuard":{"name":"ShiroseGuard","stats":{"basemovement":8.0,"cangrapple":false,"canrest":"shirose_guard","chargemultiplier":1.0,"damage":7.0,"firerate":0.1,"friendly":true,"health":175.0,"immune_poison":true,"immune_snares":true,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":40.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"resistrange":true,"scavguard":true,"shoveblocksmultiplier":1.0,"spread":3.0,"staggermultiplier":0.7,"visionrange":100.0,"wep":"SUPAK"}},"Skinner":{"name":"Skinner","stats":{"basemovement":17.0,"cangrapple":true,"chargemultiplier":1.0,"damage":15.0,"fearless_shovable":true,"firerate":0.7,"health":250.0,"immune_fracture":true,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100.0,"new_skinner":true,"no_rogue":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"shadow":true,"shoveblocksmultiplier":1.0,"skinner":true,"spread":10.0,"staggermultiplier":0.7,"suppress":false,"unshovable":true,"visionrange":40.0,"wep":"THand"}},"TemplarGuards":{"name":"TemplarGuards","stats":{"basemovement":12.0,"cangrapple":false,"cansprint":true,"chargemultiplier":2.0,"damage":10.0,"firerate":1.0,"health":150.0,"immune_poison":true,"immune_snares":true,"mag":12.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":0.8,"visionrange":120.0,"wep":"GSword"}},"TemplarMinionA":{"name":"TemplarMinionA","stats":{"basemovement":28.0,"cangrapple":false,"chargemultiplier":2.0,"damage":10.0,"firerate":0.8,"health":150.0,"immune_poison":true,"immune_snares":true,"mag":12.0,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":1.2,"visionrange":120.0,"wep":"SSword"}},"TemplarMinionB":{"name":"TemplarMinionB","stats":{"basemovement":13.0,"cangrapple":false,"chargemultiplier":2.0,"damage":8.0,"firerate":0.4,"health":300.0,"immune_poison":true,"immune_snares":true,"mag":12.0,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":1.5,"visionrange":120.0,"wep":"PSpear"}},"WendigoBossFunRuiner_gluf":{"name":"WendigoBossFunRuiner_gluf","stats":{"alt_anim":"2QU","basemovement":25,"boss":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1,"custom_exec":"queen_exec","damage":15,"extra_parry_window":0.4,"firerate":0.7,"health":1200,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"noturretarget":true,"preferranged":1,"queen":true,"raidboss_unit":true,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":6,"resistrange":true,"shoveblocksmultiplier":1,"spin_charge":true,"spread":10,"staggermultiplier":0.35,"visionrange":120,"weaponskin":"IQHammer","wep":"SHammer"}},"XMASBossFunRuiner_gluf":{"name":"XMASBossFunRuiner_gluf","stats":{"alt_anim":"2QU","basemovement":25,"boss":true,"can_combo":true,"can_dodge":true,"cangrapple":true,"chargemultiplier":1,"custom_exec":"queen_exec","damage":15,"extra_parry_window":0.4,"firerate":0.7,"health":1200,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":100,"melee_block_bullets":true,"no_roaming":true,"notagging":true,"noturretarget":true,"preferranged":1,"queen":true,"raidboss_unit":true,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":6,"resistrange":true,"shoveblocksmultiplier":1,"spin_charge":true,"spread":10,"staggermultiplier":0.35,"visionrange":120,"weaponskin":"QHammer","wep":"SHammer"}},"YosefSniper":{"name":"YosefSniper","stats":{"basemovement":2.0,"cangrapple":false,"canrest":"yosef_guard","chargemultiplier":1.0,"damage":250.0,"firerate":1.0,"friendly":true,"health":90.0,"mag":1.0,"no_roaming":true,"perfect_accuracy":true,"preferranged":75.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":3.0,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":0.0,"staggermultiplier":1.0,"visionrange":100.0,"wep":"SVD"}},"battlejuice":{"name":"battlejuice","stats":{"alt_anim":"BATTLEJUICE","basemovement":13,"boss":true,"can_dodge":true,"cangrapple":false,"cankick":true,"chargemultiplier":1.5,"cult":true,"cultboss":true,"damage":2,"dualies":true,"firerate":0.05,"health":600,"immune_mindkill":true,"mag":50,"no_roaming":true,"no_rogue":true,"notagging":true,"preferranged":18,"range":5,"ranged":true,"rangedbulletsfired":1,"reloadmultiplier":1.5,"resistrange":true,"shadow":true,"shadowfading":true,"shoveblocksmultiplier":1,"song":137608124013928.0,"spread":3,"staggermultiplier":0.4,"visionrange":120,"weaponskin":"CultG","wep":"SubMG"}},"c1":{"name":"c1","stats":{"basemovement":18.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":2.0,"cult":true,"damage":4.0,"firerate":0.4,"health":75.0,"mag":28.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.8,"visionrange":50.0,"wep":"Sabre"}},"c2":{"name":"c2","stats":{"basemovement":20.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":2.0,"cult":true,"damage":6.0,"firerate":0.7,"health":85.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.8,"visionrange":50.0,"wep":"Kukri"}},"c3":{"name":"c3","stats":{"basemovement":22.0,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"damage":11.0,"firerate":0.7,"health":80.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.8,"visionrange":50.0,"wep":"GasWrench"}},"c4":{"name":"c4","stats":{"basemovement":11.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":4.0,"cult":true,"damage":15.0,"firerate":0.7,"health":200.0,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":5.0,"staggermultiplier":0.8,"visionrange":50.0,"wep":"PipeWrench"}},"celldweller":{"name":"celldweller","stats":{"abilities":{},"alt_anim":"CELLDWELLER","basemovement":13,"boss":true,"can_dodge":true,"cangrapple":false,"celldweller":true,"chargemultiplier":4,"cult":true,"cultboss":true,"damage":3,"firerate":4294967296.0,"health":800,"immune_mindkill":true,"mag":0,"no_roaming":true,"no_rogue":true,"notagging":true,"preferranged":30,"range":5,"ranged":true,"rangedbulletsfired":1,"reloadmultiplier":1.5,"resistrange":true,"shadow":true,"shadowfading":true,"shoveblocksmultiplier":1,"song":115210236194973.0,"spread":3,"staggermultiplier":0.4,"visionrange":70,"weaponskin":"SClaw","wep":"BKnuckles"}},"cowboy":{"name":"cowboy","stats":{"basemovement":12.0,"boss":true,"cangrapple":false,"chargemultiplier":4.0,"damage":256.0,"firerate":0.7,"friendly":true,"health":1000.0,"immune_poison":true,"immune_snares":true,"mag":30.0,"no_roaming":true,"notagging":true,"preferranged":2.0,"range":4.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":2.3,"shoveblocksmultiplier":1.0,"spread":8.0,"staggermultiplier":0.7,"visionrange":60.0,"weaponskin":"SClaw","wep":"BKnuckles"}},"cowboy_evac":{"name":"cowboy_evac","stats":{"basemovement":16.0,"boss":true,"cangrapple":false,"chargemultiplier":1.5,"damage":20.0,"dualies":true,"firerate":0.1,"health":1000.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":12.0,"no_roaming":true,"notagging":true,"preferranged":20.0,"range":5.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":2.0,"staggermultiplier":0.5,"visionrange":120.0,"weaponskin":"Mateba","wep":"Mateba"}},"cultist_bulldozer":{"name":"cultist_bulldozer","stats":{"basemovement":11.0,"can_dodge":false,"cangrapple":false,"chargemultiplier":1.0,"cult":true,"damage":8.0,"firerate":1.0,"health":150.0,"mag":30.0,"max_shoot":25.0,"no_roaming":true,"notagging":true,"preferranged":1.0,"range":3.0,"ranged":true,"rangedbulletsfired":10.0,"reloadmultiplier":3.5,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"visionrange":120.0,"weaponskin":"CultSPShotgun","wep":"SPShotgun"}},"lebrock":{"name":"lebrock","stats":{"alt_anim":"LEBROCK","basemovement":20.0,"boss":true,"can_dodge":true,"cangrapple":false,"chargemultiplier":1.5,"cult":true,"cultboss":true,"damage":32.0,"firerate":0.5,"health":850.0,"immune_mindkill":true,"mag":50.0,"no_roaming":true,"no_rogue":true,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.5,"resistrange":true,"shadow":true,"shadowfading":true,"shoveblocksmultiplier":1.0,"song":140298647639432.0,"spread":3.0,"staggermultiplier":0.4,"visionrange":70.0,"weaponskin":"ShadowScythe","wep":"RScythe"}},"ls":{"name":"ls","stats":{"abilities":{"1":"Shadow_Death","2":"LostSoul_SpreadOnKill","3":"LostSoul_Body"},"basemovement":50.0,"cangrapple":false,"chargemultiplier":0.0,"custom_exec":"queen_exec","damage":2.0,"firerate":0.1,"getupanim":true,"health":1.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":25.0,"no_rogue":true,"nohexing":true,"notagging":true,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shadow":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"unstunnable":true,"use_new_ai":true,"visionrange":40.0,"weaponskin":"SClaw","wep":"BKnuckles"}},"lumi":{"name":"lumi","stats":{"alt_anim":"Lumi","basemovement":26,"boss":true,"can_combo":true,"can_dodge":true,"can_reanimate":true,"cangrapple":true,"chargemultiplier":1,"damage":10,"extra_parry_window":0.4,"female":true,"firerate":0.7,"health":1500,"healthbartop":"Lumi","immune_mindkill":true,"immune_snares":true,"lumi":true,"lumi_transform":true,"mag":100,"notagging":true,"preferranged":1,"range":6,"ranged":false,"rangedbulletsfired":1,"reloadmultiplier":6,"resistrange":true,"shoveblocksmultiplier":1,"snowenemy":true,"spin_charge":true,"spread":10,"staggermultiplier":0.35,"visionrange":120,"wep":"lumi_sword_base"}},"lumi_reanimated_minion":{"name":"lumi_reanimated_minion","stats":{"basemovement":18.0,"cangrapple":false,"chargemultiplier":0.0,"damage":8.0,"firerate":0.3,"getupanim":true,"health":200.0,"immune_mindkill":true,"jollyeyes":true,"mag":25.0,"no_roaming":true,"no_rogue":true,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":70.0,"weaponskin":"Icicle","wep":"MMachete"}},"lure":{"name":"lure","stats":{"basemovement":1.0,"cangrapple":false,"chargemultiplier":0.0,"damage":1.0,"firerate":1.0,"friendly":true,"health":1.0,"invisbody":true,"mag":25.0,"preferranged":1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"visionrange":40.0,"wep":"Fist"}},"scientist":{"name":"scientist","stats":{"alt_anim":"CULB","basemovement":14.0,"boss":true,"cangrapple":false,"chargemultiplier":1.0,"damage":0.0,"female":true,"firerate":0.1,"friendly":true,"health":4294967296.0,"mag":30.0,"no_roaming":true,"notagging":true,"notarget":true,"preferranged":-1.0,"range":5.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"scientist":true,"shoveblocksmultiplier":1.0,"spread":0.01,"staggermultiplier":0.7,"unshovable":true,"visionrange":-1.0,"weaponskin":"WHITESUPAK","wep":"SUPAK"}},"snowbrute":{"name":"snowbrute","stats":{"basemovement":20.0,"cangrapple":true,"canthrowsnowballs":true,"chargemultiplier":1.2,"damage":15.0,"firerate":1.0,"health":250.0,"mag":25.0,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":0.8,"visionrange":60.0,"wep":"Snowball"}},"snowbrute_holdout":{"name":"snowbrute_holdout","stats":{"basemovement":14.0,"cangrapple":true,"chargemultiplier":1.0,"damage":4.0,"firerate":1.0,"getupanim":true,"health":110.0,"immune_poison":true,"immune_snares":true,"mag":25.0,"no_roaming":true,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":70.0,"wep":"Snowball"}},"snowguard":{"name":"snowguard","stats":{"basemovement":16.0,"boss":true,"cangrapple":true,"chargemultiplier":3.0,"damage":20.0,"firerate":1.0,"getupanim":true,"health":500.0,"healthbartop":"Guard","immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":25.0,"no_roaming":true,"preferranged":1.0,"range":6.5,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.3,"resistrange":true,"shoveblocksmultiplier":1.0,"snowenemy":true,"specialmark":true,"spread":10.0,"staggermultiplier":0.8,"visionrange":60.0,"wep":"SSword"}},"snowminigun":{"name":"snowminigun","stats":{"basemovement":16.0,"cangrapple":false,"canthrowsnowballs":true,"chargemultiplier":1.0,"customsnowballcd":0.1,"customsnowballdmg":2.0,"damage":1.0,"firerate":1.0,"health":85.0,"mag":0.0,"preferranged":20.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"visionrange":50.0,"wep":"Snowball"}},"snowminigun_holdout":{"name":"snowminigun_holdout","stats":{"basemovement":12.0,"cangrapple":false,"canthrowsnowballs":true,"chargemultiplier":1.0,"customsnowballcd":0.25,"customsnowballdmg":1.0,"damage":1.0,"firerate":1.0,"health":75.0,"mag":0.0,"preferranged":20.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"visionrange":50.0,"wep":"Snowball"}},"snowsniper":{"name":"snowsniper","stats":{"basemovement":10.0,"cangrapple":false,"canthrowsnowballs":true,"chargemultiplier":1.0,"customsnowballcd":2.0,"customsnowballdmg":20.0,"damage":1.0,"firerate":1.0,"health":75.0,"mag":0.0,"preferranged":40.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"visionrange":70.0,"wep":"Snowball"}},"snowsniper_holdout":{"name":"snowsniper_holdout","stats":{"basemovement":12.0,"cangrapple":false,"canthrowsnowballs":true,"chargemultiplier":1.0,"customsnowballcd":3.0,"customsnowballdmg":10.0,"damage":1.0,"firerate":1.0,"health":40.0,"mag":0.0,"preferranged":30.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"visionrange":70.0,"wep":"Snowball"}},"so":{"name":"so","stats":{"abilities":{"1":"ShadowOverseer_Puddle","2":"Shadow_Spawn","3":"Transparent_Body"},"basemovement":3.0,"cangrapple":false,"chargemultiplier":3.0,"damage":1.0,"firerate":1.0,"health":300.0,"immune_mindkill":true,"immune_poison":true,"immune_snares":true,"mag":0.0,"no_rogue":true,"preferranged":80.0,"range":4.0,"ranged":true,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"shadow":true,"shoveblocksmultiplier":1.0,"spread":10.0,"staggermultiplier":1.0,"use_new_ai":true,"visionrange":120.0,"weaponskin":"SClaw","wep":"KitKnife"}},"stickler":{"name":"stickler","stats":{"basemovement":2.0,"boss":true,"cangrapple":false,"chargemultiplier":0.0,"damage":15.0,"firerate":0.4,"health":700.0,"ignoreblocks":true,"immune_fracture":true,"immune_mindkill":true,"mag":100.0,"notagging":true,"preferranged":1.0,"range":6.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":6.0,"shadow":true,"shoveblocksmultiplier":1.0,"sickler":true,"spread":10.0,"staggermultiplier":0.15,"unshovable":true,"unstunnable":true,"visionrange":15.0,"wep":"SClaw"}},"turfwar_bait":{"name":"turfwar_bait","stats":{"abilities":{"1":"Turfwar_Bait"},"basemovement":0.0,"cangrapple":false,"chargemultiplier":0.0,"damage":1.0,"firerate":1.0,"health":1.0,"mag":1.0,"preferranged":1.0,"range":1.0,"ranged":false,"rangedbulletsfired":1.0,"reloadmultiplier":1.0,"shoveblocksmultiplier":1.0,"spread":1.0,"staggermultiplier":1.0,"use_new_ai":true,"visionrange":1.0,"wep":"SClaw"}}},"interactables":{"DRP_activate_sprinkler":{"interact_duration":0.5},"DRP_agent_watch_RED":{"interact_duration":2.0},"DRP_clear_input_YELLOW":{},"DRP_confirm_input_YELLOW":{},"DRP_dedguy_interact_YELLOW":{"interact_duration":10.0},"DRP_divert_power":{"interact_duration":5.0},"DRP_enter_number_input_YELLOW":{},"DRP_input_overseer_code_CLEAR":{},"DRP_input_overseer_code_CONFIRM":{},"DRP_input_overseer_code_NUM":{},"DRP_insert_battery":{"interact_duration":5.0},"DRP_insert_keycard_BLUE":{"interact_duration":3.0},"DRP_insert_keycard_RED":{"interact_duration":3.0},"DRP_insert_keycard_YELLOW":{"interact_duration":3.0},"DRP_laptop_keycode":{"interact_duration":4.0},"DRP_locator_terminal":{"interact_duration":10.0},"DRP_open_safe_RED":{"interact_duration":1.0},"DRP_open_vent_YELLOW":{"interact_duration":3.0},"DRP_pickup_battery":{"interact_duration":4.0},"DRP_pickup_keycard_BLUE":{"interact_duration":10.0},"DRP_pickup_keycard_RED":{},"DRP_pickup_keycard_YELLOW":{},"DRP_repair_box":{"interact_duration":2.5},"DRP_rope_down":{"interact_duration":3.0},"DRP_scientist_interact":{"interact_duration":1.5},"DRP_teleporter_terminal":{"interact_duration":3.0},"ELEVATOR_CallButton":{"interact_duration":1.0},"ELEVATOR_InnerMoveButton":{"interact_duration":1.3},"JOLLY_DRP_Door":{"interact_duration":2.0},"JOLLY_EVAC_Frequency":{},"JOLLY_EVAC_fix_generator":{"interact_duration":4.0},"JOLLY_EVAC_fix_sat_dish":{"interact_duration":2.0},"JOLLY_EVAC_get_security_key":{},"JOLLY_EVAC_grab_repair_kit":{},"JOLLY_EVAC_ignite_flare":{"interact_duration":3.0},"JOLLY_EVAC_insert_battery":{"interact_duration":3.0},"JOLLY_EVAC_insert_security_key":{},"JOLLY_EVAC_keypad_clear":{},"JOLLY_EVAC_keypad_numbers":{},"JOLLY_EVAC_keypad_submit":{},"JOLLY_EVAC_open_ship_hatch":{"interact_duration":1.0},"JOLLY_EVAC_pick_up_battery":{"interact_duration":3.0},"JOLLY_EVAC_repair_sat_wire":{"interact_duration":5.0},"JOLLY_EVAC_send_life_signal":{"interact_duration":4.0},"JOLLY_Get_DRP_Data":{"interact_duration":2.0},"JOLLY_IrisMessages":{"interact_duration":1.5},"JOLLY_THORUM_ignite_flare":{"interact_duration":3.0},"JOLLY_THORUM_signal_ship":{"interact_duration":3.0},"JOLLY_ThorumDeath":{"interact_duration":1.5},"JOLLY_ThorumMessages":{"interact_duration":1.5},"JOLLY_collect_data":{"interact_duration":3.0},"JOLLY_flip_power_lever":{"interact_duration":3.0},"JOLLY_fuse_get":{},"JOLLY_hardmode_activate":{"interact_duration":3.0},"JOLLY_pickup_teleporter_battery":{"interact_duration":2.0},"JOLLY_powerbox_fix":{},"JOLLY_powerbox_open":{"interact_duration":1.0},"JOLLY_repair_teleporter":{"interact_duration":3.0},"JOLLY_return_teleporter_battery":{"interact_duration":4.0},"JOLLY_return_teleporter_part":{},"JOLLY_scrap_crate":{"interact_duration":2.0},"JOLLY_security_keycard":{},"JOLLY_send_data":{"interact_duration":5.0},"JOLLY_supply_container":{"interact_duration":2.0},"JOLLY_teleporter_OUT":{"interact_duration":4.0},"JOLLY_teleporter_START":{"interact_duration":4.0},"JOLLY_teleporter_set":{"interact_duration":4.0},"SNOWSTORM_open_ammobox":{"interact_duration":4.0},"SNOWSTORM_open_medbox":{"interact_duration":4.0},"SNOWSTORM_open_wepbox":{"interact_duration":5.0},"ULTIMA_camera_interact":{},"ULTIMA_zealot_interact":{"interact_duration":30.0},"acquirething":{},"activatething":{},"arsenal_locker":{"interact_duration":4.0},"crate":{"interact_duration":1.0},"double_locker":{},"getguitar":{},"holdout_buy_chemical_station":{"interact_duration":2.0},"holdout_buy_communication_server":{"interact_duration":2.0},"holdout_buy_defensive_barricade":{"interact_duration":2.0},"holdout_buy_mechanical_tools":{"interact_duration":2.0},"holdout_buy_medical_equipment":{"interact_duration":2.0},"holdout_buy_medical_station":{"interaction_duration":2.0},"holdout_buy_personal_scrapper":{"interaction_duration":2.0},"holdout_buy_personal_workbench":{"interaction_duration":2.0},"holdout_buy_ration_dispenser":{"interaction_duration":2.0},"holdout_buy_spare_parts":{"interact_duration":2.0},"holdout_buy_upgrade":{"interact_duration":2.0},"holdout_personal_scrapper":{"interact_duration":3.0},"holdout_use_fabricator":{"interaction_duration":1.0},"item_fabricator":{"interact_duration":1.0},"keycardget":{},"labdoors":{},"locker":{},"med_cabinet":{},"pickup":{},"returnguitar":{},"scrapper":{"interact_duration":2.0},"signalthing":{"interact_duration":4.0},"unlockthing":{},"workbench":{"interact_duration":0.5}}}]==])
local App = {
    alive = true, connections = {}, controls = {}, modules = {}, moduleStatus = {},
    entries = {}, visuals = {}, roots = {}, log = {}, traitOwned = {},
    traitFolders = {}, traitConnections = {}, cfg = {}, tick = 0,
    statusTime = 0, espTime = 0, scanTime = 0, traitTime = 0,
    actionBusy = false, actionTime = -100, autoPause = {}, runtimeFailures = {},
    build = "0.4.1", catalog = Catalog,
}
Environment.DW_RayfieldFieldKit = App
local Defaults = {
    traitsEnabled = false, espEnabled = false, labels = true, highlights = true,
    throughWalls = true, espDistance = 1600, maxLabels = 65, maxHighlights = 20,
    textSize = 14, espInterval = 0.20, filter = "", espHealth = true,
    hud = true, aimEnabled = false, aimRadius = 130, aimDistance = 400,
    aimSmooth = 0.12, aimPart = "Head", aimWallCheck = true, aimRing = true,
    autoPickup = false, pickupDistance = 8, pickupInterval = 1.25,
    speedEnabled = false, walkSpeed = 20, jumpEnabled = false, jumpPower = 50,
    infiniteJump = false, noclip = false, fly = false, flySpeed = 35,
    fullbright = false, noFog = false, noPostEffects = false, noShadows = false,
    fovEnabled = false, fov = 85, leaderboard = true, theme = "Default",
}
local Categories = {
    "Workbenches", "Scrappers", "Lockers", "Medical cabinets", "Crates", "Ammo",
    "Rations", "Scrap", "Harvest", "Blueprints", "Medical", "Weapons", "Items",
    "Hostiles", "Bosses", "Friendlies", "Players", "Objectives",
}
local Colors = {
    Workbenches = Color3.fromRGB(60, 240, 165), Scrappers = Color3.fromRGB(245, 195, 80),
    Lockers = Color3.fromRGB(105, 190, 255), ["Medical cabinets"] = Color3.fromRGB(255, 150, 180),
    Crates = Color3.fromRGB(180, 135, 90), Ammo = Color3.fromRGB(255, 215, 95),
    Rations = Color3.fromRGB(155, 235, 85), Scrap = Color3.fromRGB(220, 215, 185),
    Harvest = Color3.fromRGB(140, 220, 150), Blueprints = Color3.fromRGB(150, 160, 255),
    Medical = Color3.fromRGB(255, 145, 170), Weapons = Color3.fromRGB(255, 180, 100),
    Items = Color3.fromRGB(220, 220, 220), Hostiles = Color3.fromRGB(255, 100, 90),
    Bosses = Color3.fromRGB(255, 80, 175), Friendlies = Color3.fromRGB(90, 210, 255),
    Players = Color3.fromRGB(110, 255, 220), Objectives = Color3.fromRGB(215, 150, 255),
}
local TraitGroups = {
    {"Melee", {"rustic", "manic", "violence", "boxer", "honor"}},
    {"Firearms", {"recoil", "hip", "reliab", "paranoia"}},
    {"Stamina and movement", {"second", "leg", "lungs"}},
    {"Survival / server-dependent effects", {"regen", "boned", "thick", "tough"}},
}
local TraitPresets = {
    ["Melee"] = {"rustic", "manic", "violence", "boxer", "honor", "leg", "second"},
    ["Firearms"] = {"recoil", "hip", "reliab", "paranoia", "leg", "lungs"},
    ["Survival"] = {"regen", "boned", "thick", "tough", "lungs", "leg"},
    ["All 16 markers"] = {"rustic", "manic", "violence", "boxer", "honor", "recoil", "hip", "reliab", "paranoia", "second", "leg", "lungs", "regen", "boned", "thick", "tough"},
    ["Clear selections"] = {},
}
App.traits, App.categories, App.pickupCategories = {}, {}, {}
for key, value in pairs(Defaults) do App.cfg[key] = value end
for key in pairs(Catalog.traits) do App.traits[key] = false end
for _, category in ipairs(Categories) do
    App.categories[category] = category == "Workbenches" or category == "Scrappers" or category == "Bosses"
end
for _, category in ipairs({"Ammo", "Rations", "Scrap", "Medical", "Blueprints", "Weapons", "Items"}) do
    App.pickupCategories[category] = category == "Ammo" or category == "Rations" or category == "Medical"
end

function App.Note(message)
    message = tostring(message):sub(1, 600)
    App.log[#App.log + 1] = message
    if #App.log > 60 then table.remove(App.log, 1) end
    warn("[DW Field Kit] " .. message)
end
function App.Connect(signal, callback, bag)
    if not App.alive then return nil end
    local connection = signal:Connect(function(...)
        if not App.alive then return end
        local ok, err = pcall(callback, ...)
        if not ok then
            local key = tostring(err)
            if not App.runtimeFailures[key] then App.runtimeFailures[key] = true; App.Note(key) end
        end
    end)
    local list = bag or App.connections
    list[#list + 1] = connection
    return connection
end
function App.Disconnect(bag)
    for _, connection in ipairs(bag) do pcall(function() connection:Disconnect() end) end
    table.clear(bag)
end
function App.Path(root, ...)
    for _, name in ipairs({...}) do
        root = root and root:FindFirstChild(name)
        if not root then return nil end
    end
    return root
end
function App.Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
function App.Call(object, key, ...)
    if type(object) ~= "table" then return nil end
    local readable, method = pcall(function() return object[key] end)
    if not readable or type(method) ~= "function" then return nil end
    local ok, value = pcall(method, ...)
    if ok then return value end
    return nil
end
function App.Character()
    local active = Services.World:FindFirstChild("activePlayers")
    local character = active and active:FindFirstChild(LP.Name)
    if character and character:IsA("Model") then return character end
    character = LP.Character
    if character and character.Parent then return character end
    return nil
end
function App.Root(character)
    character = character or App.Character()
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character:FindFirstChild("Torso")
end
function App.Humanoid()
    local character = App.Character()
    return character and character:FindFirstChildOfClass("Humanoid")
end
function App.Part(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") or instance:FindFirstChild("Head") or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end
function App.Entity(instance)
    local node = instance
    for _ = 1, 5 do
        if not node or node == Services.World then break end
        local marker = node:FindFirstChildOfClass("Camera")
        if marker then return tonumber(marker.Name) end
        node = node.Parent
    end
    return nil
end
function App.Component(entity, name)
    local world, cts = App.modules.world, App.modules.cts
    if not entity or not world or not cts or not cts[name] then return nil end
    local ok, value = pcall(function() return world:get(entity, cts[name]) end)
    if ok then return value end
    return nil
end
function App.Active()
    return App.Call(App.modules.interface, "active") == true
end
function App.GetInventory()
    if not App.Active() then return nil end
    return App.Call(App.modules.interface, "get_inventory") or App.modules.inventory
end
function App.Store(key)
    local store = App.modules.store
    if not store then return nil end
    local readable, value = pcall(function() return store[key] end)
    if not readable then return nil end
    if type(value) == "function" or (type(value) == "table" and getmetatable(value) and type(getmetatable(value).__call) == "function") then
        local ok, result = pcall(function() return value() end)
        if ok then return result end
    elseif type(value) ~= "table" then return value end
    return nil
end
function App.Format(value, depth)
    depth = depth or 0
    if type(value) ~= "table" then return tostring(value) end
    if depth > 2 then return "{...}" end
    local keys, out = {}, {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for i, key in ipairs(keys) do
        if i > 30 then out[#out + 1] = "..."; break end
        out[#out + 1] = tostring(key) .. ": " .. App.Format(value[key], depth + 1)
    end
    return table.concat(out, depth == 0 and "\n" or "; ")
end
function App.Notify(title, content)
    if App.rayfield then
        pcall(function() App.rayfield:Notify({Title = title, Content = tostring(content):sub(1, 600), Duration = 5}) end)
    else App.Note(title .. ": " .. tostring(content)) end
end

-- Each optional require runs separately: one unavailable module cannot stall the UI.
function App.LoadModules()
    local paths = {
        interface = {"client", "legacy", "main_handler_interface"},
        inventory = {"client", "legacy", "inventory"},
        interactions = {"client", "client_interactables"},
        world = {"shared", "world"}, cts = {"shared", "ecs", "shared_cts"},
        store = {"client", "ui", "store"},
    }
    for key, path in pairs(paths) do
        if not App.modules[key] and App.moduleStatus[key] ~= "loading" then
            local module = App.Path(Services.Replicated, table.unpack(path))
            if module and module:IsA("ModuleScript") then
                App.moduleStatus[key] = "loading"
                task.spawn(function()
                    local ok, value = pcall(require, module)
                    if not App.alive then return end
                    if ok and type(value) == "table" then
                        local needed = {interface = "active", inventory = "get", interactions = "start_interaction", world = "get", cts = "NetworkedInteractable", store = "stamina"}
                        local readable, member = pcall(function() return value[needed[key]] end)
                        if not readable or member == nil then ok = false; value = "Module export is incomplete or inaccessible." end
                    end
                    if ok and type(value) == "table" then
                        App.modules[key] = value; App.moduleStatus[key] = "ready"
                    else App.moduleStatus[key] = "unavailable"; App.Note(key .. " require failed: " .. tostring(value)) end
                end)
            else App.moduleStatus[key] = "not replicated" end
        end
    end
end

-- Existence-based trait markers, following the mechanism in Teddy's V0.1.
-- Native markers are never deleted. Only exact instances made here are removed.
function App.RemoveTraitMarkers(folder)
    local owned = App.traitOwned[folder]
    if owned then
        for key, instance in pairs(owned) do
            if instance.Parent == folder then instance:Destroy() end
            owned[key] = nil
        end
        App.traitOwned[folder] = nil
    end
end
function App.ApplyTraits()
    if not App.alive then return end
    local character = App.Character()
    for folder in pairs(App.traitOwned) do
        if not folder.Parent or folder.Parent ~= character then App.RemoveTraitMarkers(folder) end
    end
    if not character then return end
    local folder = character:FindFirstChild("perks")
    if not folder and App.cfg.traitsEnabled then
        folder = Instance.new("Folder"); folder.Name = "perks"
        folder:SetAttribute("DWFieldKitOwned", true)
        App.traitFolders[folder] = true
        folder.Parent = character
    end
    if not folder then return end
    local owned = App.traitOwned[folder] or {}
    App.traitOwned[folder] = owned
    for key in pairs(Catalog.traits) do
        local instance = owned[key]
        if instance and instance.Parent ~= folder then owned[key] = nil; instance = nil end
        local wanted = App.cfg.traitsEnabled and App.traits[key] == true
        if not wanted and instance then instance:Destroy(); owned[key] = nil
        elseif wanted and not folder:FindFirstChild("trait:" .. key) then
            instance = Instance.new("BoolValue")
            instance.Name = "trait:" .. key
            instance.Value = false -- Original client checks marker existence, not Value.
            instance:SetAttribute("DWFieldKitOwned", true)
            owned[key] = instance
            instance.Parent = folder
        end
    end
    if not App.cfg.traitsEnabled and App.traitFolders[folder] and #folder:GetChildren() == 0 then
        App.traitOwned[folder] = nil; App.traitFolders[folder] = nil; folder:Destroy()
    end
end
function App.TraitSummary()
    local character = App.Character()
    local folder = character and character:FindFirstChild("perks")
    local native, added, selected = 0, 0, 0
    for key, state in pairs(App.traits) do
        if state then selected = selected + 1 end
        local instance = folder and folder:FindFirstChild("trait:" .. key)
        if instance then
            if App.traitOwned[folder] and App.traitOwned[folder][key] == instance then added = added + 1
            else native = native + 1 end
        end
    end
    return string.format("Selected %d | native markers %d | added locally %d\n%s", selected, native, added,
        character and "Markers observed locally; server effects are not confirmed." or "Waiting for your character. Selections are retained.")
end
function App.WatchCharacter(character)
    App.Disconnect(App.traitConnections)
    if App.RestoreProperty then
        for _, property in ipairs({"CanCollide", "WalkSpeed", "JumpPower", "JumpHeight", "AutoRotate", "PlatformStand"}) do App.RestoreProperty(property) end
    end
    App.collisionCharacter = nil
    App.ApplyTraits()
    if not character then return end
    App.Connect(character.ChildAdded, function(child)
        if child.Name == "perks" then task.defer(App.ApplyTraits) end
    end, App.traitConnections)
    local folder = character:FindFirstChild("perks")
    if folder then
        App.Connect(folder.ChildAdded, function() App.traitTime = 1 end, App.traitConnections)
        App.Connect(folder.ChildRemoved, function() App.traitTime = 1 end, App.traitConnections)
    end
end

function App.ItemCategory(id)
    local item = Catalog.items[id]
    if not item then return "Items" end
    if item.chargerating == "blueprint" then return "Blueprints" end
    if item.weapontype ~= "Item" then return "Weapons" end
    local name = string.lower(item.name or id)
    if name:find("bandage", 1, true) or name:find("aid", 1, true) or name:find("splint", 1, true)
        or name:find("tourni", 1, true) or name:find("stim", 1, true) or name:find("tablet", 1, true)
        or name:find("antibiot", 1, true) or name:find("augmentin", 1, true) or name:find("amoxicillin", 1, true)
        or name:find("painkiller", 1, true) then return "Medical" end
    return "Items"
end
function App.Metadata(entry)
    local object, root = entry.object, entry.root
    local name, category = object.Name, entry.fallback
    local entity = App.Entity(object)
    local item = App.Component(entity, "Item")
    local mob = App.Component(entity, "NetworkedMob")
    local networkedObject = App.Component(entity, "NetworkedObject")
    local interact = App.Component(entity, "NetworkedInteractable")
    local display = App.Component(entity, "DisplayName")
    if type(display) == "string" then name = display end
    if type(display) == "table" and type(display.display_name) == "string" then name = display.display_name end
    if type(item) == "table" and type(item.identifier) == "string" then
        local id = item.identifier:gsub("^item:", "")
        name = Catalog.items[id] and Catalog.items[id].name or id
        category = App.ItemCategory(id); entry.itemId = id
    elseif Catalog.items[object.Name] then
        entry.itemId = object.Name; name = Catalog.items[object.Name].name
        category = App.ItemCategory(object.Name)
    elseif type(mob) == "table" then
        local id = mob.mob_kind
        if type(id) == "string" then
            id = id:gsub("^mob:", ""); entry.mobId = id
            if name == object.Name then name = id end
            local stats = Catalog.enemies[id] and Catalog.enemies[id].stats
            if stats and stats.friendly == true then category = "Friendlies"
            elseif id:lower():find("boss", 1, true) then category = "Bosses"
            elseif stats then category = "Hostiles" end
        end
    end
    if category == "NPCs" then category = "Unclassified NPCs" end
    if type(networkedObject) == "table" and type(networkedObject.object_id) == "string" and name == object.Name then name = networkedObject.object_id end
    local interactCategories = {workbench = "Workbenches", scrapper = "Scrappers", locker = "Lockers", double_locker = "Lockers", med_cabinet = "Medical cabinets", crate = "Crates", item_fabricator = "Objectives"}
    if type(interact) == "table" and type(interact.interact_id) == "string" then
        local kind = interact.interact_id:gsub("^interactable:", "")
        if interactCategories[kind] then category = interactCategories[kind]; if name == object.Name then name = category end end
    end
    if category == "Objects" then
        if App.Component(entity, "Ammo") or App.Component(entity, "AmmoCache") then category = "Ammo"
        elseif App.Component(entity, "Ration") then category = "Rations"
        elseif App.Component(entity, "ScrapPack") then category = "Scrap"
        elseif type(interact) == "table" then category = "Objectives"
        else category = "Items" end
    end
    local low = object.Name:lower()
    if root.Name == "Interactables" or root.Name == "InteractablesNoDel" or category == "Objects" then
        if low:find("workbench", 1, true) then category = "Workbenches"
        elseif low:find("scrapper", 1, true) then category = "Scrappers"
        elseif low:find("medical cabinet", 1, true) then category = "Medical cabinets"
        elseif low:find("locker", 1, true) then category = "Lockers"
        elseif low:find("crate", 1, true) then category = "Crates"
        elseif low:find("ammo", 1, true) then category = "Ammo"
        elseif low == "beans" or low == "mre" or low == "soda" or low == "bottle" then category = "Rations"
        elseif low:find("scrap", 1, true) then category = "Scrap" end
    end
    entry.entity, entry.interact = entity, interact
    entry.name, entry.category = name, category
    return entry
end
function App.Register(object, root, fallback)
    if not App.alive then return end
    if object == App.Character() or (not object:IsA("Model") and not object:IsA("BasePart")) then return end
    if App.entries[object] then return end
    App.entries[object] = {object = object, root = root, fallback = fallback, category = fallback, name = object.Name, updated = -100}
end
function App.RemoveVisual(object)
    local v = App.visuals[object]
    if v then
        if v.billboard then v.billboard:Destroy() end
        if v.highlight then v.highlight:Destroy() end
        App.visuals[object] = nil
    end
end
function App.TrackRoot(root, fallback)
    if not App.alive then return end
    if App.roots[root] then return end
    local bag = {}; App.roots[root] = bag
    for _, object in ipairs(root:GetChildren()) do
        if object:IsA("Folder") and object.Name == "HarvestPiles" then App.TrackRoot(object, "Harvest")
        else App.Register(object, root, fallback) end
    end
    App.Connect(root.ChildAdded, function(object)
        if object:IsA("Folder") and object.Name == "HarvestPiles" then App.TrackRoot(object, "Harvest")
        else App.Register(object, root, fallback) end
    end, bag)
    App.Connect(root.ChildRemoved, function(object)
        App.entries[object] = nil; App.autoPause[object] = nil; App.RemoveVisual(object)
        if App.roots[object] then App.Disconnect(App.roots[object]); App.roots[object] = nil end
    end, bag)
end
function App.ScanRoots()
    if not App.alive then return end
    local known = {
        WeaponDrops = "Items", Interactables = "Objectives", InteractablesNoDel = "Objectives",
        objects = "Objects", activeHostiles = "Hostiles", activeFriendlies = "Friendlies",
        activePlayers = "Players", mobs = "NPCs",
    }
    for name, category in pairs(known) do
        local root = Services.World:FindFirstChild(name)
        if root then App.TrackRoot(root, category) end
    end
    for root, bag in pairs(App.roots) do
        if not root.Parent then App.Disconnect(bag); App.roots[root] = nil end
    end
end
function App.AliveEntry(entry)
    local hum = entry.object:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    local world, cts = App.modules.world, App.modules.cts
    if world and cts and cts.NetworkedDead and entry.entity then
        local ok, dead = pcall(function() return world:has(entry.entity, cts.NetworkedDead) end)
        if ok and dead then return false end
    end
    return true
end
function App.HasLOS(part)
    local camera = Services.World.CurrentCamera
    if not camera then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excludes = {camera}
    local character = App.Character()
    if character then excludes[#excludes + 1] = character end
    local cosmetic = Services.World:FindFirstChild("fx")
    if cosmetic then excludes[#excludes + 1] = cosmetic end
    params.FilterDescendantsInstances = excludes
    params.IgnoreWater = true
    local result = Services.World:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
    local model = part:FindFirstAncestorOfClass("Model")
    return not result or result.Instance == part or (model and result.Instance:IsDescendantOf(model)) == true
end
function App.Visual(entry, part)
    local v = App.visuals[entry.object]
    if v then return v end
    local bb = Instance.new("BillboardGui")
    bb.Name = "DWLabel"; bb.Size = UDim2.fromOffset(260, 54)
    bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.Adornee = part; bb.Enabled = false
    bb.Parent = App.overlay
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1); text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamMedium; text.TextStrokeTransparency = 0.25
    text.TextWrapped = true; text.RichText = false; text.Parent = bb
    v = {billboard = bb, text = text}; App.visuals[entry.object] = v
    return v
end
function App.UpdateESP()
    local camera = Services.World.CurrentCamera
    if not camera then return end
    local origin = App.Root()
    origin = origin and origin.Position or camera.CFrame.Position
    local candidates, filter = {}, App.cfg.filter:lower()
    for object, entry in pairs(App.entries) do
        if not object.Parent or not object:IsDescendantOf(Services.World) then
            App.entries[object] = nil; App.autoPause[object] = nil; App.RemoveVisual(object)
        elseif object ~= App.Character() then
            if App.tick - entry.updated > 1 then App.Metadata(entry); entry.updated = App.tick end
            local part = App.Part(object)
            if part then
                local distance = (part.Position - origin).Magnitude
                local tracked = App.waypoint == object
                if ((App.cfg.espEnabled and App.categories[entry.category]) or tracked)
                    and distance <= App.cfg.espDistance and App.AliveEntry(entry)
                    and (filter == "" or entry.name:lower():find(filter, 1, true) or entry.category:lower():find(filter, 1, true) or tracked) then
                    candidates[#candidates + 1] = {entry = entry, part = part, distance = distance, tracked = tracked}
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.tracked ~= b.tracked then return a.tracked end
        return a.distance < b.distance
    end)
    local shown, high = {}, 0
    for index, item in ipairs(candidates) do
        if index > App.cfg.maxLabels then break end
        local entry, part = item.entry, item.part
        local visible = App.cfg.throughWalls or App.HasLOS(part)
        if visible then
            local v = App.Visual(entry, part); shown[entry.object] = true
            local color = Colors[entry.category] or Colors.Items
            v.billboard.Adornee = part; v.billboard.AlwaysOnTop = App.cfg.throughWalls
            v.billboard.MaxDistance = App.cfg.espDistance; v.billboard.Enabled = App.cfg.labels or item.tracked
            v.text.TextSize = App.cfg.textSize; v.text.TextColor3 = color
            local health = ""
            local hum = entry.object:FindFirstChildOfClass("Humanoid")
            if App.cfg.espHealth and hum then health = string.format(" | HP %.0f", hum.Health) end
            v.text.Text = (item.tracked and "[WAYPOINT] " or "") .. entry.name .. health .. string.format("\n%s | %.0f studs", entry.category, item.distance)
            if App.cfg.highlights and high < App.cfg.maxHighlights then
                high = high + 1
                if not v.highlight then
                    local hl = Instance.new("Highlight"); hl.Name = "DWHighlight"
                    hl.Adornee = entry.object; hl.FillTransparency = 0.82
                    hl.OutlineTransparency = 0; hl.Parent = App.overlay; v.highlight = hl
                end
                v.highlight.Enabled = true; v.highlight.FillColor = color; v.highlight.OutlineColor = color
                v.highlight.DepthMode = App.cfg.throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
            elseif v.highlight then v.highlight:Destroy(); v.highlight = nil end
        end
    end
    -- Destroy unused Highlights to release Roblox's limited Highlight slots.
    for object in pairs(App.visuals) do if not shown[object] then App.RemoveVisual(object) end end
end
function App.Nearest(categories, maxDistance, skipCooldown)
    local root = App.Root()
    if not root then return nil end
    local nearest, best = nil, maxDistance or math.huge
    for _, entry in pairs(App.entries) do
        if entry.object.Parent then
            App.Metadata(entry)
            local part = App.Part(entry.object)
            if part and categories[entry.category] and (not skipCooldown or (App.autoPause[entry.object] or -100) <= App.tick) then
                local distance = (part.Position - root.Position).Magnitude
                if distance < best then nearest, best = entry, distance end
            end
        end
    end
    return nearest, best
end
function App.Waypoint(category)
    local entry, distance = App.Nearest({[category] = true})
    if not entry then App.Notify("Waypoint", "No streamed " .. category:lower() .. " found."); return end
    App.waypoint = entry.object
    App.Notify("Waypoint", string.format("%s | %.0f studs", entry.name, distance))
    App.UpdateESP()
end

-- Normal interactions: no guessed remote argument lists or out-of-range calls.
function App.CancelInteraction()
    local action = App.activeInteraction
    App.activeInteraction = nil; if action then App.actionBusy = false end
    if action and action.started and type(action.api.cancel_interaction) == "function" then
        pcall(action.api.cancel_interaction, action.entity)
    end
end
function App.Interact(entry)
    if App.actionBusy or not App.Active() then return false, "Spawn and wait for the game controller." end
    if not entry or not entry.object.Parent then return false, "No eligible nearby pickup." end
    App.Metadata(entry)
    local root, part = App.Root(), App.Part(entry.object)
    if not root or not part or (part.Position - root.Position).Magnitude > App.cfg.pickupDistance then return false, "Move closer first." end
    if not App.pickupCategories[entry.category] then return false, "That pickup category is disabled." end
    local api = App.modules.interactions
    local entity = App.Entity(entry.object)
    if not api or not entity or type(api.start_interaction) ~= "function" or type(api.finish_interaction) ~= "function" then
        return false, "The native interaction API or entity marker is unavailable. Press E normally."
    end
    local implementation = App.Call(api, "get_interaction_implementation_from_entity", entity)
    if not implementation then return false, "This object has no current native interaction." end
    local component = entry.interact
    local interactId = type(component) == "table" and component.interact_id
    if type(component) == "table" and component.active == false then return false, "This pickup is no longer active." end
    -- Restrict to loose pickups; never open a lab/ending or spend salvage in an auto loop.
    if interactId and interactId ~= "interactable:pickup" and interactId ~= "pickup" then
        return false, "Automatic collection is limited to loose pickups. Use E for containers."
    end
    if not interactId then return false, "Pickup type could not be verified; use E normally." end
    local native = Catalog.interactables[interactId:gsub("^interactable:", "")] or {}
    local duration = math.max(tonumber(component.interact_duration) or tonumber(native.interact_duration) or 1, 0.15)
    App.actionBusy = true; App.actionTime = App.tick
    local action = {api = api, entity = entity, started = false}
    App.activeInteraction = action
    task.spawn(function()
        local started, reason = pcall(api.start_interaction, entity)
        if started then
            action.started = true
            task.wait(duration + 0.1)
            local currentRoot = App.Root()
            if App.alive and App.activeInteraction == action and entry.object.Parent and currentRoot and part.Parent
                and (part.Position - currentRoot.Position).Magnitude <= App.cfg.pickupDistance and App.Active() then
                local ok, err = pcall(api.finish_interaction, entity)
                if not ok then App.Note("Pickup finish failed: " .. tostring(err)) end
            elseif App.activeInteraction == action and type(api.cancel_interaction) == "function" then pcall(api.cancel_interaction, entity) end
        else App.Note("Pickup start failed: " .. tostring(reason)) end
        if App.activeInteraction == action then App.activeInteraction = nil; if action then App.actionBusy = false end end
    end)
    return true, "Normal pickup requested; server acceptance remains authoritative."
end
function App.AutoPickup()
    if not App.cfg.autoPickup or App.actionBusy or App.tick - App.actionTime < App.cfg.pickupInterval then return end
    if not App.Active() or Services.Input:GetFocusedTextBox() then return end
    local progress = App.Store("interaction_progress")
    if type(progress) == "number" and progress > 0 then return end
    local entry = App.Nearest(App.pickupCategories, App.cfg.pickupDistance, true)
    if not entry then return end
    if (App.autoPause[entry.object] or -100) > App.tick then return end
    local ok = App.Interact(entry)
    App.autoPause[entry.object] = App.tick + (ok and 8 or 15)
end
function App.InventoryAction(method, ...)
    local inventory = App.GetInventory()
    if not inventory or type(inventory[method]) ~= "function" then App.Notify("Inventory", "Native inventory unavailable. Spawn first or retry modules."); return false end
    if App.actionBusy or App.tick - App.actionTime < 1 then return false end
    App.actionTime = App.tick
    local ok, err = pcall(inventory[method], ...)
    if not ok then App.Note(method .. ": " .. tostring(err)); App.Notify("Action failed", err) end
    return ok
end
function App.WorkbenchAction(placeBlueprint)
    if App.actionBusy or not App.Active() then App.Notify("Workbench", "Spawn and wait for the controller first."); return end
    local entry = App.Nearest({Workbenches = true}, 10)
    if not entry then App.Notify("Workbench", "Stand within 10 studs of a streamed workbench."); return end
    local inventory = App.GetInventory()
    local current = inventory and App.Call(inventory, "get_current")
    if placeBlueprint then
        local id = type(current) == "table" and type(current.state) == "table" and current.state.identifier
        if not id or not Catalog.items[id] or Catalog.items[id].chargerating ~= "blueprint" then App.Notify("Workbench", "Equip a blueprint first."); return end
        if App.InventoryAction("place_blueprint_on_workbench", entry.object) then App.Notify("Workbench", "Blueprint placement requested through the native client.") end
    else
        if App.InventoryAction("craft_workbench_item", entry.object) then App.Notify("Workbench", "Craft requested. The normal blueprint and salvage costs apply.") end
    end
end

-- Property changes are tracked and restored only when their last written value
-- still matches, so unrelated game changes are not overwritten on unload.
App.patches = {}
function App.Patch(object, property, value)
    if not object then return end
    local record = App.patches[object]
    if not record then record = {}; App.patches[object] = record end
    local saved = record[property]
    local current = object[property]
    if not saved then saved = {original = current}; record[property] = saved
    elseif saved.last ~= nil and current ~= saved.last then saved.original = current end
    object[property] = value; saved.last = value
end
function App.Restore(object, property)
    local record = App.patches[object]
    local saved = record and record[property]
    if not saved then return end
    pcall(function() if object[property] == saved.last then object[property] = saved.original end end)
    record[property] = nil
    if not next(record) then App.patches[object] = nil end
end
function App.RestoreProperty(property)
    local objects = {}
    for object, record in pairs(App.patches) do if record[property] then objects[#objects + 1] = object end end
    for _, object in ipairs(objects) do App.Restore(object, property) end
end
function App.UpdateWorld()
    local lighting = Services.Lighting
    if App.cfg.fullbright then
        App.Patch(lighting, "Brightness", 2)
        App.Patch(lighting, "Ambient", Color3.fromRGB(180, 180, 180))
        App.Patch(lighting, "OutdoorAmbient", Color3.fromRGB(180, 180, 180))
    else
        for _, property in ipairs({"Brightness", "Ambient", "OutdoorAmbient"}) do App.Restore(lighting, property) end
    end
    if App.cfg.noShadows then App.Patch(lighting, "GlobalShadows", false) else App.Restore(lighting, "GlobalShadows") end
    if App.cfg.noFog then
        App.Patch(lighting, "FogEnd", 100000); App.Patch(lighting, "FogStart", 99999)
    else App.Restore(lighting, "FogStart"); App.Restore(lighting, "FogEnd") end
    for _, object in ipairs(lighting:GetChildren()) do
        if object:IsA("Atmosphere") then
            if App.cfg.noFog then App.Patch(object, "Density", 0); App.Patch(object, "Haze", 0)
            else App.Restore(object, "Density"); App.Restore(object, "Haze") end
        elseif object:IsA("PostEffect") then
            if App.cfg.noPostEffects then App.Patch(object, "Enabled", false) else App.Restore(object, "Enabled") end
        end
    end
    local camera = Services.World.CurrentCamera
    if camera then
        if App.cfg.fovEnabled then App.Patch(camera, "FieldOfView", App.cfg.fov) else App.RestoreProperty("FieldOfView") end
        for _, object in ipairs(camera:GetChildren()) do
            if object:IsA("PostEffect") then
                if App.cfg.noPostEffects then App.Patch(object, "Enabled", false) else App.Restore(object, "Enabled") end
            end
        end
    end
end
function App.UpdateMovement(delta)
    local hum, root = App.Humanoid(), App.Root()
    if not hum or hum.Health <= 0 then
        for _, property in ipairs({"CanCollide", "WalkSpeed", "JumpPower", "JumpHeight", "AutoRotate", "PlatformStand"}) do App.RestoreProperty(property) end
        App.collisionCharacter = nil; App.flyRoot = nil
        return
    end
    if App.cfg.speedEnabled then App.Patch(hum, "WalkSpeed", App.cfg.walkSpeed) else App.Restore(hum, "WalkSpeed") end
    if App.cfg.jumpEnabled then
        if hum.UseJumpPower then App.Patch(hum, "JumpPower", App.cfg.jumpPower); App.Restore(hum, "JumpHeight")
        else
            App.Patch(hum, "JumpHeight", App.cfg.jumpPower * App.cfg.jumpPower / (2 * math.max(Services.World.Gravity, 1)))
            App.Restore(hum, "JumpPower")
        end
    else App.Restore(hum, "JumpPower"); App.Restore(hum, "JumpHeight") end
    local character = App.Character()
    if App.cfg.noclip then
        if character ~= App.collisionCharacter or App.tick - (App.collisionRefreshTime or -100) > 1 then
            if character ~= App.collisionCharacter then App.RestoreProperty("CanCollide") end
            App.collisionParts = {}; App.collisionCharacter = character; App.collisionRefreshTime = App.tick
            if character then
                for _, part in ipairs(character:GetDescendants()) do if part:IsA("BasePart") then App.collisionParts[#App.collisionParts + 1] = part end end
            end
        end
        for _, part in ipairs(App.collisionParts or {}) do if part.Parent then App.Patch(part, "CanCollide", false) end end
    else App.RestoreProperty("CanCollide"); App.collisionCharacter = nil end
    if App.cfg.fly and root and Services.World.CurrentCamera then
        App.Patch(hum, "AutoRotate", false); App.Patch(hum, "PlatformStand", true)
        local camera, direction = Services.World.CurrentCamera, Vector3.zero
        if not Services.Input:GetFocusedTextBox() then
            local function held(key) return Services.Input:IsKeyDown(key) end
            if held(Enum.KeyCode.W) then direction = direction + camera.CFrame.LookVector end
            if held(Enum.KeyCode.S) then direction = direction - camera.CFrame.LookVector end
            if held(Enum.KeyCode.D) then direction = direction + camera.CFrame.RightVector end
            if held(Enum.KeyCode.A) then direction = direction - camera.CFrame.RightVector end
            if held(Enum.KeyCode.Space) then direction = direction + Vector3.yAxis end
            if held(Enum.KeyCode.LeftControl) then direction = direction - Vector3.yAxis end
        end
        if direction.Magnitude > 1 then direction = direction.Unit end
        root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = root.CFrame + direction * App.cfg.flySpeed * math.min(delta, 0.05)
        App.flyRoot = root
    else
        App.RestoreProperty("AutoRotate"); App.RestoreProperty("PlatformStand")
        if App.flyRoot and App.flyRoot.Parent then App.flyRoot.AssemblyLinearVelocity = Vector3.zero end
        App.flyRoot = nil
    end
end
function App.UpdateAim(delta)
    local camera = Services.World.CurrentCamera
    if not camera then return end
    local cursor = Services.Input:GetMouseLocation()
    if App.ring then
        App.ring.Visible = App.cfg.aimEnabled and App.cfg.aimRing
        App.ring.Size = UDim2.fromOffset(App.cfg.aimRadius * 2, App.cfg.aimRadius * 2)
        App.ring.Position = UDim2.fromOffset(cursor.X, cursor.Y)
    end
    if not App.cfg.aimEnabled or not App.Root() or Services.Input:GetFocusedTextBox()
        or not Services.Input:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local best, score = nil, App.cfg.aimRadius
    for _, entry in pairs(App.entries) do
        if entry.object.Parent and (entry.category == "Hostiles" or entry.category == "Bosses") and App.AliveEntry(entry) then
            local target = entry.object:FindFirstChild(App.cfg.aimPart) or App.Part(entry.object)
            if target and target:IsA("BasePart") and (target.Position - camera.CFrame.Position).Magnitude <= App.cfg.aimDistance then
                local projected, visible = camera:WorldToViewportPoint(target.Position)
                if visible and projected.Z > 0 then
                    -- The overlay ignores inset; use WorldToScreenPoint for matching Input coordinates.
                    local screen = camera:WorldToScreenPoint(target.Position)
                    local offset = (Vector2.new(screen.X, screen.Y) - cursor).Magnitude
                    if offset < score and (not App.cfg.aimWallCheck or App.HasLOS(target)) then best, score = target, offset end
                end
            end
        end
    end
    if best then
        local target = CFrame.lookAt(camera.CFrame.Position, best.Position)
        local smooth = math.max(App.cfg.aimSmooth, 0.01)
        camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-delta / smooth))
    end
end

function App.Set(key, value, updateControl)
    if Defaults[key] == nil or type(value) ~= type(Defaults[key]) then return false end
    local limits = {
        espDistance = {50, 5000}, maxLabels = {5, 120}, maxHighlights = {0, 28}, textSize = {10, 20},
        espInterval = {0.1, 1}, aimRadius = {30, 400}, aimDistance = {25, 1500}, aimSmooth = {0.02, 0.6},
        pickupDistance = {3, 10}, pickupInterval = {1, 5}, walkSpeed = {8, 40}, jumpPower = {25, 85}, flySpeed = {10, 80}, fov = {60, 110},
    }
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return false end
        if limits[key] then value = math.clamp(value, limits[key][1], limits[key][2]) end
    elseif key == "filter" then value = value:sub(1, 80)
    elseif key == "aimPart" and value ~= "Head" and value ~= "Torso" and value ~= "HumanoidRootPart" then return false
    elseif key == "theme" then
        local allowed = {Default = true, AmberGlow = true, Amethyst = true, Bloom = true, DarkBlue = true, Green = true, Light = true, Ocean = true, Serenity = true}
        if not allowed[value] then return false end
    end
    App.cfg[key] = value
    if key == "autoPickup" and not value then App.CancelInteraction() end
    if key == "traitsEnabled" then App.ApplyTraits() end
    if key == "leaderboard" then
        local ok = pcall(function() Services.Starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, value) end)
        if ok then App.lastLeaderboard = value end
    end
    if key == "theme" and App.window then pcall(function() App.window.ModifyTheme(value) end) end
    if updateControl and App.controls[key] then
        local v = value
        if key == "aimPart" or key == "theme" then v = {value} end
        pcall(function() App.controls[key]:Set(v) end)
    end
    return true
end
function App.SetTrait(key, enabled, updateControl)
    if not Catalog.traits[key] or type(enabled) ~= "boolean" then return end
    App.traits[key] = enabled
    if updateControl and App.controls["trait_" .. key] then pcall(function() App.controls["trait_" .. key]:Set(enabled) end) end
    App.ApplyTraits()
end
function App.ApplyPreset(name)
    local preset = TraitPresets[name]
    if not preset then return end
    local chosen = {}
    for _, key in ipairs(preset) do chosen[key] = true end
    for key in pairs(App.traits) do App.SetTrait(key, chosen[key] == true, true) end
    App.Notify("Traits", name .. " selected. Use the trait master switch to apply markers.")
end
function App.Profile()
    return {version = 1, settings = App.cfg, traits = App.traits, categories = App.categories, pickupCategories = App.pickupCategories}
end
function App.Save()
    local ok, encoded = pcall(function() return Services.Http:JSONEncode(App.Profile()) end)
    if not ok then App.Notify("Save", encoded); return end
    local saved = false
    if type(writefile) == "function" then saved = pcall(writefile, "LuckyBlessing_Repaired.json", encoded) end
    local tp = pcall(function() Services.Teleport:SetTeleportSetting("LuckyBlessing_Repaired", encoded) end)
    App.Notify("Profile", saved and "Saved LuckyBlessing_Repaired.json" or (tp and "Saved in teleport settings for this client." or "No profile persistence API available."))
end
function App.Load()
    local raw
    if type(readfile) == "function" then local ok, value = pcall(readfile, "LuckyBlessing_Repaired.json"); if ok then raw = value end end
    if not raw then pcall(function() raw = Services.Teleport:GetTeleportSetting("LuckyBlessing_Repaired") end) end
    if type(raw) ~= "string" or #raw > 100000 then App.Notify("Profile", "No valid saved profile found."); return end
    local ok, data = pcall(function() return Services.Http:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" or data.version ~= 1 then App.Notify("Profile", "Unsupported or invalid profile."); return end
    -- Apply validated keys only; the file cannot replace functions or module paths.
    if type(data.settings) == "table" then for key, value in pairs(data.settings) do App.Set(key, value, true) end end
    if type(data.traits) == "table" then for key, value in pairs(data.traits) do App.SetTrait(key, value, true) end end
    for _, field in ipairs({"categories", "pickupCategories"}) do
        if type(data[field]) == "table" then
            for key, value in pairs(data[field]) do if App[field][key] ~= nil and type(value) == "boolean" then App[field][key] = value end end
        end
    end
    App.SyncCategoryControls()
    if App.AfterLoad then App.AfterLoad(data) end
    App.Notify("Profile", "Loaded. Movement and collection use your saved selections.")
end
function App.Panic()
    App.CancelInteraction()
    for _, key in ipairs({"traitsEnabled", "espEnabled", "aimEnabled", "autoPickup", "speedEnabled", "jumpEnabled", "infiniteJump", "noclip", "fly", "fullbright", "noFog", "noPostEffects", "noShadows", "fovEnabled"}) do App.Set(key, false, true) end
    App.waypoint = nil
    App.UpdateWorld(); App.UpdateMovement(0); App.UpdateESP()
    App.Notify("Field Kit paused", "Feature switches disabled and owned local changes restored.")
end
function App.Diagnostics()
    local report = {
        build = App.build, placeId = game.PlaceId, gameId = game.GameId,
        character = App.Character() ~= nil, controllerActive = App.Active(),
        modules = App.moduleStatus, trackedObjects = App.Count(App.entries),
        renderedObjects = App.Count(App.visuals), traits = App.TraitSummary(),
        selectedTraits = App.traits, logs = App.log,
        catalogCounts = App.CatalogCounts(), catalogSources = App.CatalogDiagnostics(),
    }
    local encoded = Services.Http:JSONEncode(report)
    if type(setclipboard) == "function" then local ok = pcall(setclipboard, encoded); if ok then App.Notify("Diagnostics", "Copied to clipboard."); return end end
    if type(toclipboard) == "function" then local ok = pcall(toclipboard, encoded); if ok then App.Notify("Diagnostics", "Copied to clipboard."); return end end
    if type(writefile) == "function" then local ok = pcall(writefile, "DW_FieldKit_Diagnostics.json", encoded); if ok then App.Notify("Diagnostics", "Saved DW_FieldKit_Diagnostics.json"); return end end
    print(encoded); App.Notify("Diagnostics", "Printed to the client console.")
end
function App.Unload()
    if not App.alive then return end
    App.CancelInteraction()
    App.alive = false
    App.Disconnect(App.connections); App.Disconnect(App.traitConnections)
    for _, bag in pairs(App.roots) do App.Disconnect(bag) end
    for folder in pairs(App.traitOwned) do pcall(App.RemoveTraitMarkers, folder) end
    for folder in pairs(App.traitFolders) do pcall(function() if folder.Parent and #folder:GetChildren() == 0 then folder:Destroy() end end) end
    local objects = {}
    for object in pairs(App.patches) do objects[#objects + 1] = object end
    for _, object in ipairs(objects) do
        local keys = {}
        for property in pairs(App.patches[object] or {}) do keys[#keys + 1] = property end
        for _, property in ipairs(keys) do App.Restore(object, property) end
    end
    if App.originalLeaderboard ~= nil and App.lastLeaderboard ~= nil then
        pcall(function()
            if Services.Starter:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) == App.lastLeaderboard then
                Services.Starter:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, App.originalLeaderboard)
            end
        end)
    end
    if App.overlay then App.overlay:Destroy() end
    if App.rayfield then pcall(function() App.rayfield:Destroy() end) end
    if Environment.DW_RayfieldFieldKit == App then Environment.DW_RayfieldFieldKit = nil end
    table.clear(App.entries); table.clear(App.visuals); table.clear(App.modules)
end

function App.MakeOverlay()
    local playerGui = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui", 10)
    assert(playerGui, "PlayerGui unavailable; wait for the client to load.")
    local gui = Instance.new("ScreenGui")
    gui.Name = "DWFieldKitOverlay"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
    gui.DisplayOrder = 9100; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = playerGui
    App.overlay = gui
    local open = Instance.new("TextButton")
    open.Name = "Reopen"; open.Size = UDim2.fromOffset(54, 34)
    open.Position = UDim2.new(1, -68, 0, 12); open.Text = "DW ]"
    open.Font = Enum.Font.GothamBold; open.TextSize = 14
    open.TextColor3 = Color3.fromRGB(220, 255, 235); open.BackgroundColor3 = Color3.fromRGB(23, 40, 34)
    open.Parent = gui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 7); corner.Parent = open
    App.Connect(open.Activated, function()
        if App.rayfield and type(App.rayfield.SetVisibility) == "function" then App.rayfield:SetVisibility(true) end
    end)
    local hud = Instance.new("TextLabel")
    hud.Name = "Status"; hud.Size = UDim2.fromOffset(345, 80)
    hud.Position = UDim2.new(0, 14, 1, -100); hud.BackgroundColor3 = Color3.fromRGB(15, 22, 20)
    hud.BackgroundTransparency = 0.18; hud.TextColor3 = Color3.fromRGB(225, 240, 230)
    hud.TextXAlignment = Enum.TextXAlignment.Left; hud.TextYAlignment = Enum.TextYAlignment.Top
    hud.Font = Enum.Font.Code; hud.TextSize = 13; hud.TextWrapped = true; hud.RichText = false
    hud.Parent = gui
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingTop = UDim.new(0, 7); pad.Parent = hud
    App.hud = hud
    local ring = Instance.new("Frame"); ring.Name = "AimRadius"; ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.BackgroundTransparency = 1; ring.Visible = false; ring.Parent = gui
    local circle = Instance.new("UICorner"); circle.CornerRadius = UDim.new(1, 0); circle.Parent = ring
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(190, 230, 215); stroke.Transparency = 0.3; stroke.Thickness = 1; stroke.Parent = ring
    App.ring = ring
end

function App.Toggle(tab, name, key)
    local control = tab:CreateToggle({Name = name, CurrentValue = App.cfg[key], Flag = "DWFK_" .. key, Callback = function(value) App.Set(key, value) end})
    App.controls[key] = control; return control
end
function App.Slider(tab, name, key, range, step, suffix)
    local control = tab:CreateSlider({Name = name, Range = range, Increment = step or 1, Suffix = suffix or "", CurrentValue = App.cfg[key], Flag = "DWFK_" .. key, Callback = function(value) App.Set(key, value) end})
    App.controls[key] = control; return control
end
function App.Button(tab, name, callback)
    return tab:CreateButton({Name = name, Callback = function()
        if not App.alive then return end
        local ok, err = pcall(callback)
        if not ok then App.Note(err); App.Notify("Action failed", err) end
    end})
end
function App.Paragraph(tab, title, text)
    return tab:CreateParagraph({Title = title, Content = text})
end
function App.SyncCategoryControls()
    local esp, pickup = {}, {}
    for _, name in ipairs(Categories) do if App.categories[name] then esp[#esp + 1] = name end end
    for name, value in pairs(App.pickupCategories) do if value then pickup[#pickup + 1] = name end end
    if App.controls.categories then App.controls.categories:Set(esp) end
    if App.controls.pickupCategories then App.controls.pickupCategories:Set(pickup) end
end
function App.UpdateStatus()
    local hum, inventory = App.Humanoid(), App.GetInventory()
    local health = hum and string.format("%.0f/%.0f", hum.Health, hum.MaxHealth) or "--"
    local stamina, hunger, thirst = App.Store("stamina"), App.Store("hunger"), App.Store("thirst")
    local night, storm = App.Store("night"), App.Store("storm_in")
    local scrap = inventory and App.Call(inventory, "get_scrap")
    local function num(value) return type(value) == "number" and string.format("%.0f", value) or "--" end
    local text = string.format("HP %s | Stamina %s | Scrap %s\nHunger %s | Thirst %s | Night %s\nStorm %s | Objects %d | Controller %s", health, num(stamina), num(scrap), num(hunger), num(thirst), num(night), num(storm), App.Count(App.entries), App.Active() and "ready" or "waiting")
    if App.hud then App.hud.Visible = App.cfg.hud; App.hud.Text = text end
    if App.statusParagraph then App.statusParagraph:Set({Title = "Live status", Content = text}) end
    if App.traitParagraph then App.traitParagraph:Set({Title = "Trait marker status", Content = App.TraitSummary()}) end
end
function App.UpdateInventoryPanel()
    local inventory = App.GetInventory()
    if not inventory then App.inventoryParagraph:Set({Title = "Inventory", Content = "Spawn first; native inventory is currently unavailable."}); return end
    local slots, lines = App.Call(inventory, "get", true), {}
    if type(slots) == "table" then
        local keys = {}; for key in pairs(slots) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            local item = slots[key]
            local state = type(item) == "table" and item.state
            if type(state) == "table" then
                local record = Catalog.items[state.identifier]
                lines[#lines + 1] = string.format("%s. %s | count %s%s", tostring(key), record and record.name or tostring(state.identifier), tostring(state.count or "?"), inventory.equipped_index == key and " [equipped]" or "")
            end
        end
    end
    lines[#lines + 1] = "Salvage: " .. tostring(App.Call(inventory, "get_scrap") or "--")
    lines[#lines + 1] = "Ammo: " .. App.Format(App.Call(inventory, "get_ammo"))
    lines[#lines + 1] = "Rations: " .. App.Format(App.Call(inventory, "get_rations"))
    App.inventoryParagraph:Set({Title = "Inventory / native state", Content = table.concat(lines, "\n")})
end

function App.Start()
    App.MakeOverlay()
    pcall(function() App.originalLeaderboard = Services.Starter:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList) end)
    App.BuildUI(); if not App.alive then return end; App.ScanRoots(); App.LoadModules()
    App.WatchCharacter(App.Character())
    App.Connect(LP.CharacterAdded, function(character) App.WatchCharacter(character) end)
    App.Connect(Services.World.ChildAdded, function(child)
        if child.Name == "activePlayers" then
            App.Connect(child.ChildAdded, function(model) if model.Name == LP.Name then App.WatchCharacter(model) end end)
        end
        task.defer(App.ScanRoots)
    end)
    local active = Services.World:FindFirstChild("activePlayers")
    if active then App.Connect(active.ChildAdded, function(model) if model.Name == LP.Name then App.WatchCharacter(model) end end) end
    App.Connect(Services.Input.JumpRequest, function()
        if App.cfg.infiniteJump and not Services.Input:GetFocusedTextBox() then
            local hum = App.Humanoid()
            if hum and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)
    -- One throttled heartbeat handles non-render work; no GetDescendants scan per frame.
    App.Connect(Services.Run.Heartbeat, function(delta)
        App.tick = App.tick + delta; App.espTime = App.espTime + delta
        App.statusTime = App.statusTime + delta; App.scanTime = App.scanTime + delta; App.traitTime = App.traitTime + delta
        if App.espTime >= App.cfg.espInterval then
            App.espTime = 0; App.UpdateESP(); App.AutoPickup()
        end
        if App.traitTime >= 0.5 then App.traitTime = 0; App.ApplyTraits() end
        if App.statusTime >= 1 then App.statusTime = 0; App.UpdateStatus(); App.UpdateWorld() end
        if App.scanTime >= 5 then App.scanTime = 0; App.ScanRoots() end
    end)
    App.Connect(Services.Run.PreSimulation, App.UpdateMovement)
    App.renderName = "DWFieldKit_Aim_" .. tostring(LP.UserId)
    Services.Run:BindToRenderStep(App.renderName, Enum.RenderPriority.Camera.Value + 1, function(delta)
        if App.alive then
            local ok, err = pcall(App.UpdateAim, delta)
            if not ok and not App.runtimeFailures.aim then App.runtimeFailures.aim = true; App.Note(err) end
        end
    end)
    local oldUnload = App.Unload
    App.Unload = function()
        pcall(function() Services.Run:UnbindFromRenderStep(App.renderName) end)
        oldUnload()
    end
    App.UpdateStatus()
    App.Notify("Lucky Blessing core ready", "Apply a perk preset before spawning. Insert / ] reopens the menu.")
end

--[====[
Bundled ArrayField license (upstream Apache-2.0)
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

]====]
function App.LoadClassicUI()
local ChangeTheme, CloseNPrompt, qNotePrompt, ClosePrompt, CloseSideBar, Hide, Unhide, CloseSearch, OpenSearch, Maximise, OpenSideBar, Minimise
local spawn = App.UITask
local ClassicSections = setmetatable({}, {__mode = "k"})
local function RestoreSectionState()
    for section in pairs(ClassicSections) do
        if section.Holder.Parent then section.Holder.Visible = section.Open end
    end
    if App.FilterClassicGroups then App.FilterClassicGroups(App.classicSearchQuery or "") end
end
--[[

ArrayField Interface Suite
by Arrays

Original by Sirius

-------------------------------
Arrays  | Designing + Programming + New Features
and Rafa =D

]]

local Release = "Rafa Edition"
local NotificationDuration = 6.5
local RayfieldFolder = "Rayfield"
local ConfigurationFolder = RayfieldFolder.."/Configurations"
local ConfigurationExtension = ".rfld"
local RayFieldQuality = {}

local RayfieldLibrary = {
	Flags = {},
	Theme = {
		Default = {
			TextFont = "Default", -- Default will use the various font faces used across Rayfield
			TextColor = Color3.fromRGB(240, 240, 240),

			Background = Color3.fromRGB(25, 25, 25),
			Topbar = Color3.fromRGB(34, 34, 34),
			Shadow = Color3.fromRGB(20, 20, 20),
			
			NotificationBackground = Color3.fromRGB(20, 20, 20),
			NotificationActionsBackground = Color3.fromRGB(230, 230, 230),

			TabBackground = Color3.fromRGB(80, 80, 80),
			TabStroke = Color3.fromRGB(85, 85, 85),
			TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
			TabTextColor = Color3.fromRGB(240, 240, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 50, 50),

			ElementBackground = Color3.fromRGB(35, 35, 35),
			ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
			SecondaryElementBackground = Color3.fromRGB(25, 25, 25), -- For labels and paragraphs
			ElementStroke = Color3.fromRGB(50, 50, 50),
			SecondaryElementStroke = Color3.fromRGB(40, 40, 40), -- For labels and paragraphs

			SliderBackground = Color3.fromRGB(43, 105, 159),
			SliderProgress = Color3.fromRGB(43, 105, 159),
			SliderStroke = Color3.fromRGB(48, 119, 177),

			ToggleBackground = Color3.fromRGB(30, 30, 30),
			ToggleEnabled = Color3.fromRGB(0, 146, 214),
			ToggleDisabled = Color3.fromRGB(100, 100, 100),
			ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
			ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
			ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
			ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),

			InputBackground = Color3.fromRGB(30, 30, 30),
			InputStroke = Color3.fromRGB(65, 65, 65),
			PlaceholderColor = Color3.fromRGB(178, 178, 178)
		},
		Light = {
			TextFont = "Default",  -- Default will use the various font faces used across Rayfield
			TextColor = Color3.fromRGB(50, 50, 50), -- i need to make all text 240, 240, 240 and base gray on transparency not color to do this

			Background = Color3.fromRGB(250, 250, 250),
			Topbar = Color3.fromRGB(217, 217, 217),
			Shadow = Color3.fromRGB(223, 223, 223),

			NotificationBackground = Color3.fromRGB(20, 20, 20),
			NotificationActionsBackground = Color3.fromRGB(230, 230, 230),

			TabBackground = Color3.fromRGB(220, 220, 220),
			TabStroke = Color3.fromRGB(112, 112, 112),
			TabBackgroundSelected = Color3.fromRGB(0, 142, 208),
			TabTextColor = Color3.fromRGB(240, 240, 240),
			SelectedTabTextColor = Color3.fromRGB(50, 50, 50),

			ElementBackground = Color3.fromRGB(198, 198, 198),
			ElementBackgroundHover = Color3.fromRGB(230, 230, 230),
			SecondaryElementBackground = Color3.fromRGB(136, 136, 136), -- For labels and paragraphs
			ElementStroke = Color3.fromRGB(180, 199, 97),
			SecondaryElementStroke = Color3.fromRGB(40, 40, 40),  --For labels and paragraphs

			SliderBackground = Color3.fromRGB(31, 159, 71),
			SliderProgress = Color3.fromRGB(31, 159, 71),
			SliderStroke = Color3.fromRGB(42, 216, 94),

			ToggleBackground = Color3.fromRGB(170, 203, 60),
			ToggleEnabled = Color3.fromRGB(32, 214, 29),
			ToggleDisabled = Color3.fromRGB(100, 22, 23),
			ToggleEnabledStroke = Color3.fromRGB(17, 255, 0),
			ToggleDisabledStroke = Color3.fromRGB(65, 8, 8),
			ToggleEnabledOuterStroke = Color3.fromRGB(0, 170, 0),
			ToggleDisabledOuterStroke = Color3.fromRGB(170, 0, 0),

			InputBackground = Color3.fromRGB(31, 159, 71),
			InputStroke = Color3.fromRGB(19, 65, 31),
			PlaceholderColor = Color3.fromRGB(178, 178, 178)
		},

	}
}



-- Services

local UserInputService = App.UIService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = App.UIService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = game:GetService('Players').LocalPlayer
local ContentProvider = game:GetService("ContentProvider")
-- local TextService = game:GetService("TextService")

-- Interface Management
local Rayfield = game:GetObjects("rbxassetid://13067385695")[1]



local ParentObject = function(Gui)
    local success, failure = pcall(function()
        if get_hidden_gui or gethui then
            local hiddenUI = get_hidden_gui or gethui
            Gui.Parent = hiddenUI()
        elseif (not is_sirhurt_closure) and (syn and syn.protect_gui) then
            syn.protect_gui(Gui)
            Gui.Parent = CoreGui
        elseif CoreGui then
            Gui.Parent = CoreGui
        end
    end)
    if not success and failure then
        Gui.Parent = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
    end
	App.classicGui = Rayfield
end
ParentObject(Rayfield)

--Object Variables

local Camera = workspace.CurrentCamera
local Main = Rayfield.Main
local Topbar = Main.Topbar
local Elements = Main.Elements
local LoadingFrame = Main.LoadingFrame
local TopList = Main.TabList
local SideList = Main.SideTabList.Holder
local TabsList = TopList and SideList
local SearchBar = Main.Searchbar
local Filler = SearchBar.CanvasGroup.Filler
local Prompt = Main.Prompt
local NotePrompt = Main.NotePrompt

Rayfield.DisplayOrder = 100
LoadingFrame.Version.Text = Release


--Variables

local request = (syn and syn.request) or (http and http.request) or http_request
local CFileName = nil
local CEnabled = false
local Minimised = false
local Hidden = false
local Debounce = false
local clicked = false
local SearchHided = true
local SideBarClosed = true
local BarType = 'Top'
local HoverTime = 0.3
local Notifications = Rayfield.Notifications

local SelectedTheme = RayfieldLibrary.Theme.Default

function ChangeTheme(ThemeName)
	SelectedTheme = RayfieldLibrary.Theme[ThemeName]
	for _, obj in ipairs(Rayfield:GetDescendants()) do
		if obj.ClassName == "TextLabel" or obj.ClassName == "TextBox" or obj.ClassName == "TextButton" then
			if SelectedTheme.TextFont ~= "Default" then 
				obj.TextColor3 = SelectedTheme.TextColor
				obj.Font = SelectedTheme.TextFont
			end
		end
	end

	Rayfield.Main.BackgroundColor3 = SelectedTheme.Background
	Rayfield.Main.Topbar.BackgroundColor3 = SelectedTheme.Topbar
	Rayfield.Main.Topbar.CornerRepair.BackgroundColor3 = SelectedTheme.Topbar
	Rayfield.Main.Shadow.Image.ImageColor3 = SelectedTheme.Shadow

	Rayfield.Main.Topbar.ChangeSize.ImageColor3 = SelectedTheme.TextColor
	Rayfield.Main.Topbar.Hide.ImageColor3 = SelectedTheme.TextColor
	Rayfield.Main.Topbar.Theme.ImageColor3 = SelectedTheme.TextColor

	for _, TabPage in ipairs(Elements:GetChildren()) do
		for _, Element in ipairs(TabPage:GetChildren()) do
			if Element.ClassName == "Frame" and Element.Name ~= "Placeholder" and Element.Name ~= "SectionSpacing" and Element.Name ~= "" and Element.Name ~= "SectionTitle" then
				Element.BackgroundColor3 = SelectedTheme.ElementBackground
				Element.UIStroke.Color = SelectedTheme.ElementStroke
			end
		end
	end

end
local function AddDraggingFunctionality(DragPoint, Main)
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false,false,false,false
		DragPoint.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				Dragging = true
				MousePos = Input.Position
				FramePos = Main.Position

				Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then
						Dragging = false
					end
				end)
			end
		end)
		DragPoint.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				DragInput = Input
			end
		end)
		UserInputService.InputChanged:Connect(function(Input)
			if Input == DragInput and Dragging then
				local Delta = Input.Position - MousePos
				TweenService:Create(Main, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position  = UDim2.new(FramePos.X.Scale,FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)}):Play()
			end
		end)
	end)
end   
local function FadeDescription(Infos)

end
local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end    

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadConfiguration(Configuration)
	local Data = HttpService:JSONDecode(Configuration)
	for FlagName, FlagValue in next, Data do
		if RayfieldLibrary.Flags[FlagName] then
			spawn(function() 
				if RayfieldLibrary.Flags[FlagName].Type == "ColorPicker" then
					RayfieldLibrary.Flags[FlagName]:Set(UnpackColor(FlagValue))
				else
					if RayfieldLibrary.Flags[FlagName].CurrentValue or RayfieldLibrary.Flags[FlagName].CurrentKeybind or RayfieldLibrary.Flags[FlagName].CurrentOption or RayfieldLibrary.Flags[FlagName].Color ~= FlagValue then RayfieldLibrary.Flags[FlagName]:Set(FlagValue) end
				end    
			end)
		else
			RayfieldLibrary:Notify({Title = "Flag Error", Content = "Rayfield was unable to find '"..FlagName.. "'' in the current script"})
		end
	end
end

local function SaveConfiguration()
	if not CEnabled then return end
	-- print(debug.traceback())
	local Data = {}
	for i,v in pairs(RayfieldLibrary.Flags) do
		if v.Type == "ColorPicker" then
			Data[i] = PackColor(v.Color)
		else
			Data[i] = v.CurrentValue or v.CurrentKeybind or v.Color or v.CurrentOption
		end
	end	
	writefile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension, tostring(HttpService:JSONEncode(Data)))
end

local neon = (function()  --Open sourced neon module
	local module = {}

	do
		local function IsNotNaN(x)
			return x == x
		end
		local continued = IsNotNaN(Camera:ScreenPointToRay(0,0).Origin.x)
		while not continued do
			RunService.RenderStepped:wait()
			continued = IsNotNaN(Camera:ScreenPointToRay(0,0).Origin.x)
		end
	end
	local RootParent = Camera
	if false == nil then
		RootParent = Camera
	else
		if not false then
			RootParent = Camera
		else 
			RootParent = nil
		end
	end


	local binds = {}
	local root = Instance.new('Folder', RootParent)
	root.Name = 'neon'


	local GenUid; do
		local id = 0
		function GenUid()
			id = id + 1
			return 'neon::'..tostring(id)
		end
	end

	local DrawQuad; do
		local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
		local sz = 0.2

		local function DrawTriangle(v1, v2, v3, p0, p1)
			local s1 = (v1 - v2).magnitude
			local s2 = (v2 - v3).magnitude
			local s3 = (v3 - v1).magnitude
			local smax = max(s1, s2, s3)
			local A, B, C
			if s1 == smax then
				A, B, C = v1, v2, v3
			elseif s2 == smax then
				A, B, C = v2, v3, v1
			elseif s3 == smax then
				A, B, C = v3, v1, v2
			end

			local para = ( (B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z ) / (A-B).magnitude
			local perp = sqrt((C-A).magnitude^2 - para*para)
			local dif_para = (A - B).magnitude - para

			local st = CFrame.new(B, A)
			local za = CFrame.Angles(pi/2,0,0)

			local cf0 = st

			local Top_Look = (cf0 * za).lookVector
			local Mid_Point = A + CFrame.new(A, B).LookVector * para
			local Needed_Look = CFrame.new(Mid_Point, C).LookVector
			local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z

			local ac = CFrame.Angles(0, 0, acos(dot))

			cf0 = cf0 * ac
			if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
				cf0 = cf0 * CFrame.Angles(0, 0, -2*acos(dot))
			end
			cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))

			local cf1 = st * ac * CFrame.Angles(0, pi, 0)
			if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
				cf1 = cf1 * CFrame.Angles(0, 0, 2*acos(dot))
			end
			cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)

			if not p0 then
				p0 = Instance.new('Part')
				p0.FormFactor = 'Custom'
				p0.TopSurface = 0
				p0.BottomSurface = 0
				p0.Anchored = true
				p0.CanCollide = false
				p0.Material = 'Glass'
				p0.Size = Vector3.new(sz, sz, sz)
				local mesh = Instance.new('SpecialMesh', p0)
				mesh.MeshType = 2
				mesh.Name = 'WedgeMesh'
			end
			p0.WedgeMesh.Scale = Vector3.new(0, perp/sz, para/sz)
			p0.CFrame = cf0

			if not p1 then
				p1 = p0:clone()
			end
			p1.WedgeMesh.Scale = Vector3.new(0, perp/sz, dif_para/sz)
			p1.CFrame = cf1

			return p0, p1
		end

		function DrawQuad(v1, v2, v3, v4, parts)
			parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
			parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
		end
	end

	function module:BindFrame(frame, properties)
		if RootParent == nil then return end
		if binds[frame] then
			return binds[frame].parts
		end

		local uid = GenUid()
		local parts = {}
		local f = Instance.new('Folder', root)
		f.Name = frame.Name

		local parents = {}
		do
			local function add(child)
				if child:IsA'GuiObject' then
					parents[#parents + 1] = child
					add(child.Parent)
				end
			end
			add(frame)
		end

		local function UpdateOrientation(fetchProps)
			local zIndex = 1 - 0.05*frame.ZIndex
			local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
			local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
			do
				local rot = 0;
				for _, v in ipairs(parents) do
					rot = rot + v.Rotation
				end
				if rot ~= 0 and rot%180 ~= 0 then
					local mid = tl:lerp(br, 0.5)
					local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
					local vec = tl
					tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
					tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
					bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
					br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
				end
			end
			DrawQuad(
				Camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin, 
				Camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin, 
				Camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin, 
				Camera:ScreenPointToRay(br.x, br.y, zIndex).Origin, 
				parts
			)
			if fetchProps then
				for _, pt in pairs(parts) do
					pt.Parent = f
				end
				for propName, propValue in pairs(properties) do
					for _, pt in pairs(parts) do
						pt[propName] = propValue
					end
				end
			end
		end

		UpdateOrientation(true)
		RunService:BindToRenderStep(uid, 2000, UpdateOrientation)

		binds[frame] = {
			uid = uid;
			parts = parts;
		}
		return binds[frame].parts
	end

	function module:Modify(frame, properties)
		local parts = module:GetBoundParts(frame)
		if parts then
			for propName, propValue in pairs(properties) do
				for _, pt in pairs(parts) do
					pt[propName] = propValue
				end
			end
		end
	end

	function module:UnbindFrame(frame)
		if RootParent == nil then return end
		local cb = binds[frame]
		if cb then
			RunService:UnbindFromRenderStep(cb.uid)
			for _, v in pairs(cb.parts) do
				v:Destroy()
			end
			binds[frame] = nil
		end
	end

	function module:HasBinding(frame)
		return binds[frame] ~= nil
	end

	function module:GetBoundParts(frame)
		return binds[frame] and binds[frame].parts
	end


	function module:Destroy()
		local frames = {}; for frame in pairs(binds) do frames[#frames + 1] = frame end
		for _, frame in ipairs(frames) do module:UnbindFrame(frame) end
		root:Destroy()
	end
	return module

end)()
function CloseNPrompt()
	local Infos= TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	TweenService:Create(NotePrompt,Infos,{BackgroundTransparency = 1,Size = UDim2.fromOffset(436,92),Position = UDim2.fromScale(0.5,0.19)}):Play()
	TweenService:Create(NotePrompt.UIStroke,Infos,{Transparency = 1}):Play()
	TweenService:Create(NotePrompt.Shadow.Image,Infos,{ImageTransparency = 1}):Play()

	TweenService:Create(NotePrompt.Close,Infos,{ImageTransparency = .1}):Play()
	TweenService:Create(NotePrompt.Icon,Infos,{ImageTransparency = 1}):Play()
	TweenService:Create(NotePrompt.Title,Infos,{TextTransparency = 1}):Play()

	TweenService:Create(NotePrompt.Description,Infos,{TextTransparency = 1}):Play()
	TweenService:Create(NotePrompt.Load,Infos,{TextTransparency = 1,BackgroundTransparency = 1}):Play()
	TweenService:Create(NotePrompt.Load.UIStroke,Infos,{Transparency = 1}):Play()
	TweenService:Create(NotePrompt.Load.Shadow,Infos,{ImageTransparency = 1}):Play()
	wait(0.21)
	NotePrompt.Visible = false
end
function qNotePrompt(PromptSettings)
	local Infos= TweenInfo.new(.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	NotePrompt.Visible = false
	--Setup
	NotePrompt.Size = UDim2.fromOffset(436,92)
	NotePrompt.Position = UDim2.fromScale(0.5,0.19)
	NotePrompt.BackgroundTransparency = 1
	NotePrompt.UIStroke.Transparency = 1

	NotePrompt.Icon.ImageTransparency = 1
	NotePrompt.Close.ImageTransparency = 1

	NotePrompt.Shadow.Image.ImageTransparency = 1

	NotePrompt.Title.TextTransparency = 1
	NotePrompt.Description.TextTransparency = 1

	NotePrompt.Load.BackgroundTransparency = 1
	NotePrompt.Load.UIStroke.Transparency = 1
	NotePrompt.Load.TextTransparency = 1
	NotePrompt.Load.Shadow.ImageTransparency = 1
	--Settings
	NotePrompt.Title.Text = PromptSettings.Title or ''
	NotePrompt.Description.Text = PromptSettings.Description or ''
	NotePrompt.Icon.Image = PromptSettings.Icon or 'rbxassetid://4483362748'
	NotePrompt.Load.BackgroundColor3 = PromptSettings.Color or Color3.fromRGB(90, 90, 90)
	NotePrompt.Load.MouseButton1Down:Once(function(x,y)
		CloseNPrompt()
		if PromptSettings.Callback then
			PromptSettings.Callback()
		end
	end)

	NotePrompt.Close.MouseButton1Down:Once(function()
		CloseNPrompt()
	end)
	NotePrompt.Visible = true
	--Opening
	TweenService:Create(NotePrompt,Infos,{BackgroundTransparency = .1,Size = UDim2.fromOffset(474,100),Position = UDim2.fromScale(0.5,0.21)}):Play()
	TweenService:Create(NotePrompt.UIStroke,Infos,{Transparency = 0}):Play()
	TweenService:Create(NotePrompt.Shadow.Image,Infos,{ImageTransparency = .2}):Play()
	wait(.3)
	TweenService:Create(NotePrompt.Close,Infos,{ImageTransparency = .8}):Play()
	TweenService:Create(NotePrompt.Icon,Infos,{ImageTransparency = 0}):Play()
	TweenService:Create(NotePrompt.Title,Infos,{TextTransparency = 0}):Play()
	wait(.1)
	TweenService:Create(NotePrompt.Description,Infos,{TextTransparency = 0}):Play()
	wait(.2)
	TweenService:Create(NotePrompt.Load,Infos,{TextTransparency = 0,BackgroundTransparency = .2}):Play()
	TweenService:Create(NotePrompt.Load.UIStroke,Infos,{Transparency = 0}):Play()
	TweenService:Create(NotePrompt.Load.Shadow,Infos,{ImageTransparency = .8}):Play()
end
function ClosePrompt()
	local PromptUI = Prompt.Prompt
	clicked = false
	TweenService:Create(Prompt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(PromptUI, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1,Size = UDim2.new(0,340,0,140)}):Play()
	TweenService:Create(PromptUI.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
	TweenService:Create(PromptUI.Title, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(PromptUI.Content, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(PromptUI.Sub, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	for _,button in pairs(PromptUI.Buttons:GetChildren()) do
		if button.Name ~= 'Template' and button:IsA("Frame") then
			TweenService:Create(button.UIStroke,TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
			TweenService:Create(button.TextLabel,TweenInfo.new(0.2, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			delay(.2,function()
				button:Destroy()
			end)
		end
	end
	wait(.5)
	Prompt.Visible = false
end
function RayfieldLibrary:Notify(NotificationSettings)
	spawn(function()
		local ActionCompleted = true
		local Notification = Notifications.Template:Clone()
		Notification.Parent = Notifications
		Notification.Name = NotificationSettings.Title or "Unknown Title"
		Notification.Visible = true

		local blurlight = nil
		if not false then
			blurlight = Instance.new("DepthOfFieldEffect",game:GetService("Lighting"))
			blurlight.Enabled = true
			blurlight.FarIntensity = 0
			blurlight.FocusDistance = 51.6
			blurlight.InFocusRadius = 50
			blurlight.NearIntensity = 1
			App.classicEffects[blurlight] = true
		end

		Notification.Actions.Template.Visible = false

		if NotificationSettings.Actions then
			for _, Action in pairs(NotificationSettings.Actions) do
				ActionCompleted = false
				local NewAction = Notification.Actions.Template:Clone()
				NewAction.BackgroundColor3 = SelectedTheme.NotificationActionsBackground
				if SelectedTheme ~= RayfieldLibrary.Theme.Default then
					NewAction.TextColor3 = SelectedTheme.TextColor
				end
				NewAction.Name = Action.Name
				NewAction.Visible = true
				NewAction.Parent = Notification.Actions
				NewAction.Text = Action.Name
				NewAction.BackgroundTransparency = 1
				NewAction.TextTransparency = 1
				NewAction.Size = UDim2.new(0, NewAction.TextBounds.X + 27, 0, 36)

				NewAction.MouseButton1Click:Connect(function()
					local Success, Response = pcall(Action.Callback)
					if not Success then
						print("Rayfield | Action: "..Action.Name.." Callback Error " ..tostring(Response))
					end
					ActionCompleted = true
				end)
			end
		end
		Notification.BackgroundColor3 = SelectedTheme.Background
		Notification.Title.Text = NotificationSettings.Title or "Unknown"
		Notification.Title.TextTransparency = 1
		Notification.Title.TextColor3 = SelectedTheme.TextColor
		Notification.Description.Text = NotificationSettings.Content or "Unknown"
		Notification.Description.TextTransparency = 1
		Notification.Description.TextColor3 = SelectedTheme.TextColor
		Notification.Icon.ImageColor3 = SelectedTheme.TextColor
		if NotificationSettings.Image then
			Notification.Icon.Image = "rbxassetid://"..tostring(NotificationSettings.Image) 
		else
			Notification.Icon.Image = "rbxassetid://3944680095"
		end

		Notification.Icon.ImageTransparency = 1

		Notification.Parent = Notifications
		Notification.Size = UDim2.new(0, 260, 0, 80)
		Notification.BackgroundTransparency = 1

		TweenService:Create(Notification, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 295, 0, 91)}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.1}):Play()
		Notification:TweenPosition(UDim2.new(0.5,0,0.915,0),'Out','Quint',0.8,true)

		wait(0.3)
		TweenService:Create(Notification.Icon, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
		TweenService:Create(Notification.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
		wait(0.2)



		-- Requires Graphics Level 8-10
		if false == nil then
			TweenService:Create(Notification, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.4}):Play()
		else
			if not false then
				TweenService:Create(Notification, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.4}):Play()
			else 
				TweenService:Create(Notification, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			end
		end

		if Rayfield.Name == "Rayfield" then
			neon:BindFrame(Notification.BlurModule, {
				Transparency = 0.98;
				BrickColor = BrickColor.new("Institutional white");
			})
		end

		if not NotificationSettings.Actions then
			wait(NotificationSettings.Duration or NotificationDuration - 0.5)
		else
			wait(0.8)
			TweenService:Create(Notification, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 295, 0, 132)}):Play()
			wait(0.3)
			for _, Action in ipairs(Notification.Actions:GetChildren()) do
				if Action.ClassName == "TextButton" and Action.Name ~= "Template" then
					TweenService:Create(Action, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.2}):Play()
					TweenService:Create(Action, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
					wait(0.05)
				end
			end
		end

		repeat wait(0.001) until ActionCompleted

		for _, Action in ipairs(Notification.Actions:GetChildren()) do
			if Action.ClassName == "TextButton" and Action.Name ~= "Template" then
				TweenService:Create(Action, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				TweenService:Create(Action, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			end
		end

		TweenService:Create(Notification.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.47, 0,0.234, 0)}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(0.528, 0,0.637, 0)}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 280, 0, 83)}):Play()
		TweenService:Create(Notification.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()

		wait(0.3)
		TweenService:Create(Notification.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
		wait(0.4)
		TweenService:Create(Notification, TweenInfo.new(0.9, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 260, 0, 0)}):Play()
		TweenService:Create(Notification, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
		TweenService:Create(Notification.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		TweenService:Create(Notification.Description, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
		wait(0.2)
		if not false then
			neon:UnbindFrame(Notification.BlurModule)
			blurlight:Destroy(); App.classicEffects[blurlight] = nil
		end
		wait(0.9)
		Notification:Destroy()
	end)
end

function CloseSideBar()
	Debounce = true
	SideBarClosed = true
	for _,tabbtn in pairs(SideList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint),{TextTransparency = 1}):Play()
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint),{ImageTransparency = 1}):Play()
		end
	end
	TweenService:Create(Main.SideTabList, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1,Size = UDim2.new(0,150,0,390),Position = UDim2.new(0,10,0.5,22)}):Play()
	TweenService:Create(Main.SideTabList.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint),{Transparency = 1}):Play()
	TweenService:Create(Main.SideTabList.RDMT, TweenInfo.new(0.4, Enum.EasingStyle.Quint),{TextTransparency = 1}):Play()
	wait(.4)
	Main.SideTabList.Visible = false
	wait(0.2)
	Debounce = false
end
function Hide()
	if not SideBarClosed then
		task.spawn(CloseSideBar)
	end
	Debounce = true
	RayfieldLibrary:Notify({Title = "Interface Hidden", Content = "The interface has been hidden, you can unhide the interface with Insert or the LB button", Duration = 7})
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 470, 0, 400)}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 470, 0, 45)}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar.CornerRepair, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
	for _, TopbarButton in ipairs(Topbar:GetChildren()) do
		if TopbarButton.ClassName == "ImageButton" then
			TweenService:Create(TopbarButton, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		end
	end
	for _, tabbtn in ipairs(TabsList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
			TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
		end
	end
	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element:FindFirstChild('Holder') then
							TweenService:Create(element, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						else
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							pcall(function()
                            TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
                            end)
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
								child.Visible = false
							end
						end
					end
				end
			end
		end
	end
	wait(0.5)
	Main.Visible = false
	Debounce = false
end
function Unhide()
	Debounce = true
	Main.Position = UDim2.new(0.5, 0, 0.5, 0)
	Main.Visible = true
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 475)}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 45)}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.4}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Topbar.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	if Minimised then
		spawn(Maximise)
	end
	for _, TopbarButton in ipairs(Topbar:GetChildren()) do
		if TopbarButton.ClassName == "ImageButton" then
			TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
		end
	end
	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" and not element:FindFirstChild('ColorPickerIs') then
						if element:FindFirstChild('_UIPadding_') then
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = .25}):Play()
						else
							if element.Name ~= 'SectionTitle' then
                            TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
                            end
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if (child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel") then
								child.Visible = true
							end
						end
					elseif element:FindFirstChild('ColorPickerIs') then
						TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
						TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
						TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

						if element.ColorPickerIs.Value then
							element.ColorSlider.Visible = true
							element.HexInput.Visible = true
							element.RGB.Visible = true
						end
						element.CPBackground.Visible = true
						element.Lock.Visible = true
						element.Interact.Visible = true
						element.Title.Visible = true
					end
				end
			end
		end
	end
	RestoreSectionState()
	wait(0.5)
	Minimised = false
	Debounce = false
end
function CloseSearch()
	Debounce = true
	TweenService:Create(SearchBar, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 1,Size = UDim2.new(0, 460,0, 35)}):Play()
	TweenService:Create(SearchBar.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(SearchBar.Clear, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(SearchBar.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
	TweenService:Create(SearchBar.Filter, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(SearchBar.Shadow.Image, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()
	TweenService:Create(SearchBar.Input, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	delay(.3,function()
		SearchBar.Input.Visible = false
	end)
	wait(0.5)
	SearchBar.Visible = false
	Debounce = false
end
function OpenSearch()
	Debounce = true
	SearchBar.Visible = true
	SearchBar.Input.Visible = true
	TweenService:Create(SearchBar, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 0,Size = UDim2.new(0, 480,0, 40)}):Play()
	TweenService:Create(SearchBar.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
	TweenService:Create(SearchBar.Shadow.Image, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()
	TweenService:Create(SearchBar.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
	TweenService:Create(SearchBar.Clear, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = .8}):Play()
	TweenService:Create(SearchBar.Filter, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = .8}):Play()
	TweenService:Create(SearchBar.Input, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.5)
	Debounce = false
end
SearchBar.Input:GetPropertyChangedSignal('Text'):Connect(function()
    App.FilterClassicGroups(SearchBar.Input.Text)
end)

SearchBar.Clear.MouseButton1Down:Connect(function()
	Filler.Position = UDim2.new(0.957,0,.5,0)
	Filler.Size = UDim2.new(0,1,0,1)
	Filler.BackgroundTransparency = .9

	local goal = {}
	goal.Size = UDim2.new(0,1000,0,500)
	goal.BackgroundTransparency = 1

	TweenService:Create(Filler, TweenInfo.new(1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out), goal):Play()
	SearchBar.Input.Text = ''
end)

function Maximise()
	Debounce = true
	Topbar.ChangeSize.Image = "rbxassetid://"..10137941941

	TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.4}):Play()
	TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 475)}):Play()
	TweenService:Create(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 45)}):Play()
	TabsList.Visible = true
	wait(0.2)

	Elements.Visible = true

	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" and not element:FindFirstChild('ColorPickerIs') then
						if element:FindFirstChild('_UIPadding_') then
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = .25}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						else
							if element.Name ~= 'SectionTitle' then
                            TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
                            TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
                            end
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if (child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel") then
								child.Visible = true
							end
						end
					elseif element:FindFirstChild('ColorPickerIs') then
						TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
						TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
						TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

						if element.ColorPickerIs.Value then
							element.ColorSlider.Visible = true
							element.HexInput.Visible = true
							element.RGB.Visible = true
						end
						element.CPBackground.Visible = true
						element.Lock.Visible = true
						element.Interact.Visible = true
						element.Title.Visible = true
					end
				end
			end
		end
	end


	wait(0.1)

	for _, tabbtn in ipairs(TopList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			if tostring(Elements.UIPageLayout.CurrentPage) == tabbtn.Title.Text then
				TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
				TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
				TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()
			else
				TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
				TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()
				TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
				TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			end

		end
	end


	RestoreSectionState()
	wait(0.5)
	Debounce = false
end
function OpenSideBar()
	Debounce = true
	Main.SideTabList.Visible = true 
	TweenService:Create(Main.SideTabList, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = .03,Size = UDim2.new(0,160,0,405),Position = UDim2.new(0,14,0.5,22)}):Play()
	TweenService:Create(Main.SideTabList.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint),{Transparency = 0}):Play()
	TweenService:Create(Main.SideTabList.RDMT, TweenInfo.new(0.4, Enum.EasingStyle.Quint),{TextTransparency = 0}):Play()
	for _,tabbtn in pairs(SideList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			if tabbtn.Title.TextColor3 ~= Color3.fromRGB(255,255,255) then
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint),{TextTransparency = .2}):Play()
			else
				TweenService:Create(tabbtn.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint),{TextTransparency = 0}):Play()
			end
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.25, Enum.EasingStyle.Quint),{ImageTransparency = 0}):Play()
		end
		wait(0.12)
	end
	SideBarClosed = false
	wait(0.2)
	Debounce = false
end
function Minimise()
	Debounce = true
	Topbar.ChangeSize.Image = "rbxassetid://"..11036884234
	if not SearchHided then
		spawn(CloseSearch)
	end
	if not SideBarClosed then
		spawn(CloseSideBar)
	end
	for _, tabbtn in ipairs(TopList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			TweenService:Create(tabbtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
			TweenService:Create(tabbtn.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
			TweenService:Create(tabbtn.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
		end
	end

	for _, tab in ipairs(Elements:GetChildren()) do
		if tab.Name ~= "Template" and tab.ClassName == "ScrollingFrame" and tab.Name ~= "Placeholder" then
			for _, element in ipairs(tab:GetChildren()) do
				if element.ClassName == "Frame" then
					if element.Name ~= "SectionSpacing" and element.Name ~= "Placeholder" then
						if element:FindFirstChild('_UIPadding_') then
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						else
							TweenService:Create(element, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							pcall(function()
									TweenService:Create(element.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
								end)
							TweenService:Create(element.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
						for _, child in ipairs(element:GetChildren()) do
							if child.ClassName == "Frame" or child.ClassName == "TextLabel" or child.ClassName == "TextBox" or child.ClassName == "ImageButton" or child.ClassName == "ImageLabel" then
								child.Visible = false
							end
						end
					end
				end
			end
		end
	end

	TweenService:Create(Topbar.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
	TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Topbar.Divider, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
	TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 495, 0, 45)}):Play()
	TweenService:Create(Topbar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 495, 0, 45)}):Play()

	wait(0.3)

	Elements.Visible = false
	TabsList.Visible = false

	wait(0.2)
	Debounce = false
end

function RayfieldLibrary:CreateWindow(Settings)
	Rayfield.Enabled = false
	local Passthrough = false
	Topbar.Title.Text = Settings.Name
	Main.Size = UDim2.new(0, 450, 0, 260)
	Main.Visible = true
	Main.BackgroundTransparency = 1
	LoadingFrame.Title.TextTransparency = 1
	LoadingFrame.Subtitle.TextTransparency = 1
	Main.Shadow.Image.ImageTransparency = 1
	LoadingFrame.Version.TextTransparency = 1
	LoadingFrame.Title.Text = Settings.LoadingTitle or "Arrayfield Interface Suite"
	LoadingFrame.Subtitle.Text = Settings.LoadingSubtitle or "by Sirius | Meta | Rafa"
	if Settings.LoadingTitle ~= "Arrayfield Interface Suite" then
		LoadingFrame.Version.Text = "Arrayfield UI"
	end

	Topbar.Visible = false
	Elements.Visible = false
	LoadingFrame.Visible = true

	RayfieldLibrary:ToggleOldTabStyle(Settings.OldTabLayout)	
	
	pcall(function()
		if not Settings.ConfigurationSaving.FileName then
			Settings.ConfigurationSaving.FileName = tostring(game.PlaceId)
		end
		if not isfolder(RayfieldFolder.."/".."Configuration Folders") then

		end
		if Settings.ConfigurationSaving.Enabled == nil then
			Settings.ConfigurationSaving.Enabled = false
		end
		CFileName = Settings.ConfigurationSaving.FileName
		ConfigurationFolder = Settings.ConfigurationSaving.FolderName or ConfigurationFolder
		CEnabled = Settings.ConfigurationSaving.Enabled

		if Settings.ConfigurationSaving.Enabled then
			if not isfolder(ConfigurationFolder) then
				makefolder(ConfigurationFolder)
			end	
		end
	end)

	AddDraggingFunctionality(Topbar,Main)

	for _, TabButton in ipairs(TabsList:GetChildren()) do
		if TabButton.ClassName == "Frame" and TabButton.Name ~= "Placeholder" then
			TabButton.BackgroundTransparency = 1
			TabButton.Title.TextTransparency = 1
			TabButton.Shadow.ImageTransparency = 1
			TabButton.Image.ImageTransparency = 1
			TabButton.UIStroke.Transparency = 1
		end
	end

	if Settings.Discord then
		if not isfolder(RayfieldFolder.."/Discord Invites") then
			makefolder(RayfieldFolder.."/Discord Invites")
		end
		if not isfile(RayfieldFolder.."/Discord Invites".."/"..Settings.Discord.Invite..ConfigurationExtension) then
			if request then
				request({
					Url = 'http://127.0.0.1:6463/rpc?v=1',
					Method = 'POST',
					Headers = {
						['Content-Type'] = 'application/json',
						Origin = 'https://discord.com'
					},
					Body = HttpService:JSONEncode({
						cmd = 'INVITE_BROWSER',
						nonce = HttpService:GenerateGUID(false),
						args = {code = Settings.Discord.Invite}
					})
				})
			end

			if Settings.Discord.RememberJoins then -- We do logic this way so if the developer changes this setting, the user still won't be prompted, only new users
				writefile(RayfieldFolder.."/Discord Invites".."/"..Settings.Discord.Invite..ConfigurationExtension,"Rayfield RememberJoins is true for this invite, this invite will not ask you to join again")
			end
		else

		end
	end

	if Settings.KeySystem then
		if not Settings.KeySettings then
			Passthrough = true
			return
		end

		if not isfolder(RayfieldFolder.."/Key System") then
			makefolder(RayfieldFolder.."/Key System")
		end

		if Settings.KeySettings.GrabKeyFromSite then
			local Success, Response = pcall(function()
				Settings.KeySettings.Key = game:HttpGet(Settings.KeySettings.Key)
			end)
			if not Success then
				print("Rayfield | "..Settings.KeySettings.Key.." Error " ..tostring(Response))
			end
		end

		if not Settings.KeySettings.FileName then
			Settings.KeySettings.FileName = "No file name specified"
		end

		if isfile(RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension) then
			if readfile(RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension) == Settings.KeySettings.Key then
				Passthrough = true
			end
		end

		if not Passthrough then
			local AttemptsRemaining = math.random(2,6)
			Rayfield.Enabled = false
			local KeyUI = game:GetObjects("rbxassetid://11695805160")[1]
			KeyUI.Enabled = true
			pcall(function()
				_G.KeyUI:Destroy()
			end)
			_G.KeyUI = KeyUI

			ParentObject(KeyUI)

			local KeyMain = KeyUI.Main
			KeyMain.Title.Text = Settings.KeySettings.Title or Settings.Name
			KeyMain.Subtitle.Text = Settings.KeySettings.Subtitle or "Key System"
			KeyMain.NoteMessage.Text = Settings.KeySettings.Note or "No instructions"

			KeyMain.Size = UDim2.new(0, 467, 0, 175)
			KeyMain.BackgroundTransparency = 1
			KeyMain.EShadow.ImageTransparency = 1
			KeyMain.Title.TextTransparency = 1
			KeyMain.Subtitle.TextTransparency = 1
			KeyMain.KeyNote.TextTransparency = 1
			KeyMain.Input.BackgroundTransparency = 1
			KeyMain.Input.UIStroke.Transparency = 1
			KeyMain.Input.InputBox.TextTransparency = 1
			KeyMain.NoteTitle.TextTransparency = 1
			KeyMain.NoteMessage.TextTransparency = 1
			KeyMain.Hide.ImageTransparency = 1
			KeyMain.HideP.ImageTransparency = 1

			TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 187)}):Play()
			TweenService:Create(KeyMain.EShadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 0.5}):Play()
			wait(0.05)
			TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			wait(0.05)
			TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(KeyMain.Input.HidenInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			wait(0.05)
			TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			wait(0.15)
			TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 0.3}):Play()
			TweenService:Create(KeyMain.HideP, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 0.3}):Play()

			KeyUI.Main.Input.InputBox:GetPropertyChangedSignal('Text'):Connect(function()
				KeyUI.Main.Input.HidenInput.Text = string.rep('•', #KeyUI.Main.Input.InputBox.Text)
			end)
			KeyUI.Main.Input.InputBox.FocusLost:Connect(function(EnterPressed)
				if not EnterPressed then return end
				if KeyMain.Input.InputBox.Text == Settings.KeySettings.Key then
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
					TweenService:Create(KeyMain.EShadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
					TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(KeyMain.Input.InputBox,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Input.HidenInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(KeyMain.HideP, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					delay(.4,function()
						KeyMain.Hide.Visible = false
						KeyUI:Destroy()
					end)
					wait(0.51)
					Passthrough = true
					if Settings.KeySettings.SaveKey then
						if writefile then
							writefile(RayfieldFolder.."/Key System".."/"..Settings.KeySettings.FileName..ConfigurationExtension, Settings.KeySettings.Key)
						end
						RayfieldLibrary:Notify({Title = "Key System", Content = "The key for this script has been saved successfully"})
					end
				else
					if AttemptsRemaining == 0 then
						TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
						TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
						TweenService:Create(KeyMain.Shadow.Image, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
						TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
						TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						TweenService:Create(KeyMain.Input.InputBox,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Input.HidenInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
						TweenService:Create(KeyMain.HideP, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
						wait(0.45)
						game.Players.LocalPlayer:Kick("No Attempts Remaining")
						game:Shutdown()
					end
					KeyMain.Input.InputBox.Text = ""
					AttemptsRemaining = AttemptsRemaining - 1
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
					TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {Position = UDim2.new(0.495,0,0.5,0)}):Play()
					wait(0.1)
					TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Elastic), {Position = UDim2.new(0.505,0,0.5,0)}):Play()
					wait(0.1)
					TweenService:Create(KeyMain, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5,0,0.5,0)}):Play()
					TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 187)}):Play()
				end
			end)
			local Hidden = true
			KeyMain.HideP.MouseButton1Click:Connect(function()
				if Hidden then
					TweenService:Create(KeyMain.Input.HidenInput,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(KeyMain.Input.InputBox,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
					Hidden = false
				else
					TweenService:Create(KeyMain.Input.HidenInput,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
					TweenService:Create(KeyMain.Input.InputBox,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					Hidden = true
				end
			end)

			KeyMain.Hide.MouseButton1Click:Connect(function()
				TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				TweenService:Create(KeyMain, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 467, 0, 175)}):Play()
				TweenService:Create(KeyMain.EShadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
				TweenService:Create(KeyMain.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.KeyNote, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Input, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				TweenService:Create(KeyMain.Input.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				TweenService:Create(KeyMain.Input.InputBox, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.NoteTitle, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Input.HidenInput,TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.NoteMessage, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
				TweenService:Create(KeyMain.Hide, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
				TweenService:Create(KeyMain.HideP, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
				wait(0.51)
				RayfieldLibrary:Destroy()
				KeyUI:Destroy()
			end)
		else
			Passthrough = true
		end
	end
	if Settings.KeySystem then
		repeat wait() until Passthrough
	end
	Rayfield.Enabled = true
	for _,tabbtn in pairs(SideList:GetChildren()) do
		if tabbtn.ClassName == "Frame" and tabbtn.Name ~= "Placeholder" then
			TweenService:Create(tabbtn.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint),{TextTransparency = 1}):Play()
			TweenService:Create(tabbtn.Image, TweenInfo.new(0.3, Enum.EasingStyle.Quint),{ImageTransparency = 1}):Play()
		end
	end
	TweenService:Create(Main.SideTabList, TweenInfo.new(0, Enum.EasingStyle.Quint), {BackgroundTransparency = 1,Size = UDim2.new(0,150,0,390),Position = UDim2.new(0,10,0.5,22)}):Play()
	TweenService:Create(Main.SideTabList.UIStroke, TweenInfo.new(0, Enum.EasingStyle.Quint),{Transparency = 1}):Play()
	TweenService:Create(Main.SideTabList.RDMT, TweenInfo.new(0, Enum.EasingStyle.Quint),{TextTransparency = 1}):Play()
-- 	delay(4,function()
-- 		qNotePrompt({
-- 			Title = 'New Library Documentation Available',
-- 			Description = 'The Library Developer has updated the Documentation and recommends all script developers to take a look.',

-- 		})
-- 	end)
	TopList.Template.Visible = false
	SideList.SideTemplate.Visible = false
	Notifications.Template.Visible = false
	Notifications.Visible = true
	wait(0.5)
	TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.55}):Play()
	wait(0.1)
	TweenService:Create(LoadingFrame.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.05)
	TweenService:Create(LoadingFrame.Subtitle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.05)
	TweenService:Create(LoadingFrame.Version, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

	Elements.Template.LayoutOrder = 100000
	Elements.Template.Visible = false

	Elements.UIPageLayout.FillDirection = Enum.FillDirection.Horizontal

	-- Tab
	local FirstTab = false
	RayFieldQuality.Window = {Tabs = {}}
	local Window = RayFieldQuality.Window
	function Window:CreateTab(Name, Image, AllowColorChange)
		Window.Tabs[Name]={Elements = {}}
		local Tab = Window.Tabs[Name]
		local SDone = false
		local TopTabButton,SideTabButton = TopList.Template:Clone(), SideList.SideTemplate:Clone()

		SideTabButton.Parent = SideList
		TopTabButton.Parent = TopList

		TopTabButton.Name=Name SideTabButton.Name=Name

		TopTabButton.Title.Text = Name SideTabButton.Title.Text = Name
		SideTabButton.Title.TextWrapped = false TopTabButton.Title.TextWrapped = false 

		TopTabButton.Size = UDim2.new(0, TopTabButton.Title.TextBounds.X + 30, 0, 30)

		if Image then
			TopTabButton.Image.Image = "rbxassetid://"..Image
			SideTabButton.Image.Image = "rbxassetid://"..Image

			TopTabButton.Title.AnchorPoint = Vector2.new(0, 0.5)
			TopTabButton.Title.Position = UDim2.new(0, 37, 0.5, 0)
			TopTabButton.Image.Visible = true
			TopTabButton.Title.TextXAlignment = Enum.TextXAlignment.Left
			TopTabButton.Size = UDim2.new(0, TopTabButton.Title.TextBounds.X + 46, 0, 30)
		end

		TopTabButton.BackgroundTransparency = 1
		TopTabButton.Title.TextTransparency = 1
		TopTabButton.Shadow.ImageTransparency = 1
		TopTabButton.Image.ImageTransparency = 1
		TopTabButton.UIStroke.Transparency = 1

		SideTabButton.BackgroundTransparency = 1
		SideTabButton.Title.TextTransparency = 1
		SideTabButton.Shadow.ImageTransparency = 1
		SideTabButton.Image.ImageTransparency = 1
		SideTabButton.UIStroke.Transparency = 1

		TopTabButton.Visible = true
		SideTabButton.Visible = true

		--Create Elements Page
		local TabPage = Elements.Template:Clone()
		TabPage.Name = Name
		TabPage.Visible = true

		TabPage.LayoutOrder = #Elements:GetChildren()

		for _, TemplateElement in ipairs(TabPage:GetChildren()) do
			if TemplateElement.ClassName == "Frame" and TemplateElement.Name ~= "Placeholder" then
				TemplateElement:Destroy()
			end
		end

		TabPage.Parent = Elements
		if not FirstTab then
			Elements.UIPageLayout.Animated = false
			Elements.UIPageLayout:JumpTo(TabPage)
			Elements.UIPageLayout.Animated = true
		end

		if SelectedTheme ~= RayfieldLibrary.Theme.Default then
			TopTabButton.Shadow.Visible = false
		end
		TopTabButton.UIStroke.Color = SelectedTheme.TabStroke
		--Animate
		wait(0.1)
		if FirstTab then
			TopTabButton.BackgroundColor3 = SelectedTheme.TabBackground
			if AllowColorChange then
				TopTabButton.Image.ImageColor3 = SelectedTheme.TabTextColor
			end
			TopTabButton.Title.TextColor3 = SelectedTheme.TabTextColor
			TweenService:Create(TopTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.7}):Play()
			TweenService:Create(TopTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0.2}):Play()
			TweenService:Create(TopTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
			TweenService:Create(TopTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(TopTabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.7}):Play()

			TweenService:Create(SideTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0,ImageColor3 = Color3.fromRGB(205, 205, 205)}):Play()
			TweenService:Create(SideTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = .2,TextColor3 = Color3.fromRGB(205, 205, 205)}):Play()	
		else
			FirstTab = Name

			TopTabButton.BackgroundColor3 = SelectedTheme.TabBackgroundSelected
			if AllowColorChange then
				TopTabButton.Image.ImageColor3 = SelectedTheme.SelectedTabTextColor
			end
			TopTabButton.Title.TextColor3 = SelectedTheme.SelectedTabTextColor
			TweenService:Create(TopTabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()
			TweenService:Create(TopTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			TweenService:Create(TopTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(TopTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

			SideTabButton.Image.ImageColor3 = Color3.fromRGB(255, 255, 255)
			SideTabButton.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
			TweenService:Create(SideTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			TweenService:Create(SideTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

		end

		local function Pick()
			if Minimised then return end
			TweenService:Create(TopTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(TopTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
			TweenService:Create(TopTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
			TweenService:Create(TopTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			TweenService:Create(TopTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.TabBackgroundSelected}):Play()
			TweenService:Create(TopTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextColor3 = SelectedTheme.SelectedTabTextColor}):Play()
			if AllowColorChange then
				TweenService:Create(TopTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageColor3 = SelectedTheme.SelectedTabTextColor}):Play()
			end
			TweenService:Create(TopTabButton.Shadow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ImageTransparency = 0.9}):Play()

			TweenService:Create(SideTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0,ImageColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			TweenService:Create(SideTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0,TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
			Elements.UIPageLayout:JumpTo(TabPage)
			for _, OtherTabButton in ipairs(TopList:GetChildren()) do
				task.spawn(function()
					if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= TopTabButton and OtherTabButton.Name ~= "Placeholder" then
						TweenService:Create(OtherTabButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.TabBackground,BackgroundTransparency = .7}):Play()
						TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageColor3 = Color3.fromRGB(240, 240, 240)}):Play()
						TweenService:Create(OtherTabButton.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0,Color = Color3.fromRGB(85,85,85)}):Play()
						TweenService:Create(OtherTabButton.Shadow, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = .85,ImageColor3 = Color3.fromRGB(20,20,20)}):Play()
						TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextColor3 = Color3.fromRGB(240, 240, 240),TextTransparency = .2}):Play()
					end
				end)
			end
			for _,OtherTabButton in ipairs(SideList:GetChildren()) do
				task.spawn(function()
					if OtherTabButton.Name ~= "Template" and OtherTabButton.ClassName == "Frame" and OtherTabButton ~= SideTabButton and OtherTabButton.Name ~= "Placeholder" then
						TweenService:Create(OtherTabButton.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0,ImageColor3 = Color3.fromRGB(205, 205, 205)}):Play()
						TweenService:Create(OtherTabButton.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = .2,TextColor3 = Color3.fromRGB(205, 205, 205)}):Play()	
					end
				end)
			end

		end

		TopTabButton.Interact.MouseButton1Click:Connect(Pick)
		SideTabButton.Interact.MouseButton1Click:Connect(Pick)

		-- Button
		function Tab:CreateButton(ButtonSettings)
			local ButtonValue = {Locked = false, Disabled = false}

			local Button = Elements.Template.Button:Clone()
			ButtonValue.Button = Button
			Tab.Elements[ButtonSettings.Name] = {
				type = 'button',
				section = ButtonSettings.SectionParent,
				element = Button
			}
			Button.Name = ButtonSettings.Name
			Button.Title.Text = ButtonSettings.Name
			Button.ElementIndicator.Text = ButtonSettings.Interact or 'button'
			Button.Visible = true

			Button.BackgroundTransparency = 1
			Button.UIStroke.Transparency = 1
			Button.Title.TextTransparency = 1
			if ButtonSettings.SectionParent then
				Button.Parent = ButtonSettings.SectionParent.Holder
			else
				Button.Parent = TabPage
			end
			TweenService:Create(Button, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Button.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Button.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Button.Interact.MouseButton1Click:Connect(function()
				if ButtonValue.Locked or ButtonValue.Disabled then return end
				local Success, Response = pcall(ButtonSettings.Callback)
				if not Success then
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Button.Title.Text = "Callback Error"
					print("Rayfield | "..ButtonSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Button.Title.Text = ButtonSettings.Name
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.9}):Play()
				else
					SaveConfiguration()
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					wait(0.2)
					TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Button.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.9}):Play()
				end
			end)

			Button.MouseEnter:Connect(function()
				TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.7}):Play()
			end)

			Button.MouseLeave:Connect(function()
				TweenService:Create(Button, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
				TweenService:Create(Button.ElementIndicator, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.9}):Play()
			end)

			function ButtonValue:Set(NewButton,Interaction)
				Button.Title.Text = NewButton or Button.Title.Text
				Button.Name = NewButton or Button.Name
				Button.ElementIndicator.Text = Interaction or Button.ElementIndicator.Text
			end
			function ButtonValue:Destroy()
				Button:Destroy()
			end
			function ButtonValue:Lock(Reason)
				if ButtonValue.Locked then return end
				ButtonValue.Locked = true
				Button.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Button.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Button.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not ButtonValue.Locked then return end --no icon bug
				TweenService:Create(Button.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			
			function ButtonValue:Disable(Reason)
				if ButtonValue.Disabled then return end
				ButtonValue.Disabled = true
				Button.Lock.Reason.Text = Reason or 'Disabled'
				TweenService:Create(Button.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Button.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
			end
			
			function ButtonValue:Enable()
				if not ButtonValue.Disabled then return end
				ButtonValue.Disabled = false	
				TweenService:Create(Button.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Button.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			
			function ButtonValue:Unlock()
				if not ButtonValue.Locked then return end
				ButtonValue.Locked = false
				wait(0.2)
				TweenService:Create(Button.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				if ButtonValue.Locked then return end --no icon bug
				TweenService:Create(Button.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Button.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function ButtonValue:Visible(bool)
				Button.Visible = bool
			end

			return ButtonValue
		end

		-- Section
		function Tab:CreateSection(SectionName, Display, DefaultHide, Icon)

			local SectionValue = {
				Holder = Rayfield.Holding,
				Open = true
			}
			local Debounce = false
			local Section = Elements.Template.SectionTitle:Clone()
			SectionValue.Holder = Section.Holder
			Section.Title.Text = SectionName
			Section.Visible = true
			Section.Parent = TabPage

			Tab.Elements[SectionName] = {
				type = 'section',
				display = Display,
				sectionholder = Section.Holder,
				element = Section
			}
			
			Section.Icon.Visible = false
			if not Icon or Icon == nil then 
				Section.Icon.Visible = false
				Section.Title.Position = UDim2.new(0, 10, 0, 8)
			else
				Section.Icon.Image = "rbxassetid://" .. tostring(Icon)
				Section.Icon.Visible = true
				Section.Title.Position = UDim2.new(0, 35, 0, 8)
			end

			Section.Title.TextTransparency = 1
			TweenService:Create(Section.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()

			function SectionValue:Set(NewSection)
				Section.Title.Text = NewSection
			end
			
			
            if Display then
                Section._UIPadding_.PaddingBottom = UDim.new(0, 4)
                Section.Holder.Visible = false
                SectionValue.Holder.Parent = Rayfield.Holding
                Section.Title.ImageButton.Visible = false
            else
                SectionValue.Open = not DefaultHide
                ClassicSections[SectionValue] = true
                function SectionValue:SetOpen(open)
                    self.Open = open == true
                    self.Holder.Visible = self.Open
                    Section._UIPadding_.PaddingBottom = UDim.new(0, self.Open and 8 or 4)
                    Section.Title.ImageButton.Rotation = self.Open and 0 or 180
                end
                SectionValue:SetOpen(SectionValue.Open)
                Section.Clickable.MouseButton1Down:Connect(function()
                    SectionValue:SetOpen(not SectionValue.Open)
                end)
            end
            SDone = true

			return SectionValue
		end

		-- Label
		function Tab:CreateLabel(LabelText, SectionParent)
			local LabelValue = {}

			local Label = Elements.Template.Label:Clone()
			Label.Title.Text = LabelText
			Label.Visible = true
			Tab.Elements[LabelText] = {
				type = 'label',
				section = SectionParent,
				element = Label
			}
			if SectionParent then
				Label.Parent = SectionParent.Holder
			else
				Label.Parent = TabPage
			end

			Label.BackgroundTransparency = 1
			Label.UIStroke.Transparency = 1
			Label.Title.TextTransparency = 1

			Label.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
			Label.UIStroke.Color = SelectedTheme.SecondaryElementStroke

			TweenService:Create(Label, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Label.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Label.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			function LabelValue:Set(NewLabel)
				Label.Title.Text = NewLabel
			end

			return LabelValue
		end

		-- Paragraph
		function Tab:CreateParagraph(ParagraphSettings, SectionParent)
			local ParagraphValue = {}

			local Paragraph = Elements.Template.Paragraph:Clone()
			Paragraph.Title.Text = ParagraphSettings.Title
			Paragraph.Title.RichText = true 
			Paragraph.Content.Text = ParagraphSettings.Content
			Paragraph.Content.RichText = true
			Paragraph.Visible = true

			Tab.Elements[ParagraphSettings.Title] = {
				type = 'paragraph',
				section = ParagraphSettings.SectionParent,
				element = Paragraph
			}

			if SectionParent or (ParagraphSettings.SectionParent and ParagraphSettings.SectionParent.Holder) then
				Paragraph.Parent = (SectionParent and SectionParent.Holder) or ParagraphSettings.SectionParent.Holder
			else
				Paragraph.Parent = TabPage
			end

			-- local textSize = TextService:GetTextSize(Paragraph.Content.Text, Paragraph.Content.TextSize, Paragraph.Content.Font, Vector2.new(math.huge, math.huge))
			-- Paragraph.Content.Size = UDim2.new(0, 438, 0, textSize.Y)
			-- --Paragraph.Content.Position = UDim2.new(0,465, 0,76)
			-- Paragraph.Size = UDim2.new(0,465, 0, textSize.Y + 40)

			Paragraph.BackgroundTransparency = 1
			Paragraph.UIStroke.Transparency = 1
			Paragraph.Title.TextTransparency = 1
			Paragraph.Content.TextTransparency = 1

			Paragraph.BackgroundColor3 = SelectedTheme.SecondaryElementBackground
			Paragraph.UIStroke.Color = SelectedTheme.SecondaryElementStroke

			TweenService:Create(Paragraph, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Paragraph.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Paragraph.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	
			TweenService:Create(Paragraph.Content, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			function ParagraphValue:Set(NewParagraphSettings)
				Paragraph.Title.Text = NewParagraphSettings.Title
				Paragraph.Content.Text = NewParagraphSettings.Content
			end

			function ParagraphValue:SetTitle(newTitle)
				Paragraph.Title.Text = newTitle
			end

			function ParagraphValue:SetContent(newContent)
				Paragraph.Content.Text = newContent
			end
			
			return ParagraphValue
		end

		-- Input
		function Tab:CreateInput(InputSettings)
			local Input = Elements.Template.Input:Clone()
			Input.Name = InputSettings.Name
			Input.Title.Text = InputSettings.Name
			Input.Visible = true
			InputSettings.Locked = false
			Tab.Elements[InputSettings.Name] = {
				type = 'input',
				section = InputSettings.SectionParent,
				element = Input
			}
			if InputSettings.SectionParent then
				Input.Parent = InputSettings.SectionParent.Holder
			else
				Input.Parent = TabPage
			end


			Input.BackgroundTransparency = 1
			Input.UIStroke.Transparency = 1
			Input.Title.TextTransparency = 1

			Input.InputFrame.BackgroundColor3 = SelectedTheme.InputBackground
			Input.InputFrame.UIStroke.Color = SelectedTheme.InputStroke

			TweenService:Create(Input, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Input.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Input.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Input.InputFrame.InputBox.PlaceholderText = InputSettings.PlaceholderText
			Input.InputFrame.Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)

			if InputSettings.NumbersOnly or InputSettings.CharacterLimit then
				Input.InputFrame.InputBox:GetPropertyChangedSignal('Text'):Connect(function()
					if Input.InputFrame.InputBox.Text == '' then return end 
					if InputSettings.CharacterLimit then Input.InputFrame.InputBox.Text = Input.InputFrame.InputBox.Text:sub(1,InputSettings.CharacterLimit) end
					if InputSettings.NumbersOnly then Input.InputFrame.InputBox.Text = Input.InputFrame.InputBox.Text:gsub('%D+', '') end
				end)
			end

			Input.InputFrame.InputBox.FocusLost:Connect(function(enter)
				if InputSettings.OnEnter and not enter then if InputSettings.RemoveTextAfterFocusLost then Input.InputFrame.InputBox.Text = "" end return end
				local Success, Response = pcall(function()
					InputSettings.Callback(Input.InputFrame.InputBox.Text)
				end)
				if not Success then
					TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Input.Title.Text = "Callback Error"
					print("Rayfield | "..InputSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Input.Title.Text = InputSettings.Name
					TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Input.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end

				if InputSettings.RemoveTextAfterFocusLost then Input.InputFrame.InputBox.Text = "" end
				SaveConfiguration()
			end)

			Input.MouseEnter:Connect(function()
				TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Input.MouseLeave:Connect(function()
				TweenService:Create(Input, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			Input.InputFrame.InputBox:GetPropertyChangedSignal("Text"):Connect(function()
				TweenService:Create(Input.InputFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Input.InputFrame.InputBox.TextBounds.X + 24, 0, 30)}):Play()
			end)

			Input.InputFrame.InputBox.Focused:Connect(function()
				if InputSettings.Locked then
					Input.InputFrame.InputBox:ReleaseFocus() return
				end
			end)

			function InputSettings:Destroy()
				Input:Destroy()
			end
			function InputSettings:Lock(Reason)
				if InputSettings.Locked then return end
				InputSettings.Locked = true
				Input.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Input.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Input.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not InputSettings.Locked then return end --no icon bug
				TweenService:Create(Input.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			function InputSettings:Unlock()
				if not InputSettings.Locked then return end
				InputSettings.Locked = false
				wait(0.2)
				TweenService:Create(Input.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				if InputSettings.Locked then return end --no icon bug
				TweenService:Create(Input.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Input.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function InputSettings:Visible(bool)
				Input.Visible = bool
			end
			return InputSettings
		end
		
		function Tab:CreateDropdown(DropdownSettings)
			local Dropdown = Elements.Template.Dropdown:Clone()
			DropdownSettings.Locked = false
			local SearchBar = Dropdown.List["-SearchBar"]
			if string.find(DropdownSettings.Name,"closed") then
				Dropdown.Name = "Dropdown"
			else
				Dropdown.Name = DropdownSettings.Name
			end
			Dropdown.Title.Text = DropdownSettings.Name
			Dropdown.Visible = true
			Dropdown.Parent = TabPage
			if DropdownSettings.MultiSelection then
			DropdownSettings.MultipleOptions = true
			end
			Dropdown.List.Visible = false
			Tab.Elements[DropdownSettings.Name] = {
				type = 'dropdown',
				section = DropdownSettings.SectionParent,
				element = Dropdown
			}
			if DropdownSettings.SectionParent then
				Dropdown.Parent = DropdownSettings.SectionParent.Holder
			else
				Dropdown.Parent = TabPage
			end
			if typeof(DropdownSettings.CurrentOption) == "string" then
				DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption}
			end

			if not DropdownSettings.MultipleOptions then
				DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption[1]}
			end

			local function Refresh() 
				if DropdownSettings.MultipleOptions then
					if not DropdownSettings.CurrentOption then
						DropdownSettings.CurrentOption = {}
					end
					
					if #DropdownSettings.CurrentOption == 1 then
						Dropdown.Selected.Text = DropdownSettings.CurrentOption[1] or "None"
					elseif #DropdownSettings.CurrentOption == 0 then
						Dropdown.Selected.Text = "None"
					else
						Dropdown.Selected.Text = "Various"
					end
				else
					Dropdown.Selected.Text = DropdownSettings.CurrentOption[1] or "None"
				end
			end
			
			Refresh()
			
			Dropdown.Icon.Visible = false
			if DropdownSettings.Icon then 
				if not string.match(DropdownSettings.Icon, "rbxassetid://") then
					DropdownSettings.Icon = "rbxassetid://" .. tostring(DropdownSettings.Icon)
				end
				Dropdown.Icon.Image = tostring(DropdownSettings.Icon)
				Dropdown.Icon.Visible = true
				Dropdown.Title.Position = UDim2.new(0, 50, 0, 22)
			end

			Dropdown.BackgroundTransparency = 1
			Dropdown.UIStroke.Transparency = 1
			Dropdown.Title.TextTransparency = 1

			Dropdown.Size = UDim2.new(1, -10, 0, 45)

			TweenService:Create(Dropdown, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Dropdown.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			for _, ununusedoption in ipairs(Dropdown.List:GetChildren()) do
				if ununusedoption.ClassName == "Frame" and ununusedoption.Name ~= 'PlaceHolder' and ununusedoption.Name ~= "-SearchBar" then
					ununusedoption:Destroy()
				end
			end

			Dropdown.Toggle.Rotation = 180

			Dropdown.Interact.MouseButton1Click:Connect(function()
				TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				wait(0.1)
				TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				if Debounce then return end
				if Dropdown.List.Visible then
					Debounce = true
					TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0, 45)}):Play()
					for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
						if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "PlaceHolder" and DropdownOpt~= SearchBar then
							TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
					end
					TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
					TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
					wait(0.35)
					Dropdown.List.Visible = false
					Debounce = false
				else
					TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0, 180)}):Play()
					Dropdown.List.Visible = true
					TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 0.7}):Play()
					TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 0}):Play()	
					for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
						if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "PlaceHolder" and DropdownOpt~= SearchBar then
							TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
					end
				end
			end)
			SearchBar.Input:GetPropertyChangedSignal('Text'):Connect(function()
				local InputText=string.upper(SearchBar.Input.Text)
				for _,item in ipairs(Dropdown.List:GetChildren()) do
					if item:IsA('Frame') and item.Name ~= 'Template' and item ~= SearchBar and item.Name ~= 'PlaceHolder' then
						if InputText=="" or InputText==" "or string.find(string.upper(item.Name),InputText,1,true)~=nil then
							TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(item.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(item.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						else
							TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(item.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(item.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
					end
				end
			end)
			
			Dropdown.MouseEnter:Connect(function()
				if not Dropdown.List.Visible then
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				end
			end)

			Dropdown.MouseLeave:Connect(function()
				TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)
			
			
			
			local function BuildOptions()
			for _, Option in ipairs(DropdownSettings.Options) do
				local DropdownOption = Elements.Template.Dropdown.List.Template:Clone()
				DropdownOption:GetPropertyChangedSignal('BackgroundTransparency'):Connect(function()
					if DropdownOption.BackgroundTransparency == 1 then
						DropdownOption.Visible = false
					else
						DropdownOption.Visible = true
					end
				end)
				DropdownOption.Name = Option
				DropdownOption.Title.Text = Option
				DropdownOption.Parent = Dropdown.List
				DropdownOption.Visible = true

				if DropdownSettings.CurrentOption == Option then
					DropdownOption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				end

				DropdownOption.BackgroundTransparency = Dropdown.List.Visible and 0 or 1
				DropdownOption.UIStroke.Transparency = Dropdown.List.Visible and 0 or 1
				DropdownOption.Title.TextTransparency = Dropdown.List.Visible and 0 or 1

				DropdownOption.Interact.ZIndex = 50
				DropdownOption.Interact.MouseButton1Click:Connect(function()
					if not DropdownSettings.MultipleOptions and table.find(DropdownSettings.CurrentOption, Option) then 
						return
					end

					if table.find(DropdownSettings.CurrentOption, Option) then
						table.remove(DropdownSettings.CurrentOption, table.find(DropdownSettings.CurrentOption, Option))
						Refresh()
					else
						if not DropdownSettings.MultipleOptions then
							table.clear(DropdownSettings.CurrentOption)
						end
						table.insert(DropdownSettings.CurrentOption, Option)
						Refresh()
						TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						TweenService:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
						Debounce = true
						wait(0.2)
						TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					end

					local Success, Response = pcall(function()
						DropdownSettings.Callback(DropdownSettings.CurrentOption)
					end)

					if not Success then
						TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						Dropdown.Title.Text = "Callback Error"
						print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
						wait(0.5)
						Dropdown.Title.Text = DropdownSettings.Name
						TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
						TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					end

					for _, droption in ipairs(Dropdown.List:GetChildren()) do
						if droption.ClassName == "Frame" and droption.Name ~= "PlaceHolder" and droption ~= SearchBar and droption ~= SearchBar and not table.find(DropdownSettings.CurrentOption, droption.Name) then
							TweenService:Create(droption, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
						end
					end
					if not DropdownSettings.MultipleOptions then
						wait(0.1)
						TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(1, -10, 0, 45)}):Play()
						for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
							if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "PlaceHolder" and DropdownOpt~= SearchBar then
								TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
								TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
								TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
							end
						end
						TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
						TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
						wait(0.35)
						Dropdown.List.Visible = false
					end
					Debounce = false	
					SaveConfiguration()
				end)
			end

			for _, droption in ipairs(Dropdown.List:GetChildren()) do
				if droption.ClassName == "Frame" and droption.Name ~= "PlaceHolder" and droption ~= SearchBar and droption ~= SearchBar then
					if not table.find(DropdownSettings.CurrentOption, droption.Name) then
						droption.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
					else
						droption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
					end
				end
			end

			end
			BuildOptions()


            function DropdownSettings:Refresh(newOptions)
                DropdownSettings.Options = table.clone(newOptions)
                local selected = {}
                for _, option in ipairs(DropdownSettings.CurrentOption or {}) do
                    if table.find(newOptions, option) then selected[#selected + 1] = option end
                end
                DropdownSettings.CurrentOption = selected
                for _, option in ipairs(Dropdown.List:GetChildren()) do
                    if option:IsA("Frame") and option ~= SearchBar and option.Name ~= "PlaceHolder" then option:Destroy() end
                end
                BuildOptions()
                Refresh()
            end

			function DropdownSettings:Set(NewOption)
				DropdownSettings.CurrentOption = NewOption

				if typeof(DropdownSettings.CurrentOption) == "string" then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption}
				end

				if not DropdownSettings.MultipleOptions then
					DropdownSettings.CurrentOption = {DropdownSettings.CurrentOption[1]}
				end

				Refresh()


				local Success, Response = pcall(function()
					DropdownSettings.Callback(NewOption)
				end)
				if not Success then
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Dropdown.Title.Text = "Callback Error"
					print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Dropdown.Title.Text = DropdownSettings.Name
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end

				for _, droption in ipairs(Dropdown.List:GetChildren()) do
					if droption.ClassName == "Frame" and droption.Name ~= "PlaceHolder" and droption ~= SearchBar then
						if not table.find(DropdownSettings.CurrentOption, droption.Name) then
							droption.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
						else
							droption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
						end
					end
				end
				--SaveConfiguration()
			end

			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and DropdownSettings.Flag then
					RayfieldLibrary.Flags[DropdownSettings.Flag] = DropdownSettings
				end
			end
			function DropdownSettings:Destroy()
				Dropdown:Destroy()
			end
			function DropdownSettings:Lock(Reason, hideIcon)
				if DropdownSettings.Locked then return end
				DropdownSettings.Locked = true
				Debounce = true
				TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0, 44)}):Play()
				for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
					if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= "PlaceHolder" and DropdownOpt~= SearchBar then
						TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
						TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					end
				end
				TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
				TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
				wait(0.35)
				Dropdown.List.Visible = false
				Debounce = false
				Dropdown.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Dropdown.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Dropdown.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not DropdownSettings.Locked or hideIcon then return end --no icon bug
				TweenService:Create(Dropdown.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			function DropdownSettings:Unlock()
				if not DropdownSettings.Locked then return end
				DropdownSettings.Locked = false
				wait(0.2)
				if Dropdown.Lock.Reason.Icon.ImageTransparency == 0 then
					TweenService:Create(Dropdown.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				end
				if DropdownSettings.Locked then return end --no icon bug
				TweenService:Create(Dropdown.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Dropdown.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function DropdownSettings:Visible(bool)
				Dropdown.Visible = bool
			end
			return DropdownSettings
		end

		-- Dropdown
		function Tab:OldCreateDropdown(DropdownSettings)
			local Dropdown = Elements.Template.Dropdown:Clone()
			local SearchBar = Dropdown.List["-SearchBar"]
			local Required = 1
			--local Debounce = false
			DropdownSettings.Items = {
				Selected = {Default = DropdownSettings.Selected or nil}
			}
			
			DropdownSettings.Locked = false
			local Multi = DropdownSettings.MultiSelection or false
			if string.find(DropdownSettings.Name,"closed") then
				Dropdown.Name = "Dropdown"
			else
				Dropdown.Name = DropdownSettings.Name
			end
			Dropdown.Title.Text = DropdownSettings.Name
			Dropdown.Visible = true
			Tab.Elements[DropdownSettings.Name] = {
				type = 'dropdown',
				section = DropdownSettings.SectionParent,
				element = Dropdown
			}
			
			if DropdownSettings.SectionParent then
				Dropdown.Parent = DropdownSettings.SectionParent.Holder
			else
				Dropdown.Parent = TabPage
			end
			
			Dropdown.Icon.Visible = false
			if DropdownSettings.Icon then 
				if not string.match(DropdownSettings.Icon, "rbxassetid://") then
					DropdownSettings.Icon = "rbxassetid://" .. tostring(DropdownSettings.Icon)
				end
				Dropdown.Icon.Image = tostring(DropdownSettings.Icon)
				Dropdown.Icon.Visible = true
				Dropdown.Title.Position = UDim2.new(0, 50, 0, 22)
			end

			Dropdown.List.Visible = false
			Dropdown.BackgroundTransparency = 1
			Dropdown.UIStroke.Transparency = 1
			Dropdown.Title.TextTransparency = 1

			Dropdown.Size = UDim2.new(0,465, 0, 44)

			TweenService:Create(Dropdown, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Dropdown.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	


			for _, ununusedoption in ipairs(Dropdown.List:GetChildren()) do
				if ununusedoption.ClassName == "Frame" and ununusedoption.Name ~= 'PlaceHolder' and ununusedoption.Name ~= "-SearchBar" then
					ununusedoption:Destroy()
				end
			end

			Dropdown.Toggle.Rotation = 180

			local function RefreshSelected()
				if #DropdownSettings.Items.Selected > 1 then
					local NT = {}
					for _,kj in ipairs(DropdownSettings.Items.Selected) do
						NT[#NT+1] = kj.Option.Name
					end
					Dropdown.Selected.Text = table.concat(NT, ", ")
				elseif DropdownSettings.Items.Selected[1] then
					Dropdown.Selected.Text = DropdownSettings.Items.Selected[1].Option.Name
				else
					Dropdown.Selected.Text = "Select an option"
				end
			end

			Dropdown.Interact.MouseButton1Click:Connect(function()
				if DropdownSettings.Locked then return end
				TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				wait(0.1)
				TweenService:Create(Dropdown, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				if Debounce then return end
				if Dropdown.List.Visible then
					Debounce = true
					TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0, 44)}):Play()
					for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
						if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= 'PlaceHolder' and DropdownOpt~= SearchBar then
							TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
					end
					TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
					TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
					wait(0.35)
					Dropdown.List.Visible = false
					Debounce = false
				else
					TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0, 178)}):Play()
					Dropdown.List.Visible = true
					TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 0.7}):Play()
					TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 0}):Play()	
					for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
						if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= 'PlaceHolder' and DropdownOpt ~= SearchBar then
							TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						end
					end
				end
			end)

			Dropdown.List['-SearchBar'].Input:GetPropertyChangedSignal('Text'):Connect(function()
				local InputText=string.upper(Dropdown.List['-SearchBar'].Input.Text)
				for _,item in ipairs(Dropdown.List:GetChildren()) do
					if item:IsA('Frame') and item.Name ~= 'Template' and item ~= SearchBar and item.Name ~= 'PlaceHolder' then
						if InputText=="" or InputText==" "or string.find(string.upper(item.Name),InputText)~=nil then
							TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
							TweenService:Create(item.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
							TweenService:Create(item.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
						else
							TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
							TweenService:Create(item.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							TweenService:Create(item.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
						end
					end
				end
			end)

			Dropdown.MouseEnter:Connect(function()
				if not Dropdown.List.Visible then
					TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
				end
			end)

			Dropdown.MouseLeave:Connect(function()
				TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			local function Error(text)
				TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
				Dropdown.Title.Text = text
				wait(0.5)
				Dropdown.Title.Text = DropdownSettings.Name
				TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
				TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			end

			local function AddOption(Option,Selecteds)
				local DropdownOption = Elements.Template.Dropdown.List.Template:Clone()
				DropdownOption:GetPropertyChangedSignal('BackgroundTransparency'):Connect(function()
					if DropdownOption.BackgroundTransparency == 1 then
						DropdownOption.Visible = false
					else
						DropdownOption.Visible = true
					end
				end)
				DropdownSettings.Items[Option] = {
					Option = DropdownOption,
					Selected = false
				}
				local OptionInTable = DropdownSettings.Items[Option]
				DropdownOption.Name = Option.Name or Option
				DropdownOption.Title.Text = Option.Name or Option
				DropdownOption.Parent = Dropdown.List
				DropdownOption.Visible = true
				local IsSelected = OptionInTable.Selected
				if Selecteds and #Selecteds > 0 then
					if typeof(Selecteds) == 'string' then
						Selecteds = {Selecteds}
					end
					for index,Selected in pairs(Selecteds) do
						if Selected == Option.Name or Selected == Option then
							IsSelected = true
							OptionInTable.Selected = true
							table.insert(DropdownSettings.Items.Selected,OptionInTable)
							DropdownSettings.Items.Selected[table.find(DropdownSettings.Items.Selected,OptionInTable)].Selected = true
						end
					end
					RefreshSelected()
				end

				if IsSelected then
					DropdownOption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				end

				if Dropdown.Visible then
					DropdownOption.BackgroundTransparency = 0
					DropdownOption.UIStroke.Transparency = 0
					DropdownOption.Title.TextTransparency = 0
				else
					DropdownOption.BackgroundTransparency = 1
					DropdownOption.UIStroke.Transparency = 1
					DropdownOption.Title.TextTransparency = 1
				end

				DropdownOption.Interact.ZIndex = 50
				DropdownOption.Interact.MouseButton1Click:Connect(function()
					if DropdownSettings.Locked then return end
					if OptionInTable.Selected then
						OptionInTable.Selected = false
						table.remove(DropdownSettings.Items.Selected,table.find(DropdownSettings.Items.Selected,OptionInTable))
						RefreshSelected()
						TweenService:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
						SaveConfiguration()
						return
					end
					if not Multi and DropdownSettings.Items.Selected[1] then
						DropdownSettings.Items.Selected[1].Selected = false
						TweenService:Create(DropdownSettings.Items.Selected[1].Option, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
					end
					if not (Multi) then
						DropdownSettings.Items.Selected = {OptionInTable}
						Dropdown.Selected.Text = Option.Name or Option
					else
						table.insert(DropdownSettings.Items.Selected,OptionInTable)
						RefreshSelected()
					end
					
					local Success, Response = pcall(function()
						DropdownSettings.Callback(Option)
					end)
					if not Success then
						Error('Callback Error')
						print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
					end
					
					OptionInTable.Selected = true
					
					if not (Multi) then
						for _,op in ipairs(DropdownSettings.Items.Selected) do
							TweenService:Create(op.Option, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}):Play()
						end
					end
					TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(DropdownOption, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
					Debounce = true
					wait(0.2)
					TweenService:Create(DropdownOption.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					wait(0.1)
					if not Multi then
						TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0, 45)}):Play()
						for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
							if DropdownOpt.ClassName == "Frame" and DropdownOpt ~= Dropdown.List.PlaceHolder and DropdownOpt ~= SearchBar then
								TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
								TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
								TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
							end
						end
						TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
						TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
						wait(0.35)
						Dropdown.List.Visible = false
						
					end
					Debounce = false
					SaveConfiguration()
				end)
			end
			local function AddOptions(Options,Selected)
				if typeof(Options) == 'table' then
					for _, Option in ipairs(Options) do
						AddOption(Option,Selected)
					end
				else
					AddOption(Options,Selected)
				end
				if Settings.ConfigurationSaving then
					if Settings.ConfigurationSaving.Enabled and DropdownSettings.Flag then
						RayfieldLibrary.Flags[DropdownSettings.Flag] = DropdownSettings
					end
				end
			end
			function DropdownSettings:Add(Items,Selected)
				AddOptions(Items,Selected)
			end
			
			AddOptions(DropdownSettings.Options, DropdownSettings.CurrentOption)
			
            --fix
			function DropdownSettings:Set(NewOption)
				
				for _,o in pairs(NewOption) do

					if typeof(NewOption) == 'table' then
						
						DropdownSettings.Items.Selected = NewOption
					else
						DropdownSettings.Items.Selected = {NewOption}
					end
					local Success, Response = pcall(function()
						DropdownSettings.Callback(NewOption)
					end)
					if not Success then
						TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						Dropdown.Title.Text = "Callback Error"
						print("Rayfield | "..DropdownSettings.Name.." Callback Error " ..tostring(Response))
						wait(0.5)
						Dropdown.Title.Text = DropdownSettings.Name
						TweenService:Create(Dropdown, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
						TweenService:Create(Dropdown.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					end
					if DropdownSettings.Items[NewOption] then
						local DropdownOption =  DropdownSettings.Items[NewOption]
						DropdownOption.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
						
						if Dropdown.Visible then
							DropdownOption.BackgroundTransparency = 0
							DropdownOption.UIStroke.Transparency = 0
							DropdownOption.Title.TextTransparency = 0
						else
							DropdownOption.BackgroundTransparency = 1
							DropdownOption.UIStroke.Transparency = 1
							DropdownOption.Title.TextTransparency = 1
						end
						
					end
				end
				--Dropdown.Selected.Text = NewText
			end
			function DropdownSettings:Error(text)
				Error(text)
			end
			function DropdownSettings:Refresh(NewOptions,Selecteds)
				DropdownSettings.Items = {}
				DropdownSettings.Items.Selected = {}
				for _, option in ipairs(Dropdown.List:GetChildren()) do
					if option.ClassName == "Frame" and option ~= SearchBar and option ~= Dropdown.List.PlaceHolder then
						option:Destroy()
					end
				end
				AddOptions(NewOptions,Selecteds)
			end
			function DropdownSettings:Remove(Item)
				if Item ~= Dropdown.List.PlaceHolder and Item ~= SearchBar then
					if DropdownSettings.Items[Item] then
						DropdownSettings.Items[Item].Option:Destroy()
						table.remove(DropdownSettings.Items,table.find(DropdownSettings.Items,Item))
					else
						Error('Option not found.')
					end
				else
					SearchBar:Destroy()
					Error("why you trynna remove the searchbar? FINE")
				end
				if Dropdown.Selected.Text == Item then
					Dropdown.Selected.Text = ''
				end
			end

			function DropdownSettings:Destroy()
				Dropdown:Destroy()
			end
			function DropdownSettings:Lock(Reason)
				if DropdownSettings.Locked then return end
				DropdownSettings.Locked = true
				Debounce = true
				TweenService:Create(Dropdown, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0, 44)}):Play()
				for _, DropdownOpt in ipairs(Dropdown.List:GetChildren()) do
					if DropdownOpt.ClassName == "Frame" and DropdownOpt.Name ~= 'PlaceHolder' and DropdownOpt.Name ~= "-SearchBar" then
						TweenService:Create(DropdownOpt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
						TweenService:Create(DropdownOpt.UIStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						TweenService:Create(DropdownOpt.Title, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
					end
				end
				TweenService:Create(Dropdown.List, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {ScrollBarImageTransparency = 1}):Play()
				TweenService:Create(Dropdown.Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Rotation = 180}):Play()	
				wait(0.35)
				Dropdown.List.Visible = false
				Debounce = false
				Dropdown.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Dropdown.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Dropdown.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not DropdownSettings.Locked then return end --no icon bug
				TweenService:Create(Dropdown.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			function DropdownSettings:Unlock()
				if not DropdownSettings.Locked then return end
				DropdownSettings.Locked = false
				wait(0.2)
				TweenService:Create(Dropdown.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				if DropdownSettings.Locked then return end --no icon bug
				TweenService:Create(Dropdown.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Dropdown.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function DropdownSettings:Visible(bool)
				Dropdown.Visible = bool
			end
			return DropdownSettings
		end

		-- Keybind
		function Tab:CreateKeybind(KeybindSettings)
			local CheckingForKey = false
			local Keybind = Elements.Template.Keybind:Clone()
			Keybind.Name = KeybindSettings.Name
			Keybind.Title.Text = KeybindSettings.Name
			Keybind.Visible = true
			Tab.Elements[KeybindSettings.Name] = {
				type = 'keybind',
				section = KeybindSettings.SectionParent,
				element = Keybind
			}
			if KeybindSettings.SectionParent then
				Keybind.Parent = KeybindSettings.SectionParent.Holder
			else
				Keybind.Parent = TabPage
			end


			Keybind.BackgroundTransparency = 1
			Keybind.UIStroke.Transparency = 1
			Keybind.Title.TextTransparency = 1

			Keybind.KeybindFrame.BackgroundColor3 = SelectedTheme.InputBackground
			Keybind.KeybindFrame.UIStroke.Color = SelectedTheme.InputStroke

			TweenService:Create(Keybind, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Keybind.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
			Keybind.KeybindFrame.Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)

			Keybind.KeybindFrame.KeybindBox.Focused:Connect(function()
				if KeybindSettings.Locked then
					Keybind.KeybindFrame.KeybindBox:ReleaseFocus() return
				end
				CheckingForKey = true
				Keybind.KeybindFrame.KeybindBox.Text = ""
			end)
			Keybind.KeybindFrame.KeybindBox.FocusLost:Connect(function()
				CheckingForKey = false
				if Keybind.KeybindFrame.KeybindBox.Text == nil or "" then
					Keybind.KeybindFrame.KeybindBox.Text = KeybindSettings.CurrentKeybind
					SaveConfiguration()
				end
			end)

			Keybind.MouseEnter:Connect(function()
				TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Keybind.MouseLeave:Connect(function()
				TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)

			UserInputService.InputBegan:Connect(function(input, processed)

				if CheckingForKey then
					if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode ~= Enum.KeyCode.RightShift then
						local SplitMessage = string.split(tostring(input.KeyCode), ".")
						local NewKeyNoEnum = SplitMessage[3]
						Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeyNoEnum)
						KeybindSettings.CurrentKeybind = tostring(NewKeyNoEnum)
						Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
						SaveConfiguration()
					end
				elseif KeybindSettings.CurrentKeybind ~= nil and (input.KeyCode == Enum.KeyCode[KeybindSettings.CurrentKeybind] and not processed) then  --Test
					local Held = true
					local Connection
					Connection = input.Changed:Connect(function(prop)
						if prop == "UserInputState" then
							Connection:Disconnect()
							Held = false
						end
					end)

					if not KeybindSettings.HoldToInteract then
						local Success, Response = pcall(KeybindSettings.Callback)
						if not Success then
							TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
							TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
							Keybind.Title.Text = "Callback Error"
							print("Rayfield | "..KeybindSettings.Name.." Callback Error " ..tostring(Response))
							wait(0.5)
							Keybind.Title.Text = KeybindSettings.Name
							TweenService:Create(Keybind, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
							TweenService:Create(Keybind.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
						end
					else
						wait(0.25)
						if Held then
							local Loop; Loop = RunService.Stepped:Connect(function()
								if not Held then
									KeybindSettings.Callback(false) -- maybe pcall this
									Loop:Disconnect()
								else
									KeybindSettings.Callback(true) -- maybe pcall this
								end
							end)	
						end
					end
				end
			end)

			Keybind.KeybindFrame.KeybindBox:GetPropertyChangedSignal("Text"):Connect(function()
				TweenService:Create(Keybind.KeybindFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Keybind.KeybindFrame.KeybindBox.TextBounds.X + 24, 0, 30)}):Play()
			end)

			function KeybindSettings:Set(NewKeybind)
				Keybind.KeybindFrame.KeybindBox.Text = tostring(NewKeybind)
				KeybindSettings.CurrentKeybind = tostring(NewKeybind)
				Keybind.KeybindFrame.KeybindBox:ReleaseFocus()
				SaveConfiguration()
			end
			function KeybindSettings:Destroy()
				Keybind:Destroy()
			end
			function KeybindSettings:Lock(Reason)
				if KeybindSettings.Locked then return end
				KeybindSettings.Locked = true
				Keybind.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Keybind.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Keybind.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not KeybindSettings.Locked then return end --no icon bug
				TweenService:Create(Keybind.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			function KeybindSettings:Unlock()
				if not KeybindSettings.Locked then return end
				KeybindSettings.Locked = false
				wait(0.2)
				TweenService:Create(Keybind.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				if KeybindSettings.Locked then return end --no icon bug
				TweenService:Create(Keybind.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Keybind.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function KeybindSettings:Visible(bool)
				Keybind.Visible = bool
			end
			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and KeybindSettings.Flag then
					RayfieldLibrary.Flags[KeybindSettings.Flag] = KeybindSettings
				end
			end
			return KeybindSettings
		end

		-- Toggle
		function Tab:CreateToggle(ToggleSettings)

			local Toggle = Elements.Template.Toggle:Clone()
			Toggle.Name = ToggleSettings.Name
			Toggle.Title.Text = ToggleSettings.Name
			Toggle.Visible = true

			Toggle.BackgroundTransparency = 1
			Toggle.UIStroke.Transparency = 1
			Toggle.Title.TextTransparency = 1
			Toggle.Switch.BackgroundColor3 = SelectedTheme.ToggleBackground
			Tab.Elements[ToggleSettings.Name] = {
				type = 'toggle',
				section = ToggleSettings.SectionParent,
				element = Toggle
			}
			if ToggleSettings.SectionParent then
				Toggle.Parent = ToggleSettings.SectionParent.Holder
			else
				Toggle.Parent = TabPage
			end
			if SelectedTheme ~= RayfieldLibrary.Theme.Default then
				Toggle.Switch.Shadow.Visible = false
			end
			ToggleSettings.Locked = false
			TweenService:Create(Toggle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Toggle.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	


			if not ToggleSettings.CurrentValue then
				Toggle.Switch.Indicator.Position = UDim2.new(1, -40, 0.5, 0)
				Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleDisabledStroke
				Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleDisabled
				Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleDisabledOuterStroke
			else
				Toggle.Switch.Indicator.Position = UDim2.new(1, -20, 0.5, 0)
				Toggle.Switch.Indicator.UIStroke.Color = SelectedTheme.ToggleEnabledStroke
				Toggle.Switch.Indicator.BackgroundColor3 = SelectedTheme.ToggleEnabled
				Toggle.Switch.UIStroke.Color = SelectedTheme.ToggleEnabledOuterStroke
			end

			Toggle.MouseEnter:Connect(function()
				TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)

			Toggle.MouseLeave:Connect(function()
				TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)
			Toggle.Interact.MouseButton1Click:Connect(function()
				if ToggleSettings.Locked then return end
				if ToggleSettings.CurrentValue then
					ToggleSettings.CurrentValue = false
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleDisabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleDisabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleDisabledOuterStroke}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()	
				else
					ToggleSettings.CurrentValue = true
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleEnabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleEnabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleEnabledOuterStroke}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()	
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()		
				end

				local Success, Response = pcall(function()
					ToggleSettings.Callback(ToggleSettings.CurrentValue)
				end)
				if not Success then
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Toggle.Title.Text = "Callback Error"
					print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Toggle.Title.Text = ToggleSettings.Name
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end

				SaveConfiguration()
			end)
			function ToggleSettings:Set(NewToggleValue)
				if NewToggleValue then
					ToggleSettings.CurrentValue = true
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleEnabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleEnabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Color3.fromRGB(100,100,100)}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()	
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()	
				else
					ToggleSettings.CurrentValue = false
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -40, 0.5, 0)}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,12,0,12)}):Play()
					TweenService:Create(Toggle.Switch.Indicator.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = SelectedTheme.ToggleDisabledStroke}):Play()
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = SelectedTheme.ToggleDisabled}):Play()
					TweenService:Create(Toggle.Switch.UIStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Color3.fromRGB(65,65,65)}):Play()
					wait(0.05)
					TweenService:Create(Toggle.Switch.Indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,17,0,17)}):Play()
					wait(0.15)
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()	
				end
				local Success, Response = pcall(function()
					ToggleSettings.Callback(ToggleSettings.CurrentValue)
				end)
				if not Success then
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Toggle.Title.Text = "Callback Error"
					print("Rayfield | "..ToggleSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Toggle.Title.Text = ToggleSettings.Name
					TweenService:Create(Toggle, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Toggle.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end
				SaveConfiguration()
			end
			function ToggleSettings:Destroy()
				Toggle:Destroy()
			end
			function ToggleSettings:Lock(Reason, HideLockIcon)
				if ToggleSettings.Locked then return end
				ToggleSettings.Locked = true
				Toggle.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Toggle.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Toggle.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				if not HideLockIcon then
					wait(0.2)
					if not ToggleSettings.Locked then return end --no icon bug
					TweenService:Create(Toggle.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
				end
			end
			function ToggleSettings:Unlock()
				if not ToggleSettings.Locked then return end
				ToggleSettings.Locked = false
				wait(0.2)
				if Toggle.Lock.Reason.Icon.ImageTransparency == 0 then
					TweenService:Create(Toggle.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				end
				if ToggleSettings.Locked then return end --no icon bug
				TweenService:Create(Toggle.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Toggle.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function ToggleSettings:Visible(bool)
				Toggle.Visible = bool
			end

			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and ToggleSettings.Flag then
					RayfieldLibrary.Flags[ToggleSettings.Flag] = ToggleSettings
				end
			end

			return ToggleSettings
		end

		-- ColorPicker
		function Tab:CreateColorPicker(ColorPickerSettings) -- by Throit
			local ColorPicker = Elements.Template.ColorPicker:Clone()
			Tab.Elements[ColorPickerSettings.Name] = {
				type = 'colorpicker',
				section = ColorPickerSettings.SectionParent,
				element = ColorPicker
			}
			local Background = ColorPicker.CPBackground
			local Display = Background.Display
			local Main = Background.MainCP
			local Slider = ColorPicker.ColorSlider
			ColorPicker.ColorPickerIs.Value = false
			ColorPicker.ClipsDescendants = true
			ColorPicker.Name = ColorPickerSettings.Name
			ColorPicker.Title.Text = ColorPickerSettings.Name
			ColorPickerSettings.Locked = false
			ColorPicker.Visible = true
			if ColorPickerSettings.SectionParent then
			ColorPicker.Parent = ColorPickerSettings.SectionParent.Holder
			else
			ColorPicker.Parent = TabPage
			end
			ColorPicker.Size = UDim2.new(0,465,0,40)
			ColorPicker.ColorSlider.Visible = false
			ColorPicker.HexInput.Visible = false
			ColorPicker.RGB.Visible = false
			Background.Size = UDim2.new(0, 39, 0, 22)
			Display.BackgroundTransparency = 0
			Main.MainPoint.ImageTransparency = 1
			ColorPicker.Interact.Size = UDim2.new(1, 0, 1, 0)
			ColorPicker.Interact.Position = UDim2.new(0.5, 0, 0.5, 0)
			ColorPicker.RGB.Position = UDim2.new(0, 17, 0, 70)
			ColorPicker.HexInput.Position = UDim2.new(0, 17, 0, 90)
			Main.ImageTransparency = 1
			Background.BackgroundTransparency = 1
			local opened  = false 
			local mouse = game.Players.LocalPlayer:GetMouse()
			Main.Image = "http://www.roblox.com/asset/?id=11415645739"
			local mainDragging = false 
			local sliderDragging = false 
			ColorPicker.Interact.MouseButton1Down:Connect(function()
			if ColorPickerSettings.Locked then return end
				if not opened then
					ColorPicker.ColorPickerIs.Value = true
					opened = true 
					ColorPicker.ColorSlider.Visible = true
					ColorPicker.HexInput.Visible = true
					ColorPicker.RGB.Visible = true
					TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0, 120)}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 173, 0, 86)}):Play()
					TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.289, 0, 0.5, 0)}):Play()
					TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 40)}):Play()
					TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 73)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0.574, 0, 1, 0)}):Play()
					TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
					TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 0.1}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
				else
					ColorPicker.ColorPickerIs.Value = false
					opened = false
					ColorPicker.ColorSlider.Visible = false
					ColorPicker.HexInput.Visible = false
					ColorPicker.RGB.Visible = false
					TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0,40)}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 39, 0, 22)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 1, 0)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
					TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 70)}):Play()
					TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 90)}):Play()
					TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
					TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				end
			end)

			game:GetService("UserInputService").InputEnded:Connect(function(input, gameProcessed) if input.UserInputType == Enum.UserInputType.MouseButton1 then 
					mainDragging = false
					sliderDragging = false
				end end)
			Main.MouseButton1Down:Connect(function()
				if opened and not ColorPickerSettings.Locked then
					mainDragging = true 
				end
			end)
			Main.MainPoint.MouseButton1Down:Connect(function()
				if opened and not ColorPickerSettings.Locked then
					mainDragging = true 
				end
			end)
			Slider.MouseButton1Down:Connect(function()
				if ColorPickerSettings.Locked then return end
				sliderDragging = true 
			end)
			Slider.SliderPoint.MouseButton1Down:Connect(function()
				if ColorPickerSettings.Locked then return end
				sliderDragging = true 
			end)

			local h,s,v = ColorPickerSettings.Color:ToHSV()
			local color = Color3.fromHSV(h,s,v) 
			local hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
			ColorPicker.HexInput.InputBox.Text = hex
			local function setDisplay()
				--Main
				Main.MainPoint.Position = UDim2.new(s,-Main.MainPoint.AbsoluteSize.X/2,1-v,-Main.MainPoint.AbsoluteSize.Y/2)
				Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
				Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
				Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
				--Slider 
				local x = h * Slider.AbsoluteSize.X
				Slider.SliderPoint.Position = UDim2.new(0,x-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
				Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
				local color = Color3.fromHSV(h,s,v) 
				local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
				ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
				ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
				ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
				hex = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
				ColorPicker.HexInput.InputBox.Text = hex
			end
			setDisplay()
			ColorPicker.HexInput.InputBox.FocusLost:Connect(function()
				if not pcall(function()
						local r, g, b = string.match(ColorPicker.HexInput.InputBox.Text, "^#?(%w%w)(%w%w)(%w%w)$")
						local rgbColor = Color3.fromRGB(tonumber(r, 16),tonumber(g, 16), tonumber(b, 16))
						h,s,v = rgbColor:ToHSV()
						hex = ColorPicker.HexInput.InputBox.Text
						setDisplay()
						ColorPickerSettings.Color = rgbColor
					end) 
				then 
					ColorPicker.HexInput.InputBox.Text = hex 
				end
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
				local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
				ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
				SaveConfiguration()
			end)
			--RGB
			local function rgbBoxes(box,toChange)
				local value = tonumber(box.Text) 
				local color = Color3.fromHSV(h,s,v) 
				local oldR,oldG,oldB = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
				local save 
				if toChange == "R" then save = oldR;oldR = value elseif toChange == "G" then save = oldG;oldG = value else save = oldB;oldB = value end
				if value then 
					value = math.clamp(value,0,255)
					h,s,v = Color3.fromRGB(oldR,oldG,oldB):ToHSV()

					setDisplay()
				else 
					box.Text = tostring(save)
				end
				local r,g,b = math.floor((h*255)+0.5),math.floor((s*255)+0.5),math.floor((v*255)+0.5)
				ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
				SaveConfiguration()
			end

			ColorPicker.RGB.RInput.InputBox.FocusLost:connect(function()
				rgbBoxes(ColorPicker.RGB.RInput.InputBox,"R")
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
			end)
			ColorPicker.RGB.GInput.InputBox.FocusLost:connect(function()
				rgbBoxes(ColorPicker.RGB.GInput.InputBox,"G")
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
			end)
			ColorPicker.RGB.BInput.InputBox.FocusLost:connect(function()
				rgbBoxes(ColorPicker.RGB.BInput.InputBox,"B")
				pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
			end)

			ColorPicker.HexInput.InputBox.Focused:Connect(function()
				if ColorPickerSettings.Locked then ColorPicker.HexInput.InputBox:ReleaseFocus() return end
			end)
			ColorPicker.RGB.RInput.InputBox.Focused:connect(function()
				if ColorPickerSettings.Locked then ColorPicker.RGB.RInput.InputBox:ReleaseFocus() return end
			end)
			ColorPicker.RGB.GInput.InputBox.Focused:connect(function()
				if ColorPickerSettings.Locked then ColorPicker.RGB.GInput.InputBox:ReleaseFocus() return end
			end)
			ColorPicker.RGB.BInput.InputBox.Focused:connect(function()
				if ColorPickerSettings.Locked then ColorPicker.RGB.BInput.InputBox:ReleaseFocus() return end
			end)

			App.UIService("RunService").RenderStepped:connect(function()
				if mainDragging then 
					local localX = math.clamp(mouse.X-Main.AbsolutePosition.X,0,Main.AbsoluteSize.X)
					local localY = math.clamp(mouse.Y-Main.AbsolutePosition.Y,0,Main.AbsoluteSize.Y)
					Main.MainPoint.Position = UDim2.new(0,localX-Main.MainPoint.AbsoluteSize.X/2,0,localY-Main.MainPoint.AbsoluteSize.Y/2)
					s = localX / Main.AbsoluteSize.X
					v = 1 - (localY / Main.AbsoluteSize.Y)
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					SaveConfiguration()
				end
				if sliderDragging then 
					local localX = math.clamp(mouse.X-Slider.AbsolutePosition.X,0,Slider.AbsoluteSize.X)
					h = localX / Slider.AbsoluteSize.X
					Display.BackgroundColor3 = Color3.fromHSV(h,s,v)
					Slider.SliderPoint.Position = UDim2.new(0,localX-Slider.SliderPoint.AbsoluteSize.X/2,0.5,0)
					Slider.SliderPoint.ImageColor3 = Color3.fromHSV(h,1,1)
					Background.BackgroundColor3 = Color3.fromHSV(h,1,1)
					Main.MainPoint.ImageColor3 = Color3.fromHSV(h,s,v)
					local color = Color3.fromHSV(h,s,v) 
					local r,g,b = math.floor((color.R*255)+0.5),math.floor((color.G*255)+0.5),math.floor((color.B*255)+0.5)
					ColorPicker.RGB.RInput.InputBox.Text = tostring(r)
					ColorPicker.RGB.GInput.InputBox.Text = tostring(g)
					ColorPicker.RGB.BInput.InputBox.Text = tostring(b)
					ColorPicker.HexInput.InputBox.Text = string.format("#%02X%02X%02X",color.R*0xFF,color.G*0xFF,color.B*0xFF)
					pcall(function()ColorPickerSettings.Callback(Color3.fromHSV(h,s,v))end)
					ColorPickerSettings.Color = Color3.fromRGB(r,g,b)
					SaveConfiguration()
				end
			end)

			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and ColorPickerSettings.Flag then
					RayfieldLibrary.Flags[ColorPickerSettings.Flag] = ColorPickerSettings
				end
			end

			function ColorPickerSettings:Set(RGBColor)
				ColorPickerSettings.Color = RGBColor
				h,s,v = ColorPickerSettings.Color:ToHSV()
				color = Color3.fromHSV(h,s,v)
				setDisplay()
			end
			function ColorPickerSettings:Destroy()
				ColorPicker:Destroy()
			end
			function ColorPickerSettings:Lock(Reason)
				if ColorPickerSettings.Locked then return end
				ColorPicker.ColorPickerIs.Value = false
					opened = false
					ColorPicker.ColorSlider.Visible = false
					ColorPicker.HexInput.Visible = false
					ColorPicker.RGB.Visible = false
					TweenService:Create(ColorPicker, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0,465, 0,40)}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 39, 0, 22)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 1, 0)}):Play()
					TweenService:Create(ColorPicker.Interact, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
					TweenService:Create(ColorPicker.RGB, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 70)}):Play()
					TweenService:Create(ColorPicker.HexInput, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 17, 0, 90)}):Play()
					TweenService:Create(Display, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
					TweenService:Create(Main.MainPoint, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(Main, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
					TweenService:Create(Background, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundTransparency = 1}):Play()
				ColorPicker.Lock.Reason.Text = Reason or 'Locked'
				ColorPickerSettings.Locked = true
				TweenService:Create(ColorPicker.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(ColorPicker.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not ColorPickerSettings.Locked then return end --no icon bug
				TweenService:Create(ColorPicker.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			function ColorPickerSettings:Unlock()
				if not ColorPickerSettings.Locked then return end
				ColorPickerSettings.Locked = false
				wait(0.2)
				TweenService:Create(ColorPicker.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				if ColorPickerSettings.Locked then return end --no icon bug
				TweenService:Create(ColorPicker.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(ColorPicker.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function ColorPickerSettings:Visible(bool)
				ColorPicker.Visible = bool
			end
			return ColorPickerSettings
		end

		function Tab:CreateSlider(SliderSettings)
			local Dragging = false
			local Slider = Elements.Template.Slider:Clone()
			Slider.Name = SliderSettings.Name
			Slider.Title.Text = SliderSettings.Name
			Slider.Visible = true
			Tab.Elements[SliderSettings.Name] = {
				type = 'slider',
				section = SliderSettings.SectionParent,
				element = Slider
			}
			if SliderSettings.SectionParent then
				Slider.Parent = SliderSettings.SectionParent.Holder
			else
				Slider.Parent = TabPage
			end

			Slider.BackgroundTransparency = 1
			Slider.UIStroke.Transparency = 1
			Slider.Title.TextTransparency = 1

			if SelectedTheme ~= RayfieldLibrary.Theme.Default then
				Slider.Main.Shadow.Visible = false
			end

			Slider.Main.BackgroundColor3 = SelectedTheme.SliderBackground
			Slider.Main.UIStroke.Color = SelectedTheme.SliderStroke
			Slider.Main.Progress.BackgroundColor3 = SelectedTheme.SliderProgress

			TweenService:Create(Slider, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
			TweenService:Create(Slider.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			TweenService:Create(Slider.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()	

			Slider.Main.Progress.Size =	UDim2.new(0, Slider.Main.AbsoluteSize.X * ((SliderSettings.CurrentValue + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (SliderSettings.CurrentValue / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)

			if not SliderSettings.Suffix then
				Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue)
			else
				Slider.Main.Information.Text = tostring(SliderSettings.CurrentValue) .. " " .. SliderSettings.Suffix
			end


			Slider.MouseEnter:Connect(function()
				TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackgroundHover}):Play()
			end)
                        Slider.Main.Interact.MouseLeave:Connect(function()
				Dragging = false
			end)
			Slider.MouseLeave:Connect(function()
				TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
			end)
			local function UpdateSlider(X)
				local Current = Slider.Main.Progress.AbsolutePosition.X + Slider.Main.Progress.AbsoluteSize.X
				local Start = Current
				local Location = X
				
				Location = UserInputService:GetMouseLocation().X
				Current = Current + 0.025 * (Location - Start)

				if Location < Slider.Main.AbsolutePosition.X then
					Location = Slider.Main.AbsolutePosition.X
				elseif Location > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
					Location = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
				end

				if Current < Slider.Main.AbsolutePosition.X + 5 then
					Current = Slider.Main.AbsolutePosition.X + 5
				elseif Current > Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X then
					Current = Slider.Main.AbsolutePosition.X + Slider.Main.AbsoluteSize.X
				end

				if Current <= Location and (Location - Start) < 0 then
					Start = Location
				elseif Current >= Location and (Location - Start) > 0 then
					Start = Location
				end
				TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, Location - Slider.Main.AbsolutePosition.X > 5 and Location - Slider.Main.AbsolutePosition.X or 5, 1, 0)}):Play()
				local NewValue = SliderSettings.Range[1] + (Location - Slider.Main.AbsolutePosition.X) / Slider.Main.AbsoluteSize.X * (SliderSettings.Range[2] - SliderSettings.Range[1])

				NewValue = math.floor(NewValue / SliderSettings.Increment + 0.5) * (SliderSettings.Increment * 10000000) / 10000000
				if not SliderSettings.Suffix then
					Slider.Main.Information.Text = tostring(NewValue)
				else
					Slider.Main.Information.Text = tostring(NewValue) .. " " .. SliderSettings.Suffix
				end

				if SliderSettings.CurrentValue ~= NewValue then
					local Success, Response = pcall(function()
						SliderSettings.Callback(NewValue)
					end)
					if not Success then
						TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
						TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
						Slider.Title.Text = "Callback Error"
						print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(Response))
						wait(0.5)
						Slider.Title.Text = SliderSettings.Name
						TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
						TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					end

					SliderSettings.CurrentValue = NewValue
					SaveConfiguration()
				end
			end
			Slider.Main.Interact.MouseButton1Down:Connect(function(X)
				if not SliderSettings.Locked then 
					UpdateSlider(X)
					Dragging = true 
				end 
			end)
			Slider.Main.Interact.MouseButton1Up:Connect(function(X) 
				Dragging = false 
			end)
			Slider.Main.Interact.MouseMoved:Connect(function(X)
				if SliderSettings.Locked then return end
				if Dragging then
					UpdateSlider(X)
				end
			end)

			function SliderSettings:Set(NewVal)
				TweenService:Create(Slider.Main.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, Slider.Main.AbsoluteSize.X * ((NewVal + SliderSettings.Range[1]) / (SliderSettings.Range[2] - SliderSettings.Range[1])) > 5 and Slider.Main.AbsoluteSize.X * (NewVal / (SliderSettings.Range[2] - SliderSettings.Range[1])) or 5, 1, 0)}):Play()
				Slider.Main.Information.Text = tostring(NewVal) .. " " .. SliderSettings.Suffix
				local Success, Response = pcall(function()
					SliderSettings.Callback(NewVal)
				end)
				if not Success then
					TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = Color3.fromRGB(85, 0, 0)}):Play()
					TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 1}):Play()
					Slider.Title.Text = "Callback Error"
					print("Rayfield | "..SliderSettings.Name.." Callback Error " ..tostring(Response))
					wait(0.5)
					Slider.Title.Text = SliderSettings.Name
					TweenService:Create(Slider, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {BackgroundColor3 = SelectedTheme.ElementBackground}):Play()
					TweenService:Create(Slider.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
				end
				SliderSettings.CurrentValue = NewVal
				SaveConfiguration()
			end
			function SliderSettings:Destroy()
				Slider:Destroy()
			end
			function SliderSettings:Lock(Reason)
				if SliderSettings.Locked then return end
				SliderSettings.Locked = true
				Slider.Lock.Reason.Text = Reason or 'Locked'
				TweenService:Create(Slider.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
				TweenService:Create(Slider.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
				wait(0.2)
				if not SliderSettings.Locked then return end --no icon bug
				TweenService:Create(Slider.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 0}):Play()
			end
			function SliderSettings:Unlock()
				if not SliderSettings.Locked then return end
				SliderSettings.Locked = false
				wait(0.2)
				TweenService:Create(Slider.Lock.Reason.Icon,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{ImageTransparency = 1}):Play()
				if SliderSettings.Locked then return end --no icon bug
				TweenService:Create(Slider.Lock,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
				TweenService:Create(Slider.Lock.Reason,TweenInfo.new(0.4,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{TextTransparency = 1}):Play()
			end
			function SliderSettings:Visible(bool)
				Slider.Visible = bool
			end
			if Settings.ConfigurationSaving then
				if Settings.ConfigurationSaving.Enabled and SliderSettings.Flag then
					RayfieldLibrary.Flags[SliderSettings.Flag] = SliderSettings
				end
			end
			return SliderSettings
		end


		return Tab
	end
	
	Elements.Visible = true

	wait(1.2)
	TweenService:Create(LoadingFrame.Title, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(LoadingFrame.Subtitle, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	TweenService:Create(LoadingFrame.Version, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {TextTransparency = 1}):Play()
	wait(0.2)
	TweenService:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {Size = UDim2.new(0, 500, 0, 475)}):Play()
	TweenService:Create(Main.Shadow.Image, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.4}):Play()

	Topbar.BackgroundTransparency = 1
	Topbar.Divider.Size = UDim2.new(0, 0, 0, 1)
	Topbar.CornerRepair.BackgroundTransparency = 1
	Topbar.Title.TextTransparency = 1
	Topbar.Theme.ImageTransparency = 1
	Topbar.ChangeSize.ImageTransparency = 1
	Topbar.Hide.ImageTransparency = 1

	wait(0.8)
	Topbar.Visible = true
	TweenService:Create(Topbar, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	TweenService:Create(Topbar.CornerRepair, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {BackgroundTransparency = 0}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Divider, TweenInfo.new(1, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, 1)}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Title, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Theme, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
	wait(0.1)
	TweenService:Create(Topbar.ChangeSize, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
	wait(0.1)
	TweenService:Create(Topbar.Hide, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
	wait(0.3)
	function Window:Prompt(PromptSettings)
		local PromptUI = Prompt.Prompt
		Prompt.Visible = true
		Prompt.BackgroundTransparency = 1
		PromptUI.BackgroundTransparency = 1
		PromptUI.UIStroke.Transparency = 1
		PromptUI.Content.TextTransparency = 1
		PromptUI.Title.TextTransparency = 1
		PromptUI.Sub.TextTransparency = 1
		PromptUI.Size = UDim2.new(0,340,0,140)
		PromptUI.Buttons.Template.Visible = false
		PromptUI.Buttons.Template.TextLabel.TextTransparency = 1
		PromptUI.Buttons.Template.UIStroke.Transparency = 1
		--PromptUI.Buttons.Middle.Visible = false
		--PromptUI.Buttons.Middle.TextLabel.TextTransparency = 1
		--PromptUI.Buttons.Middle.UIStroke.Transparency = 1

		PromptUI.Content.Text = PromptSettings.Content
		PromptUI.Sub.Text = PromptSettings.SubTitle or ''
		PromptUI.Title.Text = PromptSettings.Title or ''

		if PromptSettings.Actions then
			for name,info in pairs(PromptSettings.Actions) do
				local Button = PromptUI.Buttons.Template:Clone()
				Button.TextLabel.Text = info.Name
				Button.Interact.MouseButton1Up:Connect(function()
					if not clicked then
						local Success, Response = pcall(info.Callback)
						clicked = true
						if not Success then
							ClosePrompt()
							print("Rayfield | "..info.Name.." Callback Error " ..tostring(Response))
						else
							ClosePrompt()
						end
					end
				end)
				Button.Name = name
				Button.Parent = PromptUI.Buttons -- saving memory
				Button.Size = UDim2.fromOffset(Button.TextLabel.TextBounds.X + 24, 30)
			end
		end

		TweenService:Create(Prompt, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundTransparency = .5}):Play()
		wait(.2)
		TweenService:Create(PromptUI, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {BackgroundTransparency = 0,Size = UDim2.new(0,350,0,150)}):Play()
		wait(0.2)
		TweenService:Create(PromptUI.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
		TweenService:Create(PromptUI.Title, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		TweenService:Create(PromptUI.Content, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		TweenService:Create(PromptUI.Sub, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		wait(1)
		if PromptSettings.Actions then
			for _,button in pairs(PromptUI.Buttons:GetChildren()) do
				if button.Name ~= 'Template' and button.Name ~= 'Middle' and button:IsA('Frame') then
					button.Visible = true
					TweenService:Create(button.UIStroke,TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
					TweenService:Create(button.TextLabel,TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
					wait(.8)
				end
			end
		else
			--TweenService:Create(PromptUI.Buttons.Middle.UIStroke,TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Transparency = 0}):Play()
			--TweenService:Create(PromptUI.Buttons.Middle.TextLabel,TweenInfo.new(0.3, Enum.EasingStyle.Quint), {TextTransparency = 0}):Play()
		end
	end
	return Window
end


function RayfieldLibrary:ToggleOldTabStyle(oldTabStyle) 
	if oldTabStyle == nil then oldTabStyle = false end
	
	if oldTabStyle then
		TopList.Visible = true
		Elements.Size = UDim2.new(1, 0, 0, 364)
		Elements.Position = UDim2.new(0.5, 0, 0.5, 45)
		
		Topbar.Type.Visible = false
		Topbar.Title.Position = UDim2.new(0, 15, 0.5, 0)
	else
		TopList.Visible = false
		Elements.Size = UDim2.new(1, 0,0, 409)
		Elements.Position = UDim2.new(0.5, 0, 0.555, 0)
		
		Topbar.Type.Visible = true
		Topbar.Title.Position = UDim2.new(0, 45, 0.5, 0)
	end
end

function RayfieldLibrary:Destroy()
	App.Disconnect(App.classicConnections)
	App.CleanupClassic()
	neon:Destroy()
	Rayfield:Destroy()
end

Topbar.ChangeSize.MouseButton1Click:Connect(function()
	if Debounce then return end
	if Minimised then
		Minimised = false
		Maximise()
	else
		if not SearchHided then SearchHided = true spawn(CloseSearch)  end
		Minimised = true
		Minimise()
	end
end)
Topbar.Search.MouseButton1Click:Connect(function()
	if Debounce or Minimised then return end
	if SearchHided then
		OpenSearch()
		SearchHided = false
	else
		SearchHided = true
		CloseSearch()
	end
end)
Topbar.Type.MouseButton1Click:Connect(function()
	if Debounce or Minimised then return end
	if SideBarClosed then
		-- Topbar.Type.Image = "rbxassetid://"..6023565894
		OpenSideBar()
	else
		-- Topbar.Type.Image = "rbxassetid://"..6023565896
		CloseSideBar()
	end
end)
Topbar.Hide.MouseButton1Click:Connect(function()
	if Debounce then return end
	if Hidden then
		Hidden = false
		Minimised = false
		Unhide()
	else
		if not SearchHided then SearchHided = true spawn(CloseSearch)  end
		Hidden = true
		Hide()
	end
end)

-- Topbar.Theme.MouseButton1Click:Connect(function()
	-- if Debounce then return end
	-- if SelectedTheme == RayfieldLibrary.Theme.Default then
		-- ChangeTheme("Light")
	-- else
		-- ChangeTheme("Default")
	-- end
-- end)


for _, TopbarButton in ipairs(Topbar:GetChildren()) do
	if TopbarButton.ClassName == "ImageButton" then
		TopbarButton.MouseEnter:Connect(function()
			if TopbarButton.Name ~= 'Type' then
				TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			else
				TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.2}):Play()
			end
		end)
		TopbarButton.MouseLeave:Connect(function()
			if TopbarButton.Name ~= 'Type' then
				TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
			else
				TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
			end
		end)

		TopbarButton.MouseButton1Click:Connect(function()
			TweenService:Create(TopbarButton, TweenInfo.new(0.7, Enum.EasingStyle.Quint), {ImageTransparency = 0.8}):Play()
		end)
	end
end


function RayfieldLibrary:LoadConfiguration()
	if CEnabled then
		pcall(function()
			if isfile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension) then
				LoadConfiguration(readfile(ConfigurationFolder .. "/" .. CFileName .. ConfigurationExtension))
				RayfieldLibrary:Notify({Title = "Configuration Loaded", Content = "The configuration file for this script has been loaded from a previous session"})
			end
		end)
	end
end

function RayfieldLibrary:SaveConfiguration()
	SaveConfiguration()
end

if false then -- Profile loading is owned by Lucky Blessing, not the UI fork.
	task.delay(9, RayfieldLibrary.LoadConfiguration, RayfieldLibrary)
end


function RayfieldLibrary:SetVisibility(visible)
    if visible then
        if Hidden then Hidden = false; Minimised = false; Unhide()
        elseif Minimised then Minimised = false; Maximise() end
    elseif not Hidden then
        if not SearchHided then SearchHided = true; CloseSearch() end
        Hidden = true; Hide()
    end
end
function RayfieldLibrary:IsVisible() return not Hidden end
function RayfieldLibrary:ModifyTheme(theme)
    if RayfieldLibrary.Theme[theme] then ChangeTheme(theme) end
end

RayfieldLibrary.UI = Rayfield
return RayfieldLibrary

end

-- Lucky Blessing repair: the user's original presets, categories and controls.
local Legacy = Services.Http:JSONDecode([==[{"presets":[{"label":"Left To Die (Damned)","id":"damn","stats":{"atkmod":1200,"healthmod":500,"defmod":500,"stammod":2300,"shovemod":1950,"lightatkspeed":1200,"heavyatkspeed":9999,"recoilmod":134,"harvestmod":100,"accmod":100,"reloadmod":250,"noaimmod":false,"bleed_immune":true,"mvtmod":100,"aegisduration":"Infinity","aegisdamagetakenmelee":0,"aegisrangeddamagemultiplier":50,"cooldown":0},"ui":{"name":"The Cursed one","desc":"You are strong yes but locked in these chains like a prisoner is there any way to live?..","pros":["Immune to bleeding","Extra M1 Damage","Higher defense"],"cons":["People will dislike you."],"activename":"Condemmed for the life you done.","activedetails":"You hear the laugh from the Ulaycylon higher up leaving you to die."},"active":{},"source_line":857},{"label":"Modded Damned","id":"damn","stats":{"atkmod":1950,"healthmod":999999,"defmod":1500,"stammod":5000,"shovemod":1950,"lightatkspeed":1950,"heavyatkspeed":1950,"recoilmod":2000,"harvestmod":100,"accmod":1950,"reloadmod":25000,"noaimmod":false,"bleed_immune":true,"mvtmod":100,"aegisduration":"Infinity","aegisdamagetakenmelee":0,"aegisrangeddamagemultiplier":10000,"cooldown":0},"ui":{"name":"The Cursed one","desc":"You are strong yes but locked in these chains like a prisoner is this any way to live?.","pros":["Immune to bleeding","Extra M1 Damage","Higher defense"],"cons":["People will dislike you."],"activename":"Tanziner","activedetails":"A man of his word."},"active":{},"source_line":894},{"label":"The Counter (Damned)","id":"damn","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"scavmod":4000,"lightatkspeed":1500,"heavyatkspeed":1500,"recoilmod":1950,"harvestmod":1950,"accmod":1950,"reloadmod":999999,"noaimmod":false,"bleed_immune":true,"mvtmod":100,"aegisduration":"Infinity","aegisdamagetakenmelee":0,"aegisrangeddamagemultiplier":999999,"cooldown":-1950,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":999999,"grap":false,"backpack":true,"falldamagemod":true,"craftcostmod":-150,"explosive_resist":true},"ui":{"name":"The Counter","desc":"Impossible to die.","pros":["Immune to bleeding","Extra M1 Damage","Higher defense"],"cons":["Literally UnKillable."],"activename":"Tanziner","activedetails":"The Devil."},"active":{},"source_line":929},{"label":"Deadlock (Crosslink)","id":"wire","stats":{"atkmod":17.55,"healthmod":99999,"defmod":35,"stammod":300,"shovemod":12,"lightatkspeed":40,"heavyatkspeed":45,"recoilmod":-25,"accmod":-35,"reloadmod":-15,"noaimmod":false,"scavmod":40,"harvestmod":100,"mvtmod":25,"explosivemod":400,"falldamagemod":true,"craftcostmod":10,"explosive_resist":true},"ui":{"name":"Deadlock","desc":"My territory My rule","pros":["Increased melee damage","Increase shove speed","Heavily increase melee swing"],"cons":["Do not use guns.","No immunities"],"activename":"Sentinel nanowires","activedetails":"You arent Norwegian meaning no Ahnialation skill issue dawg. (Normal crosslink wires)"},"active":{},"source_line":976},{"label":"Death Squad (Zealot)","id":"shield","stats":{"atkmod":35,"healthmod":135,"defmod":1250,"stammod":200,"shovemod":155,"lightatkspeed":150,"heavyatkspeed":200,"recoilmod":500,"accmod":690,"reloadmod":546,"noaimmod":false,"scavmod":2000,"harvestmod":690,"mvtmod":100,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-5,"aegisduration":"Infinity","aegisdamagetakenmelee":0,"aegisrangeddamagemultiplier":50,"cooldown":0,"explosive_resist":true},"ui":{"name":"Death Squad ","desc":"Welcome Agent you are drafted as a Death Squad Agent. Do not dissapoint us You will recive punishment upon on failed","pros":["Increased defense heavily","Damage with melee heavily increased","Pray to the god you belive in"],"cons":["The hardsuit takes heavy damage by explosion avoid them."],"activename":"Death Squad HardSuit","activedetails":"> DO NOT HARM DEATH SQUAD AGENTS             >ELIMINATE ALL COTESTANTS                                    >PROTECT YOUR OWN EXSISTENCE"},"active":{"cooldown":0},"source_line":1010},{"label":"Mad Lad (Berserker)","id":"berz","stats":{"atkmod":450,"healthmod":135,"defmod":350,"stammod":590,"shovemod":10,"lightatkspeed":140,"heavyatkspeed":255,"recoilmod":10,"accmod":10,"reloadmod":10,"noaimmod":false,"scavmod":100,"harvestmod":100,"mvtmod":40,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":100,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":1000,"explosive_resist":true},"ui":{"name":"Mad Lad","desc":"HOW ARE YOU EVEN ALIVE!!?!??!?","pros":["Apparently overdosing 347262657 C.Serum is good","You do stupid amout of power with melee."],"cons":["DO NOT USE GUNS AT ALL","Explosive hurt","Imagine shoving lmao"],"activename":"By Sasquatch_htv","activedetails":"Why are you using more SERUM?!?!?! IS 347262657 not ENOUGH"},"active":{},"source_line":1074},{"label":"Fagabond (Vagabond)","id":"sword","stats":{"atkmod":1950,"healthmod":250,"defmod":1500,"stammod":5000,"shovemod":1950,"lightatkspeed":100,"heavyatkspeed":1950,"recoilmod":2000,"accmod":1950,"reloadmod":900,"noaimmod":false,"scavmod":4000,"harvestmod":100,"mvtmod":40,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-55,"explosive_resist":true},"ui":{"name":"Master swords man","desc":"Your not a vagabond your the master of it","pros":["More Ammunition.","Speed, No Fall Dmg, No Explosive dmg, and take barely any HP upon shot.","0 Cooldown","Faster Swings"],"cons":["There are no downsides, your just OP as hell."],"activename":"Arbiter.exe","activedetails":"No more head priviliges"},"active":{},"source_line":1112},{"label":"The Dark Knight (Drifter)","id":"drift","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":19,"lightatkspeed":165,"heavyatkspeed":163,"recoilmod":10,"accmod":10,"reloadmod":1950,"noaimmod":false,"scavmod":100,"harvestmod":100,"mvtmod":65,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-15,"explosive_resist":true},"ui":{"name":"The Darkest Knight","desc":"Keep em coming! the Knight said after taking out the 12th Battallion sent to kill him","pros":["Your great at swordmanship","Defense increased heavily","0 Cooldown","Faster Swings"],"cons":["Do not use guns at all"],"activename":"The blade of Azrael","activedetails":"Thrust the blade to their hearts. By Sasquatvh_htv"},"active":{},"source_line":1151},{"label":"Modern Ninja (Vagabond)","id":"sword","stats":{"atkmod":150,"healthmod":250,"defmod":350,"stammod":5000,"shovemod":1950,"lightatkspeed":150,"heavyatkspeed":125,"recoilmod":150,"accmod":199,"reloadmod":250,"noaimmod":false,"scavmod":1000,"harvestmod":100,"mvtmod":40,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":10,"explosive_resist":true},"ui":{"name":"Modern Ninja","desc":"C̸̖͐a̸̜̾̀n̶̹̈͠ ̵̈́y̶͚͐̒o̶̙͙͂ǘ̵̞̣̕ ̵̱́e̸̩̺̚v̸̂ͅę̶̞̕n̷͖͕͒̚ ̶̣̬́̔s̶̝͖̓ḛ̷̐͗e̴̬̦̿͘ ̷̗̿m̸̟̆̚e̷̟̋͘!̶̯̦̇̾?̷̦͒!̸̫͊̀?̴͉̀̚ Said the Agent cutting the forces one by one without them even know where he is.","pros":["More Ammunition.","Speed","No Fall Dmg","Increase defense heavily","Faster Swings"],"cons":["Is over when someone can destroy you in One Punch©"],"activename":"The M̶̥̻̓o̴̟̹͌̚ö̶͕́̈n̴̨̅̐ ̸̱̰͋K̷̭̞͌͠a̷̭̩̽̊ţ̵̍ā̶͈͈n̴̥̊a̷̯̓̽ Slash","activedetails":"Slash your enemies with a strike that will turn their flesh to paper."},"active":{},"source_line":1192},{"label":"Tanziner (Zealot dont use with DS)","id":"shield","stats":{"atkmod":1950,"healthmod":250,"defmod":1500,"stammod":5000,"shovemod":1950,"lightatkspeed":100,"heavyatkspeed":1950,"recoilmod":2000,"harvestmod":100,"accmod":1950,"reloadmod":250,"noaimmod":false,"bleed_immune":true,"mvtmod":100,"aegisduration":"Infinity","aegisdamagetakenmelee":0,"aegisrangeddamagemultiplier":50,"cooldown":0},"ui":{"name":"Tanziner","desc":"You believe in art of technology.","pros":["Immune to bleeding","Extra M1 Damage","Higher defense"],"cons":["People will dislike you."],"activename":"Tanziner","activedetails":"A Man from 2093."},"active":{},"source_line":1233},{"label":"Sledge Queen (Arbiter)","id":"shotgun","stats":{"atkmod":1950,"healthmod":999999,"defmod":1500,"stammod":5000,"shovemod":1950,"lightatkspeed":500,"heavyatkspeed":1950,"recoilmod":1950,"accmod":1950,"reloadmod":900,"noaimmod":false,"scavmod":1950,"harvestmod":1950,"mvtmod":200,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":1950,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-1000,"explosive_resist":true},"ui":{"name":"Arbiter but you are Sledge Queen","desc":"One of the most strongest boss in the game","pros":["More Ammunition.","Speed, No Fall Dmg, No Explosive dmg, and take barely any HP upon shot.","0 Cooldown","Faster Swings"],"cons":["There are no downsides, your just OP as hell."],"activename":"Arbiter.exe","activedetails":"i dunno."},"active":{},"source_line":1281},{"label":"Yharon (Immolator)","id":"fire","stats":{"atkmod":165,"healthmod":250,"defmod":850,"stammod":5000,"shovemod":10,"lightatkspeed":250,"heavyatkspeed":25,"recoilmod":10,"accmod":1,"reloadmod":1,"noaimmod":false,"scavmod":500,"harvestmod":100,"mvtmod":40,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":999,"explosive_resist":true},"ui":{"name":"The Jungle Dragon","desc":"The enemy ascended beyond your control; Or was that all your intention?","pros":["NOOO YOU CANT JUST HEAL TO FULL HP WHEN I NEARLY KILL YOU","THIS IS A MESSAGE TO MY MASTER"],"cons":["Gotta be honest with you Overheat sucks frfr","Your shit with guns","Do not craft worst mistake of my life"],"activename":"Terraria calamity momento","activedetails":"Script by Sasquatch_htv"},"active":{},"source_line":1321},{"label":"Jericho (Arbiter)","id":"shotgun","stats":{"atkmod":135,"healthmod":250,"defmod":750,"stammod":100,"shovemod":100,"lightatkspeed":135,"heavyatkspeed":125,"recoilmod":2000,"accmod":100,"reloadmod":100,"noaimmod":false,"scavmod":1,"harvestmod":100,"mvtmod":55,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"falldamagemod":true,"craftcostmod":-500,"explosive_resist":true},"ui":{"name":"Agent Jackson 'Jericho' K.","desc":"you know nothing of the bottomless malice within the human heart","pros":["YOU ARE HIM","Sharp you'r blade is dull.","Increased melee damage","Increased swing speed"],"cons":["Even tho you are HIM you still cant revived"],"activename":"Augmentation 'Doom'","activedetails":"Why kolderea? It's the cheapest brand I could find, now leave me alone. -Jackson K.(Agent Jericho)"},"active":{},"source_line":1394},{"label":"Elite Mercenary (Survivalist)","id":"survival","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":500,"heavyatkspeed":1950,"recoilmod":65,"accmod":1900,"reloadmod":1900,"noaimmod":false,"scavmod":1950,"harvestmod":1950,"mvtmod":95,"backpack":true,"explosive_resist":true},"ui":{"name":"Elite Mercenary","desc":"“The justifications of men who kill should always be heard with skepticism, said the monster.” ― Patrick Ness, A Monster Calls","pros":["Gain all trait buffs","Start with all inventory slots","Start Noruished and Quenched"],"cons":["Huh whats a con?","I'm afraid, everything has it's own dark side.","Mercury Infected."],"activename":"Mercenary","activedetails":"Your a Mercenary NOT an Agent. Your hired to clear out eden-227 with Agents for one reason They cant find one more Agent to fill in because of what happened last time."},"active":{"cooldown":0},"source_line":1441},{"label":"Black Death (Executioner)","id":"goggles","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":125,"heavyatkspeed":1950,"recoilmod":2000,"accmod":1950,"noaimmod":false,"scavmod":4000,"harvestmod":100,"mvtmod":90,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"falldamagemod":true,"craftcostmod":-55,"explosive_resist":true},"ui":{"name":"The black death","desc":"“The justifications of men who kill should always be heard with skepticism, said the monster.”― Patrick Ness, A Monster Calls","pros":["Swing and melee damage increased","Increased hip-fire Acruaccy","Crafting increase your salvage","Increase defense slightly"],"cons":["Decreased recoil control","Decreased reload time","Cannot aim at all","Unable to scrap"],"activename":"Death sighting","activedetails":"Reape the tears of the victim crys(Same as normal exe goggles but you gain 35 salvage per bounty)"},"active":{"scrap_per_bounty":35},"source_line":1483},{"label":"Solutist (Sovereign)","id":"dagger","stats":{"atkmod":1950,"healthmod":99999,"defmod":1950,"stammod":500,"shovemod":1950,"lightatkspeed":100,"heavyatkspeed":10,"recoilmod":2000,"accmod":1950,"reloadmod":900,"noaimmod":true,"scavmod":6999,"harvestmod":100,"mvtmod":40,"explosive_resist":true,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-55},"ui":{"name":"S̶͖̆o̶̱͋l̸͈͊û̵̜t̵͙͒i̶̤̚s̴̥̏t̷͈̄","desc":"ɎØɄⱤ Ⱡ₳₵₭ Ø₣ ĐłⱠł₲Ɇ₦₵Ɇ ₴Ʉ₥₥₳ⱤłⱫɆ₴ ɎØɄ","pros":["₮Ⱨ₳₦₭₴ ₣ØⱤ ₮ⱧɆ ₣ⱤɆɆ ₭łⱠⱠ","Guns are cooler than melees","The anarchy collapse"],"cons":["Unable to aim","You cant do Cold Blooded takedown","Wheres's the statue?"],"activename":"By Sasquatch_htv","activedetails":"Go play it yourself why you ask me?"},"active":{},"source_line":1524},{"label":"Thanatos (Apostle Unfinished)","id":"shadow","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":500,"heavyatkspeed":500,"recoilmod":1950,"harvestmod":1950,"accmod":1950,"reloadmod":999999,"noaimmod":false,"bleed_immune":true,"mvtmod":90,"aegisduration":"Infinity","aegisdamagetakenmelee":0,"aegisrangeddamagemultiplier":999999,"cooldown":-1950,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":999999,"grap":false,"backpack":true,"falldamagemod":true,"craftcostmod":-150,"explosive_resist":true},"ui":{"name":"Thanatos","desc":"As they trying to run for their lives you laughed maniacly as you take them out One.. By.. One.","pros":["Reaping souls gives health","Drifting in the ocean all alone"],"cons":["No."],"activename":"Soul Reaoer","activedetails":"Steal a soul for as second chance but you will never become a man. My chosen torture makes me stronger. In a life that craves the hunge. A Freedom and a quest for life. Until the end the judgment night"},"active":{},"source_line":1575},{"label":"RIS Medic (Lazarus)","id":"lazarus","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":125,"heavyatkspeed":1950,"recoilmod":2000,"accmod":1950,"noaimmod":false,"scavmod":4000,"harvestmod":100,"mvtmod":90,"backpack":true,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"falldamagemod":true,"craftcostmod":-55,"explosive_resist":true},"ui":{"name":"R.I.S World War Medic","desc":"When the patient woke up his skeleton was missing and the doctor was never heard ever again *laughs hystericly* and that's how I lost my medical liscene.","pros":["Hurting is more rewarding than hurting","Increase swing speed","Faster movemnt speed","heavily increased hip fire accruacy"],"cons":["Bad recoil control","guns hurt you alot more","HEAVY IS DEAD"],"activename":"TROPIK NCU DEVICE","activedetails":"Somewhere before the exploration of Eden-227. The R.I.S found the location of the Servo factory and sent Scouts to steal as much they can. Which was a huge success and they found the TROPIK NCU DEVICE"},"active":{},"source_line":1623},{"label":"Bulldozer (Riskrunner)","id":"gunner","stats":{"atkmod":45,"healthmod":250,"defmod":900,"stammod":345,"lightatkspeed":-25,"heavyatkspeed":-25,"recoilmod":-100,"accmod":-199,"reloadmod":-1000,"noaimmod":false,"scavmod":4000,"harvestmod":100,"mvtmod":-15,"cripple_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"craftcostmod":-55,"explosive_resist":true},"ui":{"name":"The bulldozer","desc":"You are up agaisnt the wall and I'M THE FUCKING WALL","pros":["Increased melee damage","Heavily HEAVILY increase defense"],"cons":["Slower movement speed.","Slower swing speed","Unable to aim"],"activename":"Vulcan minigun","activedetails":"Give up! And maybe I won't stuff a mudhole in your ass!"},"active":{},"source_line":1674},{"label":"GunSlinger (Artilist)","id":"revolver","stats":{"atkmod":10,"healthmod":250,"defmod":135,"stammod":100,"shovemod":10,"lightatkspeed":100,"heavyatkspeed":100,"recoilmod":1250,"accmod":100,"reloadmod":350,"noaimmod":false,"scavmod":4000,"harvestmod":5000,"mvtmod":65,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":599,"explosive_resist":true},"ui":{"name":"Gunslinger of death","desc":"You may not see them but you already dead without knowing","pros":["Your an expert of gunsmanship","Slightly increased defense","You shall die!"],"cons":["Your shit with melee","Dont shove,Dont craft","Do not die."],"activename":"Rayleigh","activedetails":"Shoot lmao      By Sasquatch_htv"},"active":{},"source_line":1708},{"label":"Hivemaster (Hivemind)","id":"hive","stats":{"atkmod":175,"healthmod":75,"defmod":1950,"stammod":900,"shovemod":1950,"lightatkspeed":300,"heavyatkspeed":275,"recoilmod":2000,"accmod":1950,"reloadmod":900,"noaimmod":false,"scavmod":4000,"harvestmod":100,"mvtmod":40,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-55,"explosive_resist":true},"ui":{"name":"hivemaster","desc":"The whimpers of the victim crys are just one of many","pros":["The Jack of all trades","Your Hivemind will support you.","Slay all."],"cons":["Unlike the rest your weaker"],"activename":"The hive","activedetails":"Reap their souls before they takes your."},"active":{},"source_line":1748},{"label":"The Mother Nature. (Hivemind)","id":"hive","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":1950,"heavyatkspeed":1950,"recoilmod":1250,"accmod":1950,"reloadmod":350,"noaimmod":false,"scavmod":4000,"harvestmod":5000,"mvtmod":120,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":1950,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-599,"explosive_resist":true},"ui":{"name":"The Mother Of Nature.","desc":"You are technically The Monther Of Nature (Earth).","pros":["Annoying","Moss","Bees","Too Green"],"cons":["Trashes","Polutee","Humans","Structures"],"activename":"Nature","activedetails":"Greenie!!! :D"},"active":{},"source_line":1789},{"label":"Sniped (Blitzer)","id":"ranger","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":1950,"heavyatkspeed":1950,"recoilmod":1250,"accmod":1950,"reloadmod":350,"noaimmod":false,"scavmod":4000,"harvestmod":5000,"mvtmod":120,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":400,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-599,"explosive_resist":true},"ui":{"name":"Sniped (Sniper / Ranger)","desc":"Hire this guy for 2000$!!!","pros":["Your an expert of Sniping","Slightly better aim","You shall also die!"],"cons":["Snipe (Obviously)","Kill Itself,Dead","Scam"],"activename":"Sniped","activedetails":"Another goddamn sniper. - Ry"},"active":{},"source_line":1829},{"label":"The traffic worker (Crosslink)","id":"wire","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":1950,"heavyatkspeed":1950,"recoilmod":1250,"accmod":1950,"reloadmod":350,"noaimmod":false,"scavmod":4000,"harvestmod":5000,"mvtmod":120,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":1950,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-599,"explosive_resist":true},"ui":{"name":"The Traffic Worker","desc":"What a long day working in public!","pros":["Wires.","I LIEK ELECTRIC","Town."],"cons":["Work (Too Obvious)","Ice Creams","Always work."],"activename":"Traffic","activedetails":"MUHAHAHAHAHAH. - Ry"},"active":{},"source_line":1869},{"label":"The Rock (Immolator)","id":"fire","stats":{"atkmod":1950,"healthmod":999999,"defmod":1950,"stammod":5000,"shovemod":1950,"lightatkspeed":1950,"heavyatkspeed":1950,"recoilmod":1250,"accmod":1950,"reloadmod":350,"noaimmod":false,"scavmod":4000,"harvestmod":5000,"mvtmod":120,"cripple_immune":true,"exhaust_immune":true,"frac_immune":true,"nomorale":true,"explosivemod":1950,"grap":true,"bleed_immune":true,"backpack":true,"falldamagemod":true,"craftcostmod":-599,"explosive_resist":true},"ui":{"name":"The Rock.","desc":"Always look at the internet and O_o SUSUS","pros":["pro.","cringe destroyer","also orphan"],"cons":["reset everything","love cock","memer"],"activename":"Rock","activedetails":"MUHAHAHAHAHAH. - Ry"},"active":{},"source_line":1910}],"items":[{"label":"Spawn AWP","id":"AWMSniper","section":"Guns","source_line":1978},{"label":"Spawn ScarL","id":"ScarL","section":"Guns","source_line":2003},{"label":"Spawn ScarH","id":"SubScar","section":"Guns","source_line":2028},{"label":"Spawn Hi Capa","id":"STIPistol","section":"Guns","source_line":2053},{"label":"Spawn Modded Pistol","id":"MPistol","section":"Guns","source_line":2077},{"label":"Spawn AK74","id":"SubAK","section":"Guns","source_line":2100},{"label":"Spawn SKS","id":"SKS","section":"Guns","source_line":2123},{"label":"Spawn MCX","id":"SubMCX","section":"Guns","source_line":2147},{"label":"Spawn MPX","id":"SubMPX","section":"Guns","source_line":2170},{"label":"Spawn FAMAS","id":"FAMAS","section":"Guns","source_line":2193},{"label":"Spawn AS Val","id":"ASVal","section":"Guns","source_line":2216},{"label":"Spawn Tommy Gun","id":"TSMG","section":"Guns","source_line":2239},{"label":"Spawn Deagle (MARKVII)","id":"Deagle","section":"Guns","source_line":2263},{"label":"Spawn RSASS","id":"RSASS","section":"Guns","source_line":2285},{"label":"Spawn UMP","id":"UMP","section":"Guns","source_line":2307},{"label":"Spawn M60","id":"SubLMG","section":"Guns","source_line":2330},{"label":"Spawn REDEEMER","id":"MRVolver","section":"Guns","source_line":2353},{"label":"Spawn Benelli","id":"Benelli","section":"Guns","source_line":2376},{"label":"Spawn IZM","id":"SUPSniper","section":"Guns","source_line":2399},{"label":"Spawn Intervention / Sniper","id":"IntSniper","section":"Guns","source_line":2423},{"label":"Spawn M249","id":"FNLMG","section":"Guns","source_line":2446},{"label":"Spawn AKM","id":"SUPAK","section":"Guns","source_line":2469},{"label":"Spawn Milbow","id":"CPBow","section":"Guns","source_line":2493},{"label":"Spawn AA12","id":"AAShotgun","section":"Guns","source_line":2516},{"label":"Spawn Vector","id":"SubVector","section":"Guns","source_line":2539},{"label":"Spawn Avtomat","id":"Avto","section":"Guns","source_line":2562},{"label":"Spawn KSG","id":"KSG","section":"Guns","source_line":2586},{"label":"Spawn AJM","id":"AJM","section":"Guns","source_line":2609},{"label":"Spawn Hemostatic Stim","id":"AdrStim","section":"stims","source_line":2634},{"label":"Spawn Orange Stim","id":"SStim","section":"stims","source_line":2657},{"label":"Spawn Blue Stim","id":"SPDStim","section":"stims","source_line":2680},{"label":"Spawn Green Stim","id":"DEFStim","section":"stims","source_line":2703},{"label":"Spawn Red Stim","id":"HStim","section":"stims","source_line":2727},{"label":"Spawn Purple Stim","id":"DStim","section":"stims","source_line":2750},{"label":"Spawn Used Stim (Useless)","id":"TStim","section":"stims","source_line":2773},{"label":"Spawn Decimator","id":"RBHammer","section":"melee","source_line":2799},{"label":"Spawn Reikgon Hand","id":"THand","section":"melee","source_line":2822},{"label":"Spawn Maria","id":"NailedB","section":"melee","source_line":2846},{"label":"Spawn Exe sword","id":"ExecSword","section":"melee","source_line":2869},{"label":"Spawn Fire axe","id":"FAxe","section":"melee","source_line":2892},{"label":"Spawn BllHook","id":"BHook","section":"melee","source_line":2916},{"label":"Bad Bat","id":"BadBat","section":"melee","source_line":2939},{"label":"Spawn Firerier Axe","id":"DFAxe","section":"melee","source_line":2963},{"label":"Spawn Great Sword","id":"GSword","section":"melee","source_line":2986},{"label":"Spawn Estoc","id":"ESword","section":"melee","source_line":3010},{"label":"Spawn Specalist Knife (Karambit)","id":"KaramB","section":"melee","source_line":3034},{"label":"Spawn Halberd","id":"HBerd","section":"melee","source_line":3058},{"label":"Spawn Frying Pan (L4D2 Moment)","id":"FPan","section":"melee","source_line":3082},{"label":"Spawn SClaw","id":"SClaw","section":"melee","source_line":3105},{"label":"Spawn HyperLame","id":"Hyperlame","section":"melee","source_line":3127},{"label":"Spawn Brass Knuckles","id":"BKnuckles","section":"melee","source_line":3151},{"label":"Spawn Sledgehammer *BONK*","id":"SHammer","section":"melee","source_line":3176},{"label":"Spawn Advanced IFAK","id":"FAid","section":"Heal","source_line":3201},{"label":"Spawn Pain killers","id":"PKillers","section":"Heal","source_line":3224},{"label":"Spawn Crude Bandage","id":"CRBandage","section":"Heal","source_line":3247},{"label":"Spawn Armor","id":"APack","section":"Heal","source_line":3270},{"label":"Spawn Backpack","id":"BPack","section":"Heal","source_line":3294},{"label":"Spawn AntiB / Pain Killers v2","id":"IbuP","section":"Heal","source_line":3318},{"label":"Spawn Splint","id":"Splint","section":"Heal","source_line":3341},{"label":"Spawn Tourni","id":"Tourni","section":"Heal","source_line":3365},{"label":"Spawn Tear Gas","id":"TGas","section":"Throw","source_line":3391},{"label":"Spawn Caltrops","id":"TCaltrop","section":"Throw","source_line":3414},{"label":"Spawn M67 Grenade","id":"MGrenade","section":"Throw","source_line":3438},{"label":"Spawn Molotov","id":"Molo","section":"Throw","source_line":3462},{"label":"Spawn Steel Snares","id":"SSnare","section":"Throw","source_line":3486},{"label":"Spawn Proximity Mine","id":"PMine","section":"Throw","source_line":3509},{"label":"Spawn Punji","id":"PTrap","section":"Throw","source_line":3532},{"label":"Spawn Remote Explosive","id":"RExplosive","section":"Throw","source_line":3555},{"label":"Spawn Hunting Axe","id":"TAxe","section":"Throw","source_line":3579},{"label":"Spawn Impact Grenade","id":"ImpN","section":"Throw","source_line":3603},{"label":"Spawn Dynamite","id":"Dynamite","section":"Throw","source_line":3628}],"externals":[{"label":"SasSledge Free","urls":["https://raw.githubusercontent.com/sasquatchhtv/Decayingbitches/main/DW-Script-1.75"],"source_line":80,"section":null},{"label":"SasSledge Premium","urls":["https://raw.githubusercontent.com/sasquatchhtv/SasDWPremium/main/Obfuscated"],"source_line":86,"section":null},{"label":"ESP [M TO REFRESH]","urls":["https://raw.githubusercontent.com/bigblackmonkeyboi/scip/main/Decaying-Winter-Esp.lua"],"source_line":602,"section":"windowSettings"},{"label":"Speed Boost (KeyBind: L)","urls":["https://raw.githubusercontent.com/ryderfreeman/decaying-winter-old-goodwill/main/script1"],"source_line":611,"section":"windowSettings"},{"label":"Extra Ability ( R ; Y ; B ; U ; J ; M)","urls":["https://raw.githubusercontent.com/IrishBaker/scripts/main/decaying%20winter/Announce.lua","https://raw.githubusercontent.com/IrishBaker/scripts/main/decaying%20winter/Auto%20Finish.lua","https://raw.githubusercontent.com/IrishBaker/scripts/main/decaying%20winter/Longer%20Effects.lua","https://raw.githubusercontent.com/IrishBaker/scripts/main/decaying%20winter/Passive%20Heal.lua"],"source_line":619,"section":"Ess"},{"label":"Devil Hunter Animation","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Devil%20Hunter.lua"],"source_line":1362,"section":"modp"},{"label":"Jericho Animation","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/J.lua"],"source_line":1386,"section":"modp"},{"label":"Semi-Godmode (Lazarus / Kick Risk / Made by Snowy)","urls":["https://raw.githubusercontent.com/RyAtlasX/ID/main/Semi"],"source_line":1664,"section":"modp"},{"label":"Teleport SledgeQueen","urls":["https://raw.githubusercontent.com/bigblackmonkeyboi/scip/main/Sledgequeentp.lua"],"source_line":3808,"section":null},{"label":"Teleport ALL Scavengers","urls":["https://raw.githubusercontent.com/bigblackmonkeyboi/scip/main/tp-all-enemy-to-you-in-dw.lua"],"source_line":3815,"section":null},{"label":"Control Scav interface (lag)","urls":["https://raw.githubusercontent.com/IncorrectDecisions/silver-octo-adventure/main/DW%20Control%20GUI.lua"],"source_line":3884,"section":null},{"label":"Executor Functions Tester (Check Console After Clicking)","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Exect%20Tester.lua"],"source_line":3912,"section":null},{"label":"Music / Theme Songs","urls":["https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"],"source_line":3920,"section":null},{"label":"Toggle Netless","urls":["https://raw.githubusercontent.com/KattWasTaken/pepsi_hub/main/netless.txt"],"source_line":4515,"section":"Net"},{"label":" FE Physics Gun","urls":["https://raw.githubusercontent.com/RyAtlasX/Roblox_Scripts/main/FE%20Physics%20Gun.lua"],"source_line":4549,"section":"RCH"},{"label":" VAPE V4","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/VAPE%20V4%20%5Bbedwar%5D"],"source_line":4557,"section":"RCH"},{"label":" Proton Free / Proton Admin","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Proton%20Free.lua"],"source_line":4565,"section":"RCH"},{"label":" Infinite Yield v5.9.3","urls":["https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"],"source_line":4573,"section":"RCH"},{"label":" Nameless Admin","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Nameless%20Admin.lua"],"source_line":4581,"section":null},{"label":" CMD X v1.9.9F","urls":["https://raw.githubusercontent.com/CMD-X/CMD-X/master/CMD-X"],"source_line":4588,"section":"RCH"},{"label":" Localscript Anti Kick","urls":["https://raw.githubusercontent.com/Exunys/Anti-Kick/main/Anti%20Kick.lua"],"source_line":4596,"section":"RCH"},{"label":" Anti Fling","urls":["https://raw.githubusercontent.com/KattWasTaken/pepsi_hub/main/AntiFling"],"source_line":4604,"section":"RCH"},{"label":" Hydroxide","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Hydroxide"],"source_line":4612,"section":"RCH"},{"label":" Orca v1.1.1","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Orca"],"source_line":4619,"section":"RCH"},{"label":" Domain X v1.96","urls":["https://raw.githubusercontent.com/fortnitemodder/DomainX/main/Source"],"source_line":4626,"section":"RCH"},{"label":" Eclipse Hub v0.88","urls":["https://raw.githubusercontent.com/RyAtlasX/Roblox_Scripts/main/Eclipse%20hub.lua"],"source_line":4634,"section":"RCH"},{"label":" FE Front Flip","urls":["https://pastebin.com/raw/8vFCxMWT"],"source_line":4642,"section":"RCH"},{"label":" FE invis tool","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/invis2tool.lua"],"source_line":4650,"section":"RCH"},{"label":" Ry's Enhancer v0.1","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/FUCKING%20SHADERS"],"source_line":4658,"section":"RCH"},{"label":" RTX | Shader","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/RTX.lua"],"source_line":4694,"section":"RCH"},{"label":" Self Moderator","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Fake%20Self%20Ban.lua"],"source_line":4731,"section":"RCH"},{"label":" Dabbing Animation","urls":["https://rawscripts.net/raw/Universal-Script-FE-Dab-8883"],"source_line":4739,"section":"RCH"},{"label":" Ball Rolling Animation | Patched","urls":["https://rawscripts.net/raw/Universal-Script-FE-Ball-Roll-8881"],"source_line":4746,"section":"RCH"},{"label":" Fast animations","urls":["https://pastebin.com/raw/8DKHE7sd"],"source_line":4753,"section":"RCH"},{"label":" Proximity Prompt Bypass","urls":["https://raw.githubusercontent.com/RyAtlasX/Script-Storages/main/Proximity%20Prompt%20bypass.lua"],"source_line":4761,"section":null}],"facts":[{"title":"The Black Death (also known as the Pestilence, the Great Mortality or the Plague)","content":"Was a bubonic plague pandemic occurring in Western Eurasia and North Africa from 1346 to 1353. It is the most fatal pandemic recorded in human history, causing the deaths of 75–200 million people, peaking in Europe from 1347 to 1351. Bubonic plague is caused by the bacterium Yersinia pestis spread by fleas, but during the Black Death it probably also took a secondary form, spread by person-to-person contact via aerosols, causing pneumonic plague. The Black Death was the beginning of the second plague pandemic. The plague created religious, social and economic upheavals, with profound effects on the course of European history. The origin of the Black Death is disputed. Genetic analysis points to the evolution of Yersinia pestis in the Tian Shan mountains on the border between Kyrgyzstan and China 2,600 years ago. The immediate territorial origins of the Black Death and its outbreak remains unclear with some pointing towards Central Asia, China, the Middle East, and Europe. The pandemic was reportedly first introduced to Europe during the siege of the Genoese trading port of Kaffa in Crimea by the Golden Horde army of Jani Beg in 1347. From Crimea, it was most likely carried by fleas living on the black rats that travelled on Genoese ships, spreading through the Mediterranean Basin and reaching North Africa, Western Asia, and the rest of Europe via Constantinople, Sicily, and the Italian Peninsula. There is evidence that once it came ashore, the Black Death mainly spread from person-to-person as pneumonic plague, thus explaining the quick inland spread of the epidemic, which was faster than would be expected if the primary vector was rat fleas causing bubonic plague. In 2022, it was discovered that there was a sudden spread may not have been due to Mongol conquests in the 14th century, as previously speculated."},{"title":"The Vietnam War (also known by other names)","content":"was a conflict in Vietnam, Laos, and Cambodia from 1 November 1955 to the fall of Saigon on 30 April 1975. It was the second of the Indochina Wars and was officially fought between North Vietnam and South Vietnam. The north was supported by the Soviet Union, China, and other communist states, while the south was supported by the United States and other anti-communist allies. The war is widely considered to be a Cold War-era proxy war. It lasted almost 20 years, with direct U.S. involvement ending in 1973. The conflict also spilled over into neighboring states, exacerbating the Laotian Civil War and the Cambodian Civil War, which ended with all three countries officially becoming communist states by 1976. With the defeat of the French Union in the First Indochina War and its acceptance of military withdrawal from Vietnam pursuant to the Geneva peace agreement on Vietnam that took effect on 23 July 1954, the country gained the independence from France but was divided into two military gathering areas: the Viet Minh took control of North Vietnam, while the U.S. assumed financial and military support for the South Vietnamese state. The Viet Cong (VC), a South Vietnamese common front under the direction of the north, initiated a guerrilla war in the south. The People's Army of Vietnam (PAVN), also known as the North Vietnamese Army (NVA), engaged in more conventional warfare with U.S. and Army of the Republic of Vietnam (ARVN). North Vietnam invaded Laos in 1958, establishing the Ho Chi Minh Trail to supply and reinforce the VC. By 1963, the north had sent 40,000 soldiers to fight in the south. involvement increased under President John F. Kennedy, from just under a thousand military advisors in 1959 to 23,000 by 1964. Following the Gulf of Tonkin incident in August 1964, the U.S. Congress passed a resolution that gave President Lyndon B. Johnson broad authority to increase U.S. military presence in Vietnam, without a formal declaration of war. Johnson ordered the deployment of combat units for the first time, and dramatically increased the number of American troops to 184,000.[62] U.S. and South Vietnamese forces relied on air superiority and overwhelming firepower to conduct search and destroy operations, involving ground forces, artillery, and airstrikes. The U.S. also conducted a large-scale strategic bombing campaign against North Vietnam and continued significantly building up its forces, despite little progress being made. In 1968, North Vietnamese forces launched the Tet Offensive; though it was a military defeat for them, it became a political victory, as it caused U.S. domestic support for the war to fade. By the end of the year, the VC held little territory and were sidelined by the PAVN. In 1969, North Vietnam declared the Provisional Revolutionary Government of the Republic of South Vietnam. Operations crossed national borders, and the U.S. bombed North Vietnamese supply routes in Laos and Cambodia. The 1970 deposing of the Cambodian monarch, Norodom Sihanouk, resulted in a PAVN invasion of the country (at the request of the Khmer Rouge), and then a U.S.-ARVN counter-invasion, escalating the Cambodian Civil War. After the election of Richard Nixon in 1969, a policy of 'Vietnamization' began, which saw the conflict fought by an expanded ARVN, while U.S. forces withdrew in the face of increasing domestic opposition. U.S. ground forces had largely withdrawn by early 1972, and their operations were limited to air support, artillery support, advisors, and materiel shipments. The Paris Peace Accords of January 1973 saw all U.S. forces withdrawn, accords were broken almost immediately, and fighting continued for two more years. Phnom Penh fell to the Khmer Rouge on 17 April 1975, while the 1975 spring offensive saw the Fall of Saigon to the PAVN on 30 April, marking the end of the war. North and South Vietnam were reunified on 2 July the following year."}]}]==])
App.legacy = {data = Legacy, active = {}, touched = {}, changes = 0, moduleLoads = {}, localSounds = {}, pending = {}, bindings = {}, uiKind = "loading"}
App.classicConnections = {}
App.classicEffects, App.classicTasks = {}, {}
function App.UITask(callback, ...)
    if not App.alive then return nil end
    local args = table.pack(...)
    local thread = task.spawn(function()
        local ok, err = pcall(callback, table.unpack(args, 1, args.n))
        App.classicTasks[coroutine.running()] = nil
        if not ok and App.alive then App.Note("Classic UI task: " .. tostring(err)) end
    end)
    if coroutine.status(thread) ~= "dead" then App.classicTasks[thread] = true end
    return thread
end
function App.CleanupClassic()
    if type(task.cancel) == "function" then
        for thread in pairs(App.classicTasks) do if thread ~= coroutine.running() then pcall(task.cancel, thread) end end
    end
    table.clear(App.classicTasks)
    for effect in pairs(App.classicEffects) do pcall(function() effect:Destroy() end) end
    table.clear(App.classicEffects)
end
for key, value in pairs({legacyStamina = false, legacyAux = false, legacyVirus = false, legacyCooldown = false, compact = false, rendering = true, extraKeys = false, musicLoop = false, ammoAmount = 150, scrapAmount = 10, uiKey = "Insert"}) do Defaults[key] = value; App.cfg[key] = value end

function App.UIService(name)
    local service = game:GetService(name)
    local cache = {}
    return setmetatable({}, {__index = function(_, key)
        local value = service[key]
        if typeof(value) == "RBXScriptSignal" then
            if not cache[key] then
                cache[key] = {Connect = function(_, callback) return App.Connect(value, callback, App.classicConnections) end,
                    Wait = function() return value:Wait() end}
                cache[key].connect = cache[key].Connect
                cache[key].wait = cache[key].Wait
            end
            return cache[key]
        elseif type(value) == "function" then return function(_, ...) return value(service, ...) end end
        return value
    end})
end
function App.Copy(text, title)
    for _, method in pairs({setclipboard, toclipboard}) do
        if type(method) == "function" and pcall(method, text) then App.Notify(title or "Copied", "Copied to clipboard."); return true end
    end
    print(text); App.Notify(title or "Text", "Printed in the console; clipboard is unavailable.")
    return false
end

function App.RestoreLegacyData()
    for object, properties in pairs(App.legacy.touched) do for key in pairs(properties) do App.Restore(object, key) end end
    table.clear(App.legacy.touched); App.legacy.changes = 0
end
function App.DataWrite(object, key, value)
    if type(object) ~= "table" or value == nil then return false end
    if value == "Infinity" then value = math.huge end
    local ok = pcall(App.Patch, object, key, value)
    if not ok then return false end
    local fields = App.legacy.touched[object] or {}; App.legacy.touched[object] = fields
    if not fields[key] then fields[key] = true; App.legacy.changes = App.legacy.changes + 1 end
    return true
end
function App.RebuildLegacyData()
    App.RestoreLegacyData()
    local aliases = {noaimmod = "no_aim_mod", nomorale = "no_morale"}
    local uiAliases = {name = "display_name", desc = "description", pros = "pros", cons = "cons"}
    for perkId, presetIndex in pairs(App.legacy.active) do
        local preset = Legacy.presets[presetIndex]
        if preset and preset.id == perkId then
            for _, pair in ipairs({{"perkContent", true}, {"legacyPerks", false}}) do
                local module, modern = App.modules[pair[1]], pair[2]
                local record = type(module) == "table" and module[perkId]
                if type(record) == "table" then
                    local stats = modern and record.stats or record.basestats
                    local active = modern and record.actives and record.actives.main and record.actives.main.stats or record.activestats
                    local activeUI = modern and record.actives and record.actives.main and record.actives.main.ui
                    for key, value in pairs(preset.stats) do
                        local normalized = aliases[key] or key
                        -- Old source placed ability values in basestats; the current schema separates them.
                        if type(active) == "table" and active[normalized] ~= nil and (not stats or stats[normalized] == nil) then
                            if normalized == "cooldown" and type(value) == "number" then value = math.max(0, value) end
                            App.DataWrite(active, normalized, value)
                        else
                            App.DataWrite(stats, normalized, value)
                            if not modern and normalized ~= key then App.DataWrite(stats, key, value) end
                        end
                    end
                    for key, value in pairs(preset.active) do
                        if key == "cooldown" and type(value) == "number" then value = math.max(0, value) end
                        App.DataWrite(active, key, value)
                    end
                    for key, value in pairs(preset.ui) do
                        if modern then
                            if uiAliases[key] then App.DataWrite(record.ui, uiAliases[key], value)
                            elseif key == "activename" then App.DataWrite(activeUI, "display_name", value)
                            elseif key == "activedetails" then App.DataWrite(activeUI, "description", value) end
                        else App.DataWrite(record, key, value) end
                    end
                end
            end
        end
    end
    if App.cfg.legacyStamina or App.cfg.legacyCooldown then
        for _, pair in ipairs({{"perkContent", true}, {"legacyPerks", false}}) do
            local module, modern = App.modules[pair[1]], pair[2]
            if type(module) == "table" then
                for _, record in pairs(module) do
                    if type(record) == "table" then
                        if App.cfg.legacyStamina then App.DataWrite(modern and record.stats or record.basestats, "stammod", 1000000) end
                        if App.cfg.legacyCooldown then
                            if modern and type(record.actives) == "table" then
                                for _, ability in pairs(record.actives) do if type(ability.stats) == "table" and type(ability.stats.cooldown) == "number" then App.DataWrite(ability.stats, "cooldown", 0) end end
                            elseif type(record.activestats) == "table" and type(record.activestats.cooldown) == "number" then App.DataWrite(record.activestats, "cooldown", 0) end
                        end
                    end
                end
            end
        end
    end
    if App.cfg.legacyAux then
        local module = App.modules.equipmentContent
        if type(module) == "table" then
            for _, record in pairs(module) do
                if type(record) == "table" and type(record.uses_per_night) == "number" then App.DataWrite(record, "uses_per_night", 200) end
            end
        end
        local oldAux = App.modules.legacyAux
        if type(oldAux) == "table" then
            for _, record in pairs(oldAux) do
                if type(record) == "table" and type(record.use_per_night) == "number" then App.DataWrite(record, "use_per_night", 200) end
            end
        end
    end
    if App.cfg.legacyVirus then
        local module = App.modules.statusDefs
        if type(module) == "table" then
            for key, record in pairs(module) do
                if type(key) == "string" and key:find("Virus", 1, true) and type(record) == "table" and type(record.dur) == "number" then App.DataWrite(record, "dur", 1000000000) end
            end
        end
    end
    if App.legacyStatus then App.legacyStatus:Set({Title = "Local preset status", Content = string.format("%d selected perk presets | %d client definition fields changed\nSelect the matching base perk in the game's loadout menu before spawning. Server health, cooldown and inventory checks still apply.", App.Count(App.legacy.active), App.legacy.changes)}) end
end
function App.UseLegacyPreset(index)
    local preset = Legacy.presets[index]
    if not preset then return false end
    App.legacy.active[preset.id] = index
    App.RebuildLegacyData()
    if App.legacy.changes == 0 then
        App.LoadLegacyModules()
        App.Notify(preset.label, "Queued until the replicated perk definitions are available. You can select presets without a character.")
    else App.Notify(preset.label, "Applied to available client perk definitions. Select its base perk before spawning. Server-side acceptance is unverified.") end
    return true
end
function App.ResetLegacyPresets()
    table.clear(App.legacy.active)
    for _, key in ipairs({"legacyStamina", "legacyAux", "legacyVirus", "legacyCooldown"}) do App.cfg[key] = false; if App.controls[key] then pcall(function() App.controls[key]:Set(false) end) end end
    App.RestoreLegacyData(); App.RebuildLegacyData()
end
function App.LoadLegacyModules()
    local specs = {
        perkContent = {Services.Replicated, "data", "content", "perks"},
        legacyPerks = {Services.World, "ServerStuff", "Statistics", "CLASS_STATISTICS"},
        equipmentContent = {Services.Replicated, "data", "content", "equipment"},
        legacyAux = {Services.World, "ServerStuff", "Statistics", "AUX_STATISTICS"},
        statusDefs = {Services.World, "ServerStuff", "Statistics", "S_STATISTICS"},
    }
    for key, path in pairs(specs) do
        if not App.modules[key] and App.moduleStatus[key] ~= "loading" then
            local root = table.remove(path, 1)
            local module = App.Path(root, table.unpack(path))
            if module and module:IsA("ModuleScript") then
                App.moduleStatus[key] = "loading"
                task.spawn(function()
                    local ok, value = pcall(require, module)
                    if not App.alive then return end
                    if ok and type(value) == "table" then App.modules[key] = value; App.moduleStatus[key] = "ready"; App.RebuildLegacyData()
                    else App.moduleStatus[key] = "unavailable"; App.Note("Legacy module " .. key .. " failed: " .. tostring(value)) end
                end)
            else App.moduleStatus[key] = "not replicated" end
        end
    end
end
local BaseLoadModules = App.LoadModules
App.LoadModules = function() BaseLoadModules(); App.LoadLegacyModules() end

function App.CraftCatalogItem(id, label)
    if not Catalog.items[id] then App.Notify(label, "This item ID is absent from the current item list."); return false end
    -- This action always uses the modern owned-blueprint API. The original
    -- arbitrary blueprint request is a separate, explicitly selected action.
    local inventory = App.GetInventory()
    if not inventory then App.Notify(label, "Spawn with an owned blueprint before using normal crafting."); return false end
    local slots = App.Call(inventory, "get", true)
    local selectedSlot, blueprint
    if type(slots) == "table" then
        for slot, owned in pairs(slots) do
            local item = type(owned) == "table" and type(owned.state) == "table" and Catalog.items[owned.state.identifier]
            if item and item.chargerating == "blueprint" and App.RecipeOutput(item) == id then
                selectedSlot = slot; blueprint = owned.state.identifier; break
            end
        end
    end
    if not selectedSlot then
        local entry, distance
        for _, e in pairs(App.entries) do
            App.Metadata(e)
            if e.itemId == id then local root, part = App.Root(), App.Part(e.object); if root and part then local d = (root.Position - part.Position).Magnitude; if not distance or d < distance then entry, distance = e, d end end end
        end
        if entry then App.waypoint = entry.object; App.UpdateESP(); App.Notify(label, string.format("No matching owned blueprint. Marked an existing %s %.0f studs away. Nothing was spawned.", entry.name, distance))
        else App.Notify(label, "No matching owned blueprint or streamed item was found. Nothing was created.") end
        return false
    end
    local entry = App.Nearest({Workbenches = true}, 10)
    if not entry then App.Waypoint("Workbenches"); App.Notify(label, "Owned blueprint found. Approach the marked workbench, then press this item again."); return false end
    if App.actionBusy then return false end
    local ok, reason = pcall(function() inventory.equip(selectedSlot); inventory.place_blueprint_on_workbench(entry.object) end)
    if not ok then App.Notify(label, reason); return false end
    local action = {kind = "craft", cancelled = false}; App.legacy.pending[action] = true; App.legacy.currentAction = action; App.actionBusy = true
    task.spawn(function()
        task.wait(1.7)
        if App.alive and not action.cancelled and entry.object.Parent and App.Active() then
            local root, part = App.Root(), App.Part(entry.object)
            if root and part and (root.Position - part.Position).Magnitude <= 10 then
                local crafted, err = pcall(inventory.craft_workbench_item, entry.object)
                if not crafted then App.Note("Craft failed: " .. tostring(err)) end
            end
        end
        App.legacy.pending[action] = nil
        if App.legacy.currentAction == action then App.legacy.currentAction = nil; App.actionBusy = false end
    end)
    App.Notify(label, "Owned " .. blueprint .. " placed. Normal-cost crafting will be requested after the hold time.")
    return true
end
function App.DropAmmo(kind)
    local inventory = App.GetInventory()
    if not inventory then App.Notify("Ammunition", "Spawn before dropping owned supplies."); return false end
    local supplies = App.Call(inventory, "get_ammo")
    local owned = type(supplies) == "table" and tonumber(supplies[kind]) or 0
    local amount = math.min(math.floor(App.cfg.ammoAmount), math.floor(owned or 0))
    if amount < 1 then App.Notify("Ammunition", "No " .. kind .. " ammo in your actual supplies."); return false end
    return App.InventoryAction("drop_ammo", kind, amount)
end
function App.DropRation(kind)
    local inventory = App.GetInventory()
    local keys = {MRE = "mre", Beans = "beans", Bottle = "bottle", Soda = "soda"}
    local rations = inventory and App.Call(inventory, "get_rations")
    if type(rations) ~= "table" or (tonumber(rations[keys[kind]]) or 0) < 1 then App.Notify("Rations", "No owned " .. kind .. " available to drop."); return false end
    return App.InventoryAction("drop_ration", kind)
end
function App.DropScrap()
    local inventory = App.GetInventory()
    local owned = inventory and App.Call(inventory, "get_scrap")
    local amount = math.min(math.floor(tonumber(owned) or 0), math.floor(App.cfg.scrapAmount))
    if amount < 1 then App.Notify("Salvage", "No owned salvage to drop."); return false end
    return App.InventoryAction("drop_scrap", amount)
end
function App.Rejoin()
    local ok, err = pcall(function() Services.Teleport:Teleport(13438553315, LP) end)
    if not ok then App.Notify("Rejoin", err) end
end
function App.MainMenu()
    local store = App.modules.store
    if store and type(store.displaying_menu) == "function" then
        local ok = pcall(store.displaying_menu, "main")
        if ok then App.Notify("Main menu", "Opened the native menu view. This does not force a server respawn."); return end
    end
    App.Notify("Main menu", "Native menu source is unavailable. Use the game's normal menu control.")
end
function App.UseHeldItem()
    local inventory = App.GetInventory()
    if not inventory or not App.Call(inventory, "get_current") then App.Notify("Item", "Equip the item you want to use first."); return false end
    return App.InventoryAction("activate_item")
end
function App.NativeKey(binding)
    if Services.Input:GetFocusedTextBox() then return end
    local settings = App.Store("game_settings")
    local name = type(settings) == "table" and settings[binding]
    local fallback = {keybind_parry = "F", keybind_aux = "C", keybind_perk = "F"}
    name = type(name) == "string" and name or fallback[binding]
    local key = name and Enum.KeyCode[name]
    if not key then App.Notify("Shortcut", "That native keybind is unavailable."); return false end
    local ok, err = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, key, false, game)
        vim:SendKeyEvent(false, key, false, game)
    end)
    if not ok then App.Notify("Shortcut", "Client input simulation is unavailable: " .. tostring(err):sub(1, 160)) end
    return ok
end
function App.SQAnimations()
    local animations = App.Path(Services.Replicated, "animationSets", "TPanimSets", "2H")
    if not animations then App.Notify("Sledge Queen animations", "The two-handed animation set is not replicated."); return false end
    local ids = {equip = "13483033688", swing = "13483037212", swing2 = "13483037668", block = "13483032046", charge = "13483033047", grapple = "13483036802"}
    local changed = 0
    for key, id in pairs(ids) do
        local animation = animations:FindFirstChild(key)
        if animation and animation:IsA("Animation") then App.Patch(animation, "AnimationId", "rbxassetid://" .. id); changed = changed + 1 end
    end
    App.Notify("Sledge Queen animations", tostring(changed) .. " local animation slots updated. Re-equip to refresh. Asset access is controlled by Roblox.")
    return changed > 0
end
function App.BringNPCs(onlySQ)
    local root = App.Root()
    if not root then App.Notify("NPC control", "Spawn first."); return false end
    local count = 0
    for _, entry in pairs(App.entries) do
        App.Metadata(entry)
        local isSQ = entry.mobId == "BossFunRuiner" or entry.mobId == "BossFunRuiner_legacy"
        if (not onlySQ or isSQ) and (entry.category == "Hostiles" or entry.category == "Bosses") and entry.object:IsA("Model") and App.AliveEntry(entry) then
            local ok = pcall(function() entry.object:PivotTo(CFrame.new(root.Position + Vector3.new((count % 5) * 4 - 8, 2, -12 - math.floor(count / 5) * 5))) end)
            if ok then count = count + 1 end
        end
    end
    App.Notify("NPC positioning", tostring(count) .. " streamed NPC models moved locally. Server replication can restore them.")
    return count > 0
end
function App.HangerThoughts()
    if App.thought then App.thought:Destroy() end
    local label = Instance.new("TextLabel")
    label.Name = "HangerThoughts"; label.Size = UDim2.new(1, 0, 0, 90); label.Position = UDim2.new(0, 0, 0.38, 0)
    label.BackgroundTransparency = 1; label.Text = "THE WINTER DOES NOT FORGET."
    label.TextColor3 = Color3.fromRGB(180, 30, 55); label.TextStrokeTransparency = 0.3
    label.TextSize = 30; label.Font = Enum.Font.Code; label.Parent = App.overlay; App.thought = label
    task.spawn(function() task.wait(3); if label.Parent then label:Destroy() end; if App.thought == label then App.thought = nil end end)
end
function App.FindSounds(group, query)
    local root = App.Path(Services.Replicated, "soundLibrary", group)
    local result, names = {}, {}
    if root then
        for _, object in ipairs(root:GetDescendants()) do
            if object:IsA("Sound") then
                local label = object:GetFullName():gsub("^ReplicatedStorage.soundLibrary.", "")
                if query == "" or label:lower():find(query:lower(), 1, true) then names[#names + 1] = label; result[label] = object end
            end
        end
    end
    table.sort(names)
    return names, result
end
function App.PlayLocalSound(template)
    if not template or not template:IsA("Sound") then App.Notify("Audio", "Choose an available sound first."); return false end
    App.StopLocalSounds()
    local clone = template:Clone(); clone.Name = "LuckyBlessingAudio"; clone.Looped = App.cfg.musicLoop
    clone.Volume = math.min(template.Volume, 1); clone.Parent = game:GetService("SoundService")
    App.legacy.localSounds[clone] = true; clone:Play()
    return true
end
function App.StopLocalSounds()
    for sound in pairs(App.legacy.localSounds) do pcall(function() sound:Stop(); sound:Destroy() end) end
    table.clear(App.legacy.localSounds)
end
function App.External(index)
    local record = Legacy.externals[index]
    if not record then return end
    local url = record.urls[1]
    local ok, result = pcall(function()
        local source = game:HttpGet(url)
        local loader, err = loadstring(source)
        assert(loader, err)
        return loader()
    end)
    if not ok then App.Notify(record.label, "Legacy loader unavailable: " .. tostring(result):sub(1, 260)); return false end
    App.Notify(record.label, "External script launched independently. Lucky Blessing cannot undo that script's changes.")
    return true
end

local BaseSet = App.Set
App.Set = function(key, value, updateControl)
    if key == "ammoAmount" or key == "scrapAmount" then
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
        value = math.floor(math.clamp(value, 1, 1000))
    elseif key == "uiKey" then
        if type(value) ~= "string" or not Enum.KeyCode[value] then return false end
    end
    local ok = BaseSet(key, value, updateControl)
    if not ok then return false end
    if key == "legacyStamina" or key == "legacyAux" or key == "legacyVirus" or key == "legacyCooldown" then App.RebuildLegacyData()
    elseif key == "compact" and App.rayfield and type(App.rayfield.ToggleOldTabStyle) == "function" then pcall(function() App.rayfield:ToggleOldTabStyle(not value) end)
    elseif key == "rendering" then pcall(function() Services.Run:Set3dRenderingEnabled(value) end)
    elseif key == "theme" and App.legacy.uiKind == "classic" then pcall(function() App.rayfield:ModifyTheme(value) end) end
    return true
end
local BaseProfile = App.Profile
App.Profile = function()
    if App.controls.uiKey and type(App.controls.uiKey.CurrentKeybind) == "string" and Enum.KeyCode[App.controls.uiKey.CurrentKeybind] then App.cfg.uiKey = App.controls.uiKey.CurrentKeybind end
    local profile = BaseProfile(); profile.legacyPresets = table.clone(App.legacy.active); return profile
end
function App.AfterLoad(profile)
    table.clear(App.legacy.active)
    if type(profile.legacyPresets) == "table" then
        for key, index in pairs(profile.legacyPresets) do
            if type(index) == "number" and index % 1 == 0 and Legacy.presets[index] and Legacy.presets[index].id == key and Catalog.perks[key] then App.legacy.active[key] = index end
        end
    end
    App.RebuildLegacyData()
end
local BasePanic = App.Panic
App.Panic = function()
    for action in pairs(App.legacy.pending) do action.cancelled = true end
    App.legacy.currentAction = nil; App.actionBusy = false
    App.ResetLegacyPresets(); App.Set("extraKeys", false, true); App.StopLocalSounds()
    BasePanic()
end
local BaseUnload = App.Unload
App.Unload = function()
    for action in pairs(App.legacy.pending) do action.cancelled = true end
    App.RestoreLegacyData(); App.StopLocalSounds(); App.Disconnect(App.classicConnections); App.CleanupClassic()
    if not App.cfg.rendering then pcall(function() Services.Run:Set3dRenderingEnabled(true) end) end
    if App.fpsOriginal and type(setfpscap) == "function" then pcall(setfpscap, App.fpsOriginal) end
    BaseUnload()
    if App.classicGui then pcall(function() App.classicGui:Destroy() end); App.classicGui = nil end
    if Environment.LuckyBlessing == App then Environment.LuckyBlessing = nil end
end

-- A group-aware adapter uses collapsible Sections in the classic Rayfield fork,
-- and regular native sections if the official current Rayfield fallback is used.
function App.Group(raw, name)
    -- ArrayField's second argument means display-only, not expanded. Passing
    -- true moves Holder into Rayfield.Holding and hides every child control.
    local section = raw:CreateSection(name, false, false)
    local proxy = {}
    for _, method in ipairs({"CreateButton", "CreateToggle", "CreateSlider", "CreateDropdown", "CreateInput", "CreateKeybind", "CreateParagraph", "CreateColorPicker"}) do
        proxy[method] = function(_, options)
            options.SectionParent = App.legacy.uiKind == "classic" and section or nil
            return raw[method](raw, options)
        end
    end
    function proxy:CreateSection(label) return raw:CreateSection(label, false, false) end
    function proxy:CreateLabel(text) return raw:CreateLabel(text, App.legacy.uiKind == "classic" and section or nil) end
    App.groups[#App.groups + 1] = {name = name, section = section}
    return proxy
end
function App.CheckClassicGroups()
    if App.legacy.uiKind ~= "classic" or not App.classicGui then return end
    local main = App.classicGui:FindFirstChild("Main")
    local pages = main and main:FindFirstChild("Elements")
    assert(pages, "Classic menu content pages are missing")
    for _, group in ipairs(App.groups) do
        local holder = group.section.Holder
        assert(holder and holder.Parent and holder:IsDescendantOf(pages), "Hidden content holder in " .. group.name)
        assert(holder.Visible == group.section.Open, "Section visibility does not match its state: " .. group.name)
    end
end
function App.FilterClassicGroups(query)
    if App.alive == false then return end
    query = tostring(query or ""):lower()
    App.classicSearchQuery = query
    for _, group in ipairs(App.groups or {}) do
        local section = group.section
        local holder = section and section.Holder
        if holder and holder.Parent then
            local headingMatches = query == "" or group.name:lower():find(query, 1, true) ~= nil
            local any = false
            for _, row in ipairs(holder:GetChildren()) do
                if row:IsA("GuiObject") or row:IsA("Frame") then
                    if row.Name ~= "SectionSpacing" and row.Name ~= "Placeholder" and row.Name ~= "Topholder" then
                        local title = row:FindFirstChild("Title")
                        local text = row.Name .. " " .. (title and title:IsA("TextLabel") and title.Text or "")
                        local matches = headingMatches or text:lower():find(query, 1, true) ~= nil
                        row.Visible = matches; any = any or matches
                    end
                end
            end
            holder.Parent.Visible = query == "" or headingMatches or any
            if query ~= "" then holder.Visible = headingMatches or any else holder.Visible = section.Open end
        end
    end
end
function App.BuildLuckyUI(library, classic)
    App.ResetCatalogUI()
    App.groups = {}
    App.rayfield = library; App.legacy.uiKind = classic and "classic" or "current"
    App.window = library:CreateWindow({Name = "Lucky Blessing 🍀 | 0.4.1", LoadingTitle = "Lucky 🍀", LoadingSubtitle = "Lucky Blessing / repaired",
        OldTabLayout = true, ShowText = "Lucky", Theme = "Default", ToggleUIKeybind = "RightBracket",
        ConfigurationSaving = {Enabled = false, FileName = "LuckyBlessing_Repaired"}, Discord = nil, KeySystem = false})
    if classic then library:ToggleOldTabStyle(true) end
    local tabs = {}
    local icons = {["Main Tab"] = 6026568198, ["Rations / Ammo"] = 13075651575, ["Others / Fun"] = 6023426915, ["Other Scripts"] = 6022668883, Settings = 13075268290, ["Facts Tab"] = 13075637275}
    for _, name in ipairs({"Main Tab", "Rations / Ammo", "Others / Fun", "Other Scripts", "Settings", "Facts Tab"}) do tabs[name] = App.window:CreateTab(name, icons[name]) end
    App.tabs = tabs
    local group = App.Group(tabs["Main Tab"], "Lucky Blessing")
    App.Paragraph(group, "Lucky Blessing", "Original named perk buttons, item shortcuts and extra abilities are back. Current game lists are available alongside them. Insert / ] or LB reopens the menu.")
    App.statusParagraph = App.Paragraph(group, "Live status", "Waiting for client data...")
    App.legacyStatus = App.Paragraph(group, "Local preset status", "No preset selected.")
    App.Button(group, "Refresh lists from current game", function() App.RefreshCatalog(true) end)
    App.Paragraph(group, "Item actions", "Choose how item shortcuts work in Item button action: original spawn request, owned-blueprint craft/find or an existing-item waypoint. The full current item browser is also available.")
    group = App.Group(tabs["Main Tab"], "Modified stuff / Salvages")
    App.Toggle(group, "Infinite Stamina", "legacyStamina")
    App.Toggle(group, "Disable Virus", "legacyVirus")
    App.Button(group, "Freeze current virus timers", App.FreezeCurrentVirus)
    App.Toggle(group, "Inf Auxiliory", "legacyAux")
    App.Toggle(group, "Longer Effects", "longEffects")
    App.Toggle(group, "Shorten debuffs", "shortDebuffs")
    App.Toggle(group, "No Fog", "noFog")
    App.Button(group, "Decreased Fog", function() App.Set("noFog", false, true); App.Patch(Services.Lighting, "FogStart", 0); App.Patch(Services.Lighting, "FogEnd", 250) end)
    App.Button(group, "Serverhop / Rejoin", App.Rejoin)
    App.Toggle(group, "ESP", "espEnabled")
    App.Toggle(group, "Speed Boost (keybind L)", "speedEnabled")
    App.Slider(group, "Speed Boost amount", "walkSpeed", {8, 40}, 1)
    App.Button(group, "Dupe Loot | Will eliminate You!", App.OriginalDeathAction)

    group = App.Group(tabs["Main Tab"], "Essential")
    App.Toggle(group, "Extra Ability shortcuts (R / Y / B / U / J / M)", "extraKeys")
    App.Paragraph(group, "Extra Ability controls", "Original bindings: R parry, Y stun grenade, B Prophet scan, U smoke, J regeneration, M ration set. R / Y / U require the original handler key structure. Buttons below also work without keyboard shortcuts.")
    App.BuildOriginalAbilities(group)
    App.Slider(group, "Scrap Giver", "scrapAmount", {1, 1000}, 1, "salvage")
    App.Button(group, "Request original Scrap Giver", function() App.SpawnOriginalResource("scrap") end)
    App.Button(group, "Drop selected owned salvage", App.DropScrap)
    App.Button(group, "SOF Nametag (Spectator's Team)", function() App.LegacySpawnSequence("Match") end)
    App.Button(group, "Main Menu", function() App.LegacySpawnSequence("Respawn") end)
    App.Button(group, "Open current menu view", App.MainMenu)

    group = App.Group(tabs["Main Tab"], "Modified Perks")
    App.Toggle(group, "Zero local cooldown definitions", "legacyCooldown")
    App.BuildRestoredPerks(group)
    App.Button(group, "Restore original perk definitions", App.ResetLegacyPresets)
    App.Button(group, "Sledge Queen 2.0 Animation", App.SQAnimations)
    App.Button(group, "Restore original animations", function() App.RestoreProperty("AnimationId") end)
    App.Paragraph(group, "Preset timing", "Select the matching base perk in the game's loadout menu, apply the profile, then spawn normally. These are the original client definition edits; server acceptance must be checked in-game.")

    group = App.Group(tabs["Main Tab"], "Medic / health")
    App.BuildMedicPanel(group)
    App.BuildRestoredItems(tabs["Main Tab"])

    group = App.Group(tabs["Main Tab"], "Current base perks / additional presets")
    App.BuildDynamicPerks(group)

    group = App.Group(tabs["Main Tab"], "Items / weapons (current game)")
    App.BuildDynamicItems(group)

    group = App.Group(tabs["Rations / Ammo"], "Ammo")
    App.Paragraph(group, "Ammo actions", "Spawn Ammo uses the original dropAmmo request. Drop selected owned ammo uses the current inventory API and clamps to actual stock. Adjusting the amount slider sends no requests.")
    App.inventoryParagraph = App.Paragraph(group, "Inventory", "Refresh to inspect owned supplies.")
    App.Button(group, "Refresh inventory and supplies", App.UpdateInventoryPanel)
    App.Slider(group, "Ammo amount", "ammoAmount", {1, 1000}, 1)
    for _, kind in ipairs({"Light", "Heavy", "Short", "Long", "Medium", "Small", "Shells"}) do
        local selected = kind; App.Button(group, "Spawn " .. (kind == "Shells" and "Shell" or kind) .. " Ammo", function() App.SpawnOriginalResource("ammo", selected) end)
    end
    App.BuildDynamicAmmo(group)
    group = App.Group(tabs["Rations / Ammo"], "Foods")
    for _, kind in ipairs({"MRE", "Beans", "Bottle", "Soda"}) do
        local selected = kind
        App.Button(group, "Spawn Ration: " .. kind, function() App.SpawnOriginalResource("rations", selected) end)
        App.Button(group, "Drop Ration: " .. kind, function() App.DropRation(selected) end)
    end
    App.Button(group, "Use equipped item", App.UseHeldItem)

    group = App.Group(tabs["Others / Fun"], "Trolling Options")
    App.Button(group, "Teleport SledgeQueen (local model)", function() App.BringNPCs(true) end)
    App.Button(group, "Teleport ALL Scavengers (local models)", function() App.BringNPCs(false) end)
    App.Paragraph(group, "NPC positioning", "Moves only currently streamed hostile NPC models locally. Server replication may immediately correct their positions. Player characters are excluded.")
    App.Paragraph(group, "Server Crasher 2.0", "Disabled: the old death-request flood is not part of this repair.")
    group = App.Group(tabs["Others / Fun"], "In-Game Modifier")
    App.Button(group, "Main Menu", function() App.LegacySpawnSequence("Respawn") end)
    App.Button(group, "Control Scav interface (lag)", function() App.OriginalExternal("Control Scav interface (lag)") end)
    App.Button(group, "Hanger Thoughts (local effect)", App.HangerThoughts)
    App.Button(group, "Executor Functions Tester", function()
        local capabilities = {loadstring = type(loadstring) == "function", files = type(writefile) == "function" and type(readfile) == "function", clipboard = type(setclipboard) == "function" or type(toclipboard) == "function", fps = type(setfpscap) == "function", classicUI = App.legacy.uiKind == "classic"}
        App.Notify("Capabilities", App.Format(capabilities))
    end)
    group = App.Group(tabs["Others / Fun"], "Music / Theme Songs")
    local soundGroup, query, soundLookup, chosen = "songs", "", {}, nil
    local soundDropdown
    local function refreshSounds()
        local options; options, soundLookup = App.FindSounds(soundGroup, query)
        if #options == 0 then options = {"No sounds found"} end
        soundDropdown:Refresh(options); soundDropdown:Set({options[1]}); chosen = soundLookup[options[1]]
    end
    App.Button(group, "Music / Theme Songs", refreshSounds)
    group:CreateDropdown({Name = "Sound group", Options = {"songs", "raidboss", "perks", "AGENT", "shadow", "ai", "events", "world_item", "christmas", "aux"}, CurrentOption = {soundGroup}, MultipleOptions = false, Callback = function(options) soundGroup = options[1] or soundGroup; if soundDropdown then refreshSounds() end end})
    group:CreateInput({Name = "Sound search", PlaceholderText = "boss, yosef, sledge...", RemoveTextAfterFocusLost = false, Callback = function(text) query = text:sub(1, 80); refreshSounds() end})
    soundDropdown = group:CreateDropdown({Name = "Available sounds", Options = {"Press Music / Theme Songs"}, CurrentOption = {"Press Music / Theme Songs"}, MultipleOptions = false, Callback = function(options) chosen = soundLookup[options[1]] end})
    App.Toggle(group, "Loop local sound", "musicLoop")
    App.Button(group, "Play selected sound locally", function() App.PlayLocalSound(chosen) end)
    App.Button(group, "Stop local sounds", App.StopLocalSounds)

    group = App.Group(tabs["Others / Fun"], "ESP / Aimbot")
    App.Toggle(group, "NPC aim assist", "aimEnabled"); App.Toggle(group, "Visibility check", "aimWallCheck")
    App.Slider(group, "Aim radius", "aimRadius", {30, 400}, 5, "px")
    App.Slider(group, "Aim smoothing", "aimSmooth", {0.02, 0.6}, 0.02, "s")
    App.controls.categories = group:CreateDropdown({Name = "ESP categories", Options = Categories, CurrentOption = {"Workbenches", "Scrappers", "Bosses"}, MultipleOptions = true, Callback = function(options)
        local selected = {}; for _, name in ipairs(options) do selected[name] = true end; for _, name in ipairs(Categories) do App.categories[name] = selected[name] == true end
    end})
    App.Slider(group, "ESP distance", "espDistance", {50, 5000}, 50, "studs")
    App.Toggle(group, "ESP through walls", "throughWalls")
    App.Button(group, "Refresh ESP", function() App.ScanRoots(); App.UpdateESP() end)
    App.Button(group, "Nearest workbench waypoint", function() App.Waypoint("Workbenches") end)
    App.Button(group, "Nearest scrapper waypoint", function() App.Waypoint("Scrappers") end)
    group = App.Group(tabs["Others / Fun"], "Traits / Movement")
    App.Toggle(group, "Enable selected trait markers", "traitsEnabled")
    App.traitParagraph = App.Paragraph(group, "Trait marker status", App.TraitSummary())
    App.BuildDynamicTraits(group)
    App.Toggle(group, "Flight", "fly"); App.Slider(group, "Flight speed", "flySpeed", {10, 80}, 1)
    App.Toggle(group, "Noclip", "noclip"); App.Toggle(group, "Extra jumps", "infiniteJump")
    App.Toggle(group, "Fullbright", "fullbright"); App.Toggle(group, "Field of view override", "fovEnabled"); App.Slider(group, "Field of view", "fov", {60, 110}, 1)

    group = App.Group(tabs["Other Scripts"], "Original loaders")
    App.Paragraph(group, "Optional archived sources", "Your old external-script links are retained below. They run only when clicked and may return 404. Lucky Blessing's core no longer auto-runs those dependencies. Its Unload cannot clean up independent external scripts.")
    for index, record in ipairs(Legacy.externals) do
        -- Built-in replacements are already present; retain their original URLs as copy actions.
        local selected = index
        if record.label:find("Animation", 1, true) or record.label:find("ESP", 1, true) or record.label:find("Speed Boost", 1, true) or record.label == "Executor Functions Tester (Check Console After Clicking)" then
            App.Button(group, record.label .. " / copy original link", function() App.Copy(Legacy.externals[selected].urls[1], "Original source") end)
        else App.Button(group, record.label, function() App.External(selected) end) end
    end

    group = App.Group(tabs.Settings, "General Options")
    App.Toggle(group, "Compact Mode", "compact"); App.Toggle(group, "Enable Rendering", "rendering")
    App.Toggle(group, "Status HUD", "hud"); App.Toggle(group, "Roblox player list", "leaderboard")
    App.controls.uiKey = group:CreateKeybind({Name = "UI Keybind", CurrentKeybind = "Insert", HoldToInteract = false, Flag = "LB_reopen", Callback = function()
        if type(App.rayfield.SetVisibility) == "function" then App.rayfield:SetVisibility(not App.rayfield:IsVisible()) end
    end})
    App.Button(group, "Unlock Fps", function()
        if type(setfpscap) ~= "function" then App.Notify("FPS", "This client does not provide setfpscap."); return end
        if type(getfpscap) == "function" and not App.fpsOriginal then local ok, value = pcall(getfpscap); if ok then App.fpsOriginal = value end end
        local ok, err = pcall(setfpscap, 1000); App.Notify("FPS", ok and "Cap set to 1000 FPS; actual FPS depends on the device." or err)
    end)
    App.Button(group, "Save profile", App.Save); App.Button(group, "Load saved profile", App.Load)
    App.Button(group, "Retry client modules", App.LoadModules)
    App.Toggle(group, "Auto-refresh lists (30 seconds)", "catalogAuto")
    App.Button(group, "Refresh game lists now", function() App.RefreshCatalog(true) end)
    App.Button(group, "Module status", function() App.Notify("Client modules", App.Format(App.moduleStatus)) end)
    App.Button(group, "Copy / export diagnostics", App.Diagnostics)
    App.Button(group, "Original feature status", App.ShowFeatureStatus)
    App.Button(group, "Pause and restore owned changes", App.Panic)
    App.Button(group, "Destroy UI / unload", App.Unload)
    App.Toggle(group, "Toggle Netless", "netless")
    App.Paragraph(group, "Netless", "Original upward limb velocity, now handled by one owned connection with cleanup. It does not establish network ownership; server replication can correct it.")
    App.Paragraph(group, "Credits", "Lucky Blessing: Ry / RyAtlasX / Atlas Studio; original notes credit Ryder, Waltuh White and Sasquatch_htv. Classic interface: Arrays and Rafa, originally Sirius. The supplied 2023 source declares CC0 1.0. Current repair keeps named presets and source references.")
    App.Paragraph(group, "Verified limits", "Compiled and tested with an isolated mock client; no live Roblox session was available. Preset definition edits, existing-supply drops and normal blueprint crafting are distinct from server-authorized spawns or invulnerability.")
    group = App.Group(tabs["Facts Tab"], "Facts")
    for _, fact in ipairs(Legacy.facts) do App.Paragraph(group, fact.title, fact.content) end
    group = App.Group(tabs["Facts Tab"], "Decaying Winter / mechanics")
    App.BuildGameNotes(group)
    group = App.Group(tabs["Facts Tab"], "Current game reference")
    App.BuildCodex(group)
    group = App.Group(tabs.Settings, "Game data / sources")
    App.catalogParagraph = App.Paragraph(group, "Game lists / sources", App.CatalogSummary())
    App.CheckClassicGroups()
end
function App.BuildUI()
    local classic, reason
    local ok, value = pcall(App.LoadClassicUI)
    if not App.alive then return end
    if ok and type(value) == "table" then classic = value else reason = value end
    if classic then
        local built, err = pcall(App.BuildLuckyUI, classic, true)
        if built then return end
        reason = err; pcall(function() classic:Destroy() end)
    end
    App.Disconnect(App.classicConnections); App.CleanupClassic()
    if App.classicGui then pcall(function() App.classicGui:Destroy() end); App.classicGui = nil end
    App.Note("Classic UI unavailable; using current Rayfield. " .. tostring(reason):sub(1, 220))
    local source = game:HttpGet("https://sirius.menu/rayfield")
    local loader, err = loadstring(source); assert(loader, err)
    local current = loader()
    App.BuildLuckyUI(current, false)
end
local StartCore = App.Start
App.Start = function()
    StartCore()
    if not App.alive then return end
    Environment.LuckyBlessing = App
    if App.overlay and App.overlay:FindFirstChild("Reopen") then App.overlay.Reopen.Text = "LB ]" end
    App.Connect(Services.Input.InputBegan, function(input, processed)
        if processed or Services.Input:GetFocusedTextBox() then return end
        if input.KeyCode == Enum.KeyCode.RightBracket then
            -- Insert is owned by CreateKeybind; current Rayfield already owns ].
            if App.legacy.uiKind == "classic" then
                if type(App.rayfield.SetVisibility) == "function" then App.rayfield:SetVisibility(not App.rayfield:IsVisible()) end
            end
        elseif input.KeyCode == Enum.KeyCode.L then App.Set("speedEnabled", not App.cfg.speedEnabled, true)
        elseif App.cfg.extraKeys then
            App.ExtraAbility(input.KeyCode)
        end
    end)
    App.Notify("Lucky Blessing repaired", "Original tabs and presets are ready. Insert / ] reopens the menu. Apply your base-perk preset before spawning.")
end


-- Live registry adapters. Only the six data modules verified in the supplied
-- place are required; no client controller or arbitrary descendant is executed.
local CatalogOrder = {"traits", "perks", "equipment", "items", "enemies", "interactables"}
local CatalogTitles = {traits = "Traits", perks = "Perks", equipment = "Auxiliary equipment", items = "Items and weapons", enemies = "NPCs", interactables = "Interactions"}
local CatalogSpecs = {
    traits = {root = Services.Replicated, path = {"data", "content", "traits"}},
    perks = {root = Services.Replicated, path = {"data", "content", "perks"}, backend = "perkContent"},
    equipment = {root = Services.Replicated, path = {"data", "content", "equipment"}, backend = "equipmentContent"},
    items = {root = Services.World, path = {"ServerStuff", "Statistics", "W_STATISTICS"}},
    enemies = {root = Services.Replicated, path = {"data", "content", "mobs"}},
    interactables = {root = Services.Replicated, path = {"data", "content", "interactables"}},
}
local SnapshotCatalog = table.clone(Catalog)
App.catalogSources, App.catalogLoads, App.catalogViews = {}, {}, {}
Defaults.catalogAuto, App.cfg.catalogAuto = true, true

-- Read our saved original when a preset currently owns this field. Reference
-- pages must not present a local edited value as the game's balance value.
function App.CatalogField(object, key)
    if type(object) ~= "table" then return nil end
    local value = object[key]
    local saved = App.patches[object] and App.patches[object][key]
    if saved and value == saved.last then return saved.original end
    return value
end
function App.CopyCatalogData(value, seen, depth, budget)
    local kind = type(value)
    if kind == "string" or kind == "boolean" then return value end
    if kind == "number" then if value == value and math.abs(value) < math.huge then return value end; return nil end
    if kind ~= "table" then return nil end
    seen, depth, budget = seen or {}, depth or 0, budget or {left = 200000}
    if depth > 10 or seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key in pairs(value) do
        budget.left = budget.left - 1
        if budget.left < 0 then error("Registry exceeds the supported data budget") end
        if type(key) == "string" or type(key) == "number" then
            result[key] = App.CopyCatalogData(App.CatalogField(value, key), seen, depth + 1, budget)
        end
    end
    seen[value] = nil
    return result
end
function App.NormalizeCatalog(group, raw)
    if type(raw) ~= "table" then return nil, 0, "Module did not return a table" end
    local result, skipped, accepted = {}, 0, 0
    local budget = {left = 200000}
    for id, value in pairs(raw) do
        if group == "traits" and id == "none" then continue end
        if type(id) ~= "string" or #id == 0 or #id > 160 or type(value) ~= "table" then skipped = skipped + 1; continue end
        local ui, stats = App.CatalogField(value, "ui"), App.CatalogField(value, "stats")
        local record
        if group == "items" then
            if type(value.name) == "string" and type(value.weapontype) == "string" then
                record = App.CopyCatalogData(value, nil, nil, budget)
                record.description = record.desc or record.ability
            end
        elseif group == "interactables" then
            -- Several legitimate definitions are empty: the client uses its
            -- normal default hold duration. Functions such as display_name are
            -- deliberately not called by a reference browser.
            record = App.CopyCatalogData(value, nil, nil, budget)
            record.name = type(ui) == "table" and ui.display_name or nil
            if type(record.name) ~= "string" then record.name = id end
            record.interact_duration = record.interact_duration or record.interaction_duration
        elseif group == "enemies" then
            if type(stats) == "table" then
                record = {name = type(stats.healthbartop) == "string" and stats.healthbartop or id, stats = App.CopyCatalogData(stats, nil, nil, budget)}
            end
        elseif type(ui) == "table" and type(App.CatalogField(ui, "display_name")) == "string" and type(stats) == "table" then
            record = {name = App.CatalogField(ui, "display_name"), description = App.CatalogField(ui, "description"), stats = App.CopyCatalogData(stats, nil, nil, budget)}
            if type(record.description) ~= "string" then record.description = nil end
            if group == "perks" then
                record.class = App.CatalogField(ui, "perk_class")
                record.pros = App.CopyCatalogData(App.CatalogField(ui, "pros"), nil, nil, budget)
                record.cons = App.CopyCatalogData(App.CatalogField(ui, "cons"), nil, nil, budget)
                record.actives = {}
                for key, ability in pairs(App.CatalogField(value, "actives") or {}) do
                    if type(key) == "string" and type(ability) == "table" then
                        local abilityUI = App.CatalogField(ability, "ui")
                        record.actives[key] = {name = App.CatalogField(abilityUI, "display_name"), description = App.CatalogField(abilityUI, "description"), stats = App.CopyCatalogData(App.CatalogField(ability, "stats"), nil, nil, budget)}
                    end
                end
                record.developer_only = id == "debug" or value.developer_only == true
            elseif group == "equipment" then record.uses = App.CatalogField(value, "uses_per_night") end
        end
        if record then
            result[id] = record; accepted = accepted + 1
            if accepted > 5000 then return nil, skipped, "Registry contains too many records" end
        else skipped = skipped + 1 end
    end
    if accepted == 0 then return nil, skipped, "No supported records (empty or changed schema)" end
    -- Reject a mixed, unfamiliar schema rather than silently hiding records.
    if skipped > 0 then return nil, skipped, "Unsupported records; game schema may have changed" end
    return result, skipped
end
local function CatalogEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not CatalogEqual(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
function App.CatalogCounts()
    local counts = {}
    for _, group in ipairs(CatalogOrder) do counts[group] = App.Count(Catalog[group]) end
    counts.normalPerks, counts.debugPerks = 0, 0
    for id, record in pairs(Catalog.perks) do
        if id == "debug" or record.developer_only then counts.debugPerks = counts.debugPerks + 1 else counts.normalPerks = counts.normalPerks + 1 end
    end
    return counts
end
function App.CatalogDiagnostics() return App.CopyCatalogData(App.catalogSources) end
function App.CatalogSourceText(group)
    local source = App.catalogSources[group]
    if not source then return "Snapshot fallback: waiting for game data" end
    if source.kind == "live" then return "Live game data: " .. source.path end
    return "Snapshot fallback: " .. (source.reason or "game data unavailable")
end
function App.CatalogSummary()
    local lines = {}
    for _, group in ipairs(CatalogOrder) do
        lines[#lines + 1] = string.format("%s: %d | %s", CatalogTitles[group], App.Count(Catalog[group]), App.CatalogSourceText(group))
    end
    lines[#lines + 1] = "Checks every 30 seconds while auto-refresh is enabled. Refresh never crafts, drops supplies or applies a perk preset."
    return table.concat(lines, "\n")
end
function App.ResetCatalogUI()
    App.catalogViews = {}; App.catalogParagraph = nil; App.dynamicItems = nil; App.dynamicPerks = nil; App.dynamicTraits = nil; App.dynamicAmmo = nil; App.originalItemViews = nil
end
function App.RefreshCatalogViews()
    if not App.alive then return end
    if App.catalogParagraph then App.catalogParagraph:Set({Title = "Game lists / sources", Content = App.CatalogSummary()}) end
    for _, refresh in ipairs(App.catalogViews) do
        local ok, err = pcall(refresh)
        if not ok then App.Note("List refresh: " .. tostring(err)) end
    end
end
function App.QueueCatalogViews()
    if App.catalogViewsQueued then return end
    App.catalogViewsQueued = true
    task.defer(function()
        App.catalogViewsQueued = false
        if App.alive then App.RefreshCatalogViews() end
    end)
end
function App.CommitCatalog(group, records, source)
    if not App.alive then return end
    records = records or SnapshotCatalog[group]
    local changed = not CatalogEqual(Catalog[group], records)
    Catalog[group] = records; App.catalogSources[group] = source
    if group == "traits" and changed then
        for id in pairs(App.traits) do if not records[id] then App.traits[id] = nil end end
        for id in pairs(records) do if App.traits[id] == nil then App.traits[id] = false end end
        for folder, owned in pairs(App.traitOwned) do
            for id, instance in pairs(owned) do
                if not records[id] then if instance.Parent == folder then instance:Destroy() end; owned[id] = nil end
            end
        end
        App.ApplyTraits()
    elseif group == "perks" and changed then
        local removed = false
        for id in pairs(App.legacy.active) do if not records[id] then App.legacy.active[id] = nil; removed = true end end
        if removed then App.RebuildLegacyData() end
    end
    App.QueueCatalogViews()
end
function App.RefreshCatalog(manual)
    if not App.alive then return end
    for _, group in ipairs(CatalogOrder) do
        local spec = CatalogSpecs[group]
        local module = App.Path(spec.root, table.unpack(spec.path))
        local path = (spec.root == Services.Replicated and "ReplicatedStorage." or "Workspace.") .. table.concat(spec.path, ".")
        local function fallback(reason)
            App.CommitCatalog(group, nil, {kind = "snapshot", path = path, reason = reason, checkedAt = App.tick})
        end
        local function adopt(load)
            local ok, records, skipped, reason = pcall(App.NormalizeCatalog, group, load.value)
            if not ok or not records then fallback(ok and reason or "unable to read the current schema")
            else
                App.CommitCatalog(group, records, {kind = "live", path = path, count = App.Count(records), skipped = skipped, checkedAt = App.tick})
                if spec.backend and App.modules[spec.backend] ~= load.value then
                    App.modules[spec.backend] = load.value; App.moduleStatus[spec.backend] = "ready"; App.RebuildLegacyData()
                end
            end
        end
        if not module or not module:IsA("ModuleScript") then
            App.catalogLoads[group] = nil; fallback("data module is not replicated at its known path")
            continue
        end
        local load = App.catalogLoads[group]
        if load and load.instance == module and load.pending then continue end
        if not load or load.instance ~= module or (load.error and manual) then
            load = {instance = module, pending = true}; App.catalogLoads[group] = load
            fallback("loading game data")
            task.spawn(function()
                local ok, value = pcall(require, module)
                if not App.alive or App.catalogLoads[group] ~= load then return end
                load.pending = false
                if not ok or type(value) ~= "table" then
                    load.error = tostring(value):sub(1, 160); fallback("module unavailable; use Refresh to retry")
                    return
                end
                load.value = value
                if App.Path(spec.root, table.unpack(spec.path)) == module then adopt(load) end
            end)
        elseif load.value then
            adopt(load)
        end
    end
    if manual then App.Notify("Game lists", "Reading the replicated registries. Each list shows whether live game data or the bundled fallback is in use.") end
end

function App.RecipeOutput(record)
    local recipe = record and record.damagerating
    return type(recipe) == "table" and (recipe[3] or recipe["3"]) or nil
end
function App.DescribeCatalog(group, id)
    local record = id and Catalog[group][id]
    if not record then return "Choose an entry", "Search the current list and select an entry. Removed entries clear the selection." end
    local lines = {"Internal ID: " .. id, App.CatalogSourceText(group)}
    for _, field in ipairs({"description", "ability"}) do
        if type(record[field]) == "string" and (field ~= "ability" or record.ability ~= record.description) then lines[#lines + 1] = record[field] end
    end
    for _, pair in ipairs({{"weapontype", "Type"}, {"class", "Role"}, {"uses", "Uses per night"}, {"ammoused", "Ammo"}, {"stack_size", "Stack size"}, {"interact_duration", "Hold time (seconds)"}}) do
        if record[pair[1]] ~= nil then lines[#lines + 1] = pair[2] .. ": " .. tostring(record[pair[1]]) end
    end
    for _, pair in ipairs({{"scrap_value", "Scrap value"}, {"damagerating", "Damage / recipe"}, {"pros", "Pros"}, {"cons", "Cons"}, {"stats", "Stats"}, {"actives", "Abilities"}}) do
        if record[pair[1]] then lines[#lines + 1] = pair[2] .. ":\n" .. App.Format(record[pair[1]]) end
    end
    if record.chargerating == "blueprint" then
        local output = App.RecipeOutput(record)
        lines[#lines + 1] = "Blueprint output: " .. (Catalog.items[output] and Catalog.items[output].name or tostring(output))
    end
    if record.developer_only or id == "debug" then lines[#lines + 1] = "Developer/debug definition: reference only." end
    if group == "enemies" then lines[#lines + 1] = "A definition does not mean this NPC is present in the current server." end
    return record.name or id, table.concat(lines, "\n"):sub(1, 7000)
end
function App.CatalogPicker(tab, name, group, filter, display)
    local view = {group = group, query = "", lookup = {}, selectedId = nil, filter = filter, compact = display and display.compact}
    function view:Describe()
        local title, content = App.DescribeCatalog(self.group, self.selectedId)
        if self.details then self.details:Set({Title = title, Content = content}) end
        if self.compact and self.results then
            local source = App.catalogSources[self.group]
            self.results:Set({Title = name, Content = string.format("%d entries | %s%s", App.Count(self.lookup), source and source.kind == "live" and "Live game list" or "Snapshot list", self.selectedId and (" | " .. title) or "")})
        end
        if self.onSelection then self.onSelection(self.selectedId) end
    end
    function view:Refresh()
        if not self.dropdown then return end
        local options, lookup, label = {}, {}, nil
        for id, record in pairs(Catalog[self.group]) do
            local searchable = ((record.name or id) .. " " .. id .. " " .. (record.description or "") .. " " .. (record.weapontype or "")):lower()
            if (not self.filter or self.filter(id, record)) and (self.query == "" or searchable:find(self.query:lower(), 1, true)) then
                local option = (record.name or id) .. " [" .. id .. "]"
                options[#options + 1] = option; lookup[option] = id
                if self.selectedId == id then label = option end
            end
        end
        table.sort(options)
        local placeholder = #options == 0 and "No matches" or "Choose an entry"
        table.insert(options, 1, placeholder)
        self.lookup = lookup
        if not label then self.selectedId = nil end
        self.updating = true
        if not CatalogEqual(self.options, options) then self.dropdown:Refresh(options); self.options = options end
        self.dropdown:Set({label or placeholder})
        self.updating = false
        self.results:Set({Title = name, Content = string.format("%d matches | %s", App.Count(lookup), App.CatalogSourceText(self.group))})
        self:Describe()
    end
    tab:CreateInput({Name = name .. " / search", PlaceholderText = "Name, internal ID or type", RemoveTextAfterFocusLost = false, Callback = function(value) view.query = tostring(value):sub(1, 100); view:Refresh() end})
    view.dropdown = tab:CreateDropdown({Name = name .. " / entries", Options = {"Choose an entry"}, CurrentOption = {"Choose an entry"}, MultipleOptions = false, Callback = function(options)
        if view.updating then return end
        view.selectedId = view.lookup[options[1]]; view:Describe()
    end})
    view.results = App.Paragraph(tab, name, "Preparing list...")
    if not view.compact then view.details = App.Paragraph(tab, "Entry details", "Choose an entry.") end
    App.catalogViews[#App.catalogViews + 1] = function() view:Refresh() end
    view:Refresh()
    return view
end
function App.DynamicItemCategory(record)
    if record.chargerating == "blueprint" then return "Blueprints" end
    if record.weapontype == "Gun" or record.weapontype == "Bow" then return "Guns / ranged" end
    if record.weapontype ~= "Item" then return "Melee" end
    local name = (record.name or ""):lower()
    if name:find("stim", 1, true) then return "Stims" end
    if name:find("grenade", 1, true) or name:find("bomb", 1, true) or name:find("molotov", 1, true) or name:find("throw", 1, true) then return "Throwables" end
    if name:find("bandage", 1, true) or name:find("aid", 1, true) or name:find("splint", 1, true) or name:find("tablet", 1, true) or name:find("tourni", 1, true) or name:find("antibiot", 1, true) or name:find("augmentin", 1, true) or name:find("amoxicillin", 1, true) then return "Healing" end
    return "Other items"
end
function App.FindCatalogItem(id)
    if not id or not Catalog.items[id] then App.Notify("Find item", "Select an item from the current list first."); return false end
    local best, distance
    for _, entry in pairs(App.entries) do
        App.Metadata(entry)
        local root, part = App.Root(), App.Part(entry.object)
        if entry.itemId == id and root and part then
            local d = (root.Position - part.Position).Magnitude
            if not distance or d < distance then best, distance = entry, d end
        end
    end
    if not best then App.Notify("Find item", "No matching item is currently streamed nearby."); return false end
    App.waypoint = best.object; App.UpdateESP(); return true
end
function App.BuildDynamicItems(tab)
    local category, view = "All", nil
    tab:CreateDropdown({Name = "Item category", Options = {"All", "Guns / ranged", "Stims", "Melee", "Healing", "Throwables", "Blueprints", "Other items"}, CurrentOption = {category}, MultipleOptions = false, Callback = function(options) category = options[1] or "All"; if view then view:Refresh() end end})
    view = App.CatalogPicker(tab, "Current items", "items", function(_, record) return category == "All" or App.DynamicItemCategory(record) == category end)
    App.dynamicItems = view
    App.Button(tab, "Find nearest selected item", function() App.FindCatalogItem(view.selectedId) end)
    App.Button(tab, "Craft selected output (owned blueprint)", function()
        local id = view.selectedId; local record = id and Catalog.items[id]
        if not record then App.Notify("Craft", "Select an item from the current list first."); return end
        if record.chargerating == "blueprint" then id = App.RecipeOutput(record) end
        if type(id) ~= "string" or not Catalog.items[id] then App.Notify("Craft", "This blueprint has no supported current output ID."); return end
        App.CraftCatalogItem(id, Catalog.items[id].name)
    end)
    App.Paragraph(tab, "Item actions", "The full item registry replaces the 2023 button list. New IDs appear automatically. Crafting requires an owned matching blueprint, normal salvage and a nearby workbench. Find only marks an existing streamed item.")
end
function App.BuildDynamicPerks(tab)
    local view = App.CatalogPicker(tab, "Current base perks", "perks")
    App.dynamicPerks = view
    local chosen, lookup, presetDropdown = nil, {}, nil
    local function refreshPresets()
        local options, label = {}, nil; lookup = {}
        for index, preset in ipairs(Legacy.presets) do
            if preset.id == view.selectedId and Catalog.perks[preset.id] then
                options[#options + 1] = preset.label; lookup[preset.label] = index
                if chosen == index then label = preset.label end
            end
        end
        table.sort(options)
        local placeholder = #options == 0 and "No original preset for this perk" or "Choose an original preset"
        table.insert(options, 1, placeholder)
        if not label then chosen = nil end
        presetDropdown:Refresh(options); presetDropdown:Set({label or placeholder})
    end
    presetDropdown = tab:CreateDropdown({Name = "Original named presets for this perk", Options = {"No original preset for this perk"}, CurrentOption = {"No original preset for this perk"}, MultipleOptions = false, Callback = function(options) chosen = lookup[options[1]] end})
    view.onSelection = refreshPresets
    App.Button(tab, "Apply selected original preset", function()
        if not chosen or not Catalog.perks[view.selectedId] or Legacy.presets[chosen].id ~= view.selectedId then App.Notify("Perk preset", "Select a current base perk and one of its original presets first."); return end
        App.UseLegacyPreset(chosen)
    end)
    App.Paragraph(tab, "New perks", "Every current base perk is listed. Your 25 named presets remain available for matching IDs. New perks without an original preset remain readable; no invented preset or unlock is applied.")
    refreshPresets()
end
function App.BuildDynamicTraits(tab)
    local state = {lookup = {}, updating = false}
    App.dynamicTraits = state
    function state:Refresh()
        local options, selected = {}, {}; self.lookup = {}
        for id, record in pairs(Catalog.traits) do
            local label = record.name .. " [" .. id .. "]"; options[#options + 1] = label; self.lookup[label] = id
            if App.traits[id] then selected[#selected + 1] = label end
        end
        table.sort(options); table.sort(selected)
        self.updating = true
        if not CatalogEqual(self.options, options) then self.dropdown:Refresh(options); self.options = options end
        self.dropdown:Set(selected); self.updating = false
    end
    state.dropdown = tab:CreateDropdown({Name = "Selected trait markers / current list", Options = {}, CurrentOption = {}, MultipleOptions = true, Callback = function(options)
        if state.updating then return end
        local selected = {}; for _, label in ipairs(options) do local id = state.lookup[label]; if id then selected[id] = true end end
        for id in pairs(Catalog.traits) do App.traits[id] = selected[id] == true end
        App.ApplyTraits()
    end})
    App.catalogViews[#App.catalogViews + 1] = function() state:Refresh() end
    App.Button(tab, "Select all current trait markers", function() for id in pairs(Catalog.traits) do App.traits[id] = true end; state:Refresh(); App.ApplyTraits() end)
    App.Button(tab, "Clear selected trait markers", function() for id in pairs(App.traits) do App.traits[id] = false end; state:Refresh(); App.ApplyTraits() end)
    state:Refresh()
end
function App.BuildDynamicAmmo(tab)
    local state = {lookup = {}, selected = nil, updating = false}
    App.dynamicAmmo = state
    function state:Refresh()
        local inventory = App.GetInventory()
        local stocks = inventory and App.Call(inventory, "get_ammo")
        local options, label = {}, nil; self.lookup = {}
        if type(stocks) == "table" then
            for kind, count in pairs(stocks) do
                if type(kind) == "string" and type(count) == "number" and count > 0 and count < math.huge then
                    local option = string.format("%s (%d owned)", kind, math.floor(count))
                    options[#options + 1] = option; self.lookup[option] = kind
                    if self.selected == kind then label = option end
                end
            end
        end
        table.sort(options); table.insert(options, 1, #options == 0 and "No owned ammo / spawn first" or "Choose owned ammo")
        if not label then self.selected = nil end
        self.updating = true
        if not CatalogEqual(self.options, options) then self.dropdown:Refresh(options); self.options = options end
        self.dropdown:Set({label or options[1]}); self.updating = false
    end
    state.dropdown = tab:CreateDropdown({Name = "Current owned ammo types", Options = {"No owned ammo / spawn first"}, CurrentOption = {"No owned ammo / spawn first"}, MultipleOptions = false, Callback = function(options)
        if not state.updating then state.selected = state.lookup[options[1]] end
    end})
    App.Button(tab, "Drop selected owned ammo", function()
        if state.selected then App.DropAmmo(state.selected) else App.Notify("Ammo", "Refresh supplies and select an owned ammo type first.") end
    end)
    App.catalogViews[#App.catalogViews + 1] = function() state:Refresh() end
    state:Refresh()
end
function App.BuildCodex(tab)
    local view
    local labels, groups = {}, {}
    for _, group in ipairs(CatalogOrder) do labels[#labels + 1] = CatalogTitles[group]; groups[CatalogTitles[group]] = group end
    tab:CreateDropdown({Name = "Catalog category", Options = labels, CurrentOption = {CatalogTitles.items}, MultipleOptions = false, Callback = function(options)
        if view then view.group = groups[options[1]] or "items"; view.selectedId = nil; view:Refresh() end
    end})
    view = App.CatalogPicker(tab, "Game reference", "items")
end
local SetTraitBeforeDynamic = App.SetTrait
App.SetTrait = function(key, enabled, updateControl)
    SetTraitBeforeDynamic(key, enabled, updateControl)
    if updateControl and App.dynamicTraits then App.dynamicTraits:Refresh() end
end
local InventoryPanelBeforeDynamic = App.UpdateInventoryPanel
App.UpdateInventoryPanel = function()
    InventoryPanelBeforeDynamic()
    if App.dynamicAmmo then App.dynamicAmmo:Refresh() end
end
local UsePresetBeforeDynamic = App.UseLegacyPreset
App.UseLegacyPreset = function(index)
    local preset = Legacy.presets[index]
    if not preset or not Catalog.perks[preset.id] then App.Notify("Perk preset", "This preset's base ID is absent from the current perk list."); return false end
    return UsePresetBeforeDynamic(index)
end
local LoadBeforeDynamic = App.LoadModules
App.LoadModules = function() LoadBeforeDynamic(); App.RefreshCatalog(false) end
local StartBeforeDynamic = App.Start
App.Start = function()
    StartBeforeDynamic()
    if not App.alive then return end
    local elapsed = 0
    App.Connect(Services.Run.Heartbeat, function(delta)
        elapsed = elapsed + delta
        if elapsed >= 30 then elapsed = 0; if App.cfg.catalogAuto then App.RefreshCatalog(false) end end
    end)
end
local UnloadBeforeDynamic = App.Unload
App.Unload = function()
    UnloadBeforeDynamic()
    table.clear(App.catalogLoads); table.clear(App.catalogViews)
    App.dynamicItems, App.dynamicPerks, App.dynamicTraits, App.dynamicAmmo = nil, nil, nil, nil
    App.originalItemViews = nil
    if App.groups then table.clear(App.groups) end
end


-- Lucky Blessing feature restoration. Original requests remain distinct from
-- owned-resource actions. Source: the user's CC0 2023 script, neutral's public
-- 2024 Regeneration implementation, and IrishBaker's effect-duration helpers.
-- A request being sent is never represented as server acceptance.
App.rewrite = {last = {}, events = {}, context = nil, tasks = {}, nextHeal = 0, healthAtRequest = nil}
for key, value in pairs({autoRegen = false, regenThreshold = 100, regenInterval = 0.25, healBurst = 10, longEffects = false, shortDebuffs = false,
    netless = false, customLazarus = false, lazarusHealth = 999999, lazarusHeal = 20, lazarusMaxHeal = 8, legacyAuth = "Auto", itemAction = "Original spawn request"}) do
    Defaults[key] = value; App.cfg[key] = value
end
function App.ActionResult(name, state, detail, quiet)
    local record = {name = name, state = state, detail = tostring(detail):sub(1, 420), at = App.tick}
    App.rewrite.last[name] = record; App.rewrite.events[#App.rewrite.events + 1] = record
    if #App.rewrite.events > 60 then table.remove(App.rewrite.events, 1) end
    if not quiet then App.Notify(name .. " / " .. state, record.detail) end
    return state == "sent" or state == "applied"
end
function App.LegacyRemote(name)
    local remote = App.Path(Services.World, "ServerStuff", name)
    return remote and remote:IsA("RemoteEvent") and remote or nil
end
function App.LegacyContext(force)
    local cached = App.rewrite.context
    if not force and cached and cached.character == App.Character() and cached.script.Parent then return cached end
    if not force and (App.rewrite.contextRetryAt or -1) > App.tick then return nil end
    App.rewrite.context = nil
    App.rewrite.contextRetryAt = App.tick + 2
    local getValues = (debug and debug.getupvalues) or getupvalues
    if type(getsenv) ~= "function" or type(getValues) ~= "function" then return nil end
    for _, root in pairs({LP:FindFirstChild("Backpack"), App.Character(), LP:FindFirstChild("PlayerScripts")}) do
        for _, scriptInstance in ipairs(root:GetDescendants()) do
            if scriptInstance:IsA("LocalScript") and scriptInstance.Name ~= "ClickDetectorScript" then
                local ok, environment = pcall(getsenv, scriptInstance)
                if ok and type(environment) == "table" and type(environment.afflictstatus) == "function" then
                    local readable, values = pcall(getValues, environment.afflictstatus)
                    -- These slots belong specifically to the original handler,
                    -- not arbitrary functions in getgc/getreg. Reject a changed shape.
                    local function key(value) return (type(value) == "string" and #value > 0) or (type(value) == "number" and value == value and math.abs(value) < math.huge) end
                    if readable and type(values) == "table" and type(values[1]) == "table" and key(values[16]) and key(values[17]) then
                        cached = {script = scriptInstance, character = App.Character(), serverKey = values[16], playerKey = values[17], effects = values[1]}
                        App.rewrite.context = cached; return cached
                    end
                end
            end
        end
    end
    return nil
end
function App.LegacyKeys()
    if App.cfg.legacyAuth == "No keys (neutral 2024)" then return nil end
    return App.LegacyContext()
end
function App.SendOriginal(name, remoteName, args, quiet)
    local remote = App.LegacyRemote(remoteName)
    if not remote then return App.ActionResult(name, "unavailable", "The original " .. remoteName .. " endpoint is not present in this session.", quiet) end
    local ok = pcall(function() remote:FireServer(table.unpack(args, 1, args.n or #args)) end)
    if not ok then return App.ActionResult(name, "failed", "The original request could not be sent.", quiet) end
    return App.ActionResult(name, "sent", "Original request sent. Server acceptance has not been established.", quiet)
end
function App.HealOriginal(quiet)
    local hum = App.Humanoid()
    if not hum or hum.Health <= 0 then return App.ActionResult("Regeneration", "unavailable", "Spawn a living character first.", quiet) end
    local context = App.LegacyKeys()
    if App.cfg.legacyAuth == "Original keys required" and not context then return App.ActionResult("Regeneration", "unavailable", "Original handler keys are unavailable; no request was sent.", quiet) end
    local args = context and table.pack("Regeneration", nil, context.serverKey, context.playerKey) or table.pack("Regeneration")
    local sent = App.SendOriginal("Regeneration", "dealDamage", args, quiet)
    if sent then App.rewrite.healthAtRequest = hum.Health; App.rewrite.nextHeal = App.tick + App.cfg.regenInterval end
    return sent
end
function App.HealBurst()
    if App.rewrite.healTask then return false end
    local token = {character = App.Character()}; App.rewrite.healTask = token
    task.spawn(function()
        local sent = 0
        for _ = 1, App.cfg.healBurst do
            if not App.alive or App.rewrite.healTask ~= token or token.character ~= App.Character() then break end
            local hum = App.Humanoid()
            if not hum or hum.Health <= 0 or hum.Health >= hum.MaxHealth then break end
            if not App.HealOriginal(true) then break end
            sent = sent + 1; task.wait(App.cfg.regenInterval)
        end
        if App.rewrite.healTask == token then App.rewrite.healTask = nil end
        if App.alive then App.Notify("Heal burst", tostring(sent) .. " regeneration requests sent. Inspect actual health to check the result.") end
    end)
    return true
end
function App.OriginalSpawnItem(id, label)
    label = label or "Spawn " .. tostring(id)
    if not Catalog.items[id] then return App.ActionResult(label, "unavailable", "This old item ID is not in the current list. Use the dynamic browser to locate its current entry.") end
    local remote = App.Path(Services.Replicated, "Interactables", "interaction")
    if not remote or not remote:IsA("RemoteEvent") then return App.ActionResult(label, "unavailable", "Original blueprint endpoint unavailable. The separate Craft / find browser uses owned blueprints.") end
    local bench = App.Nearest({Workbenches = true}, 10)
    if not bench then return App.ActionResult(label, "unavailable", "Stand within 10 studs of a workbench.") end
    if App.actionBusy then return false end
    local requested = pcall(function() remote:FireServer(bench.object, "workbenchblueprint" .. id) end)
    if not requested then return App.ActionResult(label, "failed", "The original blueprint request could not be sent.") end
    local token = {cancelled = false, character = App.Character()}
    App.legacy.pending[token] = true; App.legacy.currentAction = token; App.actionBusy = true
    task.spawn(function()
        local ok = pcall(function()
            task.wait(1.7)
            local root, part = App.Root(), App.Part(bench.object)
            if App.alive and not token.cancelled and token.character == App.Character() and bench.object.Parent and root and part and (root.Position - part.Position).Magnitude <= 10 then remote:FireServer(bench.object, "workbench") end
        end)
        App.legacy.pending[token] = nil
        if App.legacy.currentAction == token then App.legacy.currentAction = nil; App.actionBusy = false end
        if App.alive then App.ActionResult(label, ok and "sent" or "failed", "Original blueprint / workbench requests attempted. Item creation and salvage costs depend on the server.", true) end
    end)
    return App.ActionResult(label, "sent", "Original blueprint request sent; workbench follow-up is queued. This does not confirm an item was created.")
end
App.LegacyItem = App.OriginalSpawnItem
function App.SpawnOriginalResource(kind, value)
    if kind == "scrap" then return App.SendOriginal("Scrap Giver", "dropAmmo", table.pack("scrap", math.floor(App.cfg.scrapAmount))) end
    if kind == "rations" then return App.SendOriginal("Spawn Ration: " .. tostring(value), "dropAmmo", table.pack("rations", value)) end
    return App.SendOriginal("Spawn " .. tostring(value) .. " Ammo", "dropAmmo", table.pack(value, math.floor(App.cfg.ammoAmount), false))
end
function App.ExtraAbility(key)
    if key == Enum.KeyCode.J then return App.HealBurst() end
    if key == Enum.KeyCode.M then
        local result = false
        for _, kind in ipairs({"MRE", "Bottle", "Beans", "Soda"}) do result = App.SpawnOriginalResource("rations", kind) or result end
        return result
    end
    local camera, character = Services.World.CurrentCamera, App.Character()
    if not camera or not character then return App.ActionResult("Extra Ability", "unavailable", "Spawn before using a targeted ability.") end
    if key == Enum.KeyCode.B then return App.SendOriginal("Prophet scan", "applyGore", table.pack("scanarea", character, LP, {camera.CFrame})) end
    local context = App.LegacyKeys()
    if not context then return App.ActionResult("Extra Ability", "unavailable", "The R / Y / U methods require the original handler keys. They are not replaced with ordinary equipped-item actions.") end
    if key == Enum.KeyCode.R then return App.SendOriginal("Parry", "initiateblock", table.pack(context.serverKey, true))
    elseif key == Enum.KeyCode.U then return App.SendOriginal("Fire smoke", "dealDamage", table.pack("fireSmoke", camera.CFrame, context.serverKey, context.playerKey))
    elseif key == Enum.KeyCode.Y then
        local raw = App.catalogLoads.items and App.catalogLoads.items.value
        local data = raw and raw.TGas or Catalog.items.TGas
        if not data then return App.ActionResult("Stun grenade", "unavailable", "The TGas item definition is unavailable.") end
        return App.SendOriginal("Stun grenade", "throwWeapon", table.pack("TGas", 20, camera.CFrame, 1, data, 1, nil, context.serverKey, nil, context.playerKey))
    end
end
function App.FreezeCurrentVirus()
    local context = App.LegacyContext(true)
    if not context then return App.ActionResult("Disable Virus", "unavailable", "Definition timers are available, but the original active-effect table is not exposed by this controller.") end
    local changed = 0
    for id, status in pairs(context.effects) do
        if type(id) == "string" and id:lower():find("virus", 1, true) and type(status) == "table" and type(status.effects) == "table" and type(status.effects.currentduration) == "number" then
            App.DataWrite(status.effects, "currentduration", 1000000000); changed = changed + 1
        end
    end
    App.cfg.legacyVirus = true
    if App.controls.legacyVirus then App.controls.legacyVirus:Set(true) end
    return App.ActionResult("Disable Virus", changed > 0 and "applied" or "unavailable", tostring(changed) .. " active local virus timers changed.")
end
function App.OriginalDeathAction()
    local remote = App.LegacyRemote("deathPlay")
    if not remote then return App.ActionResult("Dupe Loot", "unavailable", "The original deathPlay endpoint is absent. No death or replacement action was performed.") end
    -- One deliberate death request. Repeating death requests is not needed to
    -- expose this old action, and is not treated as evidence of a duplication.
    return App.SendOriginal("Dupe Loot", "deathPlay", table.pack())
end
function App.LegacySpawnSequence(destination)
    local remote, character = App.LegacyRemote("spawnPlayer"), App.Character()
    local start = LP:FindFirstChild("start")
    if not remote or not character or not start then return App.ActionResult("Legacy spawn", "unavailable", "The original spawnPlayer / start-state interface is unavailable. The current menu-view button remains separate.") end
    if App.rewrite.spawnTask then return false end
    local token = {cancelled = false}; App.rewrite.spawnTask = token
    task.spawn(function()
        local ok = pcall(function()
            remote:FireServer("respawncharacter")
            if destination == "Respawn" then return end
            local function waitOutfit(present)
                for _ = 1, 80 do
                    if not App.alive or token.cancelled then return false end
                    local current = App.Character()
                    if current and (current:FindFirstChild("Outfit") ~= nil) == present then return true end
                    task.wait(0.1)
                end
                return false
            end
            if not waitOutfit(false) then return end
            remote:FireServer("hubbing"); App.Patch(start, "Value", "normal")
            if not waitOutfit(true) then return end
            local root = App.Root()
            if root and App.alive and not token.cancelled then root.CFrame = CFrame.new(18.777990341186523, -2.5860984325408936, -9.264251708984375) end
        end)
        App.Restore(start, "Value")
        if App.rewrite.spawnTask == token then App.rewrite.spawnTask = nil end
        if App.alive then App.ActionResult("Legacy spawn", ok and "sent" or "failed", "Original sequence ended; server acceptance is unverified.", true) end
    end)
    return true
end

local RebuildBeforeRewrite = App.RebuildLegacyData
App.RebuildLegacyData = function()
    RebuildBeforeRewrite()
    local statuses = App.modules.statusDefs
    if type(statuses) == "table" then
        local long = {RespA = 1000000000, BuffC = 1000000000, Stealth = 1000000000, Arm = 1000000000, Pnk = 1000000000, Laz = 1000000000, Rgn = 1000000000,
            Brz = 240, ArtiB = 60, AlkyA = 120, ["3-(cbSTM)"] = 1000000000, ["I4S-DS"] = 1000000000, ["BL1 (Neloprephine)"] = 1000000000, ["S44-UL1"] = 1000000000}
        local short = {Exha = 1, Crp = 1, Bld = 1, HeavBld = 1, Vcd = 1, Snr = 1, Tnt = 1, Slc = 20, Bnd = 1}
        for _, pair in ipairs({{App.cfg.longEffects, long}, {App.cfg.shortDebuffs, short}}) do
            if pair[1] then for id, duration in pairs(pair[2]) do if type(statuses[id]) == "table" and type(statuses[id].dur) == "number" then App.DataWrite(statuses[id], "dur", duration) end end end
        end
    end
    if App.cfg.customLazarus then
        for _, pair in ipairs({{"perkContent", true}, {"legacyPerks", false}}) do
            local module, modern = App.modules[pair[1]], pair[2]
            local record = type(module) == "table" and module.lazarus
            if type(record) == "table" then
                local stats = modern and record.stats or record.basestats
                local active = modern and record.actives and record.actives.main and record.actives.main.stats or record.activestats
                if type(stats) == "table" and type(stats.healthmod) == "number" then App.DataWrite(stats, "healthmod", App.cfg.lazarusHealth) end
                if type(active) == "table" then
                    for key, value in pairs({min_heal = App.cfg.lazarusHeal, lazarus_max_heal = App.cfg.lazarusMaxHeal}) do
                        if type(active[key]) == "number" then App.DataWrite(active, key, value) end
                    end
                end
            end
        end
    end
    if App.cfg.legacyVirus then
        local context = App.LegacyContext()
        if context then for id, status in pairs(context.effects) do
            if type(id) == "string" and id:lower():find("virus", 1, true) and type(status) == "table" and type(status.effects) == "table" and type(status.effects.currentduration) == "number" then App.DataWrite(status.effects, "currentduration", 1000000000) end
        end end
    end
    if App.legacyStatus then App.legacyStatus:Set({Title = "Local preset status", Content = string.format("%d selected perk presets | %d client definition fields changed. Select the matching base perk before spawning.", App.Count(App.legacy.active), App.legacy.changes)}) end
end
function App.UpdateRewritePanel()
    if not App.rewriteParagraph then return end
    local hum = App.Humanoid()
    local lines = {hum and string.format("Observed character health: %s / %s", tostring(hum.Health), tostring(hum.MaxHealth)) or "Observed character health: waiting for spawn"}
    lines[#lines + 1] = App.rewrite.stamina or "Stamina controller: not checked"
    local heal = App.rewrite.last.Regeneration
    if heal then lines[#lines + 1] = "Regeneration: " .. heal.state .. "; " .. heal.detail end
    if App.rewrite.healthAtRequest and hum then lines[#lines + 1] = "HP at latest request: " .. tostring(App.rewrite.healthAtRequest) .. "; now: " .. tostring(hum.Health) end
    App.rewriteParagraph:Set({Title = "Health / controller results", Content = table.concat(lines, "\n")})
end
function App.UpdateRuntimeStamina()
    local interface = App.modules.interface
    local state = interface and interface.raw_state
    if App.cfg.legacyStamina and type(state) == "table" and type(state.stamina) == "number" and state.stamina == state.stamina and type(state.max_stamina) == "number" and state.max_stamina > 0 and state.max_stamina < math.huge then
        local ok = pcall(App.Patch, state, "stamina", state.max_stamina)
        App.rewrite.stamina = ok and "Stamina controller: exposed runtime value refilled" or "Stamina controller: runtime value is read-only"
    else
        if type(state) == "table" then App.Restore(state, "stamina") end
        App.rewrite.stamina = App.cfg.legacyStamina and "Stamina controller: runtime value not exposed; definition capacity boost only" or "Stamina controller: disabled"
    end
end
function App.UpdateNetless()
    local character = App.Character()
    local owned = App.rewrite.netlessParts or {}; App.rewrite.netlessParts = owned
    for part in pairs(owned) do
        if not App.cfg.netless or not character or not part:IsDescendantOf(character) or App.cfg.fly then App.Restore(part, "AssemblyLinearVelocity"); owned[part] = nil end
    end
    if App.cfg.netless and character and not App.cfg.fly then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then App.Patch(part, "AssemblyLinearVelocity", Vector3.new(0, 35, 0)); owned[part] = true end
        end
    end
end
function App.ShowFeatureStatus()
    local lines = {}
    for _, name in ipairs({"dealDamage", "initiateblock", "applyGore", "throwWeapon", "dropAmmo", "deathPlay", "spawnPlayer"}) do lines[#lines + 1] = name .. ": " .. (App.LegacyRemote(name) and "present; requests unverified" or "not present") end
    local blueprint = App.Path(Services.Replicated, "Interactables", "interaction")
    lines[#lines + 1] = "Blueprint interaction: " .. (blueprint and blueprint:IsA("RemoteEvent") and "present; requests unverified" or "not present")
    lines[#lines + 1] = "Snowy's Semi loader: HTTP 404 when checked 26 October 2026. Built-in automatic regeneration is a separate implementation."
    lines[#lines + 1] = "Server crasher: disabled. Missing methods do not silently invoke another feature."
    App.Copy(table.concat(lines, "\n"), "Original feature status")
end
function App.OriginalExternal(label)
    for index, record in ipairs(Legacy.externals) do if record.label == label then return App.External(index) end end
    return App.ActionResult(label, "unavailable", "The original source reference was not found.")
end
function App.BuildRestoredPerks(tab)
    for index, preset in ipairs(Legacy.presets) do local selected = index; App.Button(tab, preset.label, function() App.UseLegacyPreset(selected) end) end
    App.Button(tab, "Semi-Godmode (Lazarus / Kick Risk / Made by Snowy)", function()
        App.Set("autoRegen", not App.cfg.autoRegen, true)
        App.Notify("Semi-Godmode", "Built-in automatic regeneration " .. (App.cfg.autoRegen and "enabled" or "disabled") .. ". Snowy's source URL is unavailable; this is the public Regeneration method, not a recovered copy of his script.")
    end)
    App.Button(tab, "Devil Hunter Animation", function() App.OriginalExternal("Devil Hunter Animation") end)
    App.Button(tab, "Jericho Animation", function() App.OriginalExternal("Jericho Animation") end)
end
function App.BuildRestoredItems(mainTab)
    local settings = App.Group(mainTab, "Item actions")
    App.controls.itemAction = settings:CreateDropdown({Name = "Item button action", Options = {"Original spawn request", "Craft / find with owned blueprint", "Find existing item"}, CurrentOption = {App.cfg.itemAction}, MultipleOptions = false, Callback = function(options) App.Set("itemAction", options[1]) end})
    App.Paragraph(settings, "Item categories", "Your original shortcuts stay in their categories. Each category also lists matching current-game items. This selector controls the shortcuts and category pickers.")
    App.originalItemViews = {}
    for _, pair in ipairs({{"Guns", "Guns", "Guns / ranged"}, {"stims", "Stim Options", "Stims"}, {"melee", "Melee Options", "Melee"}, {"Heal", "Healing Options", "Healing"}, {"Throw", "Throwable Items", "Throwables"}}) do
        local group = App.Group(mainTab, pair[2])
        local originalIds = {}
        for _, record in ipairs(Legacy.items) do
            if record.section == pair[1] then originalIds[record.id] = true end
        end
        local category = pair[3]
        local view = App.CatalogPicker(group, pair[2] .. " / current items", "items", function(id, record) return originalIds[id] == true or App.DynamicItemCategory(record) == category end, {compact = true})
        App.originalItemViews[pair[1]] = view
        App.Button(group, "Use selected " .. pair[2] .. " item", function()
            if not view.selectedId then App.Notify("Items", "Choose a current item in this category first."); return end
            App.RunItemAction(view.selectedId)
        end)
        for _, record in ipairs(Legacy.items) do
            if record.section == pair[1] then local id, label = record.id, record.label; App.Button(group, label, function() App.RunItemAction(id, label) end) end
        end
    end
end
function App.RunItemAction(id, label)
    if not id or not Catalog.items[id] then return App.ActionResult(label or "Items", "unavailable", "This ID is not in the current item list. Choose its current entry from the category picker.") end
    if App.cfg.itemAction == "Craft / find with owned blueprint" then return App.CraftCatalogItem(id, label or Catalog.items[id].name)
    elseif App.cfg.itemAction == "Find existing item" then return App.FindCatalogItem(id) end
    return App.OriginalSpawnItem(id, label or Catalog.items[id].name)
end
function App.BuildMedicPanel(tab)
    App.rewriteParagraph = App.Paragraph(tab, "Health / controller results", "Waiting for character...")
    App.Button(tab, "Heal once / original Regeneration", function() App.HealOriginal(false) end)
    App.Button(tab, "Heal burst (J)", App.HealBurst)
    App.Toggle(tab, "Automatic regeneration / semi-godmode", "autoRegen")
    App.Slider(tab, "Regenerate below health percent", "regenThreshold", {10, 100}, 5, "%")
    App.Slider(tab, "Regeneration interval", "regenInterval", {0.2, 2}, 0.05, "s")
    App.Slider(tab, "Heal burst requests", "healBurst", {1, 10}, 1)
    tab:CreateDropdown({Name = "Legacy regeneration authentication", Options = {"Auto", "Original keys required", "No keys (neutral 2024)"}, CurrentOption = {App.cfg.legacyAuth}, MultipleOptions = false, Callback = function(options) App.Set("legacyAuth", options[1]) end})
    App.Toggle(tab, "Custom Lazarus health / healing definitions", "customLazarus")
    App.Slider(tab, "Lazarus added max health", "lazarusHealth", {20, 1000000}, 1)
    App.Slider(tab, "Lazarus min_heal", "lazarusHeal", {20, 10000}, 1)
    App.Slider(tab, "Lazarus lazarus_max_heal", "lazarusMaxHeal", {8, 10000}, 1)
    App.Paragraph(tab, "Lazarus methods", "RIS Medic retains its original +999999 health modifier. Custom sliders expose the real Lazarus definition fields. Automatic regeneration sends the public legacy heal request; it cannot prevent an instantly lethal hit. The result panel reads actual character HP and never manufactures a health display.")
end
function App.BuildOriginalAbilities(tab)
    for _, pair in ipairs({{"Parry (R)", "R"}, {"Stun grenade (Y)", "Y"}, {"Prophet scan (B)", "B"}, {"Fire smoke (U)", "U"}, {"Heal (J)", "J"}, {"Ration set (M)", "M"}}) do
        local key = Enum.KeyCode[pair[2]]; App.Button(tab, pair[1], function() App.ExtraAbility(key) end)
    end
    App.Button(tab, "Inspect original handler context", function() App.Notify("Original handler", App.LegacyContext(true) and "Expected legacy handler structure found. Key values are kept private." or "Expected legacy handler structure unavailable. No keys were guessed.") end)
end
function App.BuildGameNotes(tab)
    App.Paragraph(tab, "Scavenge, prepare, survive", "Scavenge for food, ammunition, medical supplies and salvage, then return for the storm waves. Workbenches use blueprints and salvage; scrappers recycle unwanted items. Team deaths add morale penalties. Infection, morale, bleeding and fractures are separate systems.")
    App.Paragraph(tab, "Medical support", "Lazarus's normal shot buffs allies and shocks enemies. Holding the ability fires the healing shot. Its low-health protection is conditional, so it is not permanent invulnerability. Food supports melee output and water supports defense; medical treatment depends on the injury.")
    App.Paragraph(tab, "Research references", "Game-specific notes were checked against the community wiki and the uploaded game definitions. Script implementations reviewed: original Lucky Blessing, Goodwill, neutral's open source script, IrishBaker's Passive Heal / Longer Effects, Teddy and SkidWare. A public script's feature label or upload date does not establish that its method still works.")
end
local SetBeforeRewrite = App.Set
App.Set = function(key, value, updateControl)
    local limits = {regenThreshold = {10,100}, regenInterval = {0.2,2}, healBurst = {1,10}, lazarusHealth = {20,1000000}, lazarusHeal = {20,10000}, lazarusMaxHeal = {8,10000}}
    if limits[key] then
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
        value = math.clamp(value, limits[key][1], limits[key][2]); if key ~= "regenInterval" then value = math.floor(value) end
    elseif key == "legacyAuth" and value ~= "Auto" and value ~= "Original keys required" and value ~= "No keys (neutral 2024)" then return false
    elseif key == "itemAction" and value ~= "Original spawn request" and value ~= "Craft / find with owned blueprint" and value ~= "Find existing item" then return false end
    local nativeUpdate = updateControl
    if key == "itemAction" then nativeUpdate = false end
    local ok = SetBeforeRewrite(key, value, nativeUpdate)
    if not ok then return false end
    if key == "longEffects" or key == "shortDebuffs" or key == "customLazarus" or key:find("^lazarus") then App.RebuildLegacyData() end
    if key == "legacyStamina" then App.UpdateRuntimeStamina() end
    if key == "netless" and not value then App.UpdateNetless() end
    if key == "itemAction" and updateControl and App.controls.itemAction then App.controls.itemAction:Set({value}) end
    return true
end
local PanicBeforeRewrite = App.Panic
App.Panic = function()
    App.rewrite.healTask = nil; if App.rewrite.spawnTask then App.rewrite.spawnTask.cancelled = true; App.rewrite.spawnTask = nil end
    for _, key in ipairs({"autoRegen", "longEffects", "shortDebuffs", "customLazarus", "netless"}) do App.Set(key, false, true) end
    PanicBeforeRewrite(); App.UpdateRuntimeStamina()
end
local ResetBeforeRewrite = App.ResetLegacyPresets
App.ResetLegacyPresets = function()
    App.cfg.customLazarus = false
    if App.controls.customLazarus then App.controls.customLazarus:Set(false) end
    ResetBeforeRewrite()
end
local UnloadBeforeRewrite = App.Unload
App.Unload = function()
    App.rewrite.healTask = nil
    if App.rewrite.spawnTask then App.rewrite.spawnTask.cancelled = true; App.rewrite.spawnTask = nil end
    UnloadBeforeRewrite()
    App.rewrite.context = nil
    if App.rewrite.netlessParts then table.clear(App.rewrite.netlessParts) end
end
local StartBeforeRewrite = App.Start
App.Start = function()
    StartBeforeRewrite()
    if not App.alive then return end
    local panelTime = 0
    App.Connect(Services.Run.Heartbeat, function(delta)
        App.UpdateRuntimeStamina()
        local hum = App.Humanoid()
        if App.cfg.autoRegen and not App.rewrite.healTask and App.tick >= App.rewrite.nextHeal and hum and hum.Health > 0 and hum.Health < hum.MaxHealth and hum.Health / math.max(1, hum.MaxHealth) * 100 <= App.cfg.regenThreshold then
            if not App.HealOriginal(true) then App.cfg.autoRegen = false; if App.controls.autoRegen then App.controls.autoRegen:Set(false) end; App.Notify("Automatic regeneration paused", App.rewrite.last.Regeneration.detail) end
        end
        panelTime = panelTime + delta
        if panelTime >= 1 then panelTime = 0; App.UpdateRewritePanel() end
    end)
    App.Connect(Services.Run.PreSimulation, App.UpdateNetless)
    App.UpdateRewritePanel()
end


local ok, err = pcall(App.Start)
if not ok then
    App.Note(err)
    App.Unload()
    error("DW Field Kit init failed: " .. tostring(err))
end
return App
