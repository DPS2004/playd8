local nacho = {}

function nacho.setup(dontusejit, bitops)
    local bit = {}
    if dontusejit then
		bit = bitops
    else
		bit = require("bit")
	end
    nacho.bit = {}

    nacho.bit.tobit = bit.tobit
    nacho.bit.tohex = bit.tohex

    nacho.bit.rol = bit.rol
    nacho.bit.ror = bit.ror

    nacho.bit.lshift = bit.lshift
    nacho.bit.rshift = bit.rshift

    nacho.bit.band = bit.band
    nacho.bit.bor = bit.bor
    nacho.bit.bxor = bit.bxor

    nacho.get = function(x, i)
        return string.sub(x, i + 1, i + 1)
    end

    nacho.gbit = function(byte, i)
        return (nacho.bit.band(nacho.bit.rshift(byte, i), 0x01)) == 1
    end

    nacho.binarystring = function(x, reverse)
        local t = {}
        for i = 0, 7 do
            if reverse then
                table.insert(t, 1, nacho.bit.band(x, 0x01))
            else
                table.insert(t, nacho.bit.band(x, 0x01))
            end
            x = nacho.bit.ror(x, 1)
        end
        return table.concat(t)
    end
end
if not pr then
    pr = function()
    end
end

function nacho.loadtabletochip(prg, chip)
    for i, v in ipairs(prg) do
        chip.mem[0x200 + (i - 1)] = v
    end
    return chip
end

-- general utility functions go up here i guess?
function nacho.addleadings(x, n, f)
    n = n or 4
    f = f or "0"
    local r = tostring(x)
    local l = n - #r
    for i = 1, l do
        r = f .. r
    end
    return r
end

function nacho.trim(s)
    return s:match "^%s*(.-)%s*$"
end

function nacho.split(instr, s)
    s = s or "%s"
    local t = {}
    for str in string.gmatch(instr, "([^" .. s .. "]+)") do
        table.insert(t, str)
    end
    return t
end

