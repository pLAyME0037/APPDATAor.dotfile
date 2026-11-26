import json
import os
import re
import struct
import tempfile
import gdb


def _auto_load_program():
    prog = os.environ.get("NVIM_GDB_PROGRAM", "").strip()
    if not prog:
        return
    if not os.path.isfile(prog):
        return
    try:
        if len(gdb.objfiles()) == 0:
            escaped = prog.replace("\\", "\\\\").replace('"', '\\"')
            gdb.execute('file "{}"'.format(escaped), to_string=True)
    except gdb.error:
        pass


def _parse_int(token):
    if token is None:
        return None
    s = str(token).strip()
    if not s:
        return None
    try:
        if s.lower().startswith("0x"):
            return int(s, 16)
        if re.fullmatch(r"[0-9a-fA-F]+", s):
            if re.search(r"[a-fA-F]", s) or len(s) >= 8:
                return int(s, 16)
        return int(s, 0)
    except ValueError:
        return None


def _eval_expr_value(expr):
    expr_s = expr.strip()
    if not expr_s:
        raise gdb.error("Empty expression")
    return gdb.parse_and_eval(expr_s)


def _eval_int_or_expr(expr):
    s = expr.strip()
    if s.lower().startswith("0x"):
        try:
            return int(s, 16)
        except ValueError:
            pass
    if re.fullmatch(r"-?\d+", s):
        return int(s, 10)
    val = _eval_expr_value(s)
    if val.type.strip_typedefs().code == gdb.TYPE_CODE_ARRAY:
        if val.address is not None:
            return int(val.address)
    return int(val)


def _merge_regions(regions):
    if not regions:
        return []
    ordered = sorted(regions, key=lambda r: (r["start"], r["end"]))
    merged = []
    for item in ordered:
        if not merged:
            merged.append(dict(item))
            continue
        prev = merged[-1]
        same_kind = (item["kind"] == prev["kind"])
        same_perms = (item["perms"] == prev["perms"])
        if item["start"] <= prev["end"] and same_kind and same_perms:
            if item["end"] > prev["end"]:
                prev["end"] = item["end"]
            if item["label"] and item["label"] not in prev["label"]:
                if prev["label"]:
                    prev["label"] = prev["label"] + " | " + item["label"]
                else:
                    prev["label"] = item["label"]
        else:
            merged.append(dict(item))
    return merged


def _classify_section_kind(sec_name):
    lower = sec_name.lower()
    if "/usr/lib/wine/" in lower or "/lib/wine/" in lower or ".so" in lower:
        return "unix-so"
    if "/windows/system32/" in lower or "/windows/syswow64/" in lower or ".dll" in lower or ".drv" in lower:
        return "sys-dll"
    return "exe"


def _collect_info_files_regions():
    regions = []
    try:
        out = gdb.execute("info files", to_string=True)
    except gdb.error:
        return regions

    pat = re.compile(r"^\s*(0x[0-9a-fA-F]+)\s*-\s*(0x[0-9a-fA-F]+)\s+is\s+(.+)$")
    for line in out.splitlines():
        m = pat.match(line)
        if m is None:
            continue
        start = int(m.group(1), 16)
        end = int(m.group(2), 16)
        sec_name = m.group(3).strip()
        if end > start:
            regions.append({
                "start": start,
                "end": end,
                "perms": "section",
                "kind": _classify_section_kind(sec_name),
                "label": sec_name,
            })
    return regions


