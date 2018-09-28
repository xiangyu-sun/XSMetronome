# XSMetronome

[![Build Status](https://travis-ci.org/xiangyu-sun/XSMetronome.svg?branch=master)](https://travis-ci.org/xiangyu-sun/XSMetronome)

Simple demonstration of a metronome using AVAudioEngine and AVAudioPlayerNode to schedule buffers for timing accurate playback using scheduleBuffer:atTime:options:completionHandler:. The implementation also provides for a delegate object to call with the method (metronomeTicking:bar:beat:) which can be used for timing or to provide UI.


## Main Files

Metronome.swift
- Source file for metronome implementation in all the targets.

TWGenerator.swift
- Generic TriangleWaveGenerator swift class used by all targets.

## Version History

1.0 Initial release.

## Requirements

### Build

Xcode 8.2.1 or later, macOS 10.12, iOS 10.2, watchOS 3.1 SDKs

### Runtime

macOS 10.9 or greater
iOS 11.4 or greater
watchOS 4 or greater
