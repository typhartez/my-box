// Typhaine Artez 2018
// Provided under Creative Commons Attribution-Non-Commercial-ShareAlike 4.0 International license.
// Please be sure you read and adhere to the terms of this license: https://creativecommons.org/licenses/by-nc-sa/4.0/

list TYPE2STRING = [
    INVENTORY_NONE, "unknown",
    INVENTORY_TEXTURE, "texture",
    INVENTORY_SOUND, "sound",
    INVENTORY_LANDMARK, "landmark",
    INVENTORY_CLOTHING, "clothing",
    INVENTORY_OBJECT, "object",
    INVENTORY_NOTECARD, "notecard",
    INVENTORY_SCRIPT, "script",
    INVENTORY_BODYPART, "bodypart",
    INVENTORY_ANIMATION, "animation",
    INVENTORY_GESTURE, "gesture"
];
//integer TEXTURE_FACE = 0;
float STOP_ANIM_TIMEOUT = 60.0;
vector REZ_AT = <2.0, 0.0, 1.0>;
integer SHOWPIC_FACE = 0;

integer nitems = 0;     // number of items in this box, including this script
integer iscript = -1;   // index to this script in inventory

integer dlgchan = 0;
string dlgcur = "";
integer dlgpage = 0;
integer curitem = -1;
list curselect;
string playanim;

string type2string(integer type) {
    return llList2String(TYPE2STRING, llListFindList(TYPE2STRING, [type])+1);
}

dlg(string txt, list btns) {
    llDialog(llGetOwner(), txt, llList2List(btns,9,11) + llList2List(btns,6,8) +
        llList2List(btns,3,5) + llList2List(btns,0,2), dlgchan);
}

dlgList() {
    dlgcur = "LIST";
    curitem = -1;

    list btns;
    string txt;
    integer beg; integer end;

    if (nitems > 12) {
        if (iscript < dlgpage) beg = dlgpage+1;
        else beg = dlgpage;

        if (iscript < dlgpage+9) end = dlgpage+10;
        else end = dlgpage+9;
        if (end > nitems) end = nitems;

        txt = "\nPage " + (string)(dlgpage/9+1) + " / " + (string)((nitems-2)/9+1) +
            " (total " + (string)(nitems-1) + " items)\n";
    }
    else {
        beg = 0;
        end = nitems; // contains the script
        txt = "\nShowing " + (string)(nitems-1) + " items.\n";
    }

    string item;
    integer i; integer b;
    for (i = beg; i < end; ++i) {
        if (i != iscript) {
            item = llGetInventoryName(INVENTORY_ALL, i);
            txt += "\n";
            if (i >= iscript) b = i;
            else b = i+1;
            txt += (string)b + "•" + item + " {" + type2string(llGetInventoryType(item)) + "}";
            btns += (string)b;
        }
    }
    if (nitems > 12) {
        while (llGetListLength(btns) % 3) btns += " ";
        btns += [ "◀ Page", "▦ Actions", "Page ▶" ];
    }
    else {
        btns += "▦ Actions";
        while (llGetListLength(btns) % 3) btns += " ";
    }
    dlg(txt, btns);
}

dlgActions() {
    dlgcur = "ACTIONS";
    list btns = [ "Copy All", "Delete All", "Back" ];
    dlg("\nPerform actions on items.", btns);
}

dlgItem(integer n) {
    dlgcur = "ITEM";
    curitem = n;
    string item = llGetInventoryName(INVENTORY_ALL, n);
    integer type = llGetInventoryType(item);
    string txt = item + " {" + type2string(type) + "}\n[ ";
    integer permmask = llGetInventoryPermMask(item, MASK_OWNER);
    list perms = [
        llList2String(["nocopy", "copy"], ((permmask & PERM_COPY) != 0)),
        llList2String(["nomod", "mod"], ((permmask & PERM_MODIFY) != 0)),
        llList2String(["notrans", "trans"], ((permmask & PERM_TRANSFER) != 0))
    ];
    txt += llDumpList2String(perms, " / ") + " ]";
    list btns = [ "Get Copy" ];
    if (type == INVENTORY_OBJECT) btns += "Rez";
    else if (type == INVENTORY_TEXTURE) btns += "Show";
    else if (type == INVENTORY_SOUND) btns += "Play";
    else if (type == INVENTORY_ANIMATION) btns += "Animate";
//    else if (type == INVENTORY_LANDMARK) btns += "Map";
    btns += [ "Delete", "Back" ];
    while (llGetListLength(btns) % 3) btns += " ";
    dlg(txt, btns);
}

