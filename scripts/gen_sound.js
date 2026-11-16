const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'android', 'app', 'src', 'main', 'res', 'raw');
if (!fs.existsSync(dir)) {
  fs.mkdirSync(dir, { recursive: true });
}

const sampleRate = 44100;
const duration = 2; // seconds
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
buffer.writeUInt16LE(2, 32); // block align
buffer.writeUInt16LE(16, 34); // bits per sample
buffer.write('data', 36);
buffer.writeUInt32LE(numSamples * 2, 40);

for (let i = 0; i < numSamples; i++) {
  const t = i / sampleRate;
  const beep = (t % 0.4) < 0.2; // pulse
  const val = beep ? Math.sin(2 * Math.PI * 900 * t) * 28000 : 0;
  buffer.writeInt16LE(Math.floor(val), 44 + i * 2);
}

const soundPath = path.join(dir, 'alarm_alert.wav');
fs.writeFileSync(soundPath, buffer);
console.log('alarm_alert.wav created at:', soundPath);

