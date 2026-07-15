-- Worldwide Invitational 2008 promo redeemer: Ian Drake (NPC 29093).
-- Retail validated attendee codes against Blizzard's promotion backend; the
-- world DB only ships the NPC, greeting text, and an inert gossip option.
-- This script recreates the event: whisper the secret code, receive Tyrael's
-- Hilt (item 39656). One redemption per account, tracked in
-- acore_characters.custom_wwi_tyraels_hilt (auto-created below; survives
-- dbimport, covered by the normal DB backups).
--
-- The code below is visible in this public repo — fine for a LAN-only realm.
-- To keep it out of git, set AC_WWI_SECRET_CODE in the worldserver env
-- (azerothcore 1Password item -> ExternalSecret) and it takes precedence.
-- Codes are compared case-insensitively ignoring punctuation/spaces, so
-- "wwi08 kx9v 3fq7" matches.

local NPC_ENTRY   = 29093 -- Ian Drake
local ITEM_ENTRY  = 39656 -- Tyrael's Hilt
local NPC_TEXT_ID = 13441 -- retail greeting ("Greetings, $c. I trust...")

local SECRET_CODE = (os and os.getenv and os.getenv("AC_WWI_SECRET_CODE"))
    or "WWI08-KX9V-3FQ7"

local GOSSIP_EVENT_ON_HELLO  = 1
local GOSSIP_EVENT_ON_SELECT = 2
local GOSSIP_ICON_CHAT       = 0
local ACTION_WHISPER_CODE    = 1
local LANG_UNIVERSAL         = 0
local EMOTE_ONESHOT_BOW      = 2
local EMOTE_ONESHOT_NO       = 274

CharDBExecute([[
CREATE TABLE IF NOT EXISTS custom_wwi_tyraels_hilt (
  account_id     INT UNSIGNED NOT NULL PRIMARY KEY,
  character_guid INT UNSIGNED NOT NULL,
  character_name VARCHAR(12)  NOT NULL,
  redeemed_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]])

-- Case/punctuation-insensitive: keep only alphanumerics, uppercased.
local function Normalize(code)
    return (tostring(code or ""):upper():gsub("%W", ""))
end

local function HasRedeemed(player)
    return CharDBQuery(string.format(
        "SELECT 1 FROM custom_wwi_tyraels_hilt WHERE account_id = %d",
        player:GetAccountId())) ~= nil
end

local function OnHello(event, player, creature)
    player:GossipMenuAddItem(GOSSIP_ICON_CHAT,
        "I would like to whisper my secret code to you to receive Tyrael's Hilt.",
        0, ACTION_WHISPER_CODE, true,
        "Whisper your secret code into Ian Drake's ear.")
    player:GossipSendMenu(NPC_TEXT_ID, creature)
end

local function OnSelect(event, player, creature, sender, intid, code)
    player:GossipComplete()
    if intid ~= ACTION_WHISPER_CODE then
        return
    end

    local name = player:GetName()

    if HasRedeemed(player) then
        creature:SendUnitWhisper(
            "Ah, " .. name .. " — I remember you well. But I have already given" ..
            " you your gift, and Tyrael was very clear: one hilt per soul." ..
            " No exceptions, not even for heroes.",
            LANG_UNIVERSAL, player)
        return
    end

    if Normalize(code) == "" then
        creature:SendUnitWhisper(
            "You lean in close... and say nothing at all. The code, friend —" ..
            " whisper me the code.",
            LANG_UNIVERSAL, player)
        return
    end

    if Normalize(code) ~= Normalize(SECRET_CODE) then
        creature:PerformEmote(EMOTE_ONESHOT_NO)
        creature:SendUnitWhisper(
            "No... no, that is not it. Wherever you came by that one, " .. name ..
            ", I fear you were had. The true code is worth more than gold —" ..
            " guard your coin better next time.",
            LANG_UNIVERSAL, player)
        return
    end

    local item = player:AddItem(ITEM_ENTRY, 1)
    if not item then
        creature:SendUnitWhisper(
            "Eager, are we? Your bags are stuffed to bursting and I will not" ..
            " see this treasure dropped in the mud. Make some room, then" ..
            " whisper it to me again.",
            LANG_UNIVERSAL, player)
        return
    end

    CharDBExecute(string.format(
        "INSERT IGNORE INTO custom_wwi_tyraels_hilt" ..
        " (account_id, character_guid, character_name) VALUES (%d, %d, '%s')",
        player:GetAccountId(), player:GetGUIDLow(), name))

    creature:PerformEmote(EMOTE_ONESHOT_BOW)
    creature:SendUnitWhisper(
        "By the Light... that is it exactly. I had nearly given up hope that" ..
        " anyone still carried one. A promise is a promise, " .. name ..
        " — Tyrael's Hilt is yours. Guard it well; there are precious few" ..
        " left in this world.",
        LANG_UNIVERSAL, player)
end

RegisterCreatureGossipEvent(NPC_ENTRY, GOSSIP_EVENT_ON_HELLO, OnHello)
RegisterCreatureGossipEvent(NPC_ENTRY, GOSSIP_EVENT_ON_SELECT, OnSelect)

PrintInfo("[wwi-tyraels-hilt] Ian Drake (" .. NPC_ENTRY ..
    ") redemption active; table custom_wwi_tyraels_hilt ready")
