# Sensor helpers and properties for the FP5 sensors, so the soft ISP gets gain
# multipliers instead of raw gain codes. Not used by default, since overriding
# libcamera rebuilds PipeWire and everything else linked against it.
{
  libcamera,
}:
libcamera.overrideAttrs (prevAttrs: {
  patches = (prevAttrs.patches or [ ]) ++ [
    ./0001-add-fp5-sensor-helpers.patch
    ./0002-add-fp5-sensor-properties.patch
  ];
})