function nacho.copy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[nacho.copy(orig_key, copies)] = nacho.copy(orig_value, copies)
            end
            setmetatable(copy, nacho.copy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function nacho.loadspritepng(fn)
    error("loadspritepng not set up")
end

function nacho.compile(nch) -- compile .nch files to .ch8
    local function trimall(t)
        local nt = {}
        for i, v in ipairs(t) do
            print(v)

            local i1, i2 = string.find(v, "--", 1, true)
            if i1 then
                v = string.sub(v, 0, i1 - 1)
            end

            local trimmed = nacho.trim(v)

            if trimmed ~= "" then
                table.insert(nt, trimmed)
            end
        end
        return nt
    end

    local function startswith(str, k)
        if (string.sub(nacho.trim(str), 0, #k) == k) then
            return string.sub(nacho.trim(str), #k + 1)
        else
            return nil
        end
    end

    local function parsecommand(line, k)
        local testerline = startswith(line, k .. "(")
        line = startswith(line, k)
        if not testerline then -- check if line start matches k
            --if it doesnt, then exit
            return nil
        end

        --step 1: get rid of ending comments
        local i1, i2 = string.find(line, "--", 1, true)
        if i1 then
            line = nacho.trim(string.sub(line, 0, i1 - 1))
        end

        local params = {}
        for v in string.gmatch(string.sub(line, 2), "([^,]+)") do
            v = nacho.trim(v)
            table.insert(params, v)
        end
        if params[#params] then
            params[#params] = string.sub(params[#params], 1, -2) --remove )
        end

        return params
    end

    local function findbefore(str, k)
        k = k or "("
        local fi = string.find(str, k, 1, true)
        if fi then
            return string.sub(str, 0, fi - 1)
        else
            return nil
        end
    end

    local function findafter(str, k)
        k = k or "="
        local _, fi = string.find(str, k, 1, true)
        if fi then
            return string.sub(str, fi + 1)
        else
            return nil
        end
    end

    local function sandwich(j, str, k)
        return findbefore(findafter(str, j), k)
    end

    local lines = {}
    for i, v in ipairs(nacho.split(nch, "\n")) do
        local trimmed = nacho.trim(v)
        if trimmed ~= "" and string.sub(trimmed, 1, 2) ~= "--" then
            table.insert(lines, nacho.trim(v))
        end
    end

    --first we need to load the spritedata png if it exists

    local spritedata = nil

    for i, line in ipairs(lines) do
        local params = parsecommand(line, "loadspritedata")

        if params then
            spritedata = nacho.loadspritepng(params[1])
            lines[i] = ""
        end
    end

    --time to deal with macro and const

    macros = {}

    for i, line in ipairs(lines) do
        line = startswith(line, "_macro ")
        local macrolines = {}
        if line then
            local foundend = false
            for ii, iline in ipairs(lines) do
                if ii > i then
                    if not foundend then
                        if startswith(iline, "_macroend") then
                            foundend = true
                        else
                            table.insert(macrolines, iline)
                        end
                        lines[ii] = ""
                    end
                end
            end

            table.insert(macros, {def = line, lines = macrolines})
            lines[i] = ""
        end
    end
    lines = trimall(lines)
    -- at this point, all macro definitions have been removed

    -- we now need to reinsert the macros

    for li, line in ipairs(lines) do
        for mi, macro in ipairs(macros) do
            if (findbefore(line) and (findbefore(line) == findbefore(macro.def))) or line == macro.def then
                print(li, "removing " .. lines[li])
                table.remove(lines, li)
                local mlines = {}
                for i, v in ipairs(macro.lines) do
                    table.insert(mlines, v)
                end

                local mparams = {}
                local lparams = {}
                if findbefore(macro.def) then
                    mparams = parsecommand(macro.def, findbefore(macro.def))
                    lparams = parsecommand(line, findbefore(line))
                end

                for i, v in ipairs(mparams) do
                    for mli, mlv in ipairs(mlines) do
                        mlines[mli] = mlines[mli]:gsub(mparams[i], lparams[i])
                    end
                end

                for i, v in ipairs(mlines) do
                    table.insert(lines, li - 1 + i, v)
                end
            end
        end
    end

    -- all macros have been reinserted

    -- time for constants

    local constants = {}

    for li, line in ipairs(lines) do
        line = startswith(line, "_const ") -- _const testconst = 1 -- comments

        if line then --testconst = 1 -- comments
            local i1, i2 = string.find(line, "--", 1, true)
            if i1 then
                line = nacho.trim(string.sub(line, 0, i1 - 1)) --testconst = 1
            end
            print(line)

            local constname = nacho.trim(findbefore(line, "="))
            local constval = nacho.trim(findafter(line, "="))

            local params = parsecommand(constval, "load")
            if params then
                table.insert(lines, li + 1, "@" .. constname .. ":")
                for si, sv in ipairs(spritedata[tonumber(params[1]) + 1]) do
                    table.insert(lines, li + si + 1, "*" .. nacho.bit.tohex(sv, 2))
                end

                lines[li] = ""
            elseif parsecommand(constval, "loadsize") then
                params = parsecommand(constval, "loadsize")

                constants[constname] = #spritedata[tonumber(params[1]) + 1]

                lines[li] = ""
            else
                constants[constname] = constval

                lines[li] = ""
            end
        end
    end

    lines = trimall(lines)

    print("final final:")
    lines = trimall(lines)

    print("!!!!!!!TIME TO DEAL WITH JUMPS.!!!!!!!!!!")
    local jindex = 512
    for li, line in ipairs(lines) do
        print("jindex: " .. jindex)
        print(line)
        local startch = string.sub(line, 0, 1)
        if startch == "@" then
            constants[sandwich("@", line, ":")] = jindex
            print("setting " .. sandwich("@", line, ":") .. " to " .. jindex)
            lines[li] = ""
        elseif startch == "*" then
            jindex = jindex + 1
        else
            jindex = jindex + 2
        end
    end

    lines = trimall(lines)

    --Here is where the error is.
    print("set all constants to their actual values")

    local orderedconstants = {}
    for k, v in pairs(constants) do
        table.insert(orderedconstants, k)
    end

    table.sort(
        orderedconstants,
        function(a, b)
            return #a > #b
        end
    )

    for i, v in ipairs(orderedconstants) do
        print(i, v)
    end

    for li, line in ipairs(lines) do
        for i, v in ipairs(orderedconstants) do
            lines[li] = lines[li]:gsub(v, constants[v])
        end
    end
    lines = trimall(lines)

    local cmdlist = {
        "cls",
        "jump",
        "draw",
        "waitforkey",
        "skipif",
        "font"
    }

    local bytelines = {}
    print("FINAL FINAL PASS! MAKING BYTES!")

    local function addbyte(byte)
        print(byte)
        table.insert(bytelines, nacho.bit.tobit(tonumber("0x" .. byte)))
    end
    local function doublebytes(bytes)
        addbyte(string.sub(bytes, 1, 2))
        addbyte(string.sub(bytes, 3, 4))
    end

    for i, line in ipairs(lines) do
        print("converting " .. line)
        local params = nil
        local fcmd = nil

        for icmd, vcmd in ipairs(cmdlist) do
            if not params then
                params = parsecommand(line, vcmd)
                fcmd = vcmd
            end
        end

        if params then
            if fcmd == "cls" then
                doublebytes("00e0")
            elseif fcmd == "jump" then
                doublebytes("1" .. nacho.bit.tohex(params[1], 3))
            elseif fcmd == "draw" then
                doublebytes(
                    "d" ..
                        nacho.bit.tohex(string.sub(params[1], 2, 2), 1) ..
                            nacho.bit.tohex(string.sub(params[2], 2, 2), 1) .. nacho.bit.tohex(params[3], 1)
                )
            elseif fcmd == "waitforkey" then
                doublebytes("f" .. nacho.bit.tohex(string.sub(params[1], 2, 2), 1) .. "0a")
            elseif fcmd == "skipif" then
                local tcond = nacho.trim(params[1])
                local firstv = nacho.bit.tohex(string.sub(tcond, 2, 2), 1)
                local secondv = nacho.trim(findafter(tcond, "="))
                local usenot = false
                if string.find(tcond, "~=", 1, true) or string.find(tcond, "!=", 1, true) then
                    usenot = true
                end
                if string.sub(secondv, 0, 1) == "v" then
                    if not usenot then
                        doublebytes("5" .. firstv .. nacho.bit.tohex(string.sub(secondv, 2, 2), 1) .. "0")
                    else
                        doublebytes("9" .. firstv .. nacho.bit.tohex(string.sub(secondv, 2, 2), 1) .. "0")
                    end
                else
                    if not usenot then
                        doublebytes("3" .. firstv .. nacho.bit.tohex(secondv, 2))
                    else
                        doublebytes("4" .. firstv .. nacho.bit.tohex(secondv, 2))
                    end
                end
            elseif fcmd == "font" then
                doublebytes("f" .. nacho.bit.tohex(string.sub(params[1], 2, 2), 1) .. "29")
            end
        else
            local startch = string.sub(line, 0, 1)
            if startch == "*" then
                addbyte(string.sub(line, 2, 3))
            elseif startswith(line, "index") then
                doublebytes("a" .. nacho.bit.tohex(nacho.trim(findafter(line, "=")), 3))
            elseif startch == "v" then
                local setvar = string.sub(line, 2, 2)
                --print(toset)
                local toset = tonumber(nacho.trim(findafter(line, "=")))
                if string.sub(toset, 0, 1) == "v" then
                    if false then --check for add, subtract, etc etc
                    else
                        --8XY0
                    end
                else
                    if false then --check for add
                    else
                        --6XNN
                        doublebytes("6" .. setvar .. nacho.bit.tohex(toset, 2))
                    end
                end
            end
        end
    end

    return bytelines
end

function nacho.init(mode, cmode, extras) -- make a new instance of chip8
    local chip = {}

    if extras then
        for k, v in pairs(extras) do
            chip[k] = v
        end
    end

    chip.dmp = function()
    end
    chip.dmpj = function()
    end
    chip.spr = function()
    end
    chip.nop = function()
    end

    if chip.dumper then
        print("loading chip in dumper mode!")
        --DUMPER MODE OVERVIEW:
        -- Dumper mode is a special mode that cannot write to memory, but can read.
        -- Any instruction that writes to memory is skipped over.

        -- Instructions 3xnn, 4xnn, 5xy0, and 9xy0 will never skip.
        -- However, PC+2 is added to a queue of instructions to check after the current path is exhausted by the decompiler.
        chip.keys = {}
        for i = 0, 15 do --set all keys to pressed
            chip.keys[i] = {pressed = true, released = true, down = true}
        end

        chip.dump = {}
        chip.labels = {}
        chip.lcount = {}
        chip.sprites = {}

        chip.dmp = function(val, pos, og, length)
            pos = pos or (chip.pc - 2)
            og = og or nacho.bit.tohex(chip.mem[pos], 2) .. nacho.bit.tohex(chip.mem[pos + 1], 2)

            length = length or 2

            chip.dump[pos] = {length = length - 1, val = val, og = og, pos = pos}

            for i = 1, length do
                local outval = ""
                if i == 1 then
                    outval = val .. " "
                end
                --print(pos + (i-1), outval .. '-- '.. nacho.bit.tohex(chip.mem[pos + (i-1)],2))
                table.insert(
                    chip.chipout.foundops,
                    {
                        pos = pos + (i - 1),
                        val = outval .. "-- " .. nacho.bit.tohex(chip.mem[pos + (i - 1)], 2)
                    }
                )
            end
        end
        chip.dmpj = function(txt, val, pos, pos2)
            if pos >= 512 then
                if not chip.labels[val] then
                    chip.labels[val] = {}
                    chip.lcount[val] = 0
                end

                local lblholder = nil
                local lblname = nil

                for _, lb in pairs(chip.labels) do
                    for k, v in pairs(lb) do
                        if v.pos == pos then -- this label already exists!
                            lblholder = _
                            lblname = k
                        end
                    end
                end

                if lblname then
                else
                    chip.lcount[val] = chip.lcount[val] + 1
                    --haha what
                    chip.labels[val][val .. "_" .. chip.lcount[val]] = {pos = pos}
                    lblname = val .. "_" .. chip.lcount[val]
                end
                txt = txt:gsub("#LBL#", lblname)
            end
            chip.dmp(txt, pos2)
        end
        chip.spr = function(pos, h)
            if pos >= 512 then
                local binstr = ""
                local bytestr = ""
                for dyi = 0, h - 1 do
                    local sprbyte = chip.mem[pos + dyi] -- get byte from memory
                    binstr =
                        binstr ..
                        "*" ..
                            nacho.bit.tohex(sprbyte, 2) ..
                                " -- " .. nacho.binarystring(sprbyte, true):gsub("0", "."):gsub("1", "#") .. "\n"
                    bytestr = bytestr .. nacho.bit.tohex(sprbyte, 2)
                end
                if chip.sprites[pos] then
                    if chip.sprites[pos].height >= h then
                        return
                    end
                end
                chip.dmp(binstr, pos, bytestr, h)
                chip.sprites[pos] = {height = h}
            end
        end

        chip.nop = function(nop)
            nop = nop or chip.pc
            table.insert(chip.chipout.nops, nop)
        end
    end

    chip.mode = mode or "common" -- define default mode.

    chip.modelist = {
        -- COMMON: the default mode, should work for most programs.
        common = {
            sw = 64, -- screen width
            sh = 32, -- screen height
            ips = 700, -- number of instructions to execute per second
            memsize = 4096, -- how many bytes of memory
            vyshift = false, --set vx to vy in 8xy6 and 8xye
            vxoffsetjump = false, -- false for bnnn, true for bxnn
            indexoverflow = true, -- true to set vf to 1 if index goes over 1000
            tempstoreload = true, -- set false to increment i for fx55 and fx65 instead of using a temporary variable
            waitforrelease = false, -- wait for the key to be released for fx0a
            dotimedupdate = false, -- set to true to emulate the vip cosmac's timing. overides ips.
            pagesize = 256 -- only used if timedupdate = true, this is just a guess!!
        },
        -- COSMAC VIP: The original. Use for super old programs.
        cosmac = {
            vyshift = true,
            indexoverflow = false,
            tempstoreload = false,
            waitforrelease = true,
            dotimedupdate = true
        },
        -- SUPER-CHIP: bigger screen res, and some other extra fun stuff.
        schip = {
            sw = 128,
            sh = 64
        },
        -- BISQWIT: runs programs made by Bisqwit for his Chip-8 interpreter, found in this video https://www.youtube.com/watch?v=rpLoS7B6T94
        -- note: currently does not ;)
        bisqwit = {}
    }
    chip.cf = {}
    for k, v in pairs(chip.modelist.common) do
        chip.cf[k] = v
    end

    local ncf = nil
    if chip.mode == "custom" then
        ncf = cmode
    else
        ncf = chip.modelist[chip.mode]
    end
    for k, v in pairs(ncf) do
        chip.cf[k] = v
    end

    chip.last = "0000"

    chip.pc = 0x200 -- the program counter
    chip.index = 0 -- index register

    chip.stack = {} -- stack for subroutines

    function chip.push(x) --push to stack
        table.insert(chip.stack, x)
    end

    function chip.pop() -- pop from stack
        return table.remove(chip.stack)
    end

    function chip.peek() -- look at last item in stack
        return chip.stack[#chip.stack]
    end

    chip.microseconds = 0 --how many microseconds have elapsed

    chip.maxms = math.floor(1000000 / 60) --assuming 60fps for now

    function chip.ms(x, v, a, b)
        chip.microseconds = chip.microseconds + x

        if v then
            if b then
                if math.floor(a / chip.cf.pagesize) == math.floor(b / chip.cf.pagesize) then
                    chip.microseconds = chip.microseconds - v
                else
                    chip.microseconds = chip.microseconds + v
                end
            elseif a ~= nil then
                if a then
                    chip.microseconds = chip.microseconds - v
                else
                    chip.microseconds = chip.microseconds + v
                end
            else
                chip.microseconds = chip.microseconds + v
            end
        end
    end

    chip.screenupdated = true -- has a function that modifies the screen been called?

    chip.delay = 0 -- sound and delay timers
    chip.sound = 0

    chip.v = {}
    for i = 0, 15 do -- set up v0-vf
        chip.v[i] = 0
    end

    chip.mem = {}
    for i = 0, chip.cf.memsize do -- set up memory
        chip.mem[i] = 0
    end

    local fontdata = {
        --font data from tobiasvl.github.io
        0xf0,
        0x90,
        0x90,
        0x90,
        0xf0,
        0x20,
        0x60,
        0x20,
        0x20,
        0x70,
        0xf0,
        0x10,
        0xf0,
        0x80,
        0xf0,
        0xf0,
        0x10,
        0xf0,
        0x10,
        0xf0,
        0x90,
        0x90,
        0xf0,
        0x10,
        0x10,
        0xf0,
        0x80,
        0xf0,
        0x10,
        0xf0,
        0xf0,
        0x80,
        0xf0,
        0x90,
        0xf0,
        0xf0,
        0x10,
        0x20,
        0x40,
        0x40,
        0xf0,
        0x90,
        0xf0,
        0x90,
        0xf0,
        0xf0,
        0x90,
        0xf0,
        0x10,
        0xf0,
        0xf0,
        0x90,
        0xf0,
        0x90,
        0x90,
        0xe0,
        0x90,
        0xe0,
        0x90,
        0xe0,
        0xf0,
        0x80,
        0x80,
        0x80,
        0xf0,
        0xe0,
        0x90,
        0x90,
        0x90,
        0xe0,
        0xf0,
        0x80,
        0xf0,
        0x80,
        0xf0,
        0xf0,
        0x80,
        0xf0,
        0x80,
        0x80
    }

    for i, v in ipairs(fontdata) do --load into memory starting at 0x050
        chip.mem[0x050 + (i - 1)] = v
    end

    chip.display = {}
    for x = 0, chip.cf.sw - 1 do
        chip.display[x] = {}
        for y = 0, chip.cf.sh - 1 do
            chip.display[x][y] = false -- initialize all pixels to black
        end
    end

    function chip.decode(b1, b2)
        chip.last = nacho.bit.tohex(b1, 2) .. nacho.bit.tohex(b2, 2)
        pr("decoding " .. chip.last)
        local c = nacho.bit.rshift(nacho.bit.band(b1, 0xf0), 4) -- first nibble, the instruction
        local x = nacho.bit.band(b1, 0x0f) -- second nibble, for a register
        local y = nacho.bit.rshift(nacho.bit.band(b2, 0xf0), 4) -- third nibble, for a register
        local n = nacho.bit.band(b2, 0x0f) -- fourth nibble, 4 bit number
        local nn = b2 -- second byte, 8 bit number
        local nnn = x * 256 + b2 -- nibbles 2 3 and 4, 12 bits
        return c, x, y, n, nn, nnn
    end

    function chip.execute(c, x, y, n, nn, nnn)
        if chip.dumper then
            chip.chipout = {
                foundops = {},
                nops = {}
            }
        end

        -- technically this doesnt have to be separate from the decode,
        -- but it's good practice for more complicated systems.
        if c == 0 then
            if nnn == 0x0e0 then
                -- clear screen
                chip.dmp("cls()")
                chip.nop()
                chip.ms(109)

                pr("executing clear screen")
                for dx = 0, #chip.display do
                    for dy = 0, #chip.display[dx] do
                        chip.display[dx][dy] = false
                    end
                end
                chip.screenupdated = true
            elseif nnn == 0x0ee then
                --return from subroutine
                pr("executing return from subroutine")
                chip.dmp("return")
                chip.ms(105, 5, chip.pc, chip.peek())

                pr("pc has gone from " .. chip.pc .. " to " .. chip.peek())
                chip.pc = chip.pop()
            else
                print("unknown instruction!")
            end
        elseif c == 1 then
            -- jump
            pr("executing jump")
            chip.dmpj("jump(#LBL#)", "jump", nnn)
            chip.nop(nnn)
            chip.ms(105, 5, chip.pc, nnn)

            pr("pc has gone from " .. chip.pc .. " to " .. nnn)
            chip.pc = nnn
        elseif c == 2 then
            -- go to subroutine
            pr("executing go to subroutine")
            chip.dmpj("goto(#LBL#)", "goto", nnn)
            chip.nop(nnn)
            chip.ms(105, 5, chip.pc, nnn)

            pr("pc has gone from " .. chip.pc .. " to " .. nnn)
            chip.push(chip.pc)
            chip.pc = nnn
        elseif c == 3 then
            -- skip if equal
            pr("executing skip if equal")
            chip.dmp("skipif(v" .. x .. " = " .. nn .. ")")
            chip.nop(chip.pc)
            chip.nop(chip.pc + 2)
            chip.ms(55, 9, nn == chip.v[x])

            pr("nn is " .. nn .. ", v" .. x .. " is " .. chip.v[x])
            if nn == chip.v[x] then
                pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                chip.pc = chip.pc + 2
            else
                pr("pc remains at " .. chip.pc)
            end
        elseif c == 4 then
            -- skip if not equal
            pr("executing skip if not equal")
            chip.dmp("skipif(v" .. x .. " != " .. nn .. ")")
            chip.nop(chip.pc)
            chip.nop(chip.pc + 2)
            chip.ms(55, 9, nn ~= chip.v[x])

            pr("nn is " .. nn .. ", v" .. x .. " is " .. chip.v[x])
            if nn ~= chip.v[x] then
                pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                chip.pc = chip.pc + 2
            else
                pr("pc remains at " .. chip.pc)
            end
        elseif c == 5 then
            -- register skip if equal
            pr("executing register skip if equal")
            chip.dmp("skipif(v" .. x .. " = v" .. y .. ")")
            chip.nop(chip.pc)
            chip.nop(chip.pc + 2)
            chip.ms(73, 9, chip.v[x] == chip.v[y])

            pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
            if chip.v[x] == chip.v[y] then
                pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                chip.pc = chip.pc + 2
            else
                pr("pc remains at " .. chip.pc)
            end
        elseif c == 6 then
            -- set
            pr("executing set")
            chip.dmp("v" .. x .. " = " .. nn)
            chip.nop()
            chip.ms(27)

            pr("v" .. x .. " has gone from " .. chip.v[x] .. " to " .. nn)
            chip.v[x] = nn
        elseif c == 7 then
            -- add
            pr("executing add")
            chip.dmp("v" .. x .. " += " .. nn)
            chip.nop()
            chip.ms(45)

            pr("v" .. x .. " has gone from " .. chip.v[x] .. " to " .. (chip.v[x] + nn) % 256)
            chip.v[x] = (chip.v[x] + nn) % 256
        elseif c == 8 then
            chip.ms(200)
            chip.nop()
            if n == 0 then
                -- register set
                pr("executing register set")
                chip.dmp("v" .. x .. " = v" .. y)

                pr("setting v" .. x .. " from " .. chip.v[x] .. " to v" .. y .. ", which is " .. chip.v[y])
                chip.v[x] = chip.v[y]
            elseif n == 1 then
                --register or
                pr("executing register or")
                chip.dmp("v" .. x .. " = bor(v" .. x .. "v" .. y .. ")")

                pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                pr("setting v" .. x .. " to " .. nacho.bit.bor(chip.v[x], chip.v[y]))
                chip.v[x] = nacho.bit.bor(chip.v[x], chip.v[y])
            elseif n == 2 then
                --register and
                pr("executing register and")
                chip.dmp("v" .. x .. " = band(v" .. x .. "v" .. y .. ")")

                pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                pr("setting v" .. x .. " to " .. nacho.bit.band(chip.v[x], chip.v[y]))
                chip.v[x] = nacho.bit.band(chip.v[x], chip.v[y])
            elseif n == 3 then
                --register xor
                pr("executing register xor")
                chip.dmp("v" .. x .. " = bxor(v" .. x .. "v" .. y .. ")")

                pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                pr("setting v" .. x .. " to " .. nacho.bit.bxor(chip.v[x], chip.v[y]))
                chip.v[x] = nacho.bit.bxor(chip.v[x], chip.v[y])
            elseif n == 4 then
                --register add
                pr("executing register add")
                chip.dmp("v" .. x .. " += v" .. y)

                pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                pr("setting v" .. x .. " to " .. (chip.v[x] + chip.v[y]))
                chip.v[x] = (chip.v[x] + chip.v[y])
                if chip.v[x] > 256 then
                    chip.v[x] = chip.v[x] % 256
                    pr("setting vf to 1 for overflow")
                    chip.v[0xf] = 1
                else
                    pr("setting vf to 0")
                    chip.v[0xf] = 0
                end
            elseif n == 5 then
                --register subtract
                pr("executing register subtract")
                chip.dmp("v" .. x .. " -= v" .. y)

                pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                pr("setting v" .. x .. " to " .. (chip.v[x] - chip.v[y]))
                chip.v[x] = (chip.v[x] - chip.v[y])

                if chip.v[x] < 0 then
                    chip.v[x] = chip.v[x] % 256
                    pr("setting vf to 0 for underflow")
                    chip.v[0xf] = 1
                else
                    pr("setting vf to 1")
                    chip.v[0xf] = 0
                end
            elseif n == 6 then
                --register shift right
                pr("executing register shift right")

                local stradd = ""

                if chip.cf.vyshift then
                    pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                    pr("setting v" .. x .. " to " .. chip.v[y])
                    chip.v[x] = chip.v[y]
                    stradd = "v" .. x .. " = v" .. y .. "\n"
                end

                chip.dmp(stradd .. "v" .. x .. " = rshift(v" .. x .. ", 1)")

                local shiftout = nacho.gbit(chip.v[x], 0)
                pr("setting v" .. x .. " from " .. chip.v[x] .. " to " .. (nacho.bit.rshift(chip.v[x], 1)) % 256)
                chip.v[x] = (nacho.bit.rshift(chip.v[x], 1)) % 256
                if shiftout then
                    chip.v[0xf] = 1
                    pr("shifted out 1")
                else
                    chip.v[0xf] = 0
                    pr("shifted out 0")
                end
            elseif n == 7 then
                --register subtract, but like, the other way?
                pr("executing register subtract")
                chip.dmp("v" .. x .. " = v" .. y .. " - v" .. x)

                pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                pr("setting v" .. x .. " to " .. (chip.v[y] - chip.v[x]))
                chip.v[x] = (chip.v[y] - chip.v[x])
                if chip.v[x] < 0 then
                    chip.v[x] = chip.v[x] % 256
                    pr("setting vf to 0 for underflow")
                    chip.v[0xf] = 1
                else
                    pr("setting vf to 1")
                    chip.v[0xf] = 0
                end
            elseif n == 0xe then
                --register left shift
                pr("executing register shift left")

                local stradd = ""

                if chip.cf.vyshift then
                    pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
                    pr("setting v" .. x .. " to " .. chip.v[y])
                    chip.v[x] = chip.v[y]
                    stradd = "v" .. x .. " = v" .. y .. "\n"
                end

                chip.dmp(stradd .. "v" .. x .. " = lshift(v" .. x .. ", 1")

                local shiftout = nacho.gbit(chip.v[x], 7)
                pr("setting v" .. x .. " from " .. chip.v[x] .. " to " .. (nacho.bit.lshift(chip.v[x], 1)) % 256)
                chip.v[x] = (nacho.bit.lshift(chip.v[x], 1)) % 256
                if shiftout then
                    chip.v[0xf] = 1
                    pr("shifted out 1")
                else
                    chip.v[0xf] = 0
                    pr("shifted out 0")
                end
            end
        elseif c == 9 then
            -- register skip if not equal
            pr("executing register skip if not equal")
            chip.dmp("skipif(v" .. x .. " != v" .. y .. ")")
            chip.nop(chip.pc)
            chip.nop(chip.pc + 2)
            chip.ms(73, 9, chip.v[x] ~= chip.v[y])

            pr("v" .. x .. " is " .. chip.v[x] .. ", v" .. y .. " is " .. chip.v[y])
            if chip.v[x] ~= chip.v[y] then
                pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                chip.pc = chip.pc + 2
            else
                pr("pc remains at " .. chip.pc)
            end
        elseif c == 0xa then
            -- set index
            pr("executing set index")
            chip.dmp("index = " .. nnn)
            chip.nop()
            chip.ms(55)

            pr("index has gone from " .. chip.index .. " to " .. nnn)
            chip.index = nnn
        elseif c == 0xb then
            -- offset jump
            pr("executing jump with offset")
            if not vxoffsetjump then
                chip.dmp("jump(" .. nnn .. " + v0) -- DECOMPILER WARNING: THIS MIGHT BE MISSING POSSIBILITIES")
                chip.nop(nnn + chip.v[0])
                chip.ms(73, 9, chip.pc, nnn + chip.v[0])

                pr(
                    "pc has gone from " ..
                        chip.pc ..
                            " to " .. nnn .. " + v0, (" .. nnn .. "+" .. chip.v[0] .. "=" .. nnn + chip.v[0] .. ")"
                )
                chip.pc = nnn + chip.v[0]
            else
                chip.dmp(
                    "jump({" ..
                        x ..
                            "}" ..
                                y ..
                                    n ..
                                        " + v{" ..
                                            x ..
                                                "} --DECOMPILER WARNING: THIS MIGHT BE MISSING POSSIBILITIES! also, {" ..
                                                    x .. "} must be the same number"
                )
                chip.nop(nnn + chip.v[x])
                chip.ms(73, 9, chip.pc, nnn + chip.v[x])

                pr(
                    "pc has gone from " ..
                        chip.pc ..
                            " to " ..
                                nnn .. " + v" .. x .. ", (" .. nnn .. "+" .. chip.v[x] .. "=" .. nnn + chip.v[x] .. ")"
                )
                chip.pc = nnn + chip.v[x]
            end
        elseif c == 0xc then
            -- random number
            pr("executing random number")
            chip.dmp("v" .. x .. " = band(random(0,255), " .. nn .. ")")
            chip.nop()
            chip.ms(164)

            local rn = nacho.bit.band(math.random(0, 255), nn)
            pr("setting v" .. x .. " from " .. chip.v[x] .. " to " .. rn)
            chip.v[x] = rn
        elseif c == 0xd then
            -- display to screen (oh god)
            pr("executing draw at " .. chip.v[x] .. "," .. chip.v[y])
            chip.dmpj("draw(v" .. x .. ", v" .. y .. ", " .. n .. ")", "spr", chip.index)
            chip.nop()
            chip.spr(chip.index, n)
            chip.ms(22734, (n - 8) * 662) --this is my best guess, probably not be accurate

            local dx = chip.v[x] % chip.cf.sw
            local dy = chip.v[y] % chip.cf.sh
            chip.v[0xf] = 0 -- set vf to 0
            for dyi = 0, n - 1 do -- iterate n times
                local sprbyte = chip.mem[chip.index + dyi] -- get byte from memory
                pr("drawing " .. nacho.binarystring(sprbyte, true))
                for dxi = 0, 7 do -- iterate through the byte
                    local val = nacho.gbit(sprbyte, 7 - dxi) -- get value of bit
                    if dx + dxi < chip.cf.sw and dy + dyi < chip.cf.sh then --make sure we are in bounds
                        if val then
                            if chip.display[dx + dxi][dy + dyi + 1] then
                                chip.v[0xf] = 1
                                chip.display[dx + dxi][dy + dyi + 1] = false -- turn off pixel
                            else
                                chip.display[dx + dxi][dy + dyi + 1] = true -- turn on pixel
                            end
                        end
                    end
                end
            end
            chip.screenupdated = true
        elseif c == 0xe then
            if nn == 0x9e then
                --skip if key down
                pr("executing skip if key down")
                chip.dmp("if keydown(v" .. x .. ") then jump(" .. chip.pc + 2 .. ") --skip next")
                chip.nop(chip.pc)
                chip.nop(chip.pc + 2)

                pr("v" .. x .. " is" .. nacho.bit.tohex(chip.v[x], 1))
                if chip.keys then
                    if chip.keys[chip.v[x]].down then
                        pr("key " .. nacho.bit.tohex(chip.v[x], 1) .. " is down")
                        pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                        chip.pc = chip.pc + 2

                        chip.ms(73, -9)
                    else
                        pr("key " .. nacho.bit.tohex(chip.v[x], 1) .. " is not down")
                        pr("pc remains at " .. chip.pc)

                        chip.ms(73, 9)
                    end
                else
                    print("no key setup found! assuming that no keys are pressed.")
                    pr("key " .. nacho.bit.tohex(chip.v[x], 1) .. " is not down")
                    pr("pc remains at " .. chip.pc)

                    chip.ms(73, 9)
                end
            elseif nn == 0xa1 then
                --skip if key not down
                pr("executing skip if key not down")
                chip.dmp("if not keydown(v" .. x .. ") then jump(" .. chip.pc + 2 .. ") --skip next")
                chip.nop(chip.pc)
                chip.nop(chip.pc + 2)

                pr("v" .. x .. " is" .. nacho.bit.tohex(chip.v[x], 1))
                if chip.keys then
                    if chip.keys[chip.v[x]].down then
                        pr("key " .. nacho.bit.tohex(chip.v[x], 1) .. " is down")
                        pr("pc remains at " .. chip.pc)

                        chip.ms(73, -9)
                    else
                        pr("key " .. nacho.bit.tohex(chip.v[x], 1) .. " is not down")
                        pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                        chip.pc = chip.pc + 2

                        chip.ms(73, 9)
                    end
                else
                    print("no key setup found! assuming that no keys are pressed.")
                    pr("key " .. nacho.bit.tohex(chip.v[x], 1) .. " is not down")
                    pr("pc has gone from " .. chip.pc .. " to " .. chip.pc + 2)
                    chip.pc = chip.pc + 2

                    chip.ms(73, 9)
                end
            end
        elseif c == 0xf then
            if nn == 0x07 then
                -- set register to delay
                pr("executing set register to delay")
                chip.dmp("v" .. x .. " = delay")
                chip.nop()
                chip.ms(45)

                pr("setting v" .. x .. " from " .. chip.v[x] .. " to " .. chip.delay)
                chip.v[x] = chip.delay
            elseif nn == 0x0a then
                --wait for key
                pr("executing wait for key")
                chip.dmp("waitforkey(v" .. x .. ")")
                chip.nop()

                if chip.keys then
                    local key = nil
                    for k, v in pairs(chip.keys) do
                        if chip.cf.waitforrelease then
                            if v.released then
                                key = k
                            end
                        else
                            if v.pressed then
                                key = k
                            end
                        end
                    end
                    if key then
                        pr("key " .. key .. " pressed, setting v" .. x .. " from " .. chip.v[x] .. " to " .. key)
                        chip.v[x] = key
                    else
                        chip.pc = chip.pc - 2
                        pr("key not pressed, pc remains at " .. chip.pc)
                    end
                else
                    print("no key setup found! assuming that no keys are pressed.")
                    chip.pc = chip.pc - 2
                    pr("key not pressed, pc remains at " .. chip.pc)
                end

                if chip.cf.dotimedupdate then
                    chip.microseconds = -1
                end
            elseif nn == 0x15 then
                -- set delay to register
                pr("executing set delay to resgister")
                chip.dmp("delay = v" .. x)
                chip.nop()
                chip.ms(45)

                pr("setting delay from " .. chip.delay .. " to v" .. x .. ", which is " .. chip.v[x])
                chip.delay = chip.v[x]
            elseif nn == 0x18 then
                -- set sound timer to register
                pr("executing set sound timer to resgister")
                chip.dmp("sound = v" .. x)
                chip.nop()
                chip.ms(45)

                pr("setting sound from " .. chip.sound .. " to v" .. x .. ", which is " .. chip.v[x])
                chip.sound = chip.v[x]
            elseif nn == 0x1e then
                -- index add
                pr("executing index add")
                chip.nop()
                chip.dmp("index += v" .. x .. " -- DECOMPILER WARNING: THIS MIGHT BE MISSING POSSIBILITIES")

                pr(
                    "adding v" ..
                        x ..
                            "(" ..
                                chip.v[x] ..
                                    ") to index (" ..
                                        chip.index ..
                                            ") (" ..
                                                chip.index ..
                                                    "+" .. chip.v[x] .. "=" .. (chip.index + chip.v[x]) % 4096 .. ")"
                )
                local newindex = chip.index + chip.v[x]
                if chip.cf.indexoverflow then
                    if newindex >= 4096 then
                        newindex = newindex % 4096
                        pr("setting vf to 1 for overflow")
                        chip.v[0xf] = 1
                    end
                end
                chip.ms(86, 14, chip.index, newindex)

                chip.index = newindex
            elseif nn == 0x29 then
                --get font character
                pr("executing get font character")
                chip.dmp("font(v" .. x .. ")")
                chip.nop()
                chip.ms(91)

                pr("v" .. x .. " is " .. nacho.bit.tohex(chip.v[x]))
                local newindex = 0x050 + nacho.bit.band(chip.v[x], 0x0f) * 5 --get character last nybble of vx
                pr(
                    "changing index from " ..
                        chip.index ..
                            " to " ..
                                nacho.bit.tohex(newindex) ..
                                    "(should be character " .. nacho.bit.tohex(chip.v[x]) .. ")"
                )
                chip.index = newindex ---AAAAAAAAAAAA WHY DID THIS HAPPEN TWICE I SWEAR TO
            elseif nn == 0x33 then
                --decimal split
                pr("executing decimal split")
                chip.dmp("decimalsplit(v" .. x .. ")")
                chip.nop()
				local num = chip.v[x]
				
                chip.ms(
                    364 +
                        (math.floor(num / (10 ^ 2)) % 10 + math.floor(num / (10 ^ 1)) % 10 + math.floor(num) % 10) * 73
                )
                -- the math doesn't check out *exactly*, but its whats on the page.

                
                pr("v" .. x .. " is " .. num)
                pr("index is " .. chip.index)

                pr(
                    "changing mem address " ..
                        chip.index + 0 ..
                            " from " .. chip.mem[chip.index + 0] .. " to " .. math.floor(num / (10 ^ 2)) % 10
                )
                pr(
                    "changing mem address " ..
                        chip.index + 1 ..
                            " from " .. chip.mem[chip.index + 1] .. " to " .. math.floor(num / (10 ^ 1)) % 10
                )
                pr(
                    "changing mem address " ..
                        chip.index + 2 ..
                            " from " .. chip.mem[chip.index + 2] .. " to " .. math.floor(num / (10 ^ 0)) % 10
                )
                chip.mem[chip.index + 0] = math.floor(num / (10 ^ 2)) % 10
                chip.mem[chip.index + 1] = math.floor(num / (10 ^ 1)) % 10
                chip.mem[chip.index + 2] = math.floor(num / (10 ^ 0)) % 10
            elseif nn == 0x55 then
                --store memory
                pr("executing store to memory")
                chip.dmp("for i=0," .. x .. " do mem[index + i] = vi")
                chip.nop()
                chip.ms(64 * (x + 1))

                pr("storing from v0 to v" .. x .. ", starting at mem address " .. chip.index)
                for i = 0, x do
                    pr(
                        "changing memory " ..
                            chip.index + i ..
                                " from " .. chip.mem[chip.index + i] .. " to v" .. i .. ", which is " .. chip.v[i]
                    )
                    chip.mem[chip.index + i] = chip.v[i]
                end

                if not chip.cf.tempstoreload then
                    pr("changing index from " .. chip.index .. " to " .. chip.index + x + 1)
                    chip.index = chip.index + x + 1
                end
            elseif nn == 0x65 then
                --read memory
                pr("executing read from memory")
                chip.dmp("for i=0," .. x .. " do vi = mem[index + i]")
                chip.nop()
                chip.ms(64 * (x + 1))

                pr(
                    "reading from mem address " ..
                        chip.index .. " to " .. chip.index + x .. " and storing in v0 to v" .. x
                )
                for i = 0, x do
                    pr(
                        "changing v" ..
                            i ..
                                " from " ..
                                    chip.v[i] ..
                                        " to mem " .. chip.index + i .. ", which is " .. chip.mem[chip.index + i]
                    )
                    chip.v[i] = chip.mem[chip.index + i]
                end

                if not chip.cf.tempstoreload then
                    pr("changing index from " .. chip.index .. " to " .. chip.index + x + 1)
                    chip.index = chip.index + x + 1
                end
            end
        else
            print("!!!!!!!!!!!!!!!!!unknown instruction!!!!!!!!!!!!!!!!!!!!")
        end

        if chip.dumper then
            return chip.chipout
        end
    end

    function chip.timerdec()
        pr("updating timers")
        if chip.delay > 0 then
            chip.delay = chip.delay - 1
        end
        if chip.sound > 0 then
            chip.sound = chip.sound - 1
            if chip.beep then
                chip.beep()
            else
                print("BEEEEP!")
            end
        end
    end

    function chip.dumpupdate(pc, memstate)
        chip.pc = pc
        chip.mem = nacho.copy(memstate)

        local b1, b2 = chip.mem[chip.pc], chip.mem[chip.pc + 1]
        print(b1, b2)
        chip.pc = chip.pc + 2 -- increment pc
        local c, x, y, n, nn, nnn = chip.decode(b1, b2) -- decode the two bytes
        local chipout = chip.execute(c, x, y, n, nn, nnn) -- interpret the decoded bytes

        local output = {foundops = chip.chipout.foundops, nops = chip.chipout.nops, memstate = nacho.copy(chip.mem)}

        return output
    end

    function chip.update()
        --fetch
        local b1, b2 = chip.mem[chip.pc], chip.mem[chip.pc + 1]
        chip.pc = chip.pc + 2 -- increment pc
        local c, x, y, n, nn, nnn = chip.decode(b1, b2) -- decode the two bytes
        chip.execute(c, x, y, n, nn, nnn) -- interpret the decoded bytes
    end

    function chip.timedupdate()
        -- microsecond timing values from
        chip.microseconds = 0
        local opsrun = 0
        while (chip.microseconds < chip.maxms) and (chip.microseconds >= 0) do
            chip.update()
            opsrun = opsrun + 1
        end
        return opsrun
    end

    function chip.savedump()
        if chip.dumper then
            local dstring = ""
            local lines = {}
            for k, v in pairs(chip.dump) do
                table.insert(lines, k)
            end
            table.sort(lines)
            local sorted = {}

            for i, line in ipairs(lines) do
                local op = chip.dump[line]

                local lblname = nil

                for _, lb in pairs(chip.labels) do
                    for k, v in pairs(lb) do
                        if v.pos == op.pos then
                            lblname = k
                        end
                    end
                end

                if lblname then
                    dstring = dstring .. "@" .. lblname .. ":\n"
                end
                --dstring = dstring .. nacho.addleadings(op.pos) .. '-' .. nacho.addleadings(op.pos+op.length) .. ': ' .. op.og .. '\n'
                dstring = dstring .. op.val .. "\n"
            end
            return dstring
        end
    end

    return chip
end

function nacho.decompile(mem)
    print("!!!!!!!!!!!!!!!!!!!!DECOMPILE START!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")

    local chip = nacho.init("common", nil, {dumper = true})

    chip = nacho.loadtabletochip(mem, chip)

    local queuedstates = {
        {
            pc = 512,
            memstate = nacho.copy(chip.mem),
            cycles = 0
        }
    } -- start searching at 512

    local decomp = {}

    for i, v in ipairs(mem) do
        decomp[i - 1] = {val = "#DECOMP_UNKNOWN", cycle = -1}
    end

    local curcycle = 0

    local maxcycles = 1000

    while #queuedstates ~= 0 and curcycle < maxcycles do
        local newstate = table.remove(queuedstates)
        print("pc:" .. newstate.pc)
        -- output = {foundops = chipout.foundops,nops = chipout.nops, memstate = nacho.copy(chip.mem)}
        local output = chip.dumpupdate(newstate.pc, newstate.memstate)

        curcycle = newstate.cycles + 1

        for i, v in ipairs(output.foundops) do -- pos = pos + (i-1), val = outval .. nacho.bit.tohex(chip.mem[pos + (i-1)],2)
            if decomp[v.pos - 512].cycle > curcycle or decomp[v.pos - 512].cycle == -1 then
                decomp[v.pos - 512] = {val = v.val, cycle = curcycle}
            end
        end

        for i, v in ipairs(output.nops) do
            if decomp[v - 512].val == "#DECOMP_UNKNOWN" then
                table.insert(
                    queuedstates,
                    {
                        pc = v,
                        memstate = output.memstate,
                        cycles = curcycle
                    }
                )
            end
        end

        local queuestr = ""
        for i, v in ipairs(queuedstates) do
            queuestr = v.pc .. "@" .. v.cycles .. ", " .. queuestr
        end
        print("done, queue contains " .. queuestr)
    end

    local dstring = "--NCH decomp\n\n"

    for i, v in ipairs(mem) do
        local lblname = nil
        local lbltext = ""

        for _, lb in pairs(chip.labels) do
            for k, vv in pairs(lb) do
                if vv.pos == i - 1 + 512 then
                    lblname = k
                end
            end
        end
        if lblname then
            lbltext = "@" .. lblname .. ":\n"
        end

        dstring = dstring .. lbltext .. decomp[i - 1].val .. "\n"
    end
    return (dstring)
end

return nacho