def _collect_proc_mappings():
    regions = []
    try:
        out = gdb.execute("info proc mappings", to_string=True)
    except gdb.error:
        return regions, ""

    for line in out.splitlines():
        s = line.strip()
        if not s:
            continue
        parts = s.split()
        if len(parts) < 3:
            continue
        if not parts[0].lower().startswith("0x"):
            continue
        if not parts[1].lower().startswith("0x"):
            continue
        start = _parse_int(parts[0])
        end = _parse_int(parts[1])
        if start is None or end is None or end <= start:
            continue
        perms = "---"
        label = ""
        has_perms_col = len(parts) >= 5 and re.fullmatch(r"[r-][w-][x-][ps-]?", parts[4]) is not None
        if has_perms_col:
            perms = parts[4]
            if len(parts) >= 6:
                label = " ".join(parts[5:])
            if "r" not in perms.lower():
                continue
        else:
            perms = "r??"
            if len(parts) >= 5:
                label = " ".join(parts[4:])
        kind = "app"
        lower_lbl = label.lower()
        if "/usr/lib/" in lower_lbl or "/lib/" in lower_lbl:
            kind = "sys-dll"
        regions.append({
            "start": start,
            "end": end,
            "perms": perms,
            "kind": kind,
            "label": label,
        })
    return regions, out


def _classify_winedbg_mem(tail):
    upper = tail.upper()
    lower = tail.lower()
    if "IMAGE" in upper:
        if ".dll" in lower or ".drv" in lower or "system32" in lower or "syswow64" in lower:
            return "r-ximg", "sys-dll"
        if ".exe" in lower:
            return "r-ximg", "app"
        return "r-ximg", "wine-mem"
    if "PRIVATE" in upper and "W" in upper:
        return "rw-priv", "wine-mem"
    if "MAPPED" in upper and "W" in upper:
        return "rw-map", "wine-mem"
    return "ro-mem", "wine-mem"


def _parse_winedbg_mem_line(line):
    upper = line.upper()
    upper_tokens = set(upper.split())
    if upper_tokens & {"FREE", "RESERVE", "NOACCESS", "GUARD", "PAGE_NOACCESS", "PAGE_GUARD"}:
        return None
    if re.search(r"(?:^|\s)---(?:\s|$)", line):
        return None

    dash_match = re.search(
        r"(?:0x)?([0-9a-fA-F]{6,16})\s*-\s*(?:0x)?([0-9a-fA-F]{6,16})(.*)$",
        line,
    )
    if dash_match is not None:
        start = int(dash_match.group(1), 16)
        end = int(dash_match.group(2), 16)
        rest = dash_match.group(3).strip()
        if end > start:
            if (end & 0xFFF) == 0xFFF:
                end = end + 1
            perms, kind = _classify_winedbg_mem(rest)
            return {
                "start": start,
                "end": end,
                "perms": perms,
                "kind": kind,
                "label": rest,
            }

    hex_tokens = list(re.finditer(r"\b(?:0x)?([0-9a-fA-F]{4,16})\b", line))
    if len(hex_tokens) >= 2:
        first = int(hex_tokens[0].group(1), 16)
        second = int(hex_tokens[1].group(1), 16)
        tail = line[hex_tokens[1].end():].strip()

        if len(hex_tokens) >= 3:
            third = int(hex_tokens[2].group(1), 16)
            if first + third == second and second > first:
                perms, kind = _classify_winedbg_mem(tail)
                return {
                    "start": first,
                    "end": second,
                    "perms": perms,
                    "kind": kind,
                    "label": tail,
                }

        if second > first and (second - first) <= 0x20000000:
            if second >= 0x10000 and (first & 0xFFF) == 0:
                end_addr = None
                if (second & 0xFFF) == 0xFFF:
                    end_addr = second + 1
                elif (second & 0xFFF) == 0:
                    end_addr = second
                if end_addr is not None and (upper_tokens & {"COMMIT", "RW", "RX", "RO", "IMAGE", "MAPPED", "PRIVATE"}):
                    perms, kind = _classify_winedbg_mem(tail)
                    return {
                        "start": first,
                        "end": end_addr,
                        "perms": perms,
                        "kind": kind,
                        "label": tail,
                    }
        if 0 < second < first:
            perms, kind = _classify_winedbg_mem(tail)
            return {
                "start": first,
                "end": first + second,
                "perms": perms,
                "kind": kind,
                "label": tail,
            }
    return None


