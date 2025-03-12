// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interfaces/IOverlayV1Deployer.sol";
import "./libraries/Risk.sol";
import "./OverlayV1Market.sol";

contract OverlayV1Deployer is IOverlayV1Deployer {
    address public immutable factory; // factory that has gov permissions

    // factory modifier for governance sensitive functions
    modifier onlyFactory() {
        require(msg.sender == factory, "OVLV1: !factory");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function deploy(
        address ovl,
        address feed,
        Risk.Params memory params
    ) external onlyFactory returns (address market_) {
        // Use the CREATE2 opcode to deploy a new Market contract.
        // Will revert if market which accepts feed in its constructor has already
        // been deployed since salt would be the same and can't deploy with it twice.
        market_ = address(
            new OverlayV1Market{salt: keccak256(abi.encode(feed))}(
                address(ovl),
                feed,
                factory,
                params
            )
        );
    }
}
