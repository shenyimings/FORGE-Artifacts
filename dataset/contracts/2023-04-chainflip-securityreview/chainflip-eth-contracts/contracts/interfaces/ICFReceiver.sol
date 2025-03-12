pragma solidity ^0.8.0;

/**
 * @title    CF Receiver interface
 * @dev      The ICFReceiver interface is the interface required to receive tokens and
 *           cross-chain calls from the Chainflip Protocol.
 */
interface ICFReceiver {
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
    ) external payable;

    /**
     * @notice  Receiver of a cross-chain call made by the Chainflip Protocol.

     * @param srcChain      The source chain according to the Chainflip Protocol's nomenclature.
     * @param srcAddress    Bytes containing the source address on the source chain.
     * @param message       The message sent on the source chain. This is a general purpose message.
     */
    function cfReceivexCall(uint32 srcChain, bytes calldata srcAddress, bytes calldata message) external;

    /**
     * @notice           Update Chanflip's Vault address.
     * @param cfVault    New Chainflip's Vault address.
     */
    function updateCfVault(address cfVault) external;
}