def _collect_winedbg_mem():
    regions = []
    try:
        out = gdb.execute("monitor mem", to_string=True)
    except gdb.error:
        return regions, ""

    for line in out.splitlines():
        parsed = _parse_winedbg_mem_line(line)
        if parsed is not None:
            regions.append(parsed)
    return regions, out


def _collect_stack_region():
    regions = []
    for reg_name in ("$rsp", "$esp", "$sp"):
        try:
            sp_val = int(gdb.parse_and_eval(reg_name))
            if sp_val > 0x10000:
                start = max(0, (sp_val - 0x10000) & ~0xFFF)
                end = (sp_val + 0x10000) & ~0xFFF
                regions.append({
                    "start": start,
                    "end": end,
                    "perms": "stack",
                    "kind": "stack",
                    "label": "stack around " + reg_name,
                })
                break
        except gdb.error:
            continue
    return regions


def collect_vmmap():
    proc_regs, proc_raw = _collect_proc_mappings()
    if proc_regs:
        return {
            "source": "info proc mappings",
            "raw": proc_raw,
            "regions": _merge_regions(proc_regs),
        }

    wine_regs, wine_raw = _collect_winedbg_mem()
    sec_regs = _collect_info_files_regions()
    stk_regs = _collect_stack_region()
    combined = _merge_regions(stk_regs + sec_regs + wine_regs)
    raw_text = wine_raw
    if not raw_text.strip():
        parts = []
        for r in combined:
            parts.append("0x{:x} - 0x{:x}  {}  {}".format(r["start"], r["end"], r["perms"], r["label"]))
        raw_text = "\n".join(parts)

    return {
        "source": "monitor mem + sections + stack",
        "raw": raw_text,
        "regions": combined,
    }


def resolve_addr_info(expr):
    val = _eval_expr_value(expr)
    vtype = str(val.type)
    vsize = int(val.type.sizeof)

    lvalue_addr = None
    if val.address is not None:
        lvalue_addr = "0x{:x}".format(int(val.address))

    target_addr = None
    code = val.type.strip_typedefs().code
    if code == gdb.TYPE_CODE_PTR or code == gdb.TYPE_CODE_REF:
        try:
            ptr_int = int(val)
            if ptr_int >= 0:
                target_addr = "0x{:x}".format(ptr_int)
        except gdb.error:
            pass
    elif code == gdb.TYPE_CODE_ARRAY:
        target_addr = lvalue_addr

    val_str = str(val)
    inspect_addr = lvalue_addr
    if inspect_addr is None:
        inspect_addr = target_addr

    return {
        "ok": True,
        "expr": expr,
        "type": vtype,
        "size": vsize,
        "lvalue_addr": lvalue_addr,
        "target_addr": target_addr,
        "inspect_addr": inspect_addr,
        "value": val_str,
    }


def _safe_read_chunk(inferior, addr, size):
    try:
        return bytes(inferior.read_memory(addr, size)), True
    except gdb.MemoryError:
        return b"", False


def _format_preview(data):
    hex_part = " ".join("{:02x}".format(b) for b in data)
    ascii_chars = []
    for b in data:
        if 32 <= b <= 126:
            ascii_chars.append(chr(b))
        else:
            ascii_chars.append(".")
    return "{}  |{}|".format(hex_part, "".join(ascii_chars))


def _match_needles_in_buffer(inferior, buf, base_addr, region, needles, max_hits, hits, seen_addrs):
    for needle_item in needles:
        needle = needle_item["bytes"]
        tag = needle_item["tag"]
        pos = 0
        while len(hits) < max_hits:
            idx = buf.find(needle, pos)
            if idx == -1:
                break
            hit_addr = base_addr + idx
            addr_hex = "0x{:x}".format(hit_addr)
            key = (addr_hex, tag)
            if key not in seen_addrs:
                seen_addrs.add(key)
                preview_len = min(16, max(8, len(needle)))
                pv_data, pv_ok = _safe_read_chunk(inferior, hit_addr, preview_len)
                if not pv_ok:
                    pv_data = buf[idx:idx + preview_len]
                hits.append({
                    "addr": addr_hex,
                    "tag": tag,
                    "perms": region["perms"],
                    "label": region["label"],
                    "preview": _format_preview(pv_data),
                })
            pos = idx + 1


