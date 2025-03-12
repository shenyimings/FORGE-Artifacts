// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../feeds/OverlayV1FeedFactory.sol";
import "./OverlayV1FeedMock.sol";

contract OverlayV1FeedFactoryMock is OverlayV1FeedFactory {
    mapping(uint256 => mapping(uint256 => address)) public getFeed;

    constructor(uint256 _microWindow, uint256 _macroWindow)
        OverlayV1FeedFactory(_microWindow, _macroWindow)
    {}

    /// @dev deploy mock feed
    function deployFeed(uint256 price, uint256 reserve) external returns (address feed_) {
        require(getFeed[price][reserve] == address(0), "OVLV1: feed already exists");

        // Use the CREATE2 opcode to deploy a new Feed contract.
        // Will revert if feed which accepts (price, reserve)
        // in its constructor has already been deployed since salt would be the same and can't
        // deploy with it twice.
        feed_ = address(
            new OverlayV1FeedMock{salt: keccak256(abi.encode())}(
                microWindow,
                macroWindow,
                price,
                reserve
            )
        );

        // store feed registry record for (price, reserve) combo
        // and mark feed address as feed
        getFeed[price][reserve] = feed_;
        isFeed[feed_] = true;
        emit FeedDeployed(msg.sender, feed_);
    }
}
