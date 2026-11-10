# GPU benchmark

`run.py` measures what glass costs the GPU on this Mac, without a phone.

```sh
tool/gpu_bench/run.py                  # the working tree
tool/gpu_bench/run.py --compare main   # beside another git ref
```

It builds `example/lib/gpu_bench_main.dart` as a macOS profile app. For each
scenario the app renders the layer tree offscreen in a tight loop and reads
the last frame back, so the clock stops only when the GPU has finished. The
GPU stays saturated (check `ioreg -r -d 1 -c IOAccelerator | grep "Device
Utilization"` during a run), so milliseconds per frame is GPU cost. There is
no vsync, thermal state or battery in the number, and repeat runs agree
within about 2%.

Scenarios: `none` (the backdrop alone; subtract it), `free7` (seven
free-standing surfaces), `chrome` (scaffold, tab bar, toolbar), `buttons8`,
`split8` (the buttons with content painted between them), `cards3`, `bars4`,
and `-light` variants. `GPU_BENCH_SHOTS=1` writes a PNG of
each scenario instead of timing it.

Limits: an Apple-silicon Mac renders at 2x in 8-bit sRGB; an iPhone renders
at 3x in 10-bit wide gamut, so absolute times differ and the phone pays more
per backdrop capture. Use it to compare two versions, then confirm a large
change once on a device with `example/lib/bench_main.dart`
([testing](../../doc/agents/testing.md)). Other apps using the GPU add noise;
close simulators first. The example needs its `macos/` runner.
