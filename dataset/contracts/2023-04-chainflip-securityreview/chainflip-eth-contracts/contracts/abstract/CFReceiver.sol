pragma solidity ^0.8.0;

import "../interfaces/ICFReceiver.sol";

/**
 * @title    CFReceiver
 * @dev      This abstract contract is the base implementation for a smart contract
 *           capable of receiving cross-chain swaps and calls from the Chainflip Protocol.
 *           It has a check to ensure that the functions can only be called by one
 *           address, which should be the Chainflip Protocol. This way it is ensured that
 *           the receiver will be sent the amount of tokens passed as parameters and
 *           that the cross-chain call originates from the srcChain and address specified.
 *           This contract should be inherited and then user's logic should be implemented
 *           as the internal functions (_cfReceive and _cfReceivexCall).
 *           Remember that anyone on the source chain can use the Chainflip Protocol
 *           to make a cross-chain call to this contract. If that is not desired, an extra
 *           check on the source address and source chain should be performed.
 */

abstract contract CFReceiver is ICFReceiver {
    /// @dev    Chainflip's Vault address where xSwaps and xCalls will be originated from.
    address public cfVault;
    address public owner;

    constructor(address _cfVault) {
        cfVault = _cfVault;
        owner = msg.sender;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                   CF Vault calls                         //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /**
     * @notice  Receiver of a cross-chain swap and call made by the Chainflip Protocol.

     * @param srcChain      The source chain according to the Chainflip Protocol's nomenclature.
     * @param srcAddress    Bytes containing the source address on the source chain.
     * @param message       The message sent on the source chain. This is a general purpose message.
     * @param token         Address of the token received.
     * @param amount        Amount of tokens received.
     */
    function cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) external payable override onlyCfVault {
        _cfReceive(srcChain, srcAddress, message, token, amount);
    }

    /**
     * @notice  Receiver of a cross-chain call made by the Chainflip Protocol.

     * @param srcChain      The source chain according to the Chainflip Protocol's nomenclature.
     * @param srcAddress    Bytes containing the source address on the source chain.
     * @param message       The message sent on the source chain. This is a general purpose message.
     */
    function cfReceivexCall(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message
    ) external override onlyCfVault {
        _cfReceivexCall(srcChain, srcAddress, message);
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //             User's logic to be implemented               //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev Internal function to be overriden by the user's logic.
    function _cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) internal virtual;

    /// @dev Internal function to be overriden by the user's logic.
    function _cfReceivexCall(uint32 srcChain, bytes calldata srcAddress, bytes calldata message) internal virtual;

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                 Update Vault address                     //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev Update Chainflip's Vault address
    function updateCfVault(address _cfVault) external override onlyOwner {
        cfVault = _cfVault;
    }

    //////////////////////////////////////////////////////////////
    //                                                          //
    //                          Modifiers                       //
    //                                                          //
    //////////////////////////////////////////////////////////////

    /// @dev Check that the sender is the Chainflip's Vault.
    modifier onlyCfVault() {
        require(msg.sender == cfVault, "CFReceiver: caller not Chainflip sender");
        _;
    }

    /// @dev Check that the sender is the owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "CFReceiver: caller not owner");
        _;
    }
}
