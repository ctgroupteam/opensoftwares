const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', 'raw');

// 1. Remove alarm_alert.wav
const alarmPath = path.join(dir, 'alarm_alert.wav');
if (fs.existsSync(alarmPath)) {
  fs.unlinkSync(alarmPath);
  console.log('Deleted alarm_alert.wav');
}

// 2. Generate sound_pulse.wav (Gentle high-tech executive pulse chime at 880Hz & 1320Hz with soft exponential decay)
const sampleRate = 44100;
const duration = 1.0;
const numSamples = sampleRate * duration;
const buffer = Buffer.alloc(44 + numSamples * 2);

buffer.write('RIFF', 0);
buffer.writeUInt32LE(36 + numSamples * 2, 4);
buffer.write('WAVE', 8);
buffer.write('fmt ', 12);
buffer.writeUInt32LE(16, 16);
buffer.writeUInt16LE(1, 20); // PCM
buffer.writeUInt16LE(1, 22); // mono
buffer.writeUInt32LE(sampleRate, 24);
buffer.writeUInt32LE(sampleRate * 2, 28);
buffer.writeUInt16LE(2, 32);
buffer.writeUInt16LE(16, 34);
buffer.write('data', 36);
buffer.writeUInt32LE(numSamples * 2, 40);

for (let i = 0; i < numSamples; i++) {
  const t = i / sampleRate;
  const env = Math.exp(-4.5 * t);
  const wave = 0.6 * Math.sin(2 * Math.PI * 880 * t) + 0.4 * Math.sin(2 * Math.PI * 1320 * t);
  const val = wave * env * 24000;
  buffer.writeInt16LE(Math.max(-32767, Math.min(32767, Math.floor(val))), 44 + i * 2);
}

const pulsePath = path.join(dir, 'sound_pulse.wav');
fs.writeFileSync(pulsePath, buffer);
console.log('Created sound_pulse.wav at:', pulsePath);