default {
    state_entry() {
        nitems = llGetInventoryNumber(INVENTORY_ALL);
        dlgpage = 0;
        dlgchan = 0;
        // find script index in inventory
        integer i;
        string script = llGetScriptName();
        for (i = 0; i < nitems; ++i) {
            if (script == llGetInventoryName(INVENTORY_ALL, i)) {
                iscript = i;
                jump gotindex;
            }
        }
@gotindex;
        llOwnerSay((string)(nitems - 1) + " in object inventory");
    }
    changed(integer what) {
        if (what & CHANGED_INVENTORY) state update;
        else if (what & CHANGED_OWNER) llResetScript();
    }
    touch_start(integer n) {
        key toucher = llDetectedKey(0);
        if (toucher == llGetOwner()) {
            if (nitems > 1) {
                if (!dlgchan) {
                    dlgchan = -1 * (integer)("0x" + llGetSubString(llGetKey(), -7, -1));
                    llListen(dlgchan, "", llGetOwner(), "");
                }
                dlgList();
            }
            else {
                llOwnerSay("no item in object inventory");
            }
        }
    }
    listen(integer channel, string name, key id, string msg) {
        if (dlgcur == "LIST") {
            if (msg == "◀ Page") {
                dlgpage -= 9;
                if (dlgpage < 0) dlgpage = (nitems/9)*9;
                dlgList();
            }
            else if (msg == "Page ▶") {
                dlgpage += 9;
                if (dlgpage >= nitems-1) dlgpage = 0;
                dlgList();
            }
            else if (msg == "▦ Actions") {
                dlgActions();
            }
            else if (msg == " ") {
                dlgList();
            }
            else {
                integer n = (integer)msg;
                if (n > 0) {
                    if (n < iscript) --n;
                    dlgItem(n);
                }
            }
        }
        else if (dlgcur == "ACTIONS") {
            if (msg == "Copy All") {
                list items;
                integer i;
                for (i = 0; i < nitems; ++i)
                    if (i != iscript) items += llGetInventoryName(INVENTORY_ALL, i);
                llGiveInventoryList(id, llGetObjectName(), items);
                dlgList();
            }
            else if (msg == "Delete All") {
                list items;
                integer i;
                for (i = 0; i < nitems; ++i)
                    if (i != iscript) items += llGetInventoryName(INVENTORY_ALL, i);
                i = llGetListLength(items);
                while (~(--i))
                    llRemoveInventory(llList2String(items, i));
                llResetScript();
            }
            else if (msg == "Back") {
                dlgList();
            }
        }
        else if (dlgcur == "ITEM") {
            if (msg == "Back") {
                llSetTexture("94068479-08b6-40d9-9b52-734ac6b7146e", SHOWPIC_FACE);
                dlgList();
                return;
            }
            else if (msg == "Get Copy") {
                string item = llGetInventoryName(INVENTORY_ALL, curitem);
                llOwnerSay("Giving a copy of: " + item);
                llGiveInventory(id, item);
            }
            else if (msg == "Delete") {
                string item = llGetInventoryName(INVENTORY_ALL, curitem);
                llRemoveInventory(item);
                llOwnerSay("Deleted item: " + item);
                --nitems;
                dlgpage = 0;
                dlgList();
                return;
            }
            else if (msg == "Rez") {
                string object = llGetInventoryName(INVENTORY_ALL, curitem);
                vector pos = llGetPos() + (REZ_AT * llGetRot());
                llOwnerSay("Rezzing object: " + object);
                llRezObject(object, pos, ZERO_VECTOR, ZERO_ROTATION, 0);
            }
            else if (msg == "Show") {
                string texture = llGetInventoryName(INVENTORY_ALL, curitem);
                llOwnerSay("Showing texture: " + texture);
                llSetTexture(texture, SHOWPIC_FACE);
            }
            else if (msg == "Play") {
                string sound = llGetInventoryName(INVENTORY_ALL, curitem);
                llOwnerSay("Playing sound:" + sound);
                llPlaySound(sound, 1.0);
            }
            else if (msg == "Animate") {
                llRequestPermissions(id, PERMISSION_TRIGGER_ANIMATION);
            }
/*            else if (msg == "Map") {
                string landmark = llGetInventoryName(INVENTORY_ALL, curitem);

            }*/
            dlgItem(curitem);
        }
    }
    run_time_permissions(integer p) {
        if (p & PERMISSION_TRIGGER_ANIMATION) {
            if (playanim != "") llStopAnimation(playanim);
            playanim = llGetInventoryName(INVENTORY_ALL, curitem);
            llOwnerSay("Animating you (will stop after " + (string)STOP_ANIM_TIMEOUT + " seconds max) with: " + playanim);
            llStartAnimation(playanim);
            llSetTimerEvent(STOP_ANIM_TIMEOUT);
        }
    }
    timer() {
        if (playanim) {
            llStopAnimation(playanim);
            playanim = "";
        }
        llSetTimerEvent(0.0);
    }
}
state update {
    state_entry() {
        llOwnerSay("waiting 1 second after change... (touch again for menu after loading)");
        llSleep(1.0);
        state default;
    }
}

