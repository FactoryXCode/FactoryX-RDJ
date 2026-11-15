# RDJ Pro / FxRecord outage recovery design

Decision: rebuild affected hourly recordings to include recovered material. Enable recovery preservation only for an active FxRecord recording subscription. Preserve the normal live stream while archive recovery catches up. This document specifies the change; it does not indicate that recovery-enabled binaries have been implemented or deployed.

## Current behavior that must change

RDJ Pro's dlgMediaServer.pas keeps a bounded live fragment window. CleanupOldBroadcastMseFragments deletes older local patched fragments regardless of whether the server has archived them. TRdjProMseMirrorThread.EnqueueCopy can discard the oldest copy job when its bounded in-memory queue fills; failed jobs are released rather than durably retried. Those limits are appropriate for a live-view window but cannot provide a durable archive guarantee.

FxRecord.ProcessManifest reads the live first/last range, advances past missing sequence numbers, and rotates by the current server time. The converter deletes its input source MP4 after successful conversion. Thus retention alone cannot rebuild an already-converted incomplete hour: the original media and original capture times must also be available.

## FxRecord participation: recovery is conditional

RDJ Pro must not create a recovery journal or retain extra archive media merely because broadcasting is active. FxRecord may be absent, intentionally stopped or configured not to record this publisher. With no confirmed active recording subscription, RDJ Pro uses its normal live retention and mirror behavior.

FxRecord publishes a versioned recording-interest/status record in the private shared control area: recorder identity, subscription/activation ID, intended publisher identity, recording requested, capture start UTC, heartbeat, state and capture stop UTC when applicable. This is recording intent, not simply process existence: a running recorder waiting for live input is participating, whereas a service only finalizing an already-stopped recording no longer requests new media.

RDJ Pro enables durable preservation after observing active recording interest and confirms the activation boundary with FxRecord. FxRecord must not claim protected coverage for fragments preceding that handshake. The active subscription and its last observed status are persisted locally so restarting RDJ Pro during an outage does not silently forget an ongoing recording obligation.

When the link becomes unavailable, RDJ Pro cannot distinguish a disconnected active recorder from one intentionally stopped on the unreachable server. Therefore loss or expiry of the heartbeat must NOT by itself disable preservation for a previously confirmed active subscription. RDJ Pro continues retaining that subscription's media until communication resumes or an explicit locally recorded disable instruction is available. This is necessary to preserve the outage itself.

On reconnection, FxRecord's current status and activation ID determine what to recover. If it remained active, recover the full backlog. If it stopped during the outage, use the persisted capture-stop boundary to recover only material belonging to that recording interval; material exclusively after the stop boundary is not required for that subscription. Preserve any fragment crossing the boundary until its needed portion is safely committed. A new activation is distinct from the previous one, preventing recordings made while FxRecord was off from being attached to its later restart.

On a deliberate normal stop, FxRecord publishes the end of its recording interval before waiting for conversions. RDJ Pro stops creating new recovery entries for that subscription but keeps its unacknowledged earlier entries until safely recovered/acknowledged. Service finalization is not a reason to delete pending recording material.

If FxRecord has never activated recovery for a publisher, an ordinary broadcast-server outage does not activate it. Previously pending entries remain protected even when no current subscription requests new entries.

## Recovery flow

1. While an FxRecord recording subscription requests preservation, RDJ Pro durably saves every complete public fragment and its metadata before enqueueing network delivery. This must happen before connection-loss detection; otherwise the first failed writes can already be lost. The journal lives outside the rolling live directory and survives normal live cleanup, stop, reconnection, codec-session rollover and application restart.
2. Each record has a stable publisher ID, encoder-session ID, sequence number, original UTC capture start, duration, matching initialization-segment ID, payload length and checksum. Initialization segments are immutable in the journal. A count alone cannot identify missing fragments or correctly rebuild an hour.
3. Successful live publishing continues normally. A separate delivery worker stages journal fragments into a private recovery inbox using temporary files and atomic rename. It publishes an availability manifest only after all referenced files in that manifest are complete. The existing authenticated server share can carry this protocol without adding a public unauthenticated upload interface.
4. The first successfully published live.json after reconnection includes a versioned recovery summary: pending count and recovery-manifest ID. The full inventory remains in the private recovery area, rather than growing the browser manifest or delaying live playback. FxRecord also checks this recovery inbox on startup/refresh so losing a single live.json update cannot lose the recovery announcement.
5. FxRecord verifies and commits delivered fragments to its durable original-media store. It records their stable identities in a persisted ledger and publishes acknowledgements only after the media and ledger have been safely committed. A remote file-copy success alone is not an acknowledgement that a recording is recoverable.
6. RDJ Pro deletes a journal entry only after this acknowledgement. Lost acknowledgements cause harmless retries; FxRecord recognizes duplicate identities and acknowledges them without appending twice. Pending backups are never removed by live retention, reconnection reset or normal broadcast-stop cleanup.
7. FxRecord groups original media by capture time, not reconnection time. It merges newly recovered entries with the retained original media for each affected hour, sorts them by their original session/media order, and rebuilds that hour through the reduced-load converter.
8. Rebuilds use fresh work files and validate the resulting media before replacing the existing hourly recording. The existing archive remains available until a complete replacement is ready. Replacement and the recovery ledger need restart-safe commit/reconciliation; a crash must leave either the previous archive or a validated replacement recoverable.
9. After the affected recording is successfully rebuilt and its source inventory is confirmed complete, both ends can release the recovery-only originals according to the retention policy. Keep a lightweight committed-ID ledger for idempotent late retries.

