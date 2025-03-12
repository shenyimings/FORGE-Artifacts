pragma solidity 0.5.16;

import { AbsBToken } from "./AbsBToken.sol";
import { IAvatarCEther } from "../interfaces/IAvatar.sol";

contract BEther is AbsBToken {

    constructor(
        address _registry,
        address _cToken
    ) public AbsBToken(_registry, _cToken) {}

    function _myAvatarCEther() internal returns (IAvatarCEther) {
        return IAvatarCEther(address(_myAvatar()));
    }

    // mint()
    function mint() external payable {
        // CEther calls requireNoError() to ensure no failures
        _myAvatarCEther().mint.value(msg.value)();
    }

    function mintOnAvatar(address _avatar) external onlyDelegatee(_avatar) payable {
        // CEther calls requireNoError() to ensure no failures
        IAvatarCEther(_avatar).mint.value(msg.value)();
    }

    // repayBorrow()
    function repayBorrow() external payable {
        // CEther calls requireNoError() to ensure no failures
        _myAvatarCEther().repayBorrow.value(msg.value)();
    }

    function repayBorrowOnAvatar(address _avatar) external onlyDelegatee(_avatar) payable {
        // CEther calls requireNoError() to ensure no failures
        IAvatarCEther(_avatar).repayBorrow.value(msg.value)();
    }
}