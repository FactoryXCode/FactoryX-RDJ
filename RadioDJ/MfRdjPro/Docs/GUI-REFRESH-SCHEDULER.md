# RDJ Pro shared GUI refresh scheduler

The next RDJ Pro version uses MfPack's `TMfGuiRefreshTimer` for the main clock,
audio graph recovery checks and listener-count refresh scheduling. The existing
handler and its 1000 ms interval are retained. Its event executes on the VCL
main thread, through a custom posted message.

The scheduler shares one worker across component instances and keeps at most
one GUI notification pending. Missed refreshes are collapsed rather than
replayed. This prevents the main clock from depending on low-priority
`WM_TIMER` delivery during a continuously busy GUI message queue.

For compatibility with currently installed design-time packages, the original
`tmrClock: TTimer` remains in the DFM, disabled. Its designer interval supplies
the interval of the runtime `FUiRefreshTimer`. The runtime component starts
after UI initialization, stops when closing begins and is freed before the
form's other services. There are no visual layout changes and the form can
still open before the new component package has been installed.

To use the new component directly in other forms, rebuild/install the updated
`Samples/MfComponents/MfComponents.dpk`; it appears on **MfPack Timer Samples**.
See [component usage and lifetime rules](../../../MfComponents/MfGuiRefreshTimer.md).

The component is not an audio timer. Audio rendering, capture and encoding keep
their existing worker threads. This change does not establish a higher safe
simultaneous deck capacity or address a long audio-processing callback stall.
Existing per-control peak-meter timers and other form timers are unchanged.

