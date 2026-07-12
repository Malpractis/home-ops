# Eluna (ALE) scripts

Files here are mounted at `/azerothcore/lua_scripts` (`ALE.ScriptPath`) on the
worldserver. Drop `.lua` files in this directory and list them in the
`azerothcore-lua-scripts` configMapGenerator — Reloader restarts the
worldserver on change, no image rebuild.

Note: the engine is **mod-ale** (AzerothCore Lua Engine), which has diverged
from original Eluna — write scripts against ALE's API. Non-`.lua` files (like
this one) are ignored by the engine.
