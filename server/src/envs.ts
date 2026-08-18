import * as process from 'node:process';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

export function getConfigFile(): string {
	const configFile =
		process.env['CONFIG_FILE'] ?? path.join(__dirname, '..', 'config.mjs');

	// On Windows, dynamic import() requires a file:// URL rather than a plain
	// absolute path such as "e:\foo\bar.mjs".
	return pathToFileURL(configFile).href;
}

export function getDebug(): string | undefined {
	return process.env['DEBUG'];
}

export function getTerminal(): boolean {
	return process.env['TERMINAL'] === 'true';
}

export function getNetworkThrottleSecret(): string | undefined {
	return process.env['NETWORK_THROTTLE_SECRET'];
}
