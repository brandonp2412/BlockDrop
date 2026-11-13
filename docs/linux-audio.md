# Linux audio

Block Drop uses GStreamer for Linux playback. MP3 imports need the ID3 demuxer
and MP3 decoder from the Good plug-ins collection, in addition to the base
plug-ins used for bundled Ogg audio.

On Arch Linux, install `gst-plugins-good`. On Debian or Ubuntu, install
`gstreamer1.0-plugins-good`. Restart Block Drop after installing plug-ins.

Check that both elements are available:

```sh
gst-inspect-1.0 id3demux
gst-inspect-1.0 mpg123audiodec
```

Run the native playback regression with an absolute path to an MP3 file:

```sh
flutter test integration_test/audio_playback_test.dart -d linux \
  --dart-define=AUDIO_TEST_FILE=/absolute/path/to/music.mp3
```

This uses the real AudioPlayers backend and audio output. It checks that playback
position advances, an invalid file does not escape as an uncaught exception, and
a valid track plays after that failure. Without `AUDIO_TEST_FILE`, the test skips.

Add `--dart-define=AUDIO_TEST_PULSE=true` on a Linux desktop with `pactl` to
also start the game screen and verify that its process has an active, unmuted
output stream in PulseAudio or PipeWire. This test restores the previous music
settings afterward.
