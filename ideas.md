# Droobi — Ideas Corner

A parking lot for improvements worth evaluating.

## Navigation reliability
- Add a clear diagnostic reason for each startup failure.
- Separate navigation-session state from temporary guidance availability.
- Add a controlled GPS-loss recovery path and make recovery visible.
- Review rerouting thresholds against real campus walking traces.
- Keep arrival confirmation based on multiple independent location fixes.

## Testing and observability
- Create repeatable scenarios for weak GPS, stale fixes, and route failures.
- Record route progress and off-route decisions during a session.
- Compare expected turns with the guidance actually presented to the user.
- Document device, location conditions, and outcome for each field test.

## User experience
- Make waiting, recovering, and arrived states visually distinct.
- Avoid abrupt or contradictory direction changes.
- Keep vibration patterns event-based and meaningful.

Nothing in this file is implemented or promised. These are proposals for future
evaluation; they should be validated before becoming requirements.