def _scan_region(inferior, region, needles, scope, max_hits, hits, seen_addrs):
    start = region["start"]
    end = region["end"]
    if scope in ("fast", "app", "heap"):
        max_region_bytes = 16 * 1024 * 1024
        if (end - start) > max_region_bytes:
            end = start + max_region_bytes

    max_needle_len = 1
    for item in needles:
        if len(item["bytes"]) > max_needle_len:
            max_needle_len = len(item["bytes"])

    overlap = max(0, max_needle_len - 1)
    chunk_size = 65536
    page_size = 4096
    cur = start
    tail = b""

    while cur < end and len(hits) < max_hits:
        req = min(chunk_size, end - cur)
        data, ok = _safe_read_chunk(inferior, cur, req)
        if not ok:
            sub_cur = cur
            sub_end = cur + req
            while sub_cur < sub_end and len(hits) < max_hits:
                sub_req = min(page_size, sub_end - sub_cur)
                page_data, page_ok = _safe_read_chunk(inferior, sub_cur, sub_req)
                if page_ok and page_data:
                    buf = tail + page_data
                    base_addr = sub_cur - len(tail)
                    _match_needles_in_buffer(inferior, buf, base_addr, region, needles, max_hits, hits, seen_addrs)
                    if overlap > 0 and len(buf) >= overlap:
                        tail = buf[-overlap:]
                    else:
                        tail = buf
                else:
                    tail = b""
                sub_cur += sub_req
            cur += req
            continue

        buf = tail + data
        base_addr = cur - len(tail)
        _match_needles_in_buffer(inferior, buf, base_addr, region, needles, max_hits, hits, seen_addrs)

        if overlap > 0 and len(buf) >= overlap:
            tail = buf[-overlap:]
        else:
            tail = buf
        cur += req


def _build_needles(kind, query):
    k = kind.strip().lower()
    q = query.strip()
    needles = []

    if k in ("ptr", "addr", "pointer"):
        val = _eval_int_or_expr(q)
        u64_val = val & 0xFFFFFFFFFFFFFFFF
        needles.append({"tag": "ptr64", "bytes": struct.pack("<Q", u64_val)})
        if 0 <= u64_val <= 0xFFFFFFFF:
            needles.append({"tag": "ptr32", "bytes": struct.pack("<I", u64_val)})
    elif k == "u32":
        val = _eval_int_or_expr(q) & 0xFFFFFFFF
        needles.append({"tag": "u32", "bytes": struct.pack("<I", val)})
    elif k == "i32":
        val = _eval_int_or_expr(q)
        if val < -0x80000000 or val > 0xFFFFFFFF:
            raise gdb.error("i32 query out of 32-bit range")
        needles.append({"tag": "i32", "bytes": struct.pack("<I", val & 0xFFFFFFFF)})
    elif k == "u64":
        val = _eval_int_or_expr(q) & 0xFFFFFFFFFFFFFFFF
        needles.append({"tag": "u64", "bytes": struct.pack("<Q", val)})
    elif k == "i64":
        val = _eval_int_or_expr(q)
        if val < -0x8000000000000000 or val > 0xFFFFFFFFFFFFFFFF:
            raise gdb.error("i64 query out of 64-bit range")
        needles.append({"tag": "i64", "bytes": struct.pack("<Q", val & 0xFFFFFFFFFFFFFFFF)})
    elif k in ("ascii", "utf8", "str"):
        raw = q.encode("utf-8")
        if not raw:
            raise gdb.error("Empty string query")
        needles.append({"tag": "utf8", "bytes": raw})
    elif k in ("utf16", "utf16le", "wide"):
        raw = q.encode("utf-16le")
        if not raw:
            raise gdb.error("Empty UTF-16 query")
        needles.append({"tag": "utf16le", "bytes": raw})
    elif k == "hex":
        cleaned = re.sub(r"[^0-9a-fA-F]", "", q.replace("0x", "").replace("0X", ""))
        if not cleaned or (len(cleaned) % 2) != 0:
            raise gdb.error("Hex pattern must contain an even number of hex digits")
        raw = bytes.fromhex(cleaned)
        needles.append({"tag": "hex", "bytes": raw})
    else:
        raise gdb.error("Unknown search kind: " + kind)

    return needles


