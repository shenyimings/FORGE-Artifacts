// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC677Receiver} from "./../../token/ERC20/interfaces/IERC677Receiver.sol";
import {VRFV2WrapperInterface} from "@chainlink/contracts/src/v0.8/interfaces/VRFV2WrapperInterface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract VRFV2WrapperMock is IERC677Receiver, VRFV2WrapperInterface {
    uint256 public lastRequestId;

    mapping(uint256 => VRFConsumerBaseV2) public consumers;
    mapping(uint256 => uint32) public numWords;

    function calculateRequestPrice(uint32) external pure returns (uint256) {
        return 100;
    }

    function estimateRequestPrice(uint32, uint256) external pure returns (uint256) {
        return 100;
    }

    function onTokenTransfer(address from, uint256, bytes calldata data) external returns (bool) {
        (, , uint32 nWords) = abi.decode(data, (uint32, uint16, uint32));
        uint256 requestId = lastRequestId + 1;
        consumers[requestId] = VRFConsumerBaseV2(from);
        numWords[requestId] = nWords;
        lastRequestId = requestId;
        return true;
    }

    function fulfillRandomnessRequest(uint256 requestId) external {
        uint32 nWords = numWords[requestId];
        uint256[] memory randomWords = new uint256[](nWords);
        for (uint256 i; i < nWords; ++i) {
            randomWords[i] = 123;
        }
        consumers[requestId].rawFulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(VRFConsumerBaseV2 consumer, uint256 requestId, uint256[] memory randomWords) external {
        consumer.rawFulfillRandomWords(requestId, randomWords);
    }
}
