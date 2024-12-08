---

### **Script Identities and Permissions**
1. **Script**
   - **Identity:** `2`
   - **Permissions:** Limited access to the Roblox API.
   - **Aliases:** Standard Script, Server Script.

2. **LocalScript**
   - **Identity:** `2`
   - **Permissions:** Same as Script, but runs on the client.
   - **Aliases:** Client Script, Local Client Script.

3. **ModuleScript**
   - **Identity:** Varies (based on the script requiring it).
   - **Permissions:** Inherits identity of the caller.
   - **Aliases:** Dependency Script, Utility Script.

4. **CoreScript**
   - **Identity:** `3`
   - **Permissions:** Highest permissions among accessible scripts.
   - **Aliases:** System Script, Internal Script.

5. **Command Line**
   - **Identity:** `4`
   - **Permissions:** Elevated permissions for debugging/testing.
   - **Aliases:** Debug Console, Developer Console.

6. **Run Script**
   - **Identity:** `4`
   - **Permissions:** Same as Command Line.
   - **Aliases:** Script Runner.

7. **Plugin**
   - **Identity:** `5`
   - **Permissions:** Plugin-specific access, limited compared to CoreScript.
   - **Aliases:** Editor Script, Development Plugin.

---

### **Security Tags and Associated Permissions**
1. **None**
   - **Permission Level:** No restrictions.
   - **Aliases:** Open Access, Public API.

2. **LocalUserSecurity**
   - **Permission Level:** `3`
   - **Accessible by:** LocalScripts, Plugins, CoreScripts.
   - **Aliases:** Local Access, Client Security.

3. **PluginSecurity**
   - **Permission Level:** `1`
   - **Accessible by:** Plugins, CoreScripts.
   - **Aliases:** Plugin Access, Editor Security.

4. **RobloxScriptSecurity**
   - **Permission Level:** `5,1`
   - **Accessible by:** CoreScripts only.
   - **Aliases:** Core Security, Internal API.

5. **RobloxSecurity**
   - **Permission Level:** `6`
   - **Accessible by:** Roblox internal systems only.
   - **Aliases:** Roblox Restricted, Proprietary API.

6. **NotAccessibleSecurity**
   - **Permission Level:** Unconfirmed (`???`).
   - **Accessible by:** None (completely restricted).
   - **Aliases:** No Access, Hidden API.

---

### **Key Notes**
- **Identity Numbers:** Arbitrary and do not correlate directly to permissions.
- **Permission Levels:** Define what can or cannot be accessed by scripts based on their identity and the associated security tags.
- **Security Tag Relationships:** Identities can access API members depending on the security tags:
  - `2` (Script/LocalScript): Limited access.
  - `4` (Command Line/Run Script): Can access `LocalUserSecurity` and `PluginSecurity`.
  - `5` (Plugin): Same as `4`.
  - `3` (CoreScript): Can access `LocalUserSecurity`, `PluginSecurity`, and `RobloxScriptSecurity`.

---

### **Aliases Reference**
- **Script:** Server Script.
- **LocalScript:** Client Script.
- **ModuleScript:** Utility Script.
- **CoreScript:** Internal Script.
- **Command Line:** Debug Console.
- **Run Script:** Script Runner.
- **Plugin:** Editor Script.
- **LocalUserSecurity:** Client Security.
- **PluginSecurity:** Editor Security.
- **RobloxScriptSecurity:** Core API.
- **RobloxSecurity:** Restricted Access.
- **NotAccessibleSecurity:** Hidden API.
