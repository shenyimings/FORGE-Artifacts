// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../bridge/Bridge.sol";
import "../bridge/GasToken.sol";
import "../bridge/SequencerInbox.sol";
import "../bridge/ISequencerInbox.sol";
import "../bridge/Inbox.sol";
import "../bridge/Outbox.sol";
import "./RollupEventInbox.sol";

import "../bridge/IBridge.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract BridgeCreator is Ownable {
    Bridge public bridgeTemplate;
    SequencerInbox public sequencerInboxTemplate;
    Inbox public inboxTemplate;
    RollupEventInbox public rollupEventInboxTemplate;
    Outbox public outboxTemplate;
    GasToken public gasTokenTemplate;

    event TemplatesUpdated();

    constructor() Ownable() {
        bridgeTemplate = new Bridge();
        sequencerInboxTemplate = new SequencerInbox();
        inboxTemplate = new Inbox();
        rollupEventInboxTemplate = new RollupEventInbox();
        outboxTemplate = new Outbox();
        gasTokenTemplate = new GasToken();
    }

    function updateTemplates(
        address _bridgeTemplate,
        address _sequencerInboxTemplate,
        address _inboxTemplate,
        address _rollupEventInboxTemplate,
        address _outboxTemplate,
        address _gasTokenTemplate
    ) external onlyOwner {
        bridgeTemplate = Bridge(_bridgeTemplate);
        sequencerInboxTemplate = SequencerInbox(_sequencerInboxTemplate);
        inboxTemplate = Inbox(_inboxTemplate);
        rollupEventInboxTemplate = RollupEventInbox(_rollupEventInboxTemplate);
        outboxTemplate = Outbox(_outboxTemplate);
        gasTokenTemplate = GasToken(_gasTokenTemplate);

        emit TemplatesUpdated();
    }

    struct CreateBridgeFrame {
        ProxyAdmin admin;
        Bridge bridge;
        SequencerInbox sequencerInbox;
        Inbox inbox;
        RollupEventInbox rollupEventInbox;
        Outbox outbox;
        GasToken gasToken;
    }

    function createBridge(
        address adminProxy,
        address rollup,
        address to,
        ISequencerInbox.MaxTimeVariation memory maxTimeVariation
    ) external returns (Bridge, SequencerInbox, Inbox, RollupEventInbox, Outbox) {
        CreateBridgeFrame memory frame;
        {
            frame.bridge = Bridge(
                address(new TransparentUpgradeableProxy(address(bridgeTemplate), adminProxy, ""))
            );
            frame.sequencerInbox = SequencerInbox(
                address(
                    new TransparentUpgradeableProxy(address(sequencerInboxTemplate), adminProxy, "")
                )
            );
            frame.inbox = Inbox(
                address(new TransparentUpgradeableProxy(address(inboxTemplate), adminProxy, ""))
            );
            frame.rollupEventInbox = RollupEventInbox(
                address(
                    new TransparentUpgradeableProxy(
                        address(rollupEventInboxTemplate),
                        adminProxy,
                        ""
                    )
                )
            );
            frame.outbox = Outbox(
                address(new TransparentUpgradeableProxy(address(outboxTemplate), adminProxy, ""))
            );

            frame.gasToken = GasToken(
                address(new TransparentUpgradeableProxy(address(gasTokenTemplate), adminProxy, ""))
            );
        }

        frame.bridge.initialize(IOwnable(rollup));
        frame.sequencerInbox.initialize(IBridge(frame.bridge), maxTimeVariation);
        frame.inbox.initialize(IBridge(frame.bridge), ISequencerInbox(frame.sequencerInbox));
        frame.rollupEventInbox.initialize(IBridge(frame.bridge));
        frame.outbox.initialize(IBridge(frame.bridge));
        frame.gasToken.initialize(address(frame.bridge), address(frame.inbox), to, 10000e18);

        frame.bridge.setGasToken(IGasToken(frame.gasToken));

        return (
            frame.bridge,
            frame.sequencerInbox,
            frame.inbox,
            frame.rollupEventInbox,
            frame.outbox
        );
    }
}
