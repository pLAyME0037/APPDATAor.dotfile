import lzma

data = open('GL502VML-AS.306', 'rb').read()
targets = [b'PCIR\xde\x10\x20\x1c', b'GP106', b'NVIDIA']

for target in targets:
    pos = data.find(target)
    if pos != -1:
        print(f'Raw match {target!r} at {hex(pos)}')

offset = 0
while True:
    offset = data.find(b'\x5d\x00\x00', offset)
    if offset == -1:
        break
    try:
        dec = lzma.decompress(data[offset:], format=lzma.FORMAT_ALONE)
        for target in targets:
            if target in dec:
                print(f'LZMA match {target!r} from {hex(offset)} (decompressed {len(dec)} bytes)')
    except Exception:
        pass
    offset += 1
