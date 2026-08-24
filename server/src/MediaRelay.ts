import type * as mediasoupTypes from 'mediasoup/types';

import { Logger } from './Logger';
import type { ServerConfig } from './types';

/**
 * In-line media processing relay (bypass direction only).
 *
 * When processing is enabled, this module pushes a copy of each audio stream
 * to a self-hosted processing service (audio denoiser):
 *
 *   speaker ──producer──▶ SFU ──bypass consumer──▶ processing service
 *
 * The processed stream is returned by the processing service acting as a
 * BroadcasterPeer (it joins the room and produces its own stream). The echo
 * direction is therefore NOT handled here; it reuses the existing
 * BroadcasterPeer machinery, which naturally gives the echo stream its own
 * peer entry in the frontend (enabling A/B comparison).
 *
 * Loop prevention: the echo stream is produced by a BroadcasterPeer and flows
 * through `broadcasterPeer.on('new-producer')`, never through
 * `peer.on('new-producer')` (the only bypass entry point), so it is never
 * bypassed again.
 *
 * This is a minimal, debug-oriented implementation: no health check, no
 * fallback. The transport is created on the producerRouter so the bypass
 * consumer can directly consume the original producer without pipeToRouter.
 */
export class MediaRelay {
	readonly #logger: Logger;
	readonly #outTransport: mediasoupTypes.PlainTransport;
	readonly #consumers: Map<string, mediasoupTypes.Consumer> = new Map();
	#closed: boolean = false;

	static async create({
		config,
		producerRouter,
	}: {
		config: ServerConfig;
		producerRouter: mediasoupTypes.Router;
	}): Promise<MediaRelay> {
		const processing = config.processing!;
		const logger = new Logger('MediaRelay');

		const { remoteIp, remotePort } = processing;

		if (!remoteIp || !remotePort) {
			throw new Error(
				'processing.remoteIp and processing.remotePort must be set when processing.enabled is true'
			);
		}

		// Out transport: SFU -> processing service (consumer direction).
		const outTransport =
			await producerRouter.createPlainTransport<mediasoupTypes.AppData>({
				...config.mediasoup.plainTransportOptions,
				rtcpMux: true,
				appData: { direction: 'consumer' },
			});

		await outTransport.connect({
			ip: remoteIp,
			port: remotePort,
		});

		const relay = new MediaRelay({
			logger,
			outTransport,
		});

		logger.info(
			'created [outRemote:%o:%o]',
			processing.remoteIp,
			processing.remotePort
		);

		return relay;
	}

	private constructor({
		logger,
		outTransport,
	}: {
		logger: Logger;
		outTransport: mediasoupTypes.PlainTransport;
	}) {
		this.#logger = logger;
		this.#outTransport = outTransport;
	}

	/**
	 * Create a bypass consumer for the given producer, pushing a copy of the
	 * stream to the processing service.
	 */
	async bypass(producer: mediasoupTypes.Producer): Promise<void> {
		if (this.#closed) {
			return;
		}

		try {
			// Build the capabilities from the producer's consumable opus codec.
			// Use `consumableRtpParameters` (not `rtpParameters`) because that is
			// what mediasoup uses to match channels during consume(); this avoids
			// a mono/stereo mismatch that would make the consume fail silently.
			const opusCodec = producer.consumableRtpParameters.codecs.find(
				codec => codec.mimeType.toLowerCase() === 'audio/opus'
			);

			if (!opusCodec) {
				this.#logger.warn(
					'bypass() | producer has no opus codec, skipping [producerId:%o]',
					producer.id
				);

				return;
			}

			const rtpCapabilities: mediasoupTypes.RtpCapabilities = {
				codecs: [
					{
						kind: 'audio',
						mimeType: opusCodec.mimeType,
						clockRate: opusCodec.clockRate,
						channels: opusCodec.channels ?? 2,
						preferredPayloadType: opusCodec.payloadType,
					},
				],
			};

			const consumer =
				await this.#outTransport.consume<mediasoupTypes.AppData>({
					producerId: producer.id,
					rtpCapabilities,
					// Keep DTX packets (continuous stream for the denoiser),
					// disable RTX (the processing service is a plain UDP sink).
					ignoreDtx: false,
					enableRtx: false,
					appData: {
						producerId: producer.id,
						kind: producer.kind,
					},
				});

			this.#consumers.set(producer.id, consumer);

			this.#logger.debug('bypass consumer created [producerId:%o]', producer.id);
		} catch (error) {
			this.#logger.warn(`bypass() | consume failed: ${error}`);
		}
	}

	/**
	 * Remove the bypass consumer associated with a producer (on producer close).
	 */
	stop(producerId: string): void {
		const consumer = this.#consumers.get(producerId);

		if (consumer) {
			consumer.close();
			this.#consumers.delete(producerId);
		}
	}

	close(): void {
		if (this.#closed) {
			return;
		}

		this.#closed = true;

		for (const consumer of this.#consumers.values()) {
			consumer.close();
		}

		this.#consumers.clear();

		this.#outTransport.close();
	}
}