## Hour completeness and original-media retention

The publisher must supply an hour seal/inventory covering all fragments captured for that hour, including fragments across encoder-session changes. FxRecord marks an hour complete only when all referenced media is present and its archive has been committed. If the publisher is offline or the seal is missing, an apparently successful conversion is provisional and its originals remain available for a later rebuild.

This prevents an unbounded requirement to retain every source recording forever while ensuring incomplete hours remain rebuildable. A duplicate retry for a completed/sealed hour is resolved from the ledger. A genuinely conflicting or unexpected late fragment must produce an explicit error, not overwrite a sealed recording silently.

Never rebuild an incomplete hour by transcoding the existing lossy MP3 archive plus the recovered source if the original media can be retained. Rebuild from original fragment media to avoid unnecessary repeated audio encoding.

## Session changes and codec compatibility

Preserve the initialization segment for each encoder session. Reconnection can reset public sequence numbers, so sequence numbers alone are not globally unique. Do not append fragments from incompatible initialization/codec configurations into one MP4 blindly. Compatible sessions need explicit track/timebase mapping; incompatible sessions need a validated conversion path or an explicit pending-recovery error while all originals remain retained.

The hour reconstruction must retain intended elapsed media time and original audio/video offsets across sessions. The previously observed AVI audio timestamp discrepancy should be resolved as part of validating rebuilt output; decode success and byte counts alone do not establish correct synchronization.

## Resource and failure behavior

- Keep payloads on disk, not in an expanding TBytes queue.
- Bound delivery, replay and rebuild batches and keep live recording responsive.
- Serialize archive rebuild/conversion work so catch-up does not recreate simultaneous heavy conversion load.
- Show publisher pending count/bytes, oldest pending capture time, recovery state, affected hours and progress in the relevant settings/status/log interfaces.
- Apply explicit low-disk handling. Never silently evict unacknowledged originals to satisfy the live retention window. Report when preservation cannot continue; no finite disk can guarantee retention through an unlimited outage.
- Log copy failures, unavailable sources, checksum failures, retries, unavailable initialization segments, incomplete hours and rebuild failures in persistent application logs rather than only OutputDebugString.
- FxRecord cannot reliably diagnose the client's wireless link from local files. It can detect stale publisher progress, report that archive input is interrupted, and act on recovery availability. RDJ Pro is responsible for detecting its failed server operations.

## Acceptance checks before deployment

1. Reproduce a 3.5-minute delivery outage while generation continues. Restore the connection and verify the rebuilt hourly audio sample count/content against the uninterrupted local reference; the previous approximately 3m29s deficit must disappear.
2. Cover an outage spanning an hourly boundary; recovered material must rebuild the original affected hours rather than appear in the reconnection hour.
3. Restart RDJ Pro offline, restart FxRecord during recovery, drop acknowledgements and retry batches. Verify durable recovery and no duplicated material.
4. Interrupt staging, source commit, conversion and final archive replacement independently. Preserve the old archive and pending originals until reconciliation finishes.
5. Test session rollover, sequence reset, changing initialization/codec configuration, missing or corrupt fragments and invalid manifests.
6. Exercise low disk space and ensure pending data is not silently deleted.
7. Test FxRecord absent/off, activation during broadcasting, deliberate stop during finalization, stop while disconnected and later restart with a different activation. Verify that new recovery data is created only for the applicable recording interval and that old pending data is preserved.
8. Verify original-media timestamps, audio/video synchronization, full decode, ordinary playback and long-running CPU/memory behavior. Existing live playback remains current during backfill.

## Implementation boundary

This requires coordinated changes to RDJ Pro's fragment publisher/cleanup/mirror worker and FxRecord's manifest handling, archive ledger, source retention and rebuild scheduler. FxServe can continue serving the live stream in the present SMB deployment; it must not apply live cleanup rules to the private recovery area. Schema versioning must permit older producers/recorders to continue their existing behavior without pretending recovery is available.