def search_virtual_memory(kind, query, scope="fast", start_hex="", end_hex="", max_hits=64):
    inferior = gdb.selected_inferior()
    if inferior is None or not inferior.is_valid():
        raise gdb.error("No active inferior")

    needles = _build_needles(kind, query)
    regions = []
    map_source = "custom-range"
    norm_scope = scope.strip().lower()

    if start_hex and end_hex:
        s_addr = _eval_int_or_expr(start_hex)
        e_addr = _eval_int_or_expr(end_hex)
        if e_addr <= s_addr:
            raise gdb.error("End address must be greater than start address")
        regions = [{
            "start": s_addr,
            "end": e_addr,
            "perms": "range",
            "kind": "custom",
            "label": "custom range",
        }]
    else:
        vm = collect_vmmap()
        map_source = vm["source"]
        if norm_scope == "app":
            for r in vm["regions"]:
                is_wine_img = (r["kind"] == "wine-mem" and r["perms"] == "r-ximg")
                if r["kind"] in ("stack", "exe", "app") or is_wine_img:
                    regions.append(r)
        elif norm_scope in ("fast", "heap"):
            for r in vm["regions"]:
                if r["kind"] in ("stack", "exe", "wine-mem", "app"):
                    regions.append(r)
        else:
            regions = vm["regions"]

    if not regions:
        raise gdb.error("No readable memory regions found")

    hits = []
    seen_addrs = set()
    for region in regions:
        if len(hits) >= max_hits:
            break
        _scan_region(inferior, region, needles, norm_scope, max_hits, hits, seen_addrs)

    return {
        "ok": True,
        "kind": kind,
        "query": query,
        "scope": norm_scope,
        "map_source": map_source,
        "region_count": len(regions),
        "hits": hits,
    }


def region_for_address(addr_expr):
    target = _eval_int_or_expr(addr_expr)
    vm = collect_vmmap()
    matches = []
    for region in vm["regions"]:
        if region["start"] <= target < region["end"]:
            matches.append(
                "0x{:x}-0x{:x} {} {}".format(
                    region["start"], region["end"], region["perms"], region["label"]
                )
            )
    if matches:
        return " | ".join(matches)

    target_hex = "0x{:x}".format(target)
    for line in vm["raw"].splitlines():
        if target_hex.lower() in line.lower():
            return line.strip()
    return ""


def _format_bytes_mode(raw_bytes, mode):
    if mode == "hex":
        return " ".join("{:02x}".format(b) for b in raw_bytes)
    if mode == "bin":
        return " ".join("{:08b}".format(b) for b in raw_bytes)
    return " ".join("{:03d}".format(b) for b in raw_bytes)


