// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import { IAxelarGateway } from '../../interfaces/IAxelarGateway.sol';
import { IERC20 } from '../../interfaces/IERC20.sol';

contract SourceChainSwapCaller {
    IAxelarGateway public gateway;
    string public destinationChain;
    string public executableAddress;

    constructor(
        address gateway_,
        string memory destinationChain_,
        string memory executableAddress_
    ) {
        gateway = IAxelarGateway(gateway_);
        destinationChain = destinationChain_;
        executableAddress = executableAddress_;
    }

    function swapToken(
        string memory symbolX,
        string memory symbolY,
        uint256 amount,
        string memory recipient
    ) external {
        address tokenX = gateway.tokenAddresses(symbolX);
        bytes memory payload = abi.encode(symbolY, recipient);

        IERC20(tokenX).transferFrom(msg.sender, address(this), amount);

        IERC20(tokenX).approve(address(gateway), amount);
        gateway.callContractWithToken(destinationChain, executableAddress, payload, symbolX, amount);
    }
}
