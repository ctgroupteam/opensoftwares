const fs = require('fs');
const https = require('https');
const path = require('path');

const token = process.env.GH_TOKEN;
const repo = 'mdyahhya/opensoftwares_crm';
const tag = process.argv[2] || 'v1.0.1';
const apkPath = path.join(__dirname, '..', 'output_apk', 'opensoftwares-crm-' + tag + '.apk');

if (!token) {
  console.error('Please set GH_TOKEN environment variable.');
  process.exit(1);
}

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(body) });
        } catch (_) {
          resolve({ status: res.statusCode, headers: res.headers, body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function main() {
  console.log('Publishing release on GitHub:', tag);
  const releasePayload = JSON.stringify({
    tag_name: tag,
    target_commitish: 'main',
    name: 'OpenSoftwares CRM ' + tag,
    body: 'Production Release ' + tag,
    draft: false,
    prerelease: false
  });

  const createRes = await request({
    hostname: 'api.github.com',
    path: `/repos/${repo}/releases`,
    method: 'POST',
    headers: {
      'User-Agent': 'OpenSoftwares-Release-Script',
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(releasePayload)
    }
  }, releasePayload);

  let uploadUrl = createRes.body?.upload_url;
  if (!uploadUrl) {
    const getRes = await request({
      hostname: 'api.github.com',
      path: `/repos/${repo}/releases/tags/${tag}`,
      method: 'GET',
      headers: {
        'User-Agent': 'OpenSoftwares-Release-Script',
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/vnd.github.v3+json'
      }
    });
    uploadUrl = getRes.body?.upload_url;
  }

  const cleanUploadUrl = uploadUrl.split('{')[0] + '?name=opensoftwares-crm-' + tag + '.apk';
  const urlObj = new URL(cleanUploadUrl);
  const fileStats = fs.statSync(apkPath);
  const fileStream = fs.createReadStream(apkPath);

  const uploadReq = https.request({
    hostname: urlObj.hostname,
    path: urlObj.pathname + urlObj.search,
    method: 'POST',
    headers: {
      'User-Agent': 'OpenSoftwares-Release-Script',
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': fileStats.size
    }
  }, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      console.log('Upload asset response:', res.statusCode);
    });
  });

  fileStream.pipe(uploadReq);
}

main().catch(console.error);