def disassemble_around(addr_expr="$pc", before_count=12, after_count=28):
    frame = gdb.selected_frame()
    arch = frame.architecture()
    inferior = gdb.selected_inferior()
    pc_int = int(frame.pc())
    center_int = _eval_int_or_expr(addr_expr)

    forward_insns = []
    for req_count in (after_count + 1, 16, 8, 4, 1):
        try:
            forward_insns = arch.disassemble(center_int, count=req_count)
            break
        except gdb.MemoryError:
            continue

    before_insns = []
    if before_count > 0 and center_int > 0:
        func_start = None
        try:
            blk = gdb.block_for_pc(center_int)
            while blk is not None:
                if blk.function is not None:
                    if blk.start < center_int and (center_int - blk.start) <= 8192:
                        func_start = int(blk.start)
                    break
                blk = blk.superblock
        except RuntimeError:
            pass

        if func_start is not None:
            try:
                raw_prev = arch.disassemble(func_start, center_int - 1)
                filtered = [i for i in raw_prev if i["addr"] < center_int]
                before_insns = filtered[-before_count:]
            except gdb.MemoryError:
                pass

        if not before_insns:
            offsets = [before_count * 16, before_count * 8, 64, 32, 16]
            fallback_prev = []
            for off in offsets:
                cand_start = max(0, center_int - off)
                if cand_start >= center_int:
                    continue
                try:
                    cand = arch.disassemble(cand_start, center_int - 1)
                except gdb.MemoryError:
                    continue
                filtered = [i for i in cand if i["addr"] < center_int]
                if not filtered:
                    continue
                if not fallback_prev:
                    fallback_prev = filtered[-before_count:]
                last_insn = filtered[-1]
                if (last_insn["addr"] + last_insn["length"]) == center_int:
                    before_insns = filtered[-before_count:]
                    break
            if not before_insns and fallback_prev:
                before_insns = fallback_prev

    selected = before_insns + forward_insns

    items = []
    for insn in selected:
        iaddr = insn["addr"]
        ilen = insn["length"]
        raw_b, ok = _safe_read_chunk(inferior, iaddr, ilen)
        hex_bytes = ""
        if ok:
            hex_bytes = " ".join("{:02x}".format(b) for b in raw_b)

        sym_name = ""
        try:
            blk = gdb.block_for_pc(iaddr)
            while blk is not None:
                if blk.function is not None:
                    sym_name = blk.function.print_name
                    break
                blk = blk.superblock
        except RuntimeError:
            pass
        if not sym_name:
            try:
                sym_out = gdb.execute("info symbol 0x{:x}".format(iaddr), to_string=True).strip()
                if " in section " in sym_out and not sym_out.startswith("No symbol"):
                    sym_name = sym_out.split(" in section ")[0].strip()
            except gdb.error:
                pass

        src_path = ""
        src_line = None
        try:
            sal = gdb.find_pc_line(iaddr)
            if sal is not None and sal.symtab is not None and sal.line > 0:
                src_path = sal.symtab.fullname()
                src_line = int(sal.line)
        except gdb.error:
            pass

        items.append({
            "address": "0x{:x}".format(iaddr),
            "instructionBytes": hex_bytes,
            "instruction": insn["asm"],
            "symbol": sym_name,
            "path": src_path,
            "line": src_line,
        })

    return {
        "ok": True,
        "pc": "0x{:x}".format(pc_int),
        "instructions": items,
    }


def _handle_rpc_payload(req):
    action = req.get("action", "")
    if action == "addr":
        return resolve_addr_info(req.get("expr", ""))
    if action == "vmmap":
        vm = collect_vmmap()
        return {
            "ok": True,
            "source": vm["source"],
            "raw": vm["raw"],
            "regions": vm["regions"],
        }
    if action == "region":
        return {
            "ok": True,
            "region": region_for_address(req.get("expr", "$pc")),
        }
    if action == "search":
        return search_virtual_memory(
            kind=req.get("kind", "ptr"),
            query=req.get("query", ""),
            scope=req.get("scope", "fast"),
            start_hex=req.get("start", ""),
            end_hex=req.get("end", ""),
            max_hits=int(req.get("max_hits", 64)),
        )
    if action == "asm":
        return disassemble_around(
            addr_expr=req.get("expr", "$pc"),
            before_count=int(req.get("before", 12)),
            after_count=int(req.get("after", 28)),
        )
    return {"ok": False, "error": "Unknown RPC action: " + str(action)}


