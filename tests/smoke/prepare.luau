--!nocheck
--- Prepares the headless smoke tests. Run from the repository root:  `lune run tests/smoke/prepare`
---
--- 1. Mirrors the Rojo layout (Flux/, Core/, UI/) into `.smoke/tree` so the modules' relative requires resolve on disk.
--- 2. Downloads `sert` (Flux's headless Roblox-engine emulator, MIT) into `.smoke/sert` and verifies its SHA-256.
---    The version and hash are the ones pinned in Flux's own sert.lock.
---
--- `.smoke/` is git-ignored. Re-run this after changing anything under `src/` or `vendor/`.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local SERT_VERSION = "0.2.1"
local SERT_URL = `https://github.com/kohltastrophe/sert/releases/download/v{SERT_VERSION}/sert-{SERT_VERSION}.zip`
local SERT_SHA256 = "4c2c9e76482bab44e7ad5a7633ca86f562e707b944344aec95937b51a3d2dbbe"

local ROOT = ".smoke"

local function fail(message: string)
	print("prepare: " .. message)
	process.exit(1)
end

assert(fs.isDir("src/UI") and fs.isDir("vendor/flux/src"), "run this from the repository root")

-- 1. tree ------------------------------------------------------------------------------------------------------------
if fs.isDir(`{ROOT}/tree`) then
	fs.removeDir(`{ROOT}/tree`)
end
fs.writeDir(`{ROOT}/tree`)
fs.copy("vendor/flux/src", `{ROOT}/tree/Flux`)
fs.copy("src/Core", `{ROOT}/tree/Core`)
fs.copy("src/UI", `{ROOT}/tree/UI`)
print("prepare: mirrored Flux, Core and UI into .smoke/tree")

-- 2. sert ------------------------------------------------------------------------------------------------------------
if fs.isDir(`{ROOT}/sert/src`) and fs.isFile(`{ROOT}/sert/VERSION`) and fs.readFile(`{ROOT}/sert/VERSION`) == SERT_VERSION then
	print(`prepare: sert {SERT_VERSION} already present`)
	return
end

print(`prepare: downloading sert {SERT_VERSION}...`)
local response = net.request(SERT_URL)
if not response.ok then
	fail(`download failed ({response.statusCode} {response.statusMessage})`)
end
local digest = serde.hash("sha256", response.body)
if digest ~= SERT_SHA256 then
	fail(`checksum mismatch: expected {SERT_SHA256}, got {digest}. Refusing to use the download.`)
end

if fs.isDir(`{ROOT}/sert`) then
	fs.removeDir(`{ROOT}/sert`)
end
fs.writeDir(`{ROOT}/sert`)
local zipPath = `{ROOT}/sert.zip`
fs.writeFile(zipPath, response.body)

-- `process.exec` is the Lune 0.10 name, `process.spawn` the later one.
local run = process.exec or process.spawn
local extract
if process.os == "windows" then
	extract = run("powershell", {
		"-NoProfile",
		"-Command",
		`Expand-Archive -LiteralPath '{zipPath}' -DestinationPath '{ROOT}/sert' -Force`,
	})
else
	extract = run("unzip", { "-q", "-o", zipPath, "-d", `{ROOT}/sert` })
end
if not extract.ok then
	fail("could not extract the archive: " .. extract.stderr)
end
fs.removeFile(zipPath)
fs.writeFile(`{ROOT}/sert/VERSION`, SERT_VERSION)
print(`prepare: sert {SERT_VERSION} verified and extracted`)
