// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract UserProxy {
    address private _owner;

    /**
     * @dev Initializes the contract settings
     */
    constructor() {
        _owner = msg.sender;
    }

    /**
     * @dev Transfers punk to the smart contract owner
     */
    function transfer(address punkContract, uint256 punkIndex) external returns (bool) {
        if (_owner != msg.sender) {
            return false;
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool result, ) = punkContract.call(
            abi.encodeWithSignature("transferPunk(address,uint256)", _owner, punkIndex)
        );

        return result;
    }
}