class NvimRpcFunction(gdb.Function):
    def __init__(self):
        super().__init__("_nvim_rpc")

    def invoke(self):
        rpc_dir = os.environ.get("NVIM_GDB_RPC_DIR", "").strip()
        if not rpc_dir:
            return 0
        req_path = os.path.join(rpc_dir, "req.json")
        resp_path = os.path.join(rpc_dir, "resp.json")
        try:
            with open(req_path, "r", encoding="utf-8") as fh:
                req = json.load(fh)
            resp = _handle_rpc_payload(req)
        except Exception as exc:
            resp = {"ok": False, "error": str(exc)}

        fd, tmp_path = tempfile.mkstemp(prefix=".resp.", dir=rpc_dir)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump(resp, fh)
            os.replace(tmp_path, resp_path)
        except Exception:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            raise
        return 1


class WineAddrCommand(gdb.Command):
    def __init__(self):
        super().__init__("wine-addr", gdb.COMMAND_DATA, gdb.COMPLETE_EXPRESSION)

    def invoke(self, arg, from_tty):
        res = resolve_addr_info(arg)
        gdb.write("Expr   : {}\n".format(res["expr"]))
        gdb.write("Type   : {} ({} bytes)\n".format(res["type"], res["size"]))
        gdb.write("Address: {}\n".format(res["lvalue_addr"] or "(not addressable / register)"))
        if res["target_addr"] is not None:
            gdb.write("Target : {}\n".format(res["target_addr"]))
        gdb.write("Value  : {}\n".format(res["value"]))


class WineVmmapCommand(gdb.Command):
    def __init__(self):
        super().__init__("wine-vmmap", gdb.COMMAND_STATUS)

    def invoke(self, arg, from_tty):
        vm = collect_vmmap()
        gdb.write("Source: {}\n".format(vm["source"]))
        for r in vm["regions"]:
            gdb.write("0x{:016x} - 0x{:016x}  {:10s}  {}\n".format(
                r["start"], r["end"], r["perms"], r["label"]
            ))


class WineSearchCommand(gdb.Command):
    def __init__(self):
        super().__init__("wine-search", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        argv = gdb.string_to_argv(arg)
        if len(argv) < 2:
            gdb.write("Usage: wine-search <ptr|u32|i32|u64|i64|ascii|utf16|hex> <query> [fast|all]\n", gdb.STDERR)
            return
        kind = argv[0]
        query = argv[1]
        scope = "fast"
        if len(argv) >= 3:
            scope = argv[2]
        res = search_virtual_memory(kind, query, scope=scope)
        gdb.write("Search [{}] {} ({} regions, {} hits):\n".format(
            res["kind"], res["query"], res["region_count"], len(res["hits"])
        ))
        for hit in res["hits"]:
            gdb.write("{}  [{}]  ({})  {}  {}\n".format(
                hit["addr"], hit["tag"], hit["perms"], hit["preview"], hit["label"]
            ))


class WineAsmCommand(gdb.Command):
    def __init__(self):
        super().__init__("wine-asm", gdb.COMMAND_DATA)

    def invoke(self, arg, from_tty):
        argv = gdb.string_to_argv(arg)
        mode = "dec"
        if len(argv) >= 1:
            mode = argv[0].lower()
        res = disassemble_around("$pc", 10, 20)
        gdb.write("PC: {} [mode={}]\n".format(res["pc"], mode))
        last_loc = ""
        for insn in res["instructions"]:
            if insn["path"] and insn["line"] is not None:
                loc = "{}:{}".format(os.path.basename(insn["path"]), insn["line"])
                if loc != last_loc:
                    last_loc = loc
                    gdb.write("  ; [{}]\n".format(loc))
            if insn["instructionBytes"]:
                raw = bytes.fromhex(insn["instructionBytes"])
            else:
                raw = b""
            b_str = _format_bytes_mode(raw, mode)
            if insn["address"] == res["pc"]:
                marker = "->"
            else:
                marker = "  "
            if insn["symbol"]:
                sym = "<{}> ".format(insn["symbol"])
            else:
                sym = ""
            gdb.write("{} {:14s}  {:32s}  {}{}\n".format(
                marker, insn["address"], b_str, sym, insn["instruction"]
            ))


_auto_load_program()
NvimRpcFunction()
WineAddrCommand()
WineVmmapCommand()
WineSearchCommand()
WineAsmCommand()
