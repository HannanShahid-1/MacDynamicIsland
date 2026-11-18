import Foundation

/// JavaScript for Automation source run by `/usr/bin/osascript`.
///
/// Since macOS 15.4 the system only answers Now Playing queries from Apple's own
/// processes, so the app cannot ask directly. `osascript` is allowed, and its
/// Objective-C bridge can talk to the MediaRemote framework without sending any
/// Apple Events (so no Automation permission prompt is involved).
///
/// The script prints one JSON object per line, decoded by
/// `SystemNowPlayingSnapshot`: immediately whenever the app, track, playback
/// state, or artwork changes, and once a second while something is playing so
/// the position stays fresh. It exits when the app that launched it goes away.
enum SystemNowPlayingHelperScript {
    static let source = #"""
    ObjC.import('Foundation');
    ObjC.import('stdlib');
    ObjC.bindFunction('getppid', ['int', []]);
    $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework').load;

    const stdout = $.NSFileHandle.fileHandleWithStandardOutput;
    const parent = $.getppid();

    function emit(message) {
        stdout.writeData($(JSON.stringify(message) + '\n').dataUsingEncoding($.NSUTF8StringEncoding));
    }

    function text(value) {
        try {
            const unwrapped = ObjC.unwrap(value);
            return typeof unwrapped === 'string' && unwrapped.length > 0 ? unwrapped : null;
        } catch (error) {
            return null;
        }
    }

    function number(value) {
        const converted = Number(value);
        return isFinite(converted) ? converted : null;
    }

    function makeController() {
        const destination = $.NSClassFromString('MRDestination').localDestination;
        const configuration = $.NSClassFromString('MRNowPlayingControllerConfiguration').alloc.initWithDestination(destination);
        const queueRequest = $.NSClassFromString('MRPlaybackQueueRequest').defaultPlaybackQueueRequest;
        queueRequest.setArtworkWidth(600);
        queueRequest.setArtworkHeight(600);
        configuration.setPlaybackQueueRequest(queueRequest);
        configuration.setRequestPlaybackState(true);
        configuration.setRequestClientProperties(true);
        configuration.setRequestSupportedCommands(true);
        const controller = $.NSClassFromString('MRNowPlayingController').alloc.initWithConfiguration(configuration);
        if (controller.isNil()) { throw new Error('MRNowPlayingController unavailable'); }
        controller.beginLoadingUpdates;
        return controller;
    }

    function snapshot(controller) {
        const response = controller.response;
        if (response.isNil()) { return { active: false }; }

        const client = response.playerPath.client;
        const bundleID = text(client.bundleIdentifier);
        if (bundleID === null) { return { active: false }; }

        const state = {
            active: true,
            bundleID: bundleID,
            parentBundleID: text(client.parentApplicationBundleIdentifier),
            appName: text(client.displayName),
            playbackState: number(response.playbackState),
            commands: []
        };

        const commands = response.supportedCommands;
        if (!commands.isNil()) {
            for (let index = 0; index < Number(commands.count); index++) {
                const info = commands.objectAtIndex(index);
                if (info.isEnabled) { state.commands.push(Number(info.command)); }
            }
        }

        const items = response.playbackQueue.contentItems;
        if (items.isNil() || Number(items.count) === 0) { return state; }

        const item = items.objectAtIndex(0);
        const metadata = item.metadata;
        state.title = text(metadata.title);
        state.artist = text(metadata.trackArtistName);
        state.album = text(metadata.albumName);
        const duration = number(metadata.duration);
        state.duration = duration !== null && duration > 0 ? duration : null;
        state.elapsed = state.duration === null ? null : number(metadata.calculatedPlaybackPosition);

        const artwork = item.artwork;
        if (!artwork.isNil() && !artwork.imageData.isNil() && Number(artwork.imageData.length) > 0) {
            state.artworkID = (text(metadata.artworkIdentifier) || '') + ':' + Number(artwork.imageData.length);
            state.artworkData = artwork.imageData;
        }
        return state;
    }

    let controller;
    try {
        controller = makeController();
    } catch (error) {
        emit({ error: String(error) });
        $.exit(1);
    }

    let lastIdentity = null;
    let lastArtworkKey = null;
    let lastEmit = 0;

    while ($.getppid() === parent) {
        let state;
        try { state = snapshot(controller); } catch (error) { state = { active: false }; }

        const artworkData = state.artworkData;
        delete state.artworkData;

        const identity = JSON.stringify([
            state.active, state.bundleID, state.playbackState, state.commands,
            state.title, state.artist, state.album, state.duration, state.artworkID
        ]);
        const artworkKey = JSON.stringify([state.bundleID, state.title, state.artist, state.album, state.artworkID]);
        const now = Date.now();
        const isPlaying = state.active && state.playbackState === 1;

        if (identity !== lastIdentity || (isPlaying && now - lastEmit >= 1000)) {
            if (artworkData !== undefined && artworkKey !== lastArtworkKey) {
                state.artwork = ObjC.unwrap(artworkData.base64EncodedStringWithOptions(0));
            }
            lastArtworkKey = artworkData !== undefined ? artworkKey : null;
            lastIdentity = identity;
            lastEmit = now;
            emit(state);
        }

        delay(0.25);
    }
    """#
}
