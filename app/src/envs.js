import * as process from 'node:process';
import * as path from 'node:path';
import { pathToFileURL } from 'node:url';

/**
 * @type string
 */
export function getConfigFile() {
	const configFile =
		process.env['CONFIG_FILE'] ||
		path.join(__dirname, '..', '..', 'server', 'config.mjs');

	// On Windows, dynamic import() requires a file:// URL rather than a plain
	// absolute path such as "e:\foo\bar.mjs".
	return pathToFileURL(configFile).href;
}
