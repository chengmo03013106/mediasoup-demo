/**
 * Generates a self-signed TLS certificate for localhost development.
 * Usage: node generate-cert.mjs
 */
import * as fs from 'node:fs';
import * as path from 'node:path';
import selfsigned from 'selfsigned';

const certPath = path.join(import.meta.dirname, 'cert.pem');
const keyPath = path.join(import.meta.dirname, 'key.pem');

const attrs = [{ name: 'commonName', value: 'localhost' }];
const extensions = [
	{
		name: 'subjectAltName',
		altNames: [
			{ type: 2, value: 'localhost' },
			{ type: 7, ip: '127.0.0.1' },
		],
	},
];

const pems = await selfsigned.generate(attrs, {
	algorithm: 'sha256',
	keySize: 2048,
	days: 365,
	extensions,
});

fs.writeFileSync(keyPath, pems.private);
fs.writeFileSync(certPath, pems.cert);

console.log('Generated:');
console.log('  ' + keyPath);
console.log('  ' + certPath);